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
          // Search and Filter Section in Single Row (70% search, 30% filter)
          _buildSearchAndFilterSection(),

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

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          // Search Bar - 70% width
          Expanded(
            flex: 7,
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

          const SizedBox(width: 12),

          // Filter Dropdown - 30% width
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _selectedFilter,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_list, color: Colors.indigo),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('Filter')),
                  DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                  DropdownMenuItem(value: 'DOCX', child: Text('Word')),
                  DropdownMenuItem(value: 'XLSX', child: Text('Excel')),
                  DropdownMenuItem(value: 'PPTX', child: Text('PPT')),
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

  // Build document item card with improved metadata layout
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
      'IMAGE': Icons.image,
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
      'IMAGE': Colors.purple,
    };

    String fileType = document.type.toUpperCase();
    IconData icon = docIcons[fileType] ?? Icons.insert_drive_file;
    Color color = docColors[fileType] ?? Colors.indigo;

    // Format the date to DD MM YYYY
    String formattedDate = _formatDateDDMMYYYY(document.uploadDate);

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
              // Top row with icon, document info
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
                        Text(
                          document.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Metadata details section
              if (document.keyword.isNotEmpty)
                _buildDetailRow('Keyword', document.keyword, Icons.label),
              _buildDetailRow('Owner', document.owner, Icons.person),
              _buildDetailRow('Folder', document.folder, Icons.folder),
              _buildDetailRow(
                'Classification',
                document.classification,
                Icons.security,
              ),
              if (document.details.isNotEmpty)
                _buildDetailRow(
                  'Details',
                  document.details,
                  Icons.info_outline,
                ),
              const SizedBox(height: 16),

              // ACTION BUTTONS ROW - Only View and Versions buttons
              Row(
                children: [
                  // VIEW BUTTON - opens the document
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDocumentDoubleTap(document),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // VERSIONS BUTTON - shows document versions
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDocumentVersions(document),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Versions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

  // Helper method to build detail row
  Widget _buildDetailRow(String label, String value, IconData iconData) {
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
                      'Uploaded: ${_formatDateDDMMYYYY(version['upload_date'])}',
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

  // Format date to DD-MM-YYYY
  String _formatDateDDMMYYYY(dynamic date) {
    try {
      final dateTime = DateTime.parse(date.toString());
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      debugPrint('Error formatting date: $e for input: $date');
      // Try to handle other date formats
      if (date.toString().contains('-')) {
        final parts = date.toString().split('-');
        if (parts.length >= 3) {
          final day = parts[2].split(' ')[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[0];
          return '$day-$month-$year';
        }
      }
      return date.toString();
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
