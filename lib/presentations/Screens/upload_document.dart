// ignore_for_file: use_build_context_synchronously, unnecessary_this
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/services/upload_service.dart';
import 'package:digi_sanchika/services/folder_helper.dart';
import 'package:digi_sanchika/models/folder_tree_node.dart';
import 'package:digi_sanchika/services/folder_tree_service.dart'; // ADD THIS
import 'package:digi_sanchika/presentations/screens/folder_manager_screen.dart'; // ADD THIS
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/models/folder.dart';
import 'dart:io';

class UploadDocumentTab extends StatefulWidget {
  final Function(Document) onDocumentUploaded;
  final List<Folder> folders;
  final String? userName;

  const UploadDocumentTab({
    super.key,
    required this.onDocumentUploaded,
    required this.folders,
    this.userName,
  });

  @override
  State<UploadDocumentTab> createState() => _UploadDocumentTabState();
}

class _UploadDocumentTabState extends State<UploadDocumentTab> {
  // ============ STATE VARIABLES ============
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedFolder = '';
  String _selectedClassification = 'General';
  bool _allowDownload = true;
  String _selectedSharingType = 'Public';
  final List<PlatformFile> _uploadedFiles = [];
  bool _isLoading = false;
  final bool _isConnected = true;

  // Folder management variables
  List<Map<String, dynamic>> _availableFolders = [];
  bool _foldersLoading = false;

  // New folder tree variables
  List<FolderTreeNode> _folderTree = []; // For tree structure
  String? _selectedFolderName; // For display
  int? _selectedFolderId; // For upload

  // ============ CONSTANTS ============
  static const List<String> _allSupportedExtensions = [
    // Legacy Office
    'doc', 'xls', 'ppt', 'rtf', 'mdb', 'pub', 'pps', 'dot', 'xlt', 'pot',
    // Modern Office
    'docx', 'xlsx', 'pptx', 'dotx', 'xltx', 'potx', 'accdb', 'one',
    // OpenDocument Format
    'odt', 'ods', 'odp', 'odg', 'odf',
    // Apple iWork
    'pages', 'numbers', 'key',
    // PDFs
    'pdf',
    // Text Files
    'txt', 'md', 'markdown',
    // CSV/Data Files
    'csv', 'tsv', 'xml', 'json',
    // ZIP & Archives
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso',
    // Audio Files
    'mp3',
    'wav',
    'ogg',
    'flac',
    'aac',
    'm4a',
    'wma',
    'opus',
    'mid',
    'midi',
    'aiff',
    'au',
    // Video Files
    'mp4',
    'mov',
    'avi',
    'mkv',
    'flv',
    'wmv',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
    '3gp',
    'mts',
    'vob',
    'ogv',
    // Code Files - Python
    'py', 'pyc', 'pyo', 'pyd',
    // JavaScript/TypeScript/React/Node.js
    'js', 'jsx', 'ts', 'tsx', 'node', 'njs',
    // HTML/CSS
    'html', 'htm', 'css', 'scss', 'sass', 'less',
    // Database
    'sql', 'db', 'sqlite', 'sqlite3', 'mdb', 'accdb', 'frm', 'myd', 'myi',
    // Other programming languages
    'java', 'class', 'jar', 'c', 'cpp', 'cc', 'cxx', 'h', 'hpp', 'hxx',
    'cs', 'php', 'phtml', 'rb', 'erb', 'go', 'rs', 'swift', 'kt', 'kts', 'dart',
    // Shell/Bash
    'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd',
    // Configuration Files
    'env', 'config', 'toml', 'ini', 'yaml', 'yml',
    // JSON Files
    'json', 'jsonl', 'jsonc',
    // Google Files
    'gdoc', 'gsheet', 'gslides', 'gdraw',
    // Other Important
    'log', 'lock', 'license', 'readme', 'gitignore', 'dockerfile', 'makefile',
  ];

  @override
  void dispose() {
    _keywordsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  // ============ HELPER METHODS (DECLARE THESE FIRST) ============
  String _getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method to convert tree to flat list
  List<Map<String, dynamic>> _convertTreeToFlatList(
    List<FolderTreeNode> nodes,
  ) {
    final List<Map<String, dynamic>> result = [];

    void traverse(FolderTreeNode node) {
      result.add({'id': node.id, 'name': node.name, 'depth': node.depth});

      for (var child in node.children) {
        traverse(child);
      }
    }

    for (var node in nodes) {
      traverse(node);
    }

    return result;
  }

  // ============ FOLDER MANAGEMENT METHODS ============
  Future<void> _loadFolders() async {
    if (mounted) {
      setState(() => _foldersLoading = true);
    }

    try {
      final folderService = FolderTreeService();
      final folders = await folderService.fetchFolderTree();

      if (mounted) {
        setState(() {
          _folderTree = folders;
          _foldersLoading = false;

          // Initialize with ALL folders COLLAPSED by default
          _expandedFolders = {};

          // Convert to flat list for backward compatibility
          _availableFolders = _convertTreeToFlatList(folders);

          // Set default folder to "Root" first
          _selectedFolder = ''; // Root
          _selectedFolderName = null;
          _selectedFolderId = null;
        });
      }

      if (kDebugMode) {
        print(
          '✅ Loaded ${folders.length} root folders (all collapsed by default)',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _foldersLoading = false);
      }
      if (kDebugMode) {
        print('❌ Error loading folders: $e');
      }
      _showErrorSnackBar('Failed to load folders: $e');
    }
  }

  // Method to navigate to folder manager
  Future<void> _navigateToFolderManager(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderManagerScreen(userName: widget.userName),
      ),
    );

    // When returning from FolderManagerScreen, refresh the folder list
    if (mounted && result == true) {
      await _loadFolders();
    }
  }

  // Get breadcrumb path for display
  String _getBreadcrumbPath(FolderTreeNode node) {
    final pathNodes = node.getPath(_folderTree);
    final path = pathNodes.map((n) => n.name).toList();
    path.add(node.name);

    if (path.isEmpty) return 'Root folder';
    return path.join(' → ');
  }

  // Build loading state
  Widget _buildLoadingFolders() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading folders...'),
        ],
      ),
    );
  }

  // Build folder dropdown with custom UI
  Widget _buildFolderDropdown() {
    return Column(
      children: [
        // Current selection display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                _selectedFolderId == null ? Icons.home : Icons.folder,
                size: 20,
                color: _selectedFolderId == null
                    ? Colors.grey
                    : Colors.amber.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFolderName ?? 'Root (No folder selected)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _selectedFolderId == null
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                    if (_selectedFolderId != null)
                      Text(
                        'ID: $_selectedFolderId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (_selectedFolderId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedFolder = '';
                      _selectedFolderName = null;
                      _selectedFolderId = null;
                    });
                  },
                  tooltip: 'Clear selection',
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Folder selection button - opens modal bottom sheet
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showFolderSelector(context),
            icon: const Icon(Icons.folder_open, size: 20),
            label: const Text('Select Destination Folder'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.indigo),
              foregroundColor: Colors.indigo,
            ),
          ),
        ),
      ],
    );
  }

  // NEW STATE VARIABLES FOR MODAL (add these to your state class)
  List<FolderTreeNode> _filteredFolders = [];
  Map<int, bool> _expandedFolders = {}; // Tracks which folders are expanded
  String _searchQuery = '';

  // NEW METHOD: Show folder selector in a modal bottom sheet
  Future<void> _showFolderSelector(BuildContext context) async {
    // Reset search and expanded state
    _searchQuery = '';
    _expandedFolders = {};
    _filteredFolders = List.from(_folderTree);

    // Initialize with all top-level folders expanded
    for (final folder in _folderTree) {
      _expandedFolders[folder.id] = true;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Folder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search folders...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    _searchQuery = '';
                                    _filteredFolders = List.from(_folderTree);
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          _searchQuery = value;
                          if (value.isEmpty) {
                            _filteredFolders = List.from(_folderTree);
                          } else {
                            _filteredFolders = _searchFolders(
                              _folderTree,
                              value.toLowerCase(),
                            );
                          }
                        });
                      },
                    ),
                  ),

                  // Root option (sticky)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListTile(
                      leading: const Icon(Icons.home, color: Colors.grey),
                      title: const Text(
                        'Root (No folder)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: _selectedFolderId == null
                          ? const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 22,
                            )
                          : null,
                      tileColor: _selectedFolderId == null
                          ? Colors.green.shade50
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedFolder = '';
                          _selectedFolderName = null;
                          _selectedFolderId = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Folder tree list header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'All Folders',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (_searchQuery.isNotEmpty)
                          Text(
                            '${_filteredFolders.length} found',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Folder tree list
                  Expanded(
                    child: _filteredFolders.isEmpty && _searchQuery.isNotEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_off,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No folders found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              // Build tree view
                              ..._buildTreeListWithCollapse(
                                _filteredFolders,
                                0,
                                setModalState,
                                _searchQuery.isNotEmpty,
                              ),
                            ],
                          ),
                  ),

                  // Current selection indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: const Border(top: BorderSide(color: Colors.grey)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFolderId == null
                              ? Icons.info
                              : Icons.check_circle,
                          size: 20,
                          color: _selectedFolderId == null
                              ? Colors.blue
                              : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFolderId == null
                                    ? 'Selected: Root'
                                    : 'Selected: $_selectedFolderName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (_selectedFolderId != null)
                                const SizedBox(height: 4),
                              if (_selectedFolderId != null)
                                Text(
                                  'ID: $_selectedFolderId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to search folders
  List<FolderTreeNode> _searchFolders(
    List<FolderTreeNode> nodes,
    String query,
  ) {
    final List<FolderTreeNode> results = [];

    for (final node in nodes) {
      // Check if node name contains query
      if (node.name.toLowerCase().contains(query)) {
        results.add(node);
      }

      // Always search in children
      if (node.children.isNotEmpty) {
        final childResults = _searchFolders(node.children, query);
        results.addAll(childResults);
      }
    }

    return results;
  }

  // Helper method to build tree list with collapsible sections
  List<Widget> _buildTreeListWithCollapse(
    List<FolderTreeNode> nodes,
    int depth,
    StateSetter setModalState,
    bool isSearchMode,
  ) {
    final List<Widget> widgets = [];

    for (final node in nodes) {
      final hasChildren = node.children.isNotEmpty;
      final isExpanded = _expandedFolders[node.id] ?? false;
      final isSelected = _selectedFolderId == node.id;

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder item
            Card(
              margin: EdgeInsets.only(
                left: depth * 16.0,
                right: 8,
                top: 4,
                bottom: 4,
              ),
              elevation: isSelected ? 2 : 0,
              color: isSelected ? Colors.indigo.shade50 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? Colors.indigo : Colors.transparent,
                  width: isSelected ? 1 : 0,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  hasChildren
                      ? (isExpanded ? Icons.folder_open : Icons.folder)
                      : Icons.folder,
                  color: hasChildren
                      ? Colors.amber.shade600
                      : Colors.amber.shade400,
                ),
                title: Text(
                  node.name,
                  style: TextStyle(
                    fontWeight: hasChildren
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? Colors.indigo : Colors.black,
                  ),
                ),
                subtitle: hasChildren
                    ? Text(
                        '${node.children.length} item${node.children.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.indigo.shade600
                              : Colors.grey,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: Colors.green, size: 20),
                    if (hasChildren && !isSearchMode)
                      IconButton(
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        onPressed: () {
                          setModalState(() {
                            _expandedFolders[node.id] = !isExpanded;
                          });
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
                onTap: () {
                  setState(() {
                    _selectedFolder = node.name;
                    _selectedFolderName = node.name;
                    _selectedFolderId = node.id;
                  });
                  // Only auto-close if not in search mode
                  if (!isSearchMode) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),

            // Show children if expanded (or always show in search mode)
            if (hasChildren && (isExpanded || isSearchMode))
              ..._buildTreeListWithCollapse(
                node.children,
                depth + 1,
                setModalState,
                isSearchMode,
              ),
          ],
        ),
      );
    }

    return widgets;
  }

  // Add these helper methods to your state class
  List<FolderTreeNode> _getAllFoldersFlat() {
    final List<FolderTreeNode> allFolders = [];

    void collectFolders(List<FolderTreeNode> nodes) {
      for (final node in nodes) {
        allFolders.add(node);
        if (node.children.isNotEmpty) {
          collectFolders(node.children);
        }
      }
    }

    collectFolders(_folderTree);
    return allFolders;
  }

  // Get folder ID for upload - UPDATED VERSION
  Future<String> _getFolderIdForUpload() async {
    // Use the new _selectedFolderId if available
    if (_selectedFolderId != null) {
      if (kDebugMode) {
        print(
          '📁 Using folder ID: $_selectedFolderId for name: $_selectedFolderName',
        );
      }
      return _selectedFolderId.toString();
    }

    // Fallback to old method for backward compatibility
    if (_selectedFolder.isEmpty) {
      if (kDebugMode) {
        print('📁 No folder selected, using empty folder_id');
      }
      return '';
    }

    try {
      final folderId = await FolderHelper.findFolderIdByName(_selectedFolder);

      if (folderId != null) {
        if (kDebugMode) {
          print('📁 Using folder ID: $folderId for name: $_selectedFolder');
        }
        return folderId.toString();
      } else {
        if (kDebugMode) {
          print('⚠ Folder "$_selectedFolder" not found, using empty folder_id');
        }
        return '';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting folder ID: $e');
      }
      return '';
    }
  }

  // ============ UPLOAD METHODS ============
  Future<void> _uploadDocument() async {
    if (_uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to upload'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String currentUser = widget.userName ?? 'Employee';
      DateTime now = DateTime.now();

      // Convert PlatformFile to File objects
      final List<File> files = [];
      for (var platformFile in _uploadedFiles) {
        if (platformFile.path != null) {
          files.add(File(platformFile.path!));
        }
      }

      if (files.isEmpty) {
        throw Exception('No valid files selected');
      }

      // Get folder ID - FIXED: Use new method
      String folderId = await _getFolderIdForUpload();

      // Prepare form data
      final keywords = _keywordsController.text.isNotEmpty
          ? _keywordsController.text
          : '';
      final remarks = _remarksController.text.isNotEmpty
          ? _remarksController.text
          : '';

      // Call the appropriate upload method based on connection
      if (_isConnected) {
        // Online mode - use UploadService
        Map<String, dynamic> uploadResult;
        if (_uploadedFiles.length == 1) {
          // Single file upload
          uploadResult = await UploadService.uploadSingleFile(
            file: files.first,
            keywords: keywords,
            remarks: remarks,
            docClass: _selectedClassification,
            allowDownload: _allowDownload,
            sharing: _selectedSharingType.toLowerCase(),
            folderId: folderId, // Now numeric ID or empty
          );
        } else {
          // Multiple files upload
          uploadResult = await UploadService.uploadMultipleFiles(
            files: files,
            keywords: keywords,
            remarks: remarks,
            docClass: _selectedClassification,
            allowDownload: _allowDownload,
            sharing: _selectedSharingType.toLowerCase(),
            folderId: folderId, // Now numeric ID or empty
          );
        }

        if (kDebugMode) {
          print('📊 Upload result: $uploadResult');
        }

        if (uploadResult['success'] == true) {
          // Create Document objects from uploaded files
          for (var platformFile in _uploadedFiles) {
            final fileName = platformFile.name;
            final fileExtension = fileName.split('.').last.toUpperCase();

            Document newDoc = Document(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _keywordsController.text.isNotEmpty
                  ? _keywordsController.text
                  : fileName.split('.').first,
              type: fileExtension.toUpperCase(),
              size: _getFileSizeString(platformFile.size),
              keyword: _keywordsController.text.isNotEmpty
                  ? _keywordsController.text
                  : 'No keywords',
              uploadDate: now.toIso8601String(),
              owner: currentUser,
              details: _remarksController.text.isNotEmpty
                  ? _remarksController.text
                  : 'No description',
              classification: _selectedClassification,
              allowDownload: _allowDownload,
              sharingType: _selectedSharingType,
              folder: _selectedFolder.isEmpty ? 'Root' : _selectedFolder,
              path: platformFile.path ?? '',
              fileType: fileExtension.toLowerCase(),
            );

            // Trigger callback
            widget.onDocumentUploaded(newDoc);

            // Save locally
            final isPublic = _selectedSharingType == 'Public';
            LocalStorageService.addDocument(newDoc, isPublic: isPublic);
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${_uploadedFiles.length} file(s) uploaded successfully to server!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Reset form
          _resetForm();
        } else {
          // Upload failed - check if it's authentication error
          if (uploadResult['requiresLogin'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Session expired. Please login again.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Login',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to login page
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ),
            );
            return;
          }

          // Save locally as fallback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠ Upload failed: ${uploadResult['message']}. Saving locally.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );

          _saveDocumentsLocally(currentUser, now);
        }
      } else {
        // Offline mode - save locally only
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 No internet connection. Saving locally only.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );

        _saveDocumentsLocally(currentUser, now);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Upload error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to save documents locally
  void _saveDocumentsLocally(String currentUser, DateTime now) {
    for (var platformFile in _uploadedFiles) {
      final fileName = platformFile.name;
      final fileExtension = fileName.split('.').last.toUpperCase();

      Document newDoc = Document(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _keywordsController.text.isNotEmpty
            ? _keywordsController.text
            : fileName.split('.').first,
        type: fileExtension.toUpperCase(),
        size: _getFileSizeString(platformFile.size),
        keyword: _keywordsController.text.isNotEmpty
            ? _keywordsController.text
            : 'No keywords',
        uploadDate: now.toIso8601String(),
        owner: currentUser,
        details: _remarksController.text.isNotEmpty
            ? _remarksController.text
            : 'No description',
        classification: _selectedClassification,
        allowDownload: _allowDownload,
        sharingType: _selectedSharingType,
        folder: _selectedFolder.isEmpty ? 'Root' : _selectedFolder,
        path: platformFile.path ?? '',
        fileType: fileExtension.toLowerCase(),
      );

      widget.onDocumentUploaded(newDoc);
      final isPublic = _selectedSharingType == 'Public';
      LocalStorageService.addDocument(newDoc, isPublic: isPublic);
    }

    // Reset form after local save
    _resetForm();
  }

  // Reset form after upload
  void _resetForm() {
    setState(() {
      _uploadedFiles.clear();
      _keywordsController.clear();
      _remarksController.clear();
      _selectedClassification = 'General';
      _allowDownload = true;
      _selectedSharingType = 'Public';

      // Reset folder selection
      _selectedFolder = '';
      _selectedFolderName = null;
      _selectedFolderId = null;
    });
  }

  // ============ FILE PICKER METHODS ============
  Future<void> _pickImageFile() async {
    try {
      setState(() => _isLoading = true);
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, // This will show images
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        PlatformFile file = result.files.first;

        if (file.size > 500 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image "${file.name}" exceeds 500MB limit'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _uploadedFiles.add(file);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Image picker error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickSingleFile() async {
    try {
      setState(() => _isLoading = true);

      // Show a dialog to select file type
      String? fileType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select File Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.audio_file),
                title: const Text('Audio Files'),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              ListTile(
                leading: const Icon(Icons.video_file),
                title: const Text('Video Files'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image Files'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Document Files'),
                onTap: () => Navigator.pop(context, 'document'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Code Files'),
                onTap: () => Navigator.pop(context, 'code'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('All Files'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
            ],
          ),
        ),
      );

      if (fileType == null) return;

      FilePickerResult? result;

      switch (fileType) {
        case 'audio':
          result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: false,
          );
          break;
        case 'video':
          result = await FilePicker.platform.pickFiles(
            type: FileType.video,
            allowMultiple: false,
          );
          break;
        case 'image':
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          break;
        case 'document':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              // Legacy Office
              'doc',
              'xls',
              'ppt',
              'rtf',
              'mdb',
              'pub',
              'pps',
              'dot',
              'xlt',
              'pot',
              // Modern Office
              'docx', 'xlsx', 'pptx', 'dotx', 'xltx', 'potx', 'accdb', 'one',
              // OpenDocument
              'odt', 'ods', 'odp', 'odg', 'odf',
              // Apple iWork
              'pages', 'numbers', 'key',
              // PDFs
              'pdf',
              // Text Files
              'txt', 'md', 'markdown',
              // CSV/Data
              'csv', 'tsv', 'xml', 'json',
              // ZIP & Archives
              'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso',
              // Google Files
              'gdoc', 'gsheet', 'gslides', 'gdraw',
            ],
            allowMultiple: false,
          );
          break;
        case 'code':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'doc', 'docx', 'dot', 'dotx', 'gdoc',
              // Python
              'py',
              'pyc',
              'pyo',
              'pyd',
              // JavaScript/TypeScript/React/Node.js
              'js',
              'jsx',
              'ts',
              'tsx',
              'node',
              'njs',
              // HTML/CSS
              'html', 'htm', 'css', 'scss', 'sass', 'less',
              // Database
              'sql',
              'db',
              'sqlite',
              'sqlite3',
              'mdb',
              'accdb',
              'frm',
              'myd',
              'myi',
              // Other programming languages
              'java',
              'class',
              'jar',
              'c',
              'cpp',
              'cc',
              'cxx',
              'h',
              'hpp',
              'hxx',
              'cs',
              'php',
              'phtml',
              'rb',
              'erb',
              'go',
              'rs',
              'swift',
              'kt',
              'kts',
              'dart',
              // Shell/Bash
              'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd',
              // Configuration Files
              'env', 'config', 'toml', 'ini', 'yaml', 'yml',
              // JSON Files
              'json', 'jsonl', 'jsonc',
              // Other Code Files
              'log',
              'lock',
              'license',
              'readme',
              'gitignore',
              'dockerfile',
              'makefile',
            ],
            allowMultiple: false,
          );
          break;
        case 'all':
        default:
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: _allSupportedExtensions,
            allowMultiple: false,
          );
          break;
      }

      if (result != null && result.files.isNotEmpty && mounted) {
        PlatformFile file = result.files.first;

        if (kDebugMode) {
          print('📄 ===== FILE PICKER DEBUG =====');
          print('📄 File name: ${file.name}');
          print('📄 File path: ${file.path}');
          print('📄 File size: ${file.size} bytes');
          print(
            '📄 File extension: ${file.name.split('.').last.toLowerCase()}',
          );
        }

        if (file.size > 500 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" exceeds 500MB limit'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (file.path == null || file.path!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot access file "${file.name}". Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final fileObj = File(file.path!);
        if (!fileObj.existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" not found or inaccessible.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _uploadedFiles.add(file);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Selected: ${file.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('File picker error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickMultipleFiles() async {
    try {
      setState(() => _isLoading = true);

      // Show a dialog to select file type
      String? fileType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select File Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.audio_file),
                title: const Text('Audio Files'),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              ListTile(
                leading: const Icon(Icons.video_file),
                title: const Text('Video Files'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image Files'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Document Files'),
                onTap: () => Navigator.pop(context, 'document'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Code Files'),
                onTap: () => Navigator.pop(context, 'code'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('All Files'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
            ],
          ),
        ),
      );

      if (fileType == null) return;

      FilePickerResult? result;
      List<String> selectedExtensions = [];

      switch (fileType) {
        case 'audio':
          result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: true,
          );
          selectedExtensions = [
            'mp3',
            'wav',
            'ogg',
            'flac',
            'aac',
            'm4a',
            'wma',
            'opus',
            'mid',
            'midi',
            'aiff',
            'au',
          ];
          break;
        case 'video':
          result = await FilePicker.platform.pickFiles(
            type: FileType.video,
            allowMultiple: true,
          );
          selectedExtensions = [
            'mp4',
            'mov',
            'avi',
            'mkv',
            'flv',
            'wmv',
            'webm',
            'm4v',
            'mpg',
            'mpeg',
            '3gp',
            'mts',
            'vob',
            'ogv',
          ];
          break;
        case 'image':
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: true,
          );
          selectedExtensions = [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'webp',
            'svg',
            'tiff',
            'tif',
            'ico',
            'heic',
            'heif',
            'raw',
            'cr2',
            'nef',
            'orf',
            'sr2',
          ];
          break;
        case 'document':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              // Legacy Office
              'doc',
              'xls',
              'ppt',
              'rtf',
              'mdb',
              'pub',
              'pps',
              'dot',
              'xlt',
              'pot',
              // Modern Office
              'docx', 'xlsx', 'pptx', 'dotx', 'xltx', 'potx', 'accdb', 'one',
              // OpenDocument
              'odt', 'ods', 'odp', 'odg', 'odf',
              // Apple iWork
              'pages', 'numbers', 'key',
              // PDFs
              'pdf',
              // Text Files
              'txt', 'md', 'markdown',
              // CSV/Data
              'csv', 'tsv', 'xml', 'json',
              // ZIP & Archives
              'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso',
              // Google Files
              'gdoc', 'gsheet', 'gslides', 'gdraw',
            ],
            allowMultiple: true,
          );
          selectedExtensions = [
            'doc',
            'xls',
            'ppt',
            'rtf',
            'mdb',
            'pub',
            'pps',
            'dot',
            'xlt',
            'pot',
            'docx',
            'xlsx',
            'pptx',
            'dotx',
            'xltx',
            'potx',
            'accdb',
            'one',
            'odt',
            'ods',
            'odp',
            'odg',
            'odf',
            'pages',
            'numbers',
            'key',
            'pdf',
            'txt',
            'md',
            'markdown',
            'csv',
            'tsv',
            'xml',
            'json',
            'zip',
            'rar',
            '7z',
            'tar',
            'gz',
            'bz2',
            'xz',
            'iso',
            'gdoc',
            'gsheet',
            'gslides',
            'gdraw',
          ];
          break;
        case 'code':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              // Python
              'py', 'pyc', 'pyo', 'pyd',
              // JavaScript/TypeScript/React/Node.js
              'js', 'jsx', 'ts', 'tsx', 'node', 'njs',
              // HTML/CSS
              'html', 'htm', 'css', 'scss', 'sass', 'less',
              // Database
              'sql',
              'db',
              'sqlite',
              'sqlite3',
              'mdb',
              'accdb',
              'frm',
              'myd',
              'myi',
              // Other programming languages
              'java',
              'class',
              'jar',
              'c',
              'cpp',
              'cc',
              'cxx',
              'h',
              'hpp',
              'hxx',
              'cs',
              'php',
              'phtml',
              'rb',
              'erb',
              'go',
              'rs',
              'swift',
              'kt',
              'kts',
              'dart',
              // Shell/Bash
              'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd',
              // Configuration Files
              'env', 'config', 'toml', 'ini', 'yaml', 'yml',
              // JSON Files
              'json', 'jsonl', 'jsonc',
              // Other Code Files
              'log',
              'lock',
              'license',
              'readme',
              'gitignore',
              'dockerfile',
              'makefile',
            ],
            allowMultiple: true,
          );
          selectedExtensions = [
            'py',
            'pyc',
            'pyo',
            'pyd',
            'js',
            'jsx',
            'ts',
            'tsx',
            'node',
            'njs',
            'html',
            'htm',
            'css',
            'scss',
            'sass',
            'less',
            'sql',
            'db',
            'sqlite',
            'sqlite3',
            'mdb',
            'accdb',
            'frm',
            'myd',
            'myi',
            'java',
            'class',
            'jar',
            'c',
            'cpp',
            'cc',
            'cxx',
            'h',
            'hpp',
            'hxx',
            'cs',
            'php',
            'phtml',
            'rb',
            'erb',
            'go',
            'rs',
            'swift',
            'kt',
            'kts',
            'dart',
            'sh',
            'bash',
            'zsh',
            'fish',
            'ps1',
            'bat',
            'cmd',
            'env',
            'config',
            'toml',
            'ini',
            'yaml',
            'yml',
            'json',
            'jsonl',
            'jsonc',
            'log',
            'lock',
            'license',
            'readme',
            'gitignore',
            'dockerfile',
            'makefile',
          ];
          break;
        case 'all':
        default:
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: _allSupportedExtensions,
            allowMultiple: true,
          );
          selectedExtensions = _allSupportedExtensions;
          break;
      }

      if (result != null && result.files.isNotEmpty && mounted) {
        int addedFiles = 0;
        int skippedFiles = 0;

        for (var file in result.files) {
          final extension = file.name.split('.').last.toLowerCase();

          if (fileType == 'all' || selectedExtensions.contains(extension)) {
            if (file.size > 500 * 1024 * 1024) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File "${file.name}" exceeds 500MB limit'),
                  backgroundColor: Colors.red,
                ),
              );
              skippedFiles++;
              continue;
            }

            setState(() {
              _uploadedFiles.add(file);
            });
            addedFiles++;
          } else {
            skippedFiles++;
          }
        }

        if (addedFiles > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Added $addedFiles file(s)${skippedFiles > 0 ? ' (skipped $skippedFiles)' : ''}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Multiple file picker error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFolder() async {
    try {
      await _pickMultipleFiles();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected files will be uploaded'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ FILE ICON/COLOR METHODS ============
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
      case 'dot':
      case 'dotx':
        return Icons.description;
      case 'xlsx':
      case 'xls':
      case 'csv':
      case 'ods':
        return Icons.table_chart;
      case 'pptx':
      case 'ppt':
      case 'odp':
        return Icons.slideshow;
      case 'txt':
      case 'rtf':
      case 'md':
      case 'odt':
        return Icons.text_fields;
      case 'js':
      case 'jsx':
        return Icons.code;
      case 'ts':
      case 'tsx':
        return Icons.data_object;
      case 'json':
        return Icons.data_array;
      case 'py':
      case 'pyc':
      case 'pyo':
      case 'pyd':
        return Icons.account_tree;
      case 'html':
      case 'htm':
        return Icons.language;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Icons.palette;
      case 'node':
      case 'njs':
        return Icons.dns;
      case 'java':
      case 'class':
      case 'jar':
        return Icons.coffee;
      case 'c':
      case 'cpp':
      case 'cc':
      case 'h':
      case 'hpp':
        return Icons.memory;
      case 'php':
        return Icons.web;
      case 'rb':
      case 'erb':
        return Icons.diamond;
      case 'go':
        return Icons.rocket_launch;
      case 'rs':
        return Icons.settings;
      case 'kt':
      case 'kts':
        return Icons.android;
      case 'swift':
        return Icons.phone_iphone;
      case 'dart':
        return Icons.flutter_dash;
      case 'sql':
      case 'db':
      case 'sqlite':
        return Icons.storage;
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.format_align_left;
      case 'env':
      case 'config':
      case 'toml':
      case 'ini':
        return Icons.settings_applications;
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return Icons.terminal;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'wma':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'flv':
      case 'wmv':
      case 'webm':
        return Icons.videocam;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'svg':
      case 'webp':
        return Icons.image;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Icons.archive;
      case 'exe':
      case 'app':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return Icons.play_arrow;
      case 'vue':
        return Icons.view_quilt;
      case 'svelte':
        return Icons.dashboard;
      case 'lock':
      case 'package':
        return Icons.inventory;
      case 'log':
        return Icons.assignment;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'docx':
      case 'gdoc':
      case 'gslides':
      case 'gsheet':
      case 'gform':
      case 'gscript':
        return Colors.blue;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Colors.green;
      case 'pptx':
      case 'ppt':
        return Colors.orange;
      case 'txt':
      case 'rtf':
      case 'md':
        return Colors.grey;
      case 'js':
      case 'jsx':
        return Colors.yellow[700]!;
      case 'ts':
      case 'tsx':
        return Colors.blue[700]!;
      case 'json':
        return Colors.amber;
      case 'py':
      case 'pyc':
      case 'pyo':
      case 'pyd':
        return Colors.blue[400]!;
      case 'html':
      case 'htm':
        return Colors.deepOrange;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Colors.blue[300]!;
      case 'node':
      case 'njs':
        return Colors.green[600]!;
      case 'java':
      case 'class':
      case 'jar':
        return Colors.red[700]!;
      case 'c':
      case 'cpp':
      case 'cc':
      case 'h':
      case 'hpp':
        return Colors.purple;
      case 'php':
        return Colors.purple[400]!;
      case 'rb':
      case 'erb':
        return Colors.red[900]!;
      case 'go':
        return Colors.cyan;
      case 'rs':
        return Colors.deepOrange[900]!;
      case 'kt':
      case 'kts':
        return Colors.purple[600]!;
      case 'swift':
        return Colors.orange;
      case 'dart':
        return Colors.blue[500]!;
      case 'sql':
      case 'db':
      case 'sqlite':
        return Colors.brown;
      case 'xml':
      case 'yaml':
      case 'yml':
        return Colors.green[400]!;
      case 'env':
      case 'config':
      case 'toml':
      case 'ini':
        return Colors.grey[600]!;
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return Colors.green[800]!;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'wma':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'flv':
      case 'wmv':
      case 'webm':
        return Colors.deepOrange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'svg':
      case 'webp':
        return Colors.pink;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Colors.brown;
      case 'exe':
      case 'app':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return Colors.green[700]!;
      case 'vue':
        return Colors.green[400]!;
      case 'svelte':
        return Colors.orange[300]!;
      case 'lock':
      case 'package':
        return Colors.blueGrey;
      case 'log':
        return Colors.grey[700]!;
      default:
        return Colors.indigo;
    }
  }

  // ============ BUILD METHOD ============
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Upload Files',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),

            // Upload Type Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _pickSingleFile,
                                  icon: const Icon(Icons.insert_drive_file),
                                  label: const Text('Single File'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _pickMultipleFiles,
                                  icon: const Icon(Icons.folder_copy),
                                  label: const Text('Multiple Files'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // SizedBox(
                              //   width: double.infinity,
                              //   child: OutlinedButton.icon(
                              //     onPressed: _isLoading ? null : _pickFolder,
                              //     icon: const Icon(Icons.folder),
                              //     label: const Text('Entire Folder'),
                              //     style: OutlinedButton.styleFrom(
                              //       padding: const EdgeInsets.symmetric(
                              //         vertical: 12,
                              //       ),
                              //       side: const BorderSide(
                              //         color: Colors.indigo,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _pickSingleFile,
                                  icon: const Icon(Icons.insert_drive_file),
                                  label: const Text('Single File'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.indigo,
                                    ),
                                    foregroundColor: Colors.indigo,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _pickMultipleFiles,
                                  icon: const Icon(Icons.folder_copy),
                                  label: const Text('Multiple Files'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.indigo,
                                    ),
                                    foregroundColor: Colors.indigo,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _pickFolder,
                                  icon: const Icon(Icons.folder),
                                  label: const Text('Entire Folder'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.indigo,
                                    ),
                                    foregroundColor: Colors.indigo,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_uploadedFiles.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Selected Files:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._uploadedFiles.map(
                (file) => Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getFileIcon(file.name),
                      color: _getFileColor(file.name),
                    ),
                    title: Text(file.name),
                    subtitle: Text(_getFileSizeString(file.size)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _uploadedFiles.remove(file);
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),

            // Document Details Section
            const Text(
              'Document Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Destination Folder Dropdown with Create Folder option
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Destination Folder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _navigateToFolderManager(context);
                          },
                          icon: const Icon(Icons.create_new_folder, size: 16),
                          label: const Text('Create Folder'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Folder Selection
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _foldersLoading
                          ? _buildLoadingFolders()
                          : _buildFolderDropdown(),
                    ),

                    // Help text
                    if (!_foldersLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _selectedFolderId == null
                              ? 'Files will be uploaded to root directory'
                              : 'Files will be uploaded to "$_selectedFolderName" folder',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Classification Dropdown with specified options
            DropdownButtonFormField<String>(
              initialValue: _selectedClassification,
              decoration: InputDecoration(
                labelText: 'Classification',
                prefixIcon: const Icon(Icons.security, color: Colors.indigo),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items:
                  const [
                    'General',
                    'Unclassified',
                    'Internal Use Only',
                    'Corporate Confidential',
                    'Restricted',
                    'Confidential',
                    'Secret',
                  ].map((classification) {
                    return DropdownMenuItem(
                      value: classification,
                      child: Text(classification),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedClassification = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Keywords Text Field
            TextField(
              controller: _keywordsController,
              decoration: InputDecoration(
                labelText: 'Keywords',
                hintText: 'Enter keywords separated by commas',
                prefixIcon: const Icon(Icons.label, color: Colors.indigo),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 16),

            // Remarks Description Box
            TextField(
              controller: _remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Remarks',
                hintText: 'Enter description or remarks',
                prefixIcon: const Icon(Icons.description, color: Colors.indigo),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Sharing Type Dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedSharingType,
              decoration: InputDecoration(
                labelText: 'Sharing',
                prefixIcon: const Icon(Icons.share, color: Colors.indigo),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: [
                DropdownMenuItem(
                  value: 'Public',
                  child: Row(
                    children: [
                      const Icon(Icons.public, color: Colors.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Public - Visible in Document Library',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Private',
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Private - Only in My Documents',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSharingType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 32),

            const SizedBox(height: 16),

            // Upload Document Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _foldersLoading)
                    ? null
                    : _uploadDocument,
                icon: const Icon(Icons.cloud_upload, size: 24),
                label: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Upload Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
