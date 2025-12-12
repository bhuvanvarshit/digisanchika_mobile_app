// screens/shared_folder_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:digi_sanchika/services/shared_browse_service.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:digi_sanchika/services/shared_documents_service.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/services.dart';

class SharedFolderScreen extends StatefulWidget {
  final String? folderId;
  final String folderName;
  final String? userName;

  const SharedFolderScreen({
    super.key,
    this.folderId,
    required this.folderName,
    this.userName,
  });

  @override
  State<SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends State<SharedFolderScreen> {
  List<Document> _documents = [];
  List<Map<String, dynamic>> _subfolders = [];

  bool _isLoading = true;
  bool _hasError = false;
  bool _isDownloading = false;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final DocumentOpenerService _documentOpener = DocumentOpenerService();
  final SharedDocumentsService _sharedService = SharedDocumentsService();

  @override
  void initState() {
    super.initState();
    _loadSharedFolderContents();
  }

  Future<void> _loadSharedFolderContents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final result = await SharedBrowseService.getSharedFolderContents(
        folderId: widget.folderId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _documents = (result['documents'] as List).cast<Document>();
          _subfolders = (result['folders'] as List)
              .cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage =
              result['error']?.toString() ?? 'Failed to load folder';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      debugPrint('Error loading shared folder: $e');
    }
  }

  void _navigateToSubfolder(Map<String, dynamic> folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedFolderScreen(
          folderId: folder['id']?.toString(),
          folderName: folder['name']?.toString() ?? 'Shared Folder',
          userName: folder['owner']?.toString(),
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  // ============ DOWNLOAD FUNCTIONALITY (Same as SharedMeScreen) ============
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
          bytesToSave = fileData.cast<int>();
        } else if (fileData is String) {
          bytesToSave = utf8.encode(fileData);
        } else {
          debugPrint(
            '❌ fileData is not List<int>, it is: ${fileData.runtimeType}',
          );
          throw Exception(
            'Invalid file data format. Expected List<int>, got ${fileData.runtimeType}',
          );
        }

        if (bytesToSave.isEmpty) {
          throw Exception('Downloaded file data is empty (0 bytes)');
        }

        debugPrint('✅ Received ${bytesToSave.length} bytes of file data');

        final directory = await getDownloadDirectory();

        String filename = result['filename']?.toString() ?? document.name;

        if (RegExp(r'^\d+$').hasMatch(filename) && document.name.isNotEmpty) {
          filename = document.name;
        }

        final docName = document.name;
        if (docName.isNotEmpty) {
          final extension = path.extension(docName);
          if (!filename.toLowerCase().endsWith(extension.toLowerCase()) &&
              extension.isNotEmpty) {
            final nameWithoutExt = path.withoutExtension(filename);
            filename = '$nameWithoutExt$extension';
          }
        }

        if (document.type.toLowerCase() == 'py' &&
            !filename.toLowerCase().endsWith('.py')) {
          filename = '$filename.py';
        }

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
            final docIndex = _documents.indexWhere((d) => d.id == document.id);
            if (docIndex != -1) {
              setState(() {
                _documents[docIndex] = document.copyWith(
                  size: fileSize.toString(),
                );
              });
            }
          }

          final fileExtension = filename.toLowerCase().split('.').last;
          if (fileExtension == 'py' || document.type.toLowerCase() == 'py') {
            _showFileContent(bytesToSave, filename);
            return;
          }

          try {
            final uriToOpen = Platform.isAndroid
                ? _getFileProviderUri(filePath)
                : filePath;

            debugPrint('Opening with: $uriToOpen');

            final openResult = await OpenFilex.open(uriToOpen);

            if (openResult.type != ResultType.done) {
              debugPrint('⚠ Could not open file: ${openResult.message}');

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
        debugPrint('Error creating FileProvider URI: $e');
      }
    }
    return filePath;
  }

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

  // ============ DOCUMENT HANDLING (Same as SharedMeScreen) ============
  void _handleDocumentDoubleTap(Document document) {
    _documentOpener.handleDoubleTap(context: context, document: document);
  }

  void _showDocumentDetails(Document document) {
    showDialog(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogDetailRow('File Name', document.name),
              _buildDialogDetailRow('File Type', document.type.toUpperCase()),
              _buildDialogDetailRow('Size', _formatFileSize(document.size)),
              _buildDialogDetailRow('Owner', document.owner),
              _buildDialogDetailRow('Upload Date', document.uploadDate),
              _buildDialogDetailRow('Folder', document.folder),
              _buildDialogDetailRow('Classification', document.classification),
              _buildDialogDetailRow('Keywords', document.keyword),
              _buildDialogDetailRow('Remarks', document.details),
              _buildDialogDetailRow(
                'Download Allowed',
                document.allowDownload ? 'Yes' : 'No',
              ),
              _buildDialogDetailRow('Sharing Type', document.sharingType),
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
        ],
      ),
    );
  }

  void _showDocumentVersions(Document document) {
    // You need to implement this based on your service
    _showSnackBar('Version history not available', Colors.orange);
  }

  // ============ UPDATED DOCUMENT CARD (Same as SharedMeScreen) ============
  Widget _buildDocumentCard(Document document) {
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

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

              // Action buttons row (View + Versions + Download) - SAME AS SharedMeScreen
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

  // ============ HELPER METHODS ============
  Widget _buildSubfoldersSection() {
    if (_subfolders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder, color: Colors.amber),
              const SizedBox(width: 8),
              const Text(
                'Shared Folders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _subfolders.length.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _subfolders.length,
            itemBuilder: (context, index) {
              return _buildSubfolderCard(_subfolders[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubfolderCard(Map<String, dynamic> folder) {
    final itemCount = folder['item_count'] is Map
        ? (folder['item_count'] as Map)['total'] ?? 0
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToSubfolder(folder),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder,
                  color: Colors.amber.shade800,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder['name']?.toString() ?? 'Unnamed Folder',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shared by: ${folder['owner']?.toString() ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(folder['created_at']),
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
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final filteredDocs = _filterDocuments();

    return Padding(
      padding: const EdgeInsets.all(16),
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
              const Text(
                'Shared Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  filteredDocs.length.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          filteredDocs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    return _buildDocumentCard(filteredDocs[index]);
                  },
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
            Icon(
              _subfolders.isEmpty ? Icons.folder_off : Icons.insert_drive_file,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              _subfolders.isEmpty ? 'Empty Folder' : 'No Documents',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _subfolders.isEmpty
                  ? 'This shared folder is empty'
                  : 'No documents shared in this folder',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 16),
          Text('Loading shared folder...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'Failed to Load',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadSharedFolderContents,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<Document> _filterDocuments() {
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isEmpty) return _documents;

    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(searchTerm) ||
          doc.keyword.toLowerCase().contains(searchTerm) ||
          doc.owner.toLowerCase().contains(searchTerm) ||
          doc.type.toLowerCase().contains(searchTerm);
    }).toList();
  }

  Widget _buildDialogDetailRow(String label, String value) {
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateStr = date.toString();
      if (dateStr.contains('T')) {
        final dateTime = DateTime.parse(dateStr);
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inDays == 0) {
          return 'Today';
        } else if (difference.inDays == 1) {
          return 'Yesterday';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else {
          return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        }
      }
      return dateStr;
    } catch (e) {
      return date.toString();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folderName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.userName != null)
              Text(
                'Shared by: ${widget.userName}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadSharedFolderContents,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search in shared folder...',
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
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

          // Loading/Error/Content
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _hasError
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadSharedFolderContents,
                    color: Colors.indigo,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_isDownloading) _buildDownloadingBanner(),
                          _buildSubfoldersSection(),
                          _buildDocumentsSection(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
