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
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:digi_sanchika/presentations/Screens/shared_folder_screen.dart';
import 'package:digi_sanchika/services/my_documents_service.dart';
import 'package:digi_sanchika/services/shared_folders_service.dart';

// Add enum for layout modes
enum SharedViewMode { list, grid2x2, grid3x3, compact, detailed }

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

  // NEW: Layout mode and file type filter variables
  SharedViewMode _currentViewMode = SharedViewMode.list;
  bool _showFileTypeFilter = false;
  String _selectedFileType = 'All';
  List<String> _availableFileTypes = [
    'All',
  ]; // Will be populated from documents

  // NEW: Collapsible states for document cards
  Map<String, bool> _expandedStates = {};

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
      final response = await _sharedService.fetchSharedDocuments();

      // Extract documents and folders from the response
      final List<Document> documents = response.documents;
      final List<SharedFolder> folders = response.folders;

      if (!mounted) return;

      // Extract unique file types from documents
      final fileTypes = documents
          .map((doc) => doc.type.toUpperCase())
          .toSet()
          .toList();
      fileTypes.sort();

      setState(() {
        _sharedDocuments = documents;
        _filteredDocuments = documents;
        _sharedFolders = folders;
        _totalDocuments = documents.length;
        _totalFolders = folders.length;
        _availableFileTypes = ['All', ...fileTypes];
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

      // Extract file types from local docs too
      final fileTypes = localDocs
          .map((doc) => doc.type.toUpperCase())
          .toSet()
          .toList();
      fileTypes.sort();

      if (mounted) {
        setState(() {
          _sharedDocuments = localDocs;
          _filteredDocuments = localDocs;
          _totalDocuments = localDocs.length;
          _totalFolders = 0;
          _availableFileTypes = ['All', ...fileTypes];
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

  /// Filter documents based on search query and file type
  void _filterDocuments({String? searchQuery, String? fileType}) {
    final query = searchQuery ?? _searchController.text;
    final type = fileType ?? _selectedFileType;

    setState(() {
      _filteredDocuments = _sharedDocuments.where((doc) {
        // Apply file type filter
        final fileTypeMatch = type == 'All' || doc.type.toUpperCase() == type;

        // Apply search filter if query exists
        if (query.isEmpty) return fileTypeMatch;

        final lowercaseQuery = query.toLowerCase();
        return fileTypeMatch &&
            (doc.name.toLowerCase().contains(lowercaseQuery) ||
                (doc.owner.isNotEmpty &&
                    doc.owner.toLowerCase().contains(lowercaseQuery)) ||
                (doc.keyword.isNotEmpty &&
                    doc.keyword.toLowerCase().contains(lowercaseQuery)) ||
                doc.type.toLowerCase().contains(lowercaseQuery) ||
                (doc.classification.isNotEmpty &&
                    doc.classification.toLowerCase().contains(
                      lowercaseQuery,
                    )) ||
                (doc.details.isNotEmpty &&
                    doc.details.toLowerCase().contains(lowercaseQuery)) ||
                (doc.folder.isNotEmpty &&
                    doc.folder.toLowerCase().contains(lowercaseQuery)));
      }).toList();
    });
  }

  /// Clear search and reset filter
  void _clearSearch() {
    _searchController.clear();
    _selectedFileType = 'All';
    _filterDocuments(searchQuery: '', fileType: 'All');
  }

  /// Get file icon based on type
  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'txt':
        return Icons.text_fields;
      case 'csv':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get file color based on type
  Color _getFileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'docx':
      case 'doc':
        return Colors.blue;
      case 'xlsx':
      case 'xls':
        return Colors.green;
      case 'pptx':
      case 'ppt':
        return Colors.orange;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'txt':
        return Colors.grey;
      case 'csv':
        return Colors.green.shade700;
      default:
        return Colors.indigo;
    }
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
              Icon(_getFileIcon('py'), size: 24, color: _getFileColor('py')),
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
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                _getFileIcon(document.type),
                size: 24,
                color: _getFileColor(document.type),
              ),
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
            // if (document.allowDownload)
            //   ElevatedButton(
            //     onPressed: () {
            //       Navigator.pop(context);
            //       _downloadDocument(document);
            //     },
            //     style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            //     child: const Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         Icon(Icons.download, size: 18),
            //         SizedBox(width: 6),
            //         Text('Download'),
            //       ],
            //     ),
            //   ),
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

  // Format date to DD-MM-YYYY (Same as Document Library)
  String _formatDateDDMMYYYY(dynamic date) {
    try {
      if (date == null || date.toString().isEmpty) {
        return 'N/A';
      }

      final dateStr = date.toString().trim();

      // Check if date is in DD/MM/YYYY format (e.g., "29/10/2025")
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length >= 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2];
          return '$day-$month-$year';
        }
      }

      // Check if date is in YYYY-MM-DD format (e.g., "2025-10-29")
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length >= 3) {
          // If first part is 4 digits, assume YYYY-MM-DD format
          if (parts[0].length == 4) {
            final year = parts[0];
            final month = parts[1].padLeft(2, '0');
            final day = parts[2].split(' ')[0].padLeft(2, '0');
            return '$day-$month-$year';
          } else {
            // Assume DD-MM-YYYY format
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2];
            return '$day-$month-$year';
          }
        }
      }

      // Try to parse as DateTime
      try {
        final dateTime = DateTime.parse(dateStr);
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year.toString();
        return '$day-$month-$year';
      } catch (e) {
        // If parsing fails, return original string
        return dateStr;
      }
    } catch (e) {
      debugPrint('Error formatting date: $e for input: $date');
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

  // Helper method to build detail row WITH icons (for the new design)
  Widget _buildDetailRowWithIcon(
    String label,
    String value,
    IconData iconData,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  // ============ FEATURE 1: COLLAPSIBLE DOCUMENT CARDS ============

  // Build document item card with COLLAPSIBLE functionality
  Widget _buildDocumentCard(Document document, int index) {
    final iconData = _getFileIcon(document.type);
    final color = _getFileColor(document.type);

    // Format the date to DD MM YYYY
    String formattedDate = _formatDateDDMMYYYY(document.uploadDate);

    // Check if this specific document is expanded
    bool isExpanded = _expandedStates[document.id] ?? false;

    return InkWell(
      onTap: () => _handleDocumentDoubleTap(document),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    child: Icon(iconData, color: color, size: 32),
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
                            // COLLAPSIBLE EXPAND/COLLAPSE BUTTON
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
                            // Vertical More Options Button
                            PopupMenuButton<String>(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'details',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Details'),
                                    ],
                                  ),
                                ),
                                // if (document.allowDownload)
                                //   PopupMenuItem(
                                //     value: 'download',
                                //     child: Row(
                                //       children: [
                                //         Icon(
                                //           Icons.download,
                                //           size: 20,
                                //           color: Colors.green,
                                //         ),
                                //         SizedBox(width: 8),
                                //         Text('Download'),
                                //       ],
                                //     ),
                                //   ),
                              ],
                              onSelected: (value) {
                                if (value == 'details') {
                                  _showDocumentDetails(document);
                                } else if (value == 'download') {
                                  _downloadDocument(document);
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
                      // Metadata details section
                      if (document.keyword.isNotEmpty)
                        _buildDetailRowWithIcon(
                          'Keyword',
                          document.keyword,
                          Icons.label,
                        ),
                      _buildDetailRowWithIcon(
                        'Owner',
                        document.owner,
                        Icons.person,
                      ),
                      _buildDetailRowWithIcon(
                        'Folder',
                        document.folder,
                        Icons.folder,
                      ),
                      _buildDetailRowWithIcon(
                        'Classification',
                        document.classification,
                        Icons.security,
                      ),
                      if (document.details.isNotEmpty)
                        _buildDetailRowWithIcon(
                          'Details',
                          document.details,
                          Icons.info_outline,
                        ),
                      const SizedBox(height: 16),

                      // ACTION BUTTONS ROW
                      Row(
                        children: [
                          // VIEW BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _handleDocumentDoubleTap(document),
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

                          // DOWNLOAD BUTTON (conditionally enabled)
                          // Expanded(
                          //   child: document.allowDownload
                          //       ? OutlinedButton.icon(
                          //           onPressed: () =>
                          //               _downloadDocument(document),
                          //           icon: const Icon(Icons.download, size: 18),
                          //           label: const Text('Download'),
                          //           style: OutlinedButton.styleFrom(
                          //             foregroundColor: Colors.green,
                          //             side: const BorderSide(
                          //               color: Colors.green,
                          //             ),
                          //             padding: const EdgeInsets.symmetric(
                          //               vertical: 10,
                          //             ),
                          //           ),
                          //         )
                          //       : ElevatedButton.icon(
                          //           onPressed: () =>
                          //               _showDownloadRestrictedPopup(context),
                          //           icon: Icon(
                          //             Icons.download,
                          //             size: 18,
                          //             color: Colors.grey.shade300,
                          //           ),
                          //           label: Text(
                          //             'Download',
                          //             style: TextStyle(
                          //               color: Colors.grey.shade300,
                          //             ),
                          //           ),
                          //           style: ElevatedButton.styleFrom(
                          //             backgroundColor: Colors.grey.shade200,
                          //             foregroundColor: Colors.grey.shade300,
                          //             padding: const EdgeInsets.symmetric(
                          //               vertical: 10,
                          //             ),
                          //             shape: RoundedRectangleBorder(
                          //               borderRadius: BorderRadius.circular(8),
                          //             ),
                          //           ),
                          //         ),
                          // ),
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

  // ============ FEATURE 2: LAYOUT MODES ============

  /// Method to build layout selector
  Widget _buildLayoutSelector() {
    return PopupMenuButton<SharedViewMode>(
      tooltip: 'Change Layout',
      icon: Icon(
        _getViewModeIcon(_currentViewMode),
        color: Colors.indigo,
        size: 24,
      ),
      onSelected: (SharedViewMode mode) {
        setState(() {
          _currentViewMode = mode;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<SharedViewMode>>[
        PopupMenuItem<SharedViewMode>(
          value: SharedViewMode.list,
          child: Row(
            children: [
              Icon(Icons.list, color: Colors.indigo),
              SizedBox(width: 8),
              Text('List View'),
              if (_currentViewMode == SharedViewMode.list)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<SharedViewMode>(
          value: SharedViewMode.grid2x2,
          child: Row(
            children: [
              Icon(Icons.grid_on, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Grid (2x2)'),
              if (_currentViewMode == SharedViewMode.grid2x2)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<SharedViewMode>(
          value: SharedViewMode.grid3x3,
          child: Row(
            children: [
              Icon(Icons.view_module, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Grid (3x3)'),
              if (_currentViewMode == SharedViewMode.grid3x3)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<SharedViewMode>(
          value: SharedViewMode.compact,
          child: Row(
            children: [
              Icon(Icons.view_headline, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Compact View'),
              if (_currentViewMode == SharedViewMode.compact)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<SharedViewMode>(
          value: SharedViewMode.detailed,
          child: Row(
            children: [
              Icon(Icons.table_rows, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Detailed View'),
              if (_currentViewMode == SharedViewMode.detailed)
                Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getViewModeIcon(SharedViewMode mode) {
    switch (mode) {
      case SharedViewMode.list:
        return Icons.list;
      case SharedViewMode.grid2x2:
        return Icons.grid_on;
      case SharedViewMode.grid3x3:
        return Icons.view_module;
      case SharedViewMode.compact:
        return Icons.view_headline;
      case SharedViewMode.detailed:
        return Icons.table_rows;
    }
  }

  /// Method to build documents content based on view mode
  Widget _buildDocumentsContent(List<Document> documents) {
    switch (_currentViewMode) {
      case SharedViewMode.list:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentCard(documents[index], index);
          },
        );
      case SharedViewMode.grid2x2:
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
      case SharedViewMode.grid3x3:
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
      case SharedViewMode.compact:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentCompactItem(documents[index], index);
          },
        );
      case SharedViewMode.detailed:
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

  // Grid view item
  Widget _buildDocumentGridItem(Document document, int index, int columns) {
    final iconData = _getFileIcon(document.type);
    final color = _getFileColor(document.type);
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
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(columns == 2 ? 12 : 8),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconData,
                  color: color,
                  size: columns == 2 ? 26 : 18,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  document.name,
                  style: TextStyle(
                    fontSize: columns == 2 ? 11 : 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: columns == 2 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                document.type,
                style: TextStyle(
                  fontSize: columns == 2 ? 9 : 8,
                  color: Colors.grey.shade600,
                ),
              ),
              if (columns == 2) ...[
                const SizedBox(height: 2),
                Text(
                  _formatDateDDMMYYYY(document.uploadDate),
                  style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Compact view item
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
                  _getFileIcon(document.type),
                  color: _getFileColor(document.type),
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
                  _formatDateDDMMYYYY(document.uploadDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Detailed view item
  Widget _buildDocumentDetailedItem(Document document, int index) {
    final iconData = _getFileIcon(document.type);
    final color = _getFileColor(document.type);
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          document.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    document.owner,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    document.folder,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateDDMMYYYY(document.uploadDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.security,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  document.classification,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 6),
                            const Text(
                              'Details',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (document.allowDownload)
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(
                                Icons.download,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 6),
                              const Text(
                                'Download',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      if (value == 'details') {
                        _showDocumentDetails(document);
                      } else if (value == 'download') {
                        _downloadDocument(document);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 16,
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
                        size: 14,
                        color: Colors.purple,
                      ),
                      label: Text(
                        'View',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDocumentVersions(document),
                      icon: Icon(Icons.history, size: 14, color: Colors.blue),
                      label: Text(
                        'Versions',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: document.allowDownload
                        ? OutlinedButton.icon(
                            onPressed: () => _downloadDocument(document),
                            icon: Icon(
                              Icons.download,
                              size: 14,
                              color: Colors.green,
                            ),
                            label: Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () =>
                                _showDownloadRestrictedPopup(context),
                            icon: Icon(
                              Icons.download,
                              size: 14,
                              color: Colors.grey.shade300,
                            ),
                            label: Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
    );
  }

  // ============ FEATURE 3: FILE TYPE FILTER ============

  /// Build file type filter dropdown
  Widget _buildFileTypeFilter() {
    return PopupMenuButton<String>(
      tooltip: 'Filter by File Type',
      icon: Icon(
        Icons.filter_alt,
        color: _selectedFileType != 'All' ? Colors.blue : Colors.indigo,
        size: 24,
      ),
      onSelected: (String type) {
        setState(() {
          _selectedFileType = type;
          _filterDocuments(fileType: type);
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        for (String type in _availableFileTypes)
          PopupMenuItem<String>(
            value: type,
            child: Row(
              children: [
                if (type == 'All')
                  Icon(Icons.all_inclusive, color: Colors.grey)
                else
                  Icon(_getFileIcon(type), color: _getFileColor(type)),
                SizedBox(width: 8),
                Text(type),
                if (_selectedFileType == type)
                  Icon(Icons.check, color: Colors.green, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  /// Show file type filter badge
  Widget _buildFileTypeBadge() {
    if (_selectedFileType == 'All') return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(left: 8),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getFileIcon(_selectedFileType),
            size: 14,
            color: _getFileColor(_selectedFileType),
          ),
          SizedBox(width: 6),
          Text(
            _selectedFileType,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedFileType = 'All';
                _filterDocuments(fileType: 'All');
              });
            },
            child: Icon(Icons.close, size: 14, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  void _showDownloadRestrictedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.download_outlined, size: 48, color: Colors.blue),
        title: const Text('Download Document'),
        content: const Text(
          'For security purposes, library documents require approval for downloading. '
          'Please reach out to your team administrator or the document owner '
          'to request download permissions.\n\n'
          'In the meantime, you can preview the document using the "View" option.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understand'),
          ),
        ],
      ),
    );
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

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isEmpty
                ? Icons.people_outline
                : Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            _searchController.text.isEmpty
                ? (_hasError ? 'Unable to Load Data' : 'No Shared Documents')
                : 'No Documents Found',
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
                  : _searchController.text.isEmpty
                  ? 'Documents and folders shared with you will appear here'
                  : 'No documents found for "${_searchController.text}"',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (_searchController.text.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            )
          else if (_hasError)
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
      appBar: AppBar(
        title: const Text(
          'Shared With Me',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.indigo,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.indigo,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search and stats section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Search bar with filters
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
                          onChanged: (value) =>
                              _filterDocuments(searchQuery: value),
                          maxLines: 1,
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
                              vertical: 14,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // File Type Filter
                    // _buildFileTypeFilter(),
                    // const SizedBox(width: 8),
                    // Layout Selector
                    _buildLayoutSelector(),
                    const SizedBox(width: 12),
                    // Folders button - Only show if needed
                    if (_sharedFolders.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 80),
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
                          icon: const Icon(Icons.folder_shared, size: 18),
                          label: Text(
                            '${_sharedFolders.length}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stats row with filter badge
                Row(
                  children: [
                    Text(
                      '${_filteredDocuments.length} document${_filteredDocuments.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    _buildFileTypeBadge(),
                    const Spacer(),
                    if (_sharedFolders.isNotEmpty)
                      Text(
                        '${_sharedFolders.length} folder${_sharedFolders.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Loading/Downloading Banner
          if (_isDownloading) _buildDownloadingBanner(),

          // Main Content Area
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
          else if (_filteredDocuments.isEmpty)
            Expanded(child: _buildEmptyState())
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSharedData,
                color: Colors.indigo,
                child: _buildDocumentsContent(_filteredDocuments),
              ),
            ),
        ],
      ),
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
