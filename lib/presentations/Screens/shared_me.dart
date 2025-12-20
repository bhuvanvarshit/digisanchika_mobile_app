// screens/shared_me.dart
// ignore: unused_import
// ignore_for_file: unused_field, unused_import, unnecessary_brace_in_string_interps, unused_element

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/shared_documents_service.dart';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/models/shared_folder.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:digi_sanchika/presentations/Screens/folder_screen.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:digi_sanchika/presentations/Screens/shared_folder_screen.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/my_documents_service.dart';
import 'package:digi_sanchika/services/shared_folders_service.dart';

class SharedMeScreen extends StatefulWidget {
  const SharedMeScreen({super.key});

  @override
  State<SharedMeScreen> createState() => _SharedMeScreenState();
}

class _SharedMeScreenState extends State<SharedMeScreen> {
  // Services
  final SharedDocumentsService _sharedService = SharedDocumentsService();
  final SharedFoldersService _sharedFoldersService = SharedFoldersService();
  final DocumentOpenerService _documentOpener = DocumentOpenerService();

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  // State variables
  List<Document> _sharedDocuments = [];
  List<Document> _filteredDocuments = [];
  List<SharedFolder> _sharedFolders = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDownloading = false;
  String _errorMessage = '';
  // Stats
  int _totalDocuments = 0;
  int _totalFolders = 0;

  @override
  void initState() {
    super.initState();
    _loadSharedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load shared documents and folders

  Future<void> _loadSharedData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Check if user is logged in
      final isLoggedIn = await _sharedService.isLoggedIn();
      if (!isLoggedIn) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Please login to view shared documents';
            _isLoading = false;
          });
        }
        return;
      }

      // Check internet connection
      if (!_sharedService.isConnected) {
        // Load from local storage
        _loadFromLocalStorage();
        return;
      }

      // Try to load from backend first
      // FIX: Get the SharedDocumentsResponse and extract documents/folders from it
      final response = await _sharedService.fetchSharedDocuments();

      // Extract documents and folders from the response
      final List<Document> documents = response.documents;
      final List<SharedFolder> folders = response.folders;

      if (!mounted) return;

      setState(() {
        _sharedDocuments = documents;
        _filteredDocuments = documents;
        _sharedFolders = folders;
        _totalDocuments = documents.length;
        _totalFolders = folders.length;
        _isLoading = false;
      });

      // Save to local storage for offline access
      await _saveToLocalStorage();
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error loading shared data: $e');

      // Try to load from local storage as fallback
      _loadFromLocalStorage();
    }
  }

  /// Load data from local storage
  Future<void> _loadFromLocalStorage() async {
    try {
      final localDocs = await LocalStorageService.loadSharedDocuments();

      if (mounted) {
        setState(() {
          _sharedDocuments = localDocs;
          _filteredDocuments = localDocs;
          _totalDocuments = localDocs.length;
          _totalFolders = 0;
          _hasError = true;
          _errorMessage = 'Using cached data. No internet connection.';
          _isLoading = false;
        });
      }
    } catch (localError) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'Failed to load data. Please check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  /// Save data to local storage
  Future<void> _saveToLocalStorage() async {
    if (_sharedDocuments.isNotEmpty) {
      try {
        await LocalStorageService.saveSharedDocuments(_sharedDocuments);
        debugPrint(
          '✅ Saved ${_sharedDocuments.length} documents to local storage',
        );
      } catch (e) {
        debugPrint('❌ Error saving to local storage: $e');
      }
    }
  }

  /// Filter documents based on search query
  void _filterDocuments(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredDocuments = _sharedDocuments;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredDocuments = _sharedDocuments.where((doc) {
        return doc.name.toLowerCase().contains(lowercaseQuery) ||
            doc.owner.toLowerCase().contains(lowercaseQuery) ||
            doc.keyword.toLowerCase().contains(lowercaseQuery) ||
            doc.type.toLowerCase().contains(lowercaseQuery) ||
            doc.classification.toLowerCase().contains(lowercaseQuery) ||
            doc.details.toLowerCase().contains(lowercaseQuery) ||
            doc.folder.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  /// Clear search and reset filter
  void _clearSearch() {
    _searchController.clear();
    _filterDocuments('');
  }

  // ============ DOWNLOAD HELPER METHODS ============

  /// Get download directory (same as My Documents)
  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return Directory.current;
  }

  /// Get FileProvider URI for Android
  String _getFileProviderUri(String filePath) {
    if (Platform.isAndroid) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final fileName = file.path.split('/').last;
          return 'content://com.example.digi_sanchika.fileprovider/files/$fileName';
        }
      } catch (e) {
        debugPrint('Error creating FileProvider URI: $e');
      }
    }
    return filePath;
  }

  /// Download a document (with auto-open like My Documents)
  Future<void> _downloadDocument(Document document) async {
    if (!document.allowDownload) {
      _showSnackBar('Download is not allowed for this document', Colors.orange);
      return;
    }

    if (!ApiService.isConnected) {
      _showSnackBar('Cannot download while offline', Colors.orange);
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      debugPrint(
        ' Starting download for document: ${document.id} - ${document.name}',
      );
      final result = await _sharedService.downloadDocument(document.id);

      debugPrint('Download result keys: ${result.keys}');
      debugPrint('Success: ${result['success']}');
      debugPrint('Has fileData: ${result.containsKey('fileData')}');

      if (result['success'] == true) {
        if (!result.containsKey('fileData')) {
          debugPrint('fileData key missing in response');
          throw Exception('Server did not return file data');
        }
        final fileData = result['fileData'];

        if (fileData == null) {
          debugPrint('fileData is null');
          throw Exception('Server returned null file data');
        }

        List<int> bytesToSave;

        if (fileData is List<int>) {
          bytesToSave = fileData;
        } else if (fileData is List<dynamic>) {
          // Convert List<dynamic> to List<int>
          bytesToSave = fileData.cast<int>();
        } else if (fileData is String) {
          // Convert String to bytes
          bytesToSave = utf8.encode(fileData);
        } else {
          debugPrint(
            '❌ fileData is not List<int>, it is: ${fileData.runtimeType}',
          );
          throw Exception(
            'Invalid file data format. Expected List<int>, got ${fileData.runtimeType}',
          );
        }

        // Check if data is not empty
        if (bytesToSave.isEmpty) {
          throw Exception('Downloaded file data is empty (0 bytes)');
        }

        debugPrint('✅ Received ${bytesToSave.length} bytes of file data');

        final directory = await getDownloadDirectory();

        String filename = result['filename']?.toString() ?? document.name;

        // If filename is just a number (document ID), use the document name
        if (RegExp(r'^\d+$').hasMatch(filename) && document.name.isNotEmpty) {
          filename = document.name;
        }

        // Ensure correct file extension
        final docName = document.name;
        if (docName.isNotEmpty) {
          final extension = path.extension(docName);
          // If the filename doesn't have the same extension as the document name
          if (!filename.toLowerCase().endsWith(extension.toLowerCase()) &&
              extension.isNotEmpty) {
            // Remove any existing extension from filename and add the correct one
            final nameWithoutExt = path.withoutExtension(filename);
            filename = '$nameWithoutExt$extension';
          }
        }

        // Ensure .py files have correct extension
        if (document.type.toLowerCase() == 'py' &&
            !filename.toLowerCase().endsWith('.py')) {
          filename = '$filename.py';
        }

        // Also check if we need to add .pdf extension
        if (document.type.toLowerCase() == 'pdf' &&
            !filename.toLowerCase().endsWith('.pdf')) {
          filename = '$filename.pdf';
        }

        final filePath = '${directory.path}/$filename';

        debugPrint('Saving to: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(bytesToSave);

        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('File saved: ${fileSize} bytes');
          _showSnackBar('Downloaded: $filename', Colors.green);

          if (document.size == '0' ||
              document.size == '0 KB' ||
              document.size == '0 B') {
            final docIndex = _sharedDocuments.indexWhere(
              (d) => d.id == document.id,
            );
            if (docIndex != -1) {
              setState(() {
                _sharedDocuments[docIndex] = document.copyWith(
                  size: fileSize.toString(),
                );
                _filteredDocuments = List.from(_sharedDocuments);
              });
            }
          }

          // } else {
          //   throw Exception('Failed to save file to disk');
          // }
          final fileExtension = filename.toLowerCase().split('.').last;
          if (fileExtension == 'py' || document.type.toLowerCase() == 'py') {
            _showFileContent(bytesToSave, filename);
            return;
          }

          // Auto-open the downloaded file (same as My Documents)
          try {
            final uriToOpen = Platform.isAndroid
                ? _getFileProviderUri(filePath)
                : filePath;

            debugPrint('Opening with: $uriToOpen');

            final openResult = await OpenFilex.open(uriToOpen);

            if (openResult.type != ResultType.done) {
              debugPrint('⚠ Could not open file: ${openResult.message}');

              // Fallback: Try normal path
              if (Platform.isAndroid) {
                try {
                  await OpenFilex.open(filePath);
                } catch (e) {
                  debugPrint('⚠ Fallback also failed: $e');
                }
              }
              _showSnackBar(
                'File downloaded. Could not open automatically.',
                Colors.orange,
              );
            } else {
              debugPrint('File opened successfully');
            }
          } catch (e) {
            debugPrint('⚠ Error opening file: $e');
            _showSnackBar(
              'File downloaded. Use a compatible app to open it.',
              Colors.blue,
            );
          }
        } else {
          throw Exception('Failed to save file to disk');
        }
      } else {
        final errorMsg =
            result['error'] ?? result['message'] ?? 'Download failed';
        debugPrint('Download failed from service: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      _showSnackBar('Download failed: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  /// Show text content of .py files
  void _showFileContent(List<int> fileBytes, String filename) {
    try {
      final content = utf8.decode(fileBytes);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              _getFileIcon('py', 24),
              const SizedBox(width: 12),
              Expanded(child: Text(filename, overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.code, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Python file (${fileBytes.length} bytes)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color.fromRGBO(224, 224, 224, 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(text: content));
                _showSnackBar('Code copied to clipboard', Colors.green);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing file content: $e');
      _showSnackBar('Cannot display file content', Colors.red);
    }
  }

  /// Handle document double-tap
  void _handleDocumentDoubleTap(Document document) {
    _documentOpener.handleDoubleTap(context: context, document: document);
  }

  /// Show document details
  Future<void> _showDocumentDetails(Document document) async {
    _showSnackBar('Loading document details...', Colors.blue);

    final result = await _sharedService.getDocumentDetails(document.id);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;

      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              _getFileIcon(document.type, 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(document.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(
                  'File Name',
                  data['original_filename']?.toString() ?? document.name,
                ),
                _buildDetailRow('File Type', document.type.toUpperCase()),
                _buildDetailRow(
                  'Size',
                  '${data['file_size']?.toString() ?? '0'} bytes',
                ),
                _buildDetailRow(
                  'Owner',
                  data['owner']?['name']?.toString() ?? document.owner,
                ),
                _buildDetailRow(
                  'Employee ID',
                  data['owner']?['employee_id']?.toString() ?? 'N/A',
                ),
                _buildDetailRow('Upload Date', document.uploadDate),
                _buildDetailRow(
                  'Folder',
                  data['folder_path']?.toString() ?? document.folder,
                ),
                _buildDetailRow(
                  'Classification',
                  data['doc_class']?.toString() ?? document.classification,
                ),
                _buildDetailRow(
                  'Keywords',
                  data['keywords']?.toString() ?? document.keyword,
                ),
                _buildDetailRow(
                  'Remarks',
                  data['remarks']?.toString() ?? document.details,
                ),
                _buildDetailRow(
                  'Public Access',
                  data['is_public']?.toString() == 'true' ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Download Allowed',
                  document.allowDownload ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Version',
                  data['version_number']?.toString() ?? '1',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (document.allowDownload)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadDocument(document);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 6),
                    Text('Download'),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDocumentVersions(document);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 6),
                  Text('Versions'),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      _showSnackBar(result['message'] ?? 'Failed to load details', Colors.red);
    }
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Show shared folders dialog
  void _showSharedFolders() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.folder_shared, color: Colors.indigo),
            const SizedBox(width: 10),
            Text('Shared Folders (${_sharedFolders.length})'),
          ],
        ),
        content: _sharedFolders.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No shared folders'),
                  ],
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  itemCount: _sharedFolders.length,
                  itemBuilder: (context, index) {
                    final folder = _sharedFolders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.folder, color: Colors.amber),
                        title: Text(
                          folder.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Owner: ${folder.owner}'),
                            Text('Created: ${folder.createdAt}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            Navigator.pop(context);
                            _openSharedFolder(folder);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openSharedFolder(folder);
                        },
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
        ],
      ),
    );
  }

  /// Open a shared folder (navigate to FolderScreen)
  /// Open a shared folder (navigate to FolderScreen)
  void _openSharedFolder(SharedFolder folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedFolderScreen(
          folderId: folder.id,
          folderName: folder.name,
          userName: folder.owner,
        ),
      ),
    );
  }

  void _viewAllSharedContent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedFolderScreen(
          folderId: null, // Root level
          folderName: 'All Shared Content',
          userName: null,
        ),
      ),
    );
  }

  /// Build document item card (UPDATED: View button + Single-tap options + Versions button)
  /// Build document item card (UPDATED: View button + Single-tap options + Versions button)
  /// Build document item card (UPDATED: View button + Single-tap options + Versions button)
  Widget _buildDocumentCard(Document document, int index) {
    final fileInfo = _getFileInfo(document.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleDocumentDoubleTap(document),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File type icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fileInfo['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      fileInfo['icon'],
                      color: fileInfo['color'],
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Document info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document name
                        Text(
                          document.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Owner info
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Shared by: ${document.owner}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Folder and classification
                        Row(
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${document.folder} • ${document.classification}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // File details row
              Row(
                children: [
                  Icon(
                    Icons.description,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${document.type.toUpperCase()} • ${_formatFileSize(document.size)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    document.uploadDate,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Keywords (if available)
              if (document.keyword.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: document.keyword.split(',').map((keyword) {
                      final trimmed = keyword.trim();
                      if (trimmed.isEmpty) return const SizedBox.shrink();
                      return Chip(
                        label: Text(
                          trimmed,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.indigo.withAlpha(10),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Action buttons row (View + Versions + Download)
              Row(
                children: [
                  // VIEW BUTTON with visibility icon
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDocumentDoubleTap(document),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text('View', style: TextStyle(fontSize: 12)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // VERSIONS BUTTON
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

                  // DISABLED DOWNLOAD BUTTON (with popup)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showDownloadRestrictedPopup(context),
                      icon: Icon(
                        Icons.download,
                        size: 18,
                        color: Colors.grey.shade300,
                      ),
                      label: Text(
                        'Download',
                        style: TextStyle(color: Colors.grey.shade300),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Tap hint (updated)
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tap card or click "View" button',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadRestrictedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
        title: const Text('Download Restricted'),
        content: const Text(
          'Download access is restricted for this shared document. '
          'Please contact the document owner or system administrator '
          'to request download permissions.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get file icon based on type
  Icon _getFileIcon(String type, double size) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.red, size: size);
      case 'docx':
      case 'doc':
        return Icon(Icons.description, color: Colors.blue, size: size);
      case 'xlsx':
      case 'xls':
        return Icon(Icons.table_chart, color: Colors.green, size: size);
      case 'pptx':
      case 'ppt':
        return Icon(Icons.slideshow, color: Colors.orange, size: size);
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icon(Icons.image, color: Colors.purple, size: size);
      case 'txt':
        return Icon(Icons.text_fields, color: Colors.grey, size: size);
      case 'csv':
        return Icon(
          Icons.table_chart,
          color: Colors.green.shade700,
          size: size,
        );
      default:
        return Icon(Icons.insert_drive_file, color: Colors.indigo, size: size);
    }
  }

  /// Get file icon and color based on type
  Map<String, dynamic> _getFileInfo(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
      case 'docx':
      case 'doc':
        return {'icon': Icons.description, 'color': Colors.blue};
      case 'xlsx':
      case 'xls':
        return {'icon': Icons.table_chart, 'color': Colors.green};
      case 'pptx':
      case 'ppt':
        return {'icon': Icons.slideshow, 'color': Colors.orange};
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return {'icon': Icons.image, 'color': Colors.purple};
      case 'txt':
        return {'icon': Icons.text_fields, 'color': Colors.grey};
      case 'csv':
        return {'icon': Icons.table_chart, 'color': Colors.green.shade700};
      default:
        return {'icon': Icons.insert_drive_file, 'color': Colors.indigo};
    }
  }

  /// Format file size
  String _formatFileSize(String size) {
    try {
      final cleanSize = size.replaceAll(RegExp(r'[^0-9]'), '');
      final bytes = int.tryParse(cleanSize) ?? 0;
      if (bytes == 0) return '0 B';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      debugPrint('Error formatting file size: $e for input: $size');
      return size;
    }
  }

  // /// Format date
  // String _formatDate(dynamic date) {
  //   if (date == null) return 'Unknown';
  //   try {
  //     final dateTime = DateTime.parse(date.toString());
  //     return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  //   } catch (e) {
  //     final dateStr = date.toString();
  //     if (dateStr.contains('/')) return dateStr;
  //     return dateStr;
  //   }
  // }

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            _hasError ? 'Unable to Load Data' : 'No Shared Documents',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _hasError
                  ? _errorMessage
                  : 'Documents and folders shared with you will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadSharedData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Show snackbar
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Shared With Me',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Documents and folders shared with you by other users',
                  style: TextStyle(fontSize: 14, color: Colors.indigo),
                ),
                const SizedBox(height: 20),

                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(10),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterDocuments,
                          decoration: InputDecoration(
                            hintText: 'Search documents, owners, keywords...',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.indigo,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    color: Colors.grey,
                                    onPressed: _clearSearch,
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Folders button
                    if (_sharedFolders.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(10),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _showSharedFolders,
                          icon: const Icon(Icons.folder_shared),
                          label: Text('${_sharedFolders.length}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Loading/Downloading Banner
          if (_isDownloading) _buildDownloadingBanner(),

          // Loading State
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.indigo,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading shared documents...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          // Empty or Error State
          else if (_filteredDocuments.isEmpty)
            Expanded(child: _buildEmptyState())
          // Documents List
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSharedData,
                color: Colors.indigo,
                child: Column(
                  children: [
                    // Results count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_filteredDocuments.length} document${_filteredDocuments.length == 1 ? '' : 's'} found',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (_sharedFolders.isNotEmpty)
                            Text(
                              '${_sharedFolders.length} shared folder${_sharedFolders.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Documents list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          return _buildDocumentCard(
                            _filteredDocuments[index],
                            index,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Refresh button in floating action button
      floatingActionButton: !_isLoading
          ? FloatingActionButton(
              onPressed: _loadSharedData,
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  /// Downloading banner widget
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
              style: TextStyle(
                color: const Color.fromARGB(255, 57, 170, 57),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
