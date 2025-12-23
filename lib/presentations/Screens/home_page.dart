// presentations/Screens/home_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'package:digi_sanchika/presentations/Screens/folder_screen.dart';
import 'package:digi_sanchika/presentations/Screens/shared_me.dart';
import 'package:digi_sanchika/presentations/Screens/documents_hub.dart';
import 'package:open_filex/open_filex.dart';
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:digi_sanchika/presentations/Screens/profile_screen.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:digi_sanchika/presentations/screens/folder_manager_screen.dart';

// Add this enum for layout modes
enum ViewMode { list, grid2x2, grid3x3, compact, detailed }

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

  List<Document> allDocuments = [];
  List<Folder> folders = [];
  bool _showRecent = false;
  bool _showFolderDropdown = false;
  bool _showDocumentsDropdown = true;
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isUploading = false;
  bool _showProfileDrawer = false;
  int? _currentFolderId;
  Document? _selectedDocument;
  String? _downloadingFileName;

  Map<String, bool> _expandedStates = {};

  // Add these variables for layout modes
  ViewMode _currentViewMode = ViewMode.list;
  bool _showLayoutOptions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  String _getUserInitial() {
    if (widget.userName == null || widget.userName!.isEmpty) {
      return 'U';
    }

    final nameParts = widget.userName!.trim().split(' ');
    if (nameParts.isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }

    return widget.userName![0].toUpperCase();
  }

  Future<void> _initializeBackend() async {
    await ApiService.initialize();
    if (ApiService.isConnected) {
      await _loadAllUserDocuments();
    }
  }

  Future<void> _refreshData() async {
    await ApiService.checkConnection();
    if (ApiService.isConnected) {
      await _loadAllUserDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Latest info loaded successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await _loadDataFromLocalStorage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re offline. Showing saved data'),
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
      if (kDebugMode) {
        print('Error loading from local storage: $e');
      }
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

  /// NEW FUNCTION: Builds the Documents Hub tab
  Widget _buildDocumentsHubTab() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const SizedBox(height: 20),
            const Text(
              'Documents Hub',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Access different types of documents',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),

            // Options Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // Option 1: Shared Documents
                  _buildHubCard(
                    icon: Icons.people_alt,
                    title: 'Shared With Me',
                    subtitle: 'Documents shared with you',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SharedMeScreen(),
                        ),
                      );
                    },
                  ),

                  // Option 2: Document Library
                  _buildHubCard(
                    icon: Icons.public,
                    title: 'Document Library',
                    subtitle: 'Public documents',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DocumentLibrary(),
                        ),
                      );
                    },
                  ),

                  // Option 3: Quick Stats
                  _buildHubCard(
                    icon: Icons.bar_chart,
                    title: 'Quick Stats',
                    subtitle: 'View document statistics',
                    color: Colors.orange,
                    onTap: () {
                      _showStatsDialog();
                    },
                  ),

                  // Option 4: Favorites (Coming Soon)
                  _buildHubCard(
                    icon: Icons.star,
                    title: 'Favorites',
                    subtitle: 'Coming soon',
                    color: Colors.amber,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Favorites feature coming soon!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to build Hub cards
  Widget _buildHubCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show statistics dialog
  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Statistics'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem('My Documents', allDocuments.length.toString()),
              _buildStatItem('Shared With Me', '0'), // You can update this
              _buildStatItem('Public Files', '0'), // You can update this
              const Divider(height: 20),
              _buildStatItem('Total Files', allDocuments.length.toString()),
            ],
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

  /// Helper for stats items
  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

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
        if (kDebugMode) {
          print('📁 Found ${allIds.length} folder IDs');
        }
        return allIds;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting folders: $e');
      }
    }
    return [];
  }

  List<Document> _convertToDocumentList(
    List<dynamic> docList,
    int? folderId,
    String folderPath,
  ) {
    return docList.map<Document>((doc) {
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
        folderId: folderId?.toString(),
        path: doc['original_filename'],
        fileType: _extractFileType(doc['original_filename']),
      );
    }).toList();
  }

  Future<void> _loadAllUserDocuments() async {
    if (!ApiService.isConnected) {
      if (kDebugMode) {
        print('⚠ Skipping backend load - not connected');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🔄 Loading ALL user documents...');
      }

      List<int> allFolderIds = await _getAllFolderIds();

      List<Future<Map<String, dynamic>>> futures = [];

      futures.add(_fetchMyDocumentsWithParams(null));

      for (int folderId in allFolderIds) {
        futures.add(_fetchMyDocumentsWithParams(folderId));
      }

      if (kDebugMode) {
        print('🚀 Executing ${futures.length} parallel requests...');
      }
      List<Map<String, dynamic>> results = await Future.wait(futures);

      List<Document> combinedDocuments = [];
      List<Folder> allFolders = [];

      if (results.isNotEmpty && results[0]['documents'] != null) {
        combinedDocuments.addAll(
          _convertToDocumentList(results[0]['documents'], null, 'Home'),
        );

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

      setState(() {
        allDocuments = combinedDocuments;
        folders = allFolders;

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

        if (kDebugMode) {
          print(
            '✅ Loaded ${allDocuments.length} total documents from ${results.length} sources',
          );
        }
      });

      try {
        await LocalStorageService.saveDocuments(allDocuments);
        if (kDebugMode) {
          print('💾 Saved ${allDocuments.length} documents to local storage');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Error saving to local storage: $e');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Exception in _loadAllUserDocuments: $e');
      }
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
      await _loadDataFromLocalStorage();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
      if (kDebugMode) {
        print('Error fetching documents for folder $folderId: $e');
      }
      return {'documents': [], 'folders': []};
    }
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
      allDocuments.add(document);
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
      if (kDebugMode) {
        print('Error creating folder in backend: $e');
      }
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
      if (kDebugMode) {
        print('⚠ Could not get session cookie: $e');
      }
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
          if (kDebugMode) {
            print('Error deleting folder from backend: $e');
          }
        }
      }

      allDocuments.removeWhere((doc) => doc.folder == folderName);
      setState(() {
        folders.removeAt(index);
      });

      // ignore: use_build_context_synchronously
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

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document "${docToDelete.name}" deleted successfully',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
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
      _downloadingFileName = document.name;
    });

    try {
      final result = await MyDocumentsService.downloadDocument(document.id);

      if (result['success'] == true) {
        final directory = await getDownloadDirectory();
        final filePath = '${directory.path}/${document.name}';
        final file = File(filePath);
        await file.writeAsBytes(result['data'] as List<int>);

        if (kDebugMode) {
          print('✅ Downloaded to: $filePath');
        }

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${document.name}'),
            backgroundColor: Colors.green,
          ),
        );

        try {
          final uriToOpen = Platform.isAndroid
              ? _getFileProviderUri(filePath)
              : filePath;

          if (kDebugMode) {
            print('📂 Opening with: $uriToOpen');
          }

          final result = await OpenFilex.open(uriToOpen);

          if (result.type != ResultType.done) {
            if (kDebugMode) {
              print('⚠ Could not open file automatically: ${result.message}');
            }

            if (Platform.isAndroid) {
              if (kDebugMode) {
                print('🔄 Trying fallback with normal path...');
              }
              try {
                await OpenFilex.open(filePath);
              } catch (fallbackError) {
                if (kDebugMode) {
                  print('⚠ Fallback also failed: $fallbackError');
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Error opening file: $e');
          }
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadingFileName = null;
      });
    }
  }

  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return Directory.current;
  }

  String _getFileProviderUri(String filePath) {
    if (Platform.isAndroid) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final fileName = file.path.split('/').last;
          return 'content://com.example.digi_sanchika.fileprovider/files/$fileName';
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Error creating FileProvider URI: $e');
        }
      }
    }
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

        // Add state for selected version
        Map<String, dynamic>? selectedVersion;

        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Document Versions'),
                content: Container(
                  width: double.maxFinite,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    itemBuilder: (context, index) {
                      final version = versions[index];
                      final isSelected =
                          selectedVersion?['version_number'] ==
                          version['version_number'];
                      final isCurrent = version['is_current'] == true;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedVersion = version;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isCurrent ? Icons.check_circle : Icons.history,
                              color: isCurrent ? Colors.green : Colors.grey,
                            ),
                            title: Text('Version ${version['version_number']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uploaded: ${_formatDate(version['upload_date'])}',
                                ),
                                if (version['uploaded_by'] != null)
                                  Text('By: ${version['uploaded_by']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade100,
                                      ),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  const Icon(Icons.check, color: Colors.blue),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: selectedVersion != null
                        ? () async {
                            Navigator.pop(context); // Close dialog
                            await _openSelectedVersion(
                              context,
                              document,
                              selectedVersion!,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Selected Version'),
                  ),
                ],
              );
            },
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

  Future<void> _openSelectedVersion(
    BuildContext context,
    Document document,
    Map<String, dynamic> version,
  ) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final documentOpener = DocumentOpenerService();

      await documentOpener.openDocumentVersion(
        context: context,
        documentId: document.id,
        versionNumber: version['version_number'].toString(),
        originalFileName: document.name,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open version: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  String _formatDate(dynamic date) {
    try {
      DateTime parsedDate = DateTime.parse(date.toString());
      String day = parsedDate.day.toString().padLeft(2, '0');
      String month = parsedDate.month.toString().padLeft(2, '0');
      String year = parsedDate.year.toString();
      return '$day $month $year';
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
            folderId: details['folder_id']?.toString(),
            path: details['original_filename'],
            fileType: _extractFileType(details['original_filename']),
          );
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading document details: $e');
      }
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
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha(10),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(
                          187,
                          186,
                          186,
                          1,
                        ).withAlpha(15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/acs-logo.jpeg',
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 43, 65, 189),
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Text(
                  _getUserInitial(),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 43, 65, 189),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
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
            Tab(text: 'Document Hub'),
            Tab(text: 'Upload Docs'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildMyDocumentsTab(),
              const DocumentsHub(),
              UploadDocumentTab(
                onDocumentUploaded: _addNewDocument,
                folders: folders,
                userName: widget.userName,
              ),
            ],
          ),
          if (_showProfileDrawer)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showProfileDrawer = false;
                });
              },
              child: Container(color: Colors.black.withAlpha(30)),
            ),

          if (_showProfileDrawer) _buildProfileSidebar(),
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
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Manage Folders button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FolderManagerScreen(userName: widget.userName),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_open, size: 20),
                  label: const Text('Manage Folders'),
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

              // Recent button
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

              // Layout selector button
              Container(width: 40, child: _buildLayoutSelector()),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: _buildMainContent(filteredDocuments, displayFolders),
          ),
        ),
      ],
    );
  }

  /// Method to build layout selector
  Widget _buildLayoutSelector() {
    return PopupMenuButton<ViewMode>(
      tooltip: 'Change Layout',
      icon: Icon(
        _getViewModeIcon(_currentViewMode),
        color: Colors.indigo,
        size: 24,
      ),
      onSelected: (ViewMode mode) {
        setState(() {
          _currentViewMode = mode;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewMode>>[
        PopupMenuItem<ViewMode>(
          value: ViewMode.list,
          child: Row(
            children: [
              Icon(Icons.list, color: Colors.indigo),
              SizedBox(width: 8),
              Text('List View'),
              if (_currentViewMode == ViewMode.list)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<ViewMode>(
          value: ViewMode.grid2x2,
          child: Row(
            children: [
              Icon(Icons.grid_on, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Grid (2x2)'),
              if (_currentViewMode == ViewMode.grid2x2)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<ViewMode>(
          value: ViewMode.grid3x3,
          child: Row(
            children: [
              Icon(Icons.view_module, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Grid (3x3)'),
              if (_currentViewMode == ViewMode.grid3x3)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<ViewMode>(
          value: ViewMode.compact,
          child: Row(
            children: [
              Icon(Icons.view_headline, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Compact View'),
              if (_currentViewMode == ViewMode.compact)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<ViewMode>(
          value: ViewMode.detailed,
          child: Row(
            children: [
              Icon(Icons.table_rows, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Detailed View'),
              if (_currentViewMode == ViewMode.detailed)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getViewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.list:
        return Icons.list;
      case ViewMode.grid2x2:
        return Icons.grid_on;
      case ViewMode.grid3x3:
        return Icons.view_module;
      case ViewMode.compact:
        return Icons.view_headline;
      case ViewMode.detailed:
        return Icons.table_rows;
    }
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
      ),
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
      ),
    );
  }

  Widget _buildMainContent(
    List<Document> filteredDocuments,
    List<Folder> displayFolders,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  ? MediaQuery.of(context).size.height * 0.4
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
                        : _buildFolderContent(displayFolders),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Method to build folder content based on view mode
  Widget _buildFolderContent(List<Folder> folders) {
    switch (_currentViewMode) {
      case ViewMode.list:
        return ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return _buildFolderListItem(folders[index], index);
          },
        );
      case ViewMode.grid2x2:
        return GridView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return _buildFolderGridItem(folders[index], index, 2);
          },
        );
      case ViewMode.grid3x3:
        return GridView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return _buildFolderGridItem(folders[index], index, 3);
          },
        );
      case ViewMode.compact:
        return ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return _buildFolderCompactItem(folders[index], index);
          },
        );
      case ViewMode.detailed:
        return ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return _buildFolderDetailedItem(folders[index], index);
          },
        );
    }
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
                  size: 32,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _showDocumentsDropdown
              ? (filteredDocuments.isEmpty
                    ? _buildEmptyState()
                    : _buildDocumentsContent(filteredDocuments))
              : Container(),
        ],
      ),
    );
  }

  /// Method to build documents content based on view mode
  Widget _buildDocumentsContent(List<Document> documents) {
    switch (_currentViewMode) {
      case ViewMode.list:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentCard(documents[index], index);
          },
        );
      case ViewMode.grid2x2:
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentGridItem(documents[index], index, 2);
          },
        );
      case ViewMode.grid3x3:
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentGridItem(documents[index], index, 3);
          },
        );
      case ViewMode.compact:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentCompactItem(documents[index], index);
          },
        );
      case ViewMode.detailed:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentDetailedItem(documents[index], index);
          },
        );
    }
  }

  // NEW: Folder Grid Item (for 2x2 and 3x3 views) - FIXED
  Widget _buildFolderGridItem(Folder folder, int index, int columns) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(columns == 2 ? 12 : 8), // Reduced sizes
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder,
                  color: Colors.amber.shade700,
                  size: columns == 2 ? 28 : 20, // Reduced icon sizes
                ),
              ),
              const SizedBox(height: 6), // Reduced spacing
              Flexible(
                // ADDED: Flexible widget
                child: Text(
                  folder.name,
                  style: TextStyle(
                    fontSize: columns == 2 ? 12 : 10, // Reduced font sizes
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (columns == 2) ...[
                const SizedBox(height: 2), // Reduced spacing
                Text(
                  '${folder.documents.length} items',
                  style: TextStyle(
                    fontSize: 9, // Reduced font size
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Folder Compact Item
  Widget _buildFolderCompactItem(Folder folder, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${folder.documents.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Folder Detailed Item
  // NEW: Folder Detailed Item - FIXED
  Widget _buildFolderDetailedItem(Folder folder, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder,
                  color: Colors.amber.shade700,
                  size: 24, // Reduced size
                ),
              ),
              const SizedBox(width: 12), // Reduced spacing
              Expanded(
                // ADDED: Expanded widget to prevent overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ADDED
                  children: [
                    Text(
                      folder.name,
                      style: const TextStyle(
                        fontSize: 14, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      // CHANGED: Row to Wrap for better overflow handling
                      spacing: 8, // Reduced spacing
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${folder.documents.length} docs',
                              style: TextStyle(
                                fontSize: 11, // Reduced font size
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              folder.owner,
                              style: TextStyle(
                                fontSize: 11, // Reduced font size
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(folder.createdAt.toString())}',
                      style: TextStyle(
                        fontSize: 10, // Reduced font size
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(
                          Icons.share,
                          size: 18,
                          color: Colors.blue,
                        ), // Reduced icon size
                        SizedBox(width: 6),
                        Text(
                          'Share',
                          style: TextStyle(fontSize: 13),
                        ), // Reduced font size
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ), // Reduced icon size
                        SizedBox(width: 6),
                        Text(
                          'Delete',
                          style: TextStyle(fontSize: 13),
                        ), // Reduced font size
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
                  width: 32, // Reduced size
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 16, // Reduced icon size
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Document Grid Item (for 2x2 and 3x3 views)
  Widget _buildDocumentGridItem(Document document, int index, int columns) {
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
    final documentOpener = DocumentOpenerService();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => documentOpener.handleDoubleTap(
          context: context,
          document: document,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(columns == 2 ? 16 : 12),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: columns == 2 ? 32 : 24),
              ),
              const SizedBox(height: 8),
              Text(
                document.name,
                style: TextStyle(
                  fontSize: columns == 2 ? 13 : 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: columns == 2 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                document.type,
                style: TextStyle(
                  fontSize: columns == 2 ? 11 : 10,
                  color: Colors.grey.shade600,
                ),
              ),
              if (columns == 2) ...[
                const SizedBox(height: 4),
                Text(
                  _formatToDDMMYYYY(document.uploadDate),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Document Compact Item
  Widget _buildDocumentCompactItem(Document document, int index) {
    final documentOpener = DocumentOpenerService();

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        elevation: 0.5,
        child: InkWell(
          onTap: () => documentOpener.handleDoubleTap(
            context: context,
            document: document,
          ),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade100, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  _getDocumentIcon(document.type),
                  color: _getDocumentColor(document.type),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    document.name,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatToDDMMYYYY(document.uploadDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Document Detailed Item
  Widget _buildDocumentDetailedItem(Document document, int index) {
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
    final documentOpener = DocumentOpenerService();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => documentOpener.handleDoubleTap(
          context: context,
          document: document,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 28),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              document.owner,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.folder, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              document.folder,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatToDDMMYYYY(document.uploadDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.security, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              document.classification,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'share') {
                        _showShareDialog(document);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, index);
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => documentOpener.handleDoubleTap(
                        context: context,
                        document: document,
                      ),
                      icon: Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.purple,
                      ),
                      label: Text(
                        'View',
                        style: TextStyle(color: Colors.purple),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDocumentVersions(document),
                      icon: Icon(Icons.history, size: 16, color: Colors.blue),
                      label: Text(
                        'Versions',
                        style: TextStyle(color: Colors.blue),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadDocument(document),
                      icon: Icon(Icons.download, size: 16, color: Colors.green),
                      label: Text(
                        'Download',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String fileType) {
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
    return docIcons[fileType.toUpperCase()] ?? Icons.insert_drive_file;
  }

  Color _getDocumentColor(String fileType) {
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
    return docColors[fileType.toUpperCase()] ?? Colors.indigo;
  }

  // Original folder list item (updated)
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

  // Original document card (updated)
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

    // Format the date to DD MM YYYY
    String formattedDate = _formatToDDMMYYYY(document.uploadDate);

    // Get document opener service instance
    final documentOpener = DocumentOpenerService();

    // IMPORTANT: Check if this specific document is expanded using its ID
    bool isExpanded = _expandedStates[document.id] ?? false;

    return InkWell(
      onTap: () =>
          documentOpener.handleDoubleTap(context: context, document: document),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icon, document info, and expand/collapse button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: isExpanded ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // INNOVATIVE EXPAND/COLLAPSE BUTTON
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  // Toggle only this specific document using its ID
                                  _expandedStates[document.id] = !isExpanded;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isExpanded
                                      ? color.withAlpha(20)
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isExpanded
                                        ? color.withAlpha(100)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: AnimatedRotation(
                                    duration: const Duration(milliseconds: 300),
                                    turns: isExpanded ? 0.5 : 0,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 22,
                                      color: isExpanded
                                          ? color
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Vertical More Options Button (Three Dots) - Kept from original
                            PopupMenuButton<String>(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.share,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Share'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'share') {
                                  _showShareDialog(document);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(context, index);
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${document.type} • $formattedDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // COLLAPSIBLE CONTENT SECTION
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: SizedBox(
                  height: isExpanded ? null : 0,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _buildDetailRow('Keyword', document.keyword, Icons.label),
                      _buildDetailRow('Owner', document.owner, Icons.person),
                      _buildDetailRow('Folder', document.folder, Icons.folder),
                      _buildDetailRow(
                        'Classification',
                        document.classification,
                        Icons.security,
                      ),
                      _buildDetailRow(
                        'Sharing',
                        document.sharingType,
                        Icons.share,
                      ),
                      if (document.details.isNotEmpty)
                        _buildDetailRow(
                          'Details',
                          document.details,
                          Icons.info_outline,
                        ),
                      const SizedBox(height: 16),

                      // ACTION BUTTONS ROW - Only View, Versions, and Download
                      Row(
                        children: [
                          // VIEW BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => documentOpener.handleDoubleTap(
                                context: context,
                                document: document,
                              ),
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('View'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple,
                                side: const BorderSide(color: Colors.purple),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // VERSIONS BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showDocumentVersions(document),
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('Versions'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // DOWNLOAD BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _downloadDocument(document),
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Download'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this helper method to format dates to DD MM YYYY
  String _formatToDDMMYYYY(String dateString) {
    try {
      // Try to parse the date string
      DateTime date = DateTime.parse(dateString);

      // Format as DD MM YYYY
      String day = date.day.toString().padLeft(2, '0');
      String month = date.month.toString().padLeft(2, '0');
      String year = date.year.toString();

      return '$day $month $year';
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
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

  List<Document> _getFilteredDocuments() {
    List<Document> allDocs = List.from(allDocuments);

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

  Widget _buildProfileSidebar() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color.fromARGB(255, 43, 65, 189),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showProfileDrawer = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color.fromARGB(255, 43, 65, 189),
                      radius: 50,
                      child: Text(
                        _getUserInitial(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      widget.userName ?? 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    if (widget.userEmail != null &&
                        widget.userEmail!.isNotEmpty)
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: Colors.grey,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.userEmail!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.work_outline, color: Colors.grey, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Experience',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '5+ Years',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showProfileDrawer = false;
                          });
                          _showLogoutDialog();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Logout',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            43,
                            65,
                            189,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
