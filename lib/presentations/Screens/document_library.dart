// presentations/Screens/document_library.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/services/document_library_service.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';

class DocumentLibrary extends StatefulWidget {
  const DocumentLibrary({super.key});

  @override
  State<DocumentLibrary> createState() => _DocumentLibraryState();
}

class _DocumentLibraryState extends State<DocumentLibrary>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final DocumentLibraryService _libraryService = DocumentLibraryService();
  final DocumentOpenerService _documentOpener = DocumentOpenerService();

  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<Document> _publicDocuments = [];
  List<Document> _filteredDocuments = [];
  bool _isDownloading = false;
  String? _downloadingFileName;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPublicDocuments();
  }

  Future<void> _loadPublicDocuments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Check internet connection - use ApiService instead
      if (!ApiService.isConnected) {
        // Load from local storage
        _loadFromLocalStorage();
        return;
      }

      // Try to load from backend first
      final documents = await _libraryService.fetchLibraryDocuments();

      if (!mounted) return;

      setState(() {
        _publicDocuments = documents;
        _filteredDocuments = documents;
        _isLoading = false;
      });

      // Save to local storage for offline access
      await _saveToLocalStorage();
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error loading library documents: $e');

      // Try to load from local storage as fallback
      _loadFromLocalStorage();
    }
  }

  /// Load data from local storage
  Future<void> _loadFromLocalStorage() async {
    try {
      final localDocs = await LocalStorageService.loadDocuments(isPublic: true);

      if (mounted) {
        setState(() {
          _publicDocuments = localDocs;
          _filteredDocuments = localDocs;
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
    if (_publicDocuments.isNotEmpty) {
      try {
        await LocalStorageService.saveDocuments(
          _publicDocuments,
          isPublic: true,
        );
        debugPrint(
          '✅ Saved ${_publicDocuments.length} documents to local storage',
        );
      } catch (e) {
        debugPrint('❌ Error saving to local storage: $e');
      }
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

  /// Filter documents based on search query
  void _filterDocuments(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredDocuments = _publicDocuments;
        _searchQuery = query;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredDocuments = _publicDocuments.where((doc) {
        return doc.name.toLowerCase().contains(lowercaseQuery) ||
            doc.keyword.toLowerCase().contains(lowercaseQuery) ||
            doc.type.toLowerCase().contains(lowercaseQuery) ||
            doc.owner.toLowerCase().contains(lowercaseQuery) ||
            doc.folder.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  List<Document> get _finalFilteredDocuments {
    List<Document> filtered = _filteredDocuments.where((doc) {
      final docType = doc.type.toUpperCase();
      bool isExcelFile = docType == 'XLS' || docType == 'XLSX';

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
      return matchesFilter;
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

          // Loading/Downloading Banner
          if (_isDownloading) _buildDownloadingBanner(),

          // Documents List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _finalFilteredDocuments.isEmpty
                ? _buildEmptyState()
                : _buildDocumentsList(),
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
                  onChanged: _filterDocuments,
                  decoration: InputDecoration(
                    hintText: 'Search library documents...',
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _filterDocuments('');
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
                      _searchController.clear();
                      _filterDocuments('');
                      _selectedFilter = 'All';
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
                _searchController.clear();
                _filterDocuments('');
                _selectedFilter = 'All';
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
        'Showing ${_finalFilteredDocuments.length} of ${_publicDocuments.length} documents';

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
    return RefreshIndicator(
      onRefresh: _loadPublicDocuments,
      child: Column(
        children: [
          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${_finalFilteredDocuments.length} document${_finalFilteredDocuments.length == 1 ? '' : 's'} found',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Documents list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _finalFilteredDocuments.length,
              itemBuilder: (context, index) {
                return _buildDocumentCard(
                  _finalFilteredDocuments[index],
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build document item card (UPDATED: View button + Single-tap options + Versions button)
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
                                'By: ${document.owner}',
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
                      return InkWell(
                        onTap: () => _searchByKeyword(trimmed),
                        borderRadius: BorderRadius.circular(16),
                        child: Chip(
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
          'Download access is restricted for this library document. '
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _hasError
                  ? _errorMessage
                  : _searchQuery.isEmpty
                  ? 'No public documents available in the library yet'
                  : 'No documents found for "$_searchQuery"',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filterDocuments('');
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          if (_hasError)
            ElevatedButton.icon(
              onPressed: _loadPublicDocuments,
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

  // ==================== ACTION METHODS ====================

  /// Handle document double-tap (same as SharedMeScreen)
  void _handleDocumentDoubleTap(Document document) {
    _documentOpener.handleDoubleTap(context: context, document: document);
  }

  // Search by keyword
  void _searchByKeyword(String keyword) {
    _searchController.text = keyword;
    _filterDocuments(keyword);
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

        String filename = document.name;

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

        // Add timestamp to create unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
        final ext = filename.substring(filename.lastIndexOf('.'));
        final uniqueFilename = '${nameWithoutExt}_$timestamp$ext';

        final filePath = '${directory.path}/$uniqueFilename';

        debugPrint('Saving to: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(bytesToSave);

        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('File saved: $fileSize bytes');
          _showSnackBar('Downloaded: $filename', Colors.green);

          if (document.size == '0' ||
              document.size == '0 KB' ||
              document.size == '0 B') {
            final docIndex = _publicDocuments.indexWhere(
              (d) => d.id == document.id,
            );
            if (docIndex != -1) {
              setState(() {
                _publicDocuments[docIndex] = document.copyWith(
                  size: fileSize.toString(),
                );
                _filteredDocuments = List.from(_publicDocuments);
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
        final errorMsg = result['error'] ?? 'Download failed';
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

  /// Show document details - Use existing preview instead since getDocumentDetails doesn't exist
  Future<void> _showDocumentDetails(Document document) async {
    // Since getDocumentDetails doesn't exist in DocumentLibraryService,
    // use the existing preview functionality
    _previewDocument(document);
  }

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

                _buildDetailRow('File Name', document.name),
                _buildDetailRow('File Type', document.type),
                _buildDetailRow('File Size', document.size),
                _buildDetailRow('Upload Date', document.uploadDate),
                _buildDetailRow('Owner', document.owner),
                _buildDetailRow('Classification', document.classification),
                _buildDetailRow('Folder', document.folder),
                _buildDetailRow('Keywords', document.keyword),
                if (document.details.isNotEmpty)
                  _buildDetailRow('Remarks', document.details),
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
      final result = await _libraryService.getDocumentVersions(document.id);

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

  /// Build downloading banner widget
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
}
