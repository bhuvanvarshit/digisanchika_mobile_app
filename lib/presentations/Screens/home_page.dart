// presentations/Screens/home_page.dart - FIXED VERSION
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/models/folder.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/my_documents_service.dart';
import 'package:digi_sanchika/presentations/Screens/document_library.dart';
import 'package:digi_sanchika/presentations/Screens/upload_document.dart';
import 'package:digi_sanchika/presentations/Screens/folder_screen.dart'; // NEW
import 'package:digi_sanchika/presentations/Screens/shared_me.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  const HomePage({super.key, this.userName, this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _newKeywordController = TextEditingController();

  List<Document> allDocuments = []; // CHANGED: Store ALL documents here
  List<Folder> folders = [];
  bool _showRecent = false;
  bool _showFolderDropdown = false;
  bool _showDocumentsDropdown = true;
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isUploading = false;
  int? _currentFolderId;
  Document? _selectedDocument;
  String _searchScope = 'my-documents';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();

    _initializeBackend();

    _tabController.addListener(() {
      if (_tabController.index == 1) {
        setState(() {});
      } else if (_tabController.index == 0) {
        _refreshData();
      }
    });
  }

  Future<void> _initializeBackend() async {
    await ApiService.initialize();
    if (ApiService.isConnected) {
      await _loadAllUserDocuments(); // CHANGED: Use new method
    }
  }

  Future<void> _refreshData() async {
    await ApiService.checkConnection();
    if (ApiService.isConnected) {
      await _loadAllUserDocuments(); // CHANGED: Use new method
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced from backend'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await _loadDataFromLocalStorage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using local storage (offline)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadDataFromLocalStorage() async {
    try {
      final localDocs = await LocalStorageService.loadDocuments();
      setState(() {
        allDocuments = localDocs;
        _organizeDocumentsIntoFolders();
      });
    } catch (e) {
      print('Error loading from local storage: $e');
    }
  }

  void _organizeDocumentsIntoFolders() {
    for (var folder in folders) {
      folder.documents.clear();
    }

    if (folders.isEmpty || !folders.any((f) => f.name == 'Home')) {
      folders.insert(
        0,
        Folder(
          name: 'Home',
          id: 'home',
          documents: [],
          createdAt: DateTime.now(),
          owner: widget.userName ?? 'User',
        ),
      );
    }

    for (var document in allDocuments) {
      String folderName = document.folder;
      if (folderName.isEmpty || folderName == 'Home') {
        final homeFolder = folders.firstWhere((f) => f.name == 'Home');
        homeFolder.documents.add(document);
      } else {
        var folder = folders.firstWhere(
          (f) => f.name == folderName,
          orElse: () {
            final newFolder = Folder(
              name: folderName,
              id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
              documents: [],
              createdAt: DateTime.now(),
              owner: widget.userName ?? 'User',
            );
            folders.add(newFolder);
            return newFolder;
          },
        );
        folder.documents.add(document);
      }
    }
  }

  // NEW METHOD: Get all folder IDs from /my-folders
  Future<List<int>> _getAllFolderIds() async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/my-folders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> foldersData = jsonDecode(response.body);
        List<int> allIds = [];

        void extractIds(List<dynamic> folderList) {
          for (var folder in folderList) {
            allIds.add(folder['id'] as int);
            if (folder['children'] != null && folder['children'].isNotEmpty) {
              extractIds(folder['children']);
            }
          }
        }

        extractIds(foldersData);
        print('📁 Found ${allIds.length} folder IDs');
        return allIds;
      }
    } catch (e) {
      print('Error getting folders: $e');
    }
    return [];
  }

  // In home_page.dart, line 196:
  List<Document> _convertToDocumentList(
    List<dynamic> docList,
    int? folderId,
    String folderPath,
  ) {
    return docList.map<Document>((doc) {
      // Add <Document> type parameter
      return Document(
        id: doc['id'].toString(),
        name: doc['original_filename'],
        type: _extractFileType(doc['original_filename']),
        size: '${doc['file_size'] ?? 'Unknown'} bytes',
        keyword: doc['keywords'] ?? '',
        uploadDate: doc['upload_date']?.toString() ?? '',
        owner: doc['owner']['name'] ?? 'Unknown',
        details: doc['remarks'] ?? '',
        classification: doc['doc_class'] ?? 'General',
        allowDownload: doc['allow_download'] ?? true,
        sharingType: doc['is_public'] ? 'Public' : 'Private',
        folder: folderPath,
        folderId: folderId?.toString(), // Now int? -> String? works
        path: doc['original_filename'],
        fileType: _extractFileType(doc['original_filename']),
      );
    }).toList();
  }

  // NEW METHOD: Load ALL user documents from all folders
  Future<void> _loadAllUserDocuments() async {
    if (!ApiService.isConnected) {
      print('⚠ Skipping backend load - not connected');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Loading ALL user documents...');

      // 1. Get all folder IDs
      List<int> allFolderIds = await _getAllFolderIds();

      // 2. Create batch requests
      List<Future<Map<String, dynamic>>> futures = [];

      // Root request (no folder_id)
      futures.add(_fetchMyDocumentsWithParams(null));

      // Folder requests
      for (int folderId in allFolderIds) {
        futures.add(_fetchMyDocumentsWithParams(folderId));
      }

      // 3. Execute in parallel
      print('🚀 Executing ${futures.length} parallel requests...');
      List<Map<String, dynamic>> results = await Future.wait(futures);

      // 4. Process results
      List<Document> combinedDocuments = [];
      List<Folder> allFolders = [];

      // Process root (index 0)
      if (results.isNotEmpty && results[0]['documents'] != null) {
        combinedDocuments.addAll(
          _convertToDocumentList(results[0]['documents'], null, 'Home'),
        );

        // Get folders from root response
        if (results[0]['folders'] != null) {
          for (var folder in results[0]['folders']) {
            allFolders.add(
              Folder(
                id: folder['id'].toString(),
                name: folder['name'],
                documents: [],
                createdAt: DateTime.parse(folder['created_at']),
                owner: widget.userName ?? 'User',
              ),
            );
          }
        }
      }

      // Process folders (index 1 onwards)
      for (int i = 1; i < results.length; i++) {
        if (results[i]['documents'] != null &&
            results[i]['documents'].isNotEmpty) {
          int folderId = allFolderIds[i - 1];
          String folderPath =
              results[i]['documents'][0]['folder_path'] ?? 'Unknown';

          combinedDocuments.addAll(
            _convertToDocumentList(
              results[i]['documents'],
              folderId,
              folderPath,
            ),
          );
        }
      }

      // 5. Update UI
      setState(() {
        allDocuments = combinedDocuments;
        folders = allFolders;

        // Add Home folder if not present
        if (!folders.any((f) => f.name == 'Home')) {
          folders.insert(
            0,
            Folder(
              name: 'Home',
              id: 'home',
              documents: [],
              createdAt: DateTime.now(),
              owner: widget.userName ?? 'User',
            ),
          );
        }

        print(
          '✅ Loaded ${allDocuments.length} total documents from ${results.length} sources',
        );
      });

      // 6. Save to local storage
      try {
        await LocalStorageService.saveDocuments(allDocuments);
        print('💾 Saved ${allDocuments.length} documents to local storage');
      } catch (e) {
        print('⚠ Error saving to local storage: $e');
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _loadAllUserDocuments: $e');
      print('Stack trace: $stackTrace');
      await _loadDataFromLocalStorage();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to fetch documents with parameters
  Future<Map<String, dynamic>> _fetchMyDocumentsWithParams(
    int? folderId,
  ) async {
    try {
      final headers = await _createAuthHeaders();
      String url = '${ApiService.baseUrl}/my-documents';

      if (folderId != null) {
        url += '?folder_id=$folderId';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'documents': [], 'folders': []};
      }
    } catch (e) {
      print('Error fetching documents for folder $folderId: $e');
      return {'documents': [], 'folders': []};
    }
  }

  // OLD METHOD: Keep for reference but don't use
  Future<void> _loadDataFromBackend() async {
    // This method is replaced by _loadAllUserDocuments
    await _loadAllUserDocuments();
  }

  void _loadInitialData() {
    setState(() {
      folders.add(
        Folder(
          name: 'Home',
          id: 'home',
          documents: [],
          createdAt: DateTime.now(),
          owner: widget.userName ?? 'User',
        ),
      );
    });
  }

  void _addNewDocument(Document document) async {
    setState(() {
      allDocuments.add(document); // CHANGED: Use allDocuments
      _organizeDocumentsIntoFolders();
    });

    final isPublic = document.sharingType == 'Public';
    await LocalStorageService.addDocument(document, isPublic: isPublic);
  }

  void _addNewFolder(String folderName) {
    if (folderName.isEmpty) return;

    setState(() {
      folders.add(
        Folder(
          name: folderName,
          id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
          documents: [],
          createdAt: DateTime.now(),
          owner: widget.userName ?? 'User',
        ),
      );
    });
  }

  Future<void> _createFolderInBackend(String folderName) async {
    if (!ApiService.isConnected) {
      _addNewFolder(folderName);
      return;
    }

    try {
      final result = await MyDocumentsService.createFolder(
        folderName: folderName,
        parentFolderId: _currentFolderId,
      );

      if (result['success'] == true) {
        _addNewFolder(folderName);
        _refreshData();
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      print('Error creating folder in backend: $e');
      _addNewFolder(folderName);
    }
  }

  Future<Map<String, String>> _createAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      if (ApiService.getSessionCookie != null) {
        final cookie = await ApiService.getSessionCookie();
        if (cookie != null && cookie.isNotEmpty) {
          headers['Cookie'] = 'session_id=$cookie';
        }
      }
    } catch (e) {
      print('⚠ Could not get session cookie: $e');
    }

    return headers;
  }

  Future<void> _deleteFolder(int index) async {
    if (index >= 0 && index < folders.length) {
      final folder = folders[index];
      final folderName = folder.name;

      if (ApiService.isConnected && folder.id != 'home') {
        try {
          final result = await MyDocumentsService.deleteFolder(folder.id);
          if (result['success'] != true) {
            throw Exception(result['error']);
          }
        } catch (e) {
          print('Error deleting folder from backend: $e');
        }
      }

      // Remove documents from this folder
      allDocuments.removeWhere((doc) => doc.folder == folderName);
      setState(() {
        folders.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder "$folderName" deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteDocument(int index) async {
    if (index >= 0 && index < allDocuments.length) {
      Document docToDelete = allDocuments[index];

      try {
        if (ApiService.isConnected) {
          await MyDocumentsService.deleteDocument(docToDelete.id);
        }

        setState(() {
          allDocuments.removeAt(index);
          _organizeDocumentsIntoFolders();
        });

        await LocalStorageService.deleteDocument(
          docToDelete.name,
          isPublic: docToDelete.sharingType == 'Public',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document "${docToDelete.name}" deleted successfully',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(Document document) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot download while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final result = await MyDocumentsService.downloadDocument(document.id);

      if (result['success'] == true) {
        // FIXED: Now downloads to app's private directory
        final directory = await getDownloadDirectory();
        final filePath = '${directory.path}/${document.name}';
        final file = File(filePath);
        await file.writeAsBytes(result['data'] as List<int>);

        print('✅ Downloaded to: $filePath');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${document.name}'),
            backgroundColor: Colors.green,
          ),
        );

        // FIXED: Open with FileProvider URI on Android
        try {
          final uriToOpen = Platform.isAndroid
              ? _getFileProviderUri(filePath)
              : filePath;

          print('📂 Opening with: $uriToOpen');

          final result = await OpenFilex.open(uriToOpen);

          if (result.type != ResultType.done) {
            print('⚠ Could not open file automatically: ${result.message}');

            // Fallback: Try normal path if URI fails
            if (Platform.isAndroid) {
              print('🔄 Trying fallback with normal path...');
              try {
                await OpenFilex.open(filePath);
              } catch (fallbackError) {
                print('⚠ Fallback also failed: $fallbackError');
              }
            }
          }
        } catch (e) {
          print('⚠ Error opening file: $e');
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // FIX: Use app's private directory (works without permissions)
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      // For iOS, use documents directory
      return await getApplicationDocumentsDirectory();
    }
    return Directory.current;
  }

  // ADD THIS HELPER METHOD RIGHT BEFORE _downloadDocument() method:
  String _getFileProviderUri(String filePath) {
    if (Platform.isAndroid) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          // Get just the filename from the full path
          final fileName = file.path.split('/').last;
          // Create FileProvider URI format
          return 'content://com.example.digi_sanchika.fileprovider/files/$fileName';
        }
      } catch (e) {
        print('⚠ Error creating FileProvider URI: $e');
      }
    }
    // For iOS, return normal path
    return filePath;
  }

  Future<void> _showDocumentVersions(Document document) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot view versions while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await MyDocumentsService.getDocumentVersions(document.id);

      if (result['success'] == true) {
        final versions = result['versions'] as List;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Document Versions'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: versions.length,
                itemBuilder: (context, index) {
                  final version = versions[index];
                  return ListTile(
                    leading: Icon(
                      version['is_current']
                          ? Icons.check_circle
                          : Icons.history,
                      color: version['is_current'] ? Colors.green : Colors.grey,
                    ),
                    title: Text('Version ${version['version_number']}'),
                    subtitle: Text(
                      'Uploaded: ${_formatDate(version['upload_date'])}',
                    ),
                    trailing: version['is_current']
                        ? const Text(
                            'Current',
                            style: TextStyle(color: Colors.green),
                          )
                        : null,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load versions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toString().split(' ')[0];
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _showShareDialog(Document document) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot share while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await MyDocumentsService.getUsersForSharing();

      if (result['success'] == true) {
        final users = result['users'] as List;
        final selectedUsers = <String>[];

        await showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Share Document'),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    children: [
                      Text('Share: ${document.name}'),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected = selectedUsers.contains(
                              user['id'].toString(),
                            );
                            return CheckboxListTile(
                              title: Text(user['name']),
                              subtitle: Text(user['employee_id']),
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedUsers.add(user['id'].toString());
                                  } else {
                                    selectedUsers.remove(user['id'].toString());
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedUsers.isNotEmpty) {
                        try {
                          await MyDocumentsService.shareDocument(
                            documentId: document.id,
                            userIds: selectedUsers,
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Document shared successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Share failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Share'),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFolderShareDialog(Folder folder) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot share while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await MyDocumentsService.getUsersForSharing();

      if (result['success'] == true) {
        final users = result['users'] as List;
        final selectedUsers = <String>[];

        await showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Share Folder'),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    children: [
                      Text('Share: ${folder.name}'),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected = selectedUsers.contains(
                              user['id'].toString(),
                            );
                            return CheckboxListTile(
                              title: Text(user['name']),
                              subtitle: Text(user['employee_id']),
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedUsers.add(user['id'].toString());
                                  } else {
                                    selectedUsers.remove(user['id'].toString());
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedUsers.isNotEmpty) {
                        try {
                          await MyDocumentsService.shareFolder(
                            folderId: folder.id,
                            userIds: selectedUsers,
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Folder shared successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Share failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Share'),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDocumentDetails(Document document) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot load details while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await MyDocumentsService.getDocumentDetails(document.id);

      if (result['success'] == true) {
        final details = result['details'];
        setState(() {
          _selectedDocument = Document(
            id: details['id'].toString(),
            name: details['original_filename'],
            type: _extractFileType(details['original_filename']),
            size: '${details['file_size'] ?? 'Unknown'} bytes',
            keyword: details['keywords'] ?? '',
            uploadDate: _formatDate(details['upload_date']),
            owner: details['owner']['name'] ?? 'Unknown',
            details: details['remarks'] ?? '',
            classification: details['doc_class'] ?? 'General',
            allowDownload: details['allow_download'] ?? true,
            sharingType: details['is_public'] ? 'Public' : 'Private',
            folder: details['folder_path'] ?? 'Home',
            folderId: details['folder_id']?.toString(), // Can be null
            path: details['original_filename'],
            fileType: _extractFileType(details['original_filename']),
          );
        });
      }
    } catch (e) {
      print('Error loading document details: $e');
    }
  }

  String _extractFileType(String filename) {
    final ext = path.extension(filename).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'PDF';
      case '.doc':
      case '.docx':
        return 'DOCX';
      case '.xls':
      case '.xlsx':
        return 'XLSX';
      case '.ppt':
      case '.pptx':
        return 'PPTX';
      case '.txt':
        return 'TXT';
      default:
        return ext.replaceAll('.', '').toUpperCase();
    }
  }

  Future<void> _showEnhancedSearchDialog() async {
    final searchCriteria = <String, dynamic>{
      'keyword': '',
      'filename': '',
      'user': '',
      'use_keyword': false,
      'use_filename': false,
      'use_user': false,
      'use_date': false,
      'from_date': '',
      'to_date': '',
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Advanced Search'),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 500),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSearchScopeSelector(setState),
                    const SizedBox(height: 20),
                    _buildSearchField(
                      'Keyword',
                      searchCriteria['keyword'] as String,
                      (value) => searchCriteria['keyword'] = value,
                      searchCriteria['use_keyword'] as bool,
                      (value) => searchCriteria['use_keyword'] = value,
                      Icons.search,
                    ),
                    _buildSearchField(
                      'Filename',
                      searchCriteria['filename'] as String,
                      (value) => searchCriteria['filename'] = value,
                      searchCriteria['use_filename'] as bool,
                      (value) => searchCriteria['use_filename'] = value,
                      Icons.insert_drive_file,
                    ),
                    _buildSearchField(
                      'Uploaded by',
                      searchCriteria['user'] as String,
                      (value) => searchCriteria['user'] = value,
                      searchCriteria['use_user'] as bool,
                      (value) => searchCriteria['use_user'] = value,
                      Icons.person,
                    ),
                    _buildDateRangeField(searchCriteria, setState),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performEnhancedSearch(searchCriteria);
                },
                child: const Text('Search'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchScopeSelector(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Scope:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _searchScope,
          items: const [
            DropdownMenuItem(
              value: 'my-documents',
              child: Text('My Documents'),
            ),
            DropdownMenuItem(value: 'library', child: Text('Document Library')),
            DropdownMenuItem(value: 'shared', child: Text('Shared with Me')),
            DropdownMenuItem(value: 'all', child: Text('All Documents')),
          ],
          onChanged: (value) {
            setState(() {
              _searchScope = value!;
            });
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(
    String label,
    String value,
    Function(String) onChanged,
    bool useField,
    Function(bool) onUseChanged,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: useField,
              onChanged: (val) => onUseChanged(val ?? false),
            ),
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        if (useField)
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter $label',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onChanged,
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDateRangeField(
    Map<String, dynamic> criteria,
    StateSetter setState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: criteria['use_date'] as bool,
              onChanged: (val) {
                setState(() {
                  criteria['use_date'] = val ?? false;
                });
              },
            ),
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            const Text('Date Range'),
          ],
        ),
        if (criteria['use_date'] as bool)
          Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'From Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => criteria['from_date'] = value,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'To Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => criteria['to_date'] = value,
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _performEnhancedSearch(Map<String, dynamic> criteria) async {
    if (!ApiService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot search while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await MyDocumentsService.enhancedSearch(
        criteria: criteria,
        scope: _searchScope,
      );

      if (result['success'] == true) {
        final List<Document> searchResults =
            result['documents'] as List<Document>;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Search Results'),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: searchResults.isEmpty
                  ? const Center(child: Text('No documents found'))
                  : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final doc = searchResults[index];
                        return ListTile(
                          leading: Icon(_getDocumentIcon(doc.type)),
                          title: Text(doc.name),
                          subtitle: Text('${doc.owner} • ${doc.uploadDate}'),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedDocument = doc;
                            });
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _quickUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        for (var file in result.files) {
          final document = Document(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: file.name,
            type: _extractFileType(file.name),
            size: '${file.size} bytes',
            keyword: '',
            uploadDate: DateTime.now().toString(),
            owner: widget.userName ?? 'User',
            details: '',
            classification: 'General',
            allowDownload: true,
            sharingType: 'Private',
            folder: 'Home',
            folderId: null,
            path: file.name,
            fileType: _extractFileType(file.name),
          );

          _addNewDocument(document);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${result.files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _folderNameController.dispose();
    _newKeywordController.dispose();
    super.dispose();
  }

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.create_new_folder,
                        color: Colors.indigo,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create New Folder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _folderNameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'Enter folder name',
                    prefixIcon: const Icon(Icons.folder, color: Colors.indigo),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.indigo,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _folderNameController.clear();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          String folderName = _folderNameController.text.trim();
                          if (folderName.isNotEmpty) {
                            await _createFolderInBackend(folderName);
                            _folderNameController.clear();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Folder "$folderName" created successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a folder name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            28,
                            36,
                            121,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteFolderConfirmation(BuildContext context, int index) {
    if (index >= 0 && index < folders.length) {
      final folder = folders[index];
      final folderName = folder.name;
      final documentCount = folder.documents.length;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.delete, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Delete Folder',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete folder "$folderName"?'),
              if (documentCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'This folder contains $documentCount document${documentCount == 1 ? '' : 's'}. All documents in this folder will also be deleted.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteFolder(index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteDocument(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.black, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 14, 25, 129),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Stack(
          children: [
            const Center(
              child: Text(
                'Digi Sanchika',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _refreshData,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withAlpha(10),
                      width: 1.5,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/acs-logo.jpeg',
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 43, 65, 189),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'My Documents'),
            Tab(text: 'Doc Library'),
            Tab(text: 'Shared Me'),
            Tab(text: 'Upload Document'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyDocumentsTab(),
          const DocumentLibrary(),
          const SharedMeScreen(), // <-- Use SharedMeScreen here
          UploadDocumentTab(
            onDocumentUploaded: _addNewDocument,
            folders: folders,
            userName: widget.userName,
          ),
        ],
      ),
    );
  }

  Widget _buildMyDocumentsTab() {
    List<Document> filteredDocuments = _getFilteredDocuments();
    List<Folder> displayFolders = folders
        .where((folder) => folder.name != 'Home')
        .toList();

    return Column(
      children: [
        if (!ApiService.isConnected) _buildOfflineBanner(),
        if (_isLoading) _buildLoadingBanner(),
        if (_isDownloading) _buildDownloadingBanner(),
        if (_isUploading) _buildUploadingBanner(),

        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _showRecent = false),
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _showRecent = false);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.tune, color: Colors.indigo),
                          onPressed: _showEnhancedSearchDialog,
                          tooltip: 'Advanced Search',
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _quickUpload,
                icon: const Icon(Icons.upload, color: Colors.indigo),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateFolderDialog,
                  icon: const Icon(Icons.create_new_folder, size: 20),
                  label: const Text('New Folder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showRecent = !_showRecent),
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('Recent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _showRecent ? Colors.white : Colors.indigo,
                    backgroundColor: _showRecent ? Colors.indigo : Colors.white,
                    side: const BorderSide(color: Colors.indigo, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // IconButton(
              //   onPressed: _refreshData,
              //   icon: const Icon(Icons.refresh, color: Colors.indigo),
              //   style: IconButton.styleFrom(
              //     backgroundColor: Colors.indigo.shade50,
              //     padding: const EdgeInsets.all(12),
              //   ),
              // ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(child: _buildMainContent(filteredDocuments, displayFolders)),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange[100],
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: Colors.orange[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline mode - using local storage',
              style: TextStyle(color: Colors.orange[800], fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _refreshData,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blue[50],
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading documents...',
              style: TextStyle(color: Colors.blue[800], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.green[50],
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Downloading document...',
              style: TextStyle(color: Colors.green[800], fontSize: 12),
            ),
          ),
        ],
      ), // CHANGE: Remove semicolon, add comma
    );
  }

  Widget _buildUploadingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.purple[50],
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Uploading files...',
              style: TextStyle(color: Colors.purple[800], fontSize: 12),
            ),
          ),
        ],
      ), // CHANGE: Remove semicolon, add comma
    );
  }

  Widget _buildMainContent(
    List<Document> filteredDocuments,
    List<Folder> displayFolders,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (displayFolders.isNotEmpty) _buildFoldersSection(displayFolders),
          _buildDocumentsSection(filteredDocuments),
        ],
      ),
    );
  }

  Widget _buildFoldersSection(List<Folder> displayFolders) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Folders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayFolders.length.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _showFolderDropdown = !_showFolderDropdown),
                icon: Icon(
                  _showFolderDropdown
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: Colors.indigo,
                  size: 32,
                ),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showFolderDropdown ? null : 0,
            constraints: BoxConstraints(
              maxHeight: _showFolderDropdown
                  ? MediaQuery.of(context).size.height *
                        0.4 // 40% of screen height
                  : 0,
              minHeight: 0,
            ),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _showFolderDropdown
                  ? Colors.grey.shade50
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _showFolderDropdown
                  ? Border.all(color: Colors.grey.shade300)
                  : null,
            ),
            child: _showFolderDropdown
                ? Container(
                    padding: const EdgeInsets.all(12),
                    child: displayFolders.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No folders yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const BouncingScrollPhysics(), // ✅ ENABLED SCROLLING
                            itemCount: displayFolders.length,
                            itemBuilder: (context, index) {
                              return _buildFolderListItem(
                                displayFolders[index],
                                index,
                              );
                            },
                          ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(List<Document> filteredDocuments) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insert_drive_file,
                color: Colors.indigo,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _showRecent ? 'Recent Documents' : 'All Documents',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  filteredDocuments.length.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(
                  () => _showDocumentsDropdown = !_showDocumentsDropdown,
                ),
                icon: Icon(
                  _showDocumentsDropdown
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: Colors.indigo,
                  size: 32, // 👈 Match folders size
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Only show documents when expanded
          _showDocumentsDropdown
              ? (filteredDocuments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredDocuments.length,
                        itemBuilder: (context, index) {
                          return _buildDocumentCard(
                            filteredDocuments[index],
                            index,
                          );
                        },
                      ))
              : Container(),
        ],
      ),
    );
  }

  Widget _buildFolderListItem(Folder folder, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderScreen(
                  folderId: folder.id,
                  folderName: folder.name,
                  userName: widget.userName,
                ),
              ),
            );
          },
          onLongPress: () => _showDeleteFolderConfirmation(context, index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Colors.amber.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   '${folder.documents.length} document${folder.documents.length != 1 ? 's' : ''} • Created ${_formatFolderDate(folder.createdAt)}',
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey.shade600,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Share Folder'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Folder'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'share') {
                      _showFolderShareDialog(folder);
                    } else if (value == 'delete') {
                      _showDeleteFolderConfirmation(context, index);
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFolderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks} week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildDocumentCard(Document document, int index) {
    final docIcons = {
      'PDF': Icons.picture_as_pdf,
      'DOCX': Icons.description,
      'XLSX': Icons.table_chart,
      'PPTX': Icons.slideshow,
      'TXT': Icons.text_snippet,
      'XLS': Icons.table_chart,
      'PPT': Icons.slideshow,
      'DOC': Icons.description,
    };
    final docColors = {
      'PDF': Colors.red,
      'DOCX': Colors.blue,
      'XLSX': Colors.green,
      'PPTX': Colors.orange,
      'TXT': Colors.grey,
      'PPT': Colors.orange,
      'XLS': Colors.green,
      'DOC': Colors.blue,
    };

    String fileType = document.type.toUpperCase();
    IconData icon = docIcons[fileType] ?? Icons.insert_drive_file;
    Color color = docColors[fileType] ?? Colors.indigo;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onDoubleTap: () {
                DocumentOpenerService().handleDoubleTap(
                  context: context,
                  document: document,
                );
              },
              onTap: () => _showDocumentDetails(document),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document.size,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow('Type', document.type, Icons.category),
            _buildDetailRow('Keyword', document.keyword, Icons.label),
            _buildDetailRow(
              'Upload Date',
              document.uploadDate,
              Icons.calendar_today,
            ),
            _buildDetailRow('Owner', document.owner, Icons.person),
            _buildDetailRow('Folder', document.folder, Icons.folder),
            _buildDetailRow(
              'Classification',
              document.classification,
              Icons.security,
            ),
            _buildDetailRow('Sharing', document.sharingType, Icons.share),
            if (document.details.isNotEmpty)
              _buildDetailRow('Details', document.details, Icons.info_outline),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadDocument(document),
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.download, size: 14),
                    ),
                    label: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text('Download', style: TextStyle(fontSize: 11)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDocumentVersions(document),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text('Versions', style: TextStyle(fontSize: 12)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showShareDialog(document),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showDeleteConfirmation(context, index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Upload your first document using the Upload Document tab',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.indigo),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSharedMeTab() {
  //   return const Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(Icons.construction, size: 80, color: Colors.grey),
  //         SizedBox(height: 20),
  //         Text(
  //           'Shared Me',
  //           style: TextStyle(
  //             fontSize: 24,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.indigo,
  //           ),
  //         ),
  //         SizedBox(height: 10),
  //         Text(
  //           'Coming Soon',
  //           style: TextStyle(fontSize: 16, color: Colors.grey),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  List<Document> _getFilteredDocuments() {
    List<Document> allDocs = List.from(
      allDocuments,
    ); // CHANGED: Use allDocuments

    if (_showRecent) {
      allDocs.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      return allDocs.take(10).toList();
    }

    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isEmpty) {
      return allDocs;
    }

    return allDocs.where((doc) {
      return doc.name.toLowerCase().contains(searchTerm) ||
          doc.keyword.toLowerCase().contains(searchTerm) ||
          doc.type.toLowerCase().contains(searchTerm) ||
          doc.owner.toLowerCase().contains(searchTerm) ||
          doc.classification.toLowerCase().contains(searchTerm) ||
          doc.folder.toLowerCase().contains(searchTerm);
    }).toList();
  }
}
