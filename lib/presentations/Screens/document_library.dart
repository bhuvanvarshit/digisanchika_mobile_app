// presentations/Screens/document_library.dart
// ignore_for_file: unused_element

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:digi_sanchika/services/api_service.dart'; // Add this import
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/services/document_library_service.dart';
import 'package:flutter/services.dart';

class DocumentLibrary extends StatefulWidget {
  const DocumentLibrary({super.key});

  @override
  State<DocumentLibrary> createState() => _DocumentLibraryState();
}

class _DocumentLibraryState extends State<DocumentLibrary>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final DocumentLibraryService _libraryService = DocumentLibraryService();

  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<Document> _publicDocuments = [];
  bool _isDownloading = false;
  String? _downloadingFileName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPublicDocuments();
  }

  Future<void> _loadPublicDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documents = await _libraryService.fetchLibraryDocuments();
      setState(() {
        _publicDocuments = documents;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading library documents: $e');
      }
      // Fallback to local storage
      final localDocs = await LocalStorageService.loadDocuments(isPublic: true);
      setState(() {
        _publicDocuments = localDocs;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshDocuments() {
    _loadPublicDocuments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPublicDocuments();
    }
  }

  List<Document> get _filteredDocuments {
    List<Document> filtered = _publicDocuments.where((doc) {
      final query = _searchQuery.toLowerCase();
      final docType = doc.type.toUpperCase();

      bool isExcelFile = docType == 'XLS' || docType == 'XLSX';
      final matchesSearch =
          doc.name.toLowerCase().contains(query) ||
          doc.keyword.toLowerCase().contains(query) ||
          doc.type.toLowerCase().contains(query) ||
          doc.owner.toLowerCase().contains(query) ||
          doc.folder.toLowerCase().contains(query);

      bool matchesFilter;
      if (_selectedFilter == 'All') {
        matchesFilter = true;
      } else if (_selectedFilter == 'XLSX' && isExcelFile) {
        matchesFilter = true;
      } else {
        matchesFilter = doc.type.toLowerCase().contains(
          _selectedFilter.toLowerCase(),
        );
      }
      return matchesSearch && matchesFilter;
    }).toList();

    // Sort by upload date (newest first)
    filtered.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchSection(),

          // Documents Count and Filter Info
          if (_searchQuery.isNotEmpty || _selectedFilter != 'All')
            _buildFilterInfo(),

          // Loading Indicator
          if (_isLoading) _buildLoadingIndicator(),

          // Documents List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredDocuments.isEmpty
                ? _buildEmptyState()
                : _buildDocumentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const LinearProgressIndicator(
      backgroundColor: Colors.grey,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
          ),
          SizedBox(height: 16),
          Text(
            'Loading library documents...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // Search Bar with Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search library documents...',
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
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
                onPressed: _refreshDocuments,
                icon: const Icon(Icons.refresh, color: Colors.indigo),
                tooltip: 'Refresh Documents',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Browse All and Filter Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = 'All';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Browse All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                constraints: const BoxConstraints(maxWidth: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list, color: Colors.indigo),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Types')),
                    DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                    DropdownMenuItem(value: 'DOCX', child: Text('Word')),
                    DropdownMenuItem(value: 'XLSX', child: Text('Excel')),
                    DropdownMenuItem(value: 'PPTX', child: Text('PowerPoint')),
                    DropdownMenuItem(value: 'IMAGE', child: Text('Images')),
                    DropdownMenuItem(value: 'TXT', child: Text('Text')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.info, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _buildFilterText(),
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'All';
                _searchController.clear();
              });
            },
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterText() {
    String text =
        'Showing ${_filteredDocuments.length} of ${_publicDocuments.length} documents';

    if (_searchQuery.isNotEmpty && _selectedFilter != 'All') {
      text += ' for "$_searchQuery" in $_selectedFilter';
    } else if (_searchQuery.isNotEmpty) {
      text += ' for "$_searchQuery"';
    } else if (_selectedFilter != 'All') {
      text += ' in $_selectedFilter';
    }

    return text;
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      itemCount: _filteredDocuments.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return _buildDocumentCard(_filteredDocuments[index], index);
      },
    );
  }

  Widget _buildDocumentCard(Document document, int index) {
    final docIcons = {
      'PDF': Icons.picture_as_pdf,
      'DOCX': Icons.description,
      'DOC': Icons.description,
      'XLSX': Icons.table_chart,
      'XLS': Icons.table_chart,
      'PPTX': Icons.slideshow,
      'PPT': Icons.slideshow,
      'TXT': Icons.text_snippet,
      'IMAGE': Icons.image,
    };
    final docColors = {
      'PDF': Colors.red,
      'DOCX': Colors.blue,
      'DOC': Colors.blue,
      'XLSX': Colors.green,
      'XLS': Colors.green,
      'PPTX': Colors.orange,
      'PPT': Colors.orange,
      'TXT': Colors.grey,
      'IMAGE': Colors.purple,
    };

    String fileType = document.type.toUpperCase();
    IconData icon = docIcons[fileType] ?? Icons.insert_drive_file;
    Color color = docColors[fileType] ?? Colors.indigo;

    return GestureDetector(
      onDoubleTap: () => _handleDoubleTap(document),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _previewDocument(document),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _previewDocument(document),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  document.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${document.size} • ${document.type}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'By: ${document.owner}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.folder_open,
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
                  ),
                  // IconButton(
                  //   onPressed: () => _showDeleteConfirmation(document, index),
                  //   icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  //   tooltip: 'Delete Document',
                  // ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Document Details
              _buildDetailRow('Keywords', document.keyword, Icons.label),
              _buildDetailRow(
                'Upload Date',
                document.uploadDate,
                Icons.calendar_today,
              ),
              _buildDetailRow(
                'Classification',
                document.classification,
                Icons.security,
              ),
              if (document.details.isNotEmpty)
                _buildDetailRow('Remarks', document.details, Icons.description),
              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(document),
            ],
          ),
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

  Widget _buildActionButtons(Document document) {
    return Row(
      children: [
        if (document.allowDownload)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isDownloading && _downloadingFileName == document.name
                  ? null
                  : () => _downloadDocument(document),
              icon: _isDownloading && _downloadingFileName == document.name
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    )
                  : const Icon(Icons.download, size: 18),
              label: _isDownloading && _downloadingFileName == document.name
                  ? const Text('Downloading...')
                  : const Text('Download'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        if (!document.allowDownload) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showDownloadRestricted(document),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Download Restricted'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _previewDocument(document),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Preview'),
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
            onPressed: () => _showDocumentVersions(document),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Versions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.folder_open : Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty
                ? 'Document Library Empty'
                : 'No Documents Found',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _searchQuery.isEmpty
                ? 'No public documents available in the library yet'
                : 'No documents found for "$_searchQuery"',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ==================== ACTION METHODS ====================

  // Handle double tap gesture
  Future<void> _handleDoubleTap(Document document) async {
    if (document.allowDownload) {
      await _downloadDocument(document);
    } else {
      _previewDocument(document);
    }
  }

  // Download document
  Future<void> _downloadDocument(Document document) async {
    if (!document.allowDownload) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download is not allowed for ${document.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadingFileName = document.name;
    });

    try {
      debugPrint(
        'Starting download for document: ${document.id} - ${document.name}',
      );

      final result = await _libraryService.downloadDocument(
        document.id,
        document.name,
      );

      debugPrint('Download result keys: ${result.keys}');
      debugPrint('Success: ${result['success']}');

      if (result['success'] == true) {
        if (!result.containsKey('data')) {
          debugPrint('data key missing in response');
          throw Exception('Server did not return file data');
        }

        final fileData = result['data'];
        List<int> bytesToSave;

        if (fileData is List<int>) {
          bytesToSave = fileData;
        } else if (fileData is List<dynamic>) {
          bytesToSave = fileData.cast<int>();
        } else if (fileData is String) {
          bytesToSave = utf8.encode(fileData);
        } else {
          throw Exception('Invalid file data format');
        }

        if (bytesToSave.isEmpty) {
          throw Exception('Downloaded file data is empty (0 bytes)');
        }

        debugPrint('✅ Received ${bytesToSave.length} bytes of file data');

        // Get directory
        Directory directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!directory.existsSync()) {
            directory = await getApplicationDocumentsDirectory();
          }
        } else if (Platform.isIOS) {
          directory = (await getDownloadsDirectory())!;
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        // Create filename
        String filename = document.name;
        final extension = '.${document.type.toLowerCase()}';
        if (!filename.toLowerCase().endsWith(extension.toLowerCase())) {
          filename = '$filename$extension';
        }

        // Add timestamp to create unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
        final ext = filename.substring(filename.lastIndexOf('.'));
        final uniqueFilename = '${nameWithoutExt}_$timestamp$ext';

        final filePath = '${directory.path}/$uniqueFilename';
        debugPrint('Saving to: $filePath');

        final file = File(filePath);

        // // Check if file exists
        // if (await file.exists()) {
        //   bool shouldOverwrite = await _showOverwriteDialog(filename);
        //   if (!shouldOverwrite) {
        //     setState(() {
        //       _isDownloading = false;
        //       _downloadingFileName = null;
        //     });
        //     return;
        //   }
        // }

        await file.writeAsBytes(bytesToSave);

        if (await file.exists()) {
          final fileSize = await file.length();
          // ignore: unnecessary_brace_in_string_interps
          debugPrint('File saved: ${fileSize} bytes');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded: $filename'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Special handling for Python files
          if (document.type.toLowerCase() == 'py') {
            _showFileContent(bytesToSave, filename);
            return;
          }

          // Auto-open the downloaded file
          try {
            final openResult = await OpenFilex.open(filePath);

            if (openResult.type != ResultType.done) {
              debugPrint('⚠ Could not open file: ${openResult.message}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloaded. Could not open automatically.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('⚠ Error opening file: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloaded. Use a compatible app to open it.'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          }
        } else {
          throw Exception('Failed to save file to disk');
        }
      } else {
        final errorMsg = result['error'] ?? 'Download failed';
        debugPrint('Download failed from service: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadingFileName = null;
      });
    }
  }

  // Helper method to show Python file content
  void _showFileContent(List<int> fileBytes, String filename) {
    try {
      final content = utf8.decode(fileBytes);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(_getDocumentIcon('py'), size: 24),
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
                Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code copied to clipboard'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot display file content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Preview document
  void _previewDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.preview, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Preview: ${document.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getDocumentIcon(document.type),
                        size: 60,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${document.type} File Preview',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.size,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'File Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 12),

                _buildPreviewDetailRow('File Name', document.name),
                _buildPreviewDetailRow('File Type', document.type),
                _buildPreviewDetailRow('File Size', document.size),
                _buildPreviewDetailRow('Upload Date', document.uploadDate),
                _buildPreviewDetailRow('Owner', document.owner),
                _buildPreviewDetailRow(
                  'Classification',
                  document.classification,
                ),
                _buildPreviewDetailRow('Folder', document.folder),
                _buildPreviewDetailRow('Keywords', document.keyword),
                if (document.details.isNotEmpty)
                  _buildPreviewDetailRow('Remarks', document.details),
              ],
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Download'),
            ),
        ],
      ),
    );
  }

  // Show document versions
  void _showDocumentVersions(Document document) async {
    final result = await _libraryService.getDocumentVersions(document.id);

    if (result['success'] == true) {
      final versions = result['versions'] as List;

      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document Versions'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: versions.isEmpty
                ? const Center(child: Text('No version history available'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    itemBuilder: (context, index) {
                      final version = versions[index];
                      return ListTile(
                        leading: Icon(
                          version['is_current'] == true
                              ? Icons.check_circle
                              : Icons.history,
                          color: version['is_current'] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text('Version ${version['version_number']}'),
                        subtitle: Text(
                          'Uploaded: ${_formatDate(version['upload_date'])}',
                        ),
                        trailing: version['is_current'] == true
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
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'].toString()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Show download restricted message
  void _showDownloadRestricted(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.orange),
            SizedBox(width: 8),
            Text('Download Restricted'),
          ],
        ),
        content: Text(
          'Download is not allowed for "${document.name}" due to ${document.classification} classification.',
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

  // Show delete confirmation
  void _showDeleteConfirmation(Document document, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Document'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${document.name}" from the library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDocument(document, index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete document
  Future<void> _deleteDocument(Document document, int index) async {
    try {
      // Try to delete from backend
      if (ApiService.isConnected) {
        final result = await _libraryService.deleteDocument(document.id);

        if (result['success'] == true) {
          // Remove from local storage
          await LocalStorageService.deleteDocument(
            document.name,
            isPublic: true,
          );

          // Update UI
          if (mounted) {
            setState(() {
              _publicDocuments.removeWhere((doc) => doc.id == document.id);

              _loadPublicDocuments();
            });
          }

          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Document deleted successfully',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(result['error']?.toString() ?? 'Delete failed');
        }
      } else {
        // If backend delete fails, still remove from local view
        await LocalStorageService.deleteDocument(document.id, isPublic: true);

        if (mounted) {
          setState(() {
            _publicDocuments.removeWhere((doc) => doc.id == document.id);
          });
        }
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline - Removed from local view'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Delete error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // // Helper: Show permission denied dialog
  // Future<void> _showPermissionDeniedDialog() async {
  //   await showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Storage Permission Required'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: const [
  //           Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Icon(Icons.warning, color: Colors.orange),
  //               SizedBox(width: 12),
  //               Expanded(
  //                 child: Text(
  //                   'Downloading files requires storage permission. '
  //                   'Please grant the permission in app settings to continue.',
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //       actionsAlignment: MainAxisAlignment.end,
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             openAppSettings();
  //           },
  //           child: const Text('Open Settings'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // // Helper: Show overwrite dialog
  // Future<bool> _showOverwriteDialog(String fileName) async {
  //   bool? result = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('File Exists'),
  //       content: Text(
  //         '"$fileName" already exists. Do you want to overwrite it?',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           child: const Text('Overwrite'),
  //         ),
  //       ],
  //     ),
  //   );
  //   return result ?? false;
  // }

  // Helper: Format date
  String _formatDate(dynamic date) {
    try {
      return DateTime.parse(date.toString()).toString().split(' ')[0];
    } catch (e) {
      return date.toString();
    }
  }

  // Helper: Get document icon
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
      case 'IMAGE':
        return Icons.image;
      case 'TXT':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Helper: Build preview detail row
  Widget _buildPreviewDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
