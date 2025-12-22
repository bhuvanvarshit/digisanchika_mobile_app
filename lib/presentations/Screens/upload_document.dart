// // ignore_for_file: use_build_context_synchronously, unnecessary_this
// import 'package:digi_sanchika/local_storage.dart';
// import 'package:digi_sanchika/services/upload_service.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:digi_sanchika/models/document.dart';
// import 'package:digi_sanchika/models/folder.dart';
// import 'dart:io';

// class UploadDocumentTab extends StatefulWidget {
//   final Function(Document) onDocumentUploaded;
//   final List<Folder> folders;
//   final String? userName;

//   const UploadDocumentTab({
//     super.key,
//     required this.onDocumentUploaded,
//     required this.folders,
//     this.userName,
//   });

//   @override
//   State<UploadDocumentTab> createState() => _UploadDocumentTabState();
// }

// class _UploadDocumentTabState extends State<UploadDocumentTab> {
//   final TextEditingController _keywordsController = TextEditingController();
//   final TextEditingController _remarksController = TextEditingController();

//   String _selectedFolder = 'Home';
//   String _selectedClassification = 'General';
//   bool _allowDownload = true;
//   String _selectedSharingType = 'Public';
//   final List<PlatformFile> _uploadedFiles = [];
//   bool _isLoading = false;
//   bool _isConnected = true; // You can replace this with actual connection check

//   @override
//   void dispose() {
//     _keywordsController.dispose();
//     _remarksController.dispose();
//     super.dispose();
//   }

//   List<Map<String, dynamic>> _availableFolders = [];
//   Map<String, dynamic>? _defaultFolder;
//   bool _foldersLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadFolders();
//   }

//   // ============ MAIN UPLOAD METHOD ============
//   Future<void> _uploadDocument() async {
//     if (_uploadedFiles.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select at least one file to upload'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       String currentUser = widget.userName ?? 'Employee';
//       DateTime now = DateTime.now();

//       // Convert PlatformFile to File objects
//       final List<File> files = [];
//       for (var platformFile in _uploadedFiles) {
//         if (platformFile.path != null) {
//           files.add(File(platformFile.path!));
//         }
//       }

//       if (files.isEmpty) {
//         throw Exception('No valid files selected');
//       }

//       // Get folder ID
//       String folderId = await _getFolderId(_selectedFolder);

//       // Prepare form data
//       final keywords = _keywordsController.text.isNotEmpty
//           ? _keywordsController.text
//           : '';
//       final remarks = _remarksController.text.isNotEmpty
//           ? _remarksController.text
//           : '';

//       // Call the appropriate upload method based on connection
//       if (_isConnected) {
//         // Online mode - use UploadService
//         Map<String, dynamic> uploadResult;
//         if (_uploadedFiles.length == 1) {
//           // Single file upload
//           uploadResult = await UploadService.uploadSingleFile(
//             file: files.first,
//             keywords: keywords,
//             remarks: remarks,
//             docClass: _selectedClassification,
//             allowDownload: _allowDownload,
//             sharing: _selectedSharingType.toLowerCase(),
//             folderId: folderId,
//           );
//         } else {
//           // Multiple files upload
//           uploadResult = await UploadService.uploadMultipleFiles(
//             files: files,
//             keywords: keywords,
//             remarks: remarks,
//             docClass: _selectedClassification,
//             allowDownload: _allowDownload,
//             sharing: _selectedSharingType.toLowerCase(),
//             folderId: folderId,
//           );
//         }

//         if (kDebugMode) {
//           print('📊 Upload result: $uploadResult');
//         }

//         if (uploadResult['success'] == true) {
//           // Create Document objects from uploaded files
//           for (var platformFile in _uploadedFiles) {
//             final fileName = platformFile.name;
//             final fileExtension = fileName.split('.').last.toUpperCase();

//             Document newDoc = Document(
//               id: DateTime.now().millisecondsSinceEpoch.toString(),
//               name: _keywordsController.text.isNotEmpty
//                   ? _keywordsController.text
//                   : fileName.split('.').first,
//               type: fileExtension.toUpperCase(),
//               size: _getFileSizeString(platformFile.size),
//               keyword: _keywordsController.text.isNotEmpty
//                   ? _keywordsController.text
//                   : 'No keywords',
//               uploadDate: now.toIso8601String(),
//               owner: currentUser,
//               details: _remarksController.text.isNotEmpty
//                   ? _remarksController.text
//                   : 'No description',
//               classification: _selectedClassification,
//               allowDownload: _allowDownload,
//               sharingType: _selectedSharingType,
//               folder: _selectedFolder,
//               path: platformFile.path ?? '',
//               fileType: fileExtension.toLowerCase(),
//             );

//             // Trigger callback
//             widget.onDocumentUploaded(newDoc);

//             // Save locally
//             final isPublic = _selectedSharingType == 'Public';
//             LocalStorageService.addDocument(newDoc, isPublic: isPublic);
//           }

//           // Show success message
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 '✅ ${_uploadedFiles.length} file(s) uploaded successfully to server!',
//               ),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 3),
//             ),
//           );

//           // Reset form
//           _resetForm();
//         } else {
//           // Upload failed - save locally only
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 '⚠ Upload failed: ${uploadResult['message']}. Saving locally.',
//               ),
//               backgroundColor: Colors.orange,
//               duration: const Duration(seconds: 3),
//             ),
//           );

//           // Save locally as fallback
//           _saveDocumentsLocally(currentUser, now);
//         }
//       } else {
//         // Offline mode - save locally only
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('📱 No internet connection. Saving locally only.'),
//             backgroundColor: Colors.blue,
//             duration: Duration(seconds: 3),
//           ),
//         );

//         _saveDocumentsLocally(currentUser, now);
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ Upload error: $e');
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('❌ Error: ${e.toString()}'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//     Future<void> _loadFolders() async {
//     setState(() => _foldersLoading = true);

//     try {
//       final folders = await FolderHelper.getFoldersFlatList();

//       if (folders.isNotEmpty) {
//         setState(() {
//           _availableFolders = folders;
//           _defaultFolder = FolderHelper.getDefaultFolderSync(folders);

//           // Set selected folder to default (Home or first)
//           if (_defaultFolder != null) {
//             _selectedFolder = _defaultFolder!['name'].toString();
//           }
//         });

//         print('✅ Loaded ${folders.length} folders');
//         for (var folder in folders) {
//           print('   - ${folder['name']} (ID: ${folder['id']})');
//         }
//       } else {
//         print('⚠ No folders found - will use empty folder_id');
//       }
//     } catch (e) {
//       print('❌ Error loading folders: $e');
//     } finally {
//       setState(() => _foldersLoading = false);
//     }
//   }

//   // Helper to get folder ID by name
//   Future<String?> _getFolderIdForUpload() async {
//     if (_selectedFolder.isEmpty) return '';

//     final folderId = await FolderHelper.findFolderIdByName(_selectedFolder);

//     if (folderId != null) {
//       print('📁 Using folder ID: $folderId for name: $_selectedFolder');
//       return folderId.toString();
//     } else {
//       print('⚠ Folder "$_selectedFolder" not found, using empty folder_id');
//       return '';
//     }
//   }

//   // In your _uploadDocument method, replace:
//   // String folderId = await _getFolderId(_selectedFolder);
//   // With:
//   String folderId = await _getFolderIdForUpload() ?? '';

//   // Helper method to save documents locally
//   void _saveDocumentsLocally(String currentUser, DateTime now) {
//     for (var platformFile in _uploadedFiles) {
//       final fileName = platformFile.name;
//       final fileExtension = fileName.split('.').last.toUpperCase();

//       Document newDoc = Document(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         name: _keywordsController.text.isNotEmpty
//             ? _keywordsController.text
//             : fileName.split('.').first,
//         type: fileExtension.toUpperCase(),
//         size: _getFileSizeString(platformFile.size),
//         keyword: _keywordsController.text.isNotEmpty
//             ? _keywordsController.text
//             : 'No keywords',
//         uploadDate: now.toIso8601String(),
//         owner: currentUser,
//         details: _remarksController.text.isNotEmpty
//             ? _remarksController.text
//             : 'No description',
//         classification: _selectedClassification,
//         allowDownload: _allowDownload,
//         sharingType: _selectedSharingType,
//         folder: _selectedFolder,
//         path: platformFile.path ?? '',
//         fileType: fileExtension.toLowerCase(),
//       );

//       widget.onDocumentUploaded(newDoc);
//       final isPublic = _selectedSharingType == 'Public';
//       LocalStorageService.addDocument(newDoc, isPublic: isPublic);
//     }

//     // Reset form after local save
//     _resetForm();
//   }

//   // Helper method to get folder ID
//   Future<String> _getFolderId(String folderName) async {
//     final folder = widget.folders.firstWhere(
//       (f) => f.name == folderName,
//       orElse: () => Folder(
//         id: '',
//         name: 'Home',
//         documents: [],
//         createdAt: DateTime.now(),
//         owner: widget.userName ?? 'User',
//       ),
//     );
//     return folder.id.isNotEmpty ? folder.id : '';
//   }

//   // Reset form after upload
//   void _resetForm() {
//     setState(() {
//       _uploadedFiles.clear();
//       _keywordsController.clear();
//       _remarksController.clear();
//       _selectedFolder = 'Home';
//       _selectedClassification = 'General';
//       _allowDownload = true;
//       _selectedSharingType = 'Public';
//     });
//   }

//   // ============ FILE PICKING METHODS ============
//   Future<void> _pickSingleFile() async {
//     try {
//       setState(() => _isLoading = true);
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: [
//           'pdf',
//           'docx',
//           'doc',
//           'xlsx',
//           'xls',
//           'pptx',
//           'ppt',
//           'txt',
//         ],
//       );

//       if (result != null && result.files.isNotEmpty && mounted) {
//         PlatformFile file = result.files.first;

//         if (file.size > 10 * 1024 * 1024) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('File "${file.name}" exceeds 10MB limit'),
//               backgroundColor: Colors.red,
//             ),
//           );
//           return;
//         }

//         setState(() {
//           _uploadedFiles.add(file);
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error picking file: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _pickMultipleFiles() async {
//     try {
//       setState(() => _isLoading = true);

//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: [
//           'pdf',
//           'docx',
//           'doc',
//           'xlsx',
//           'xls',
//           'pptx',
//           'ppt',
//           'txt',
//         ],
//         allowMultiple: true,
//       );

//       if (result != null && result.files.isNotEmpty && mounted) {
//         for (var file in result.files) {
//           if (file.size > 10 * 1024 * 1024) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('File "${file.name}" exceeds 10MB limit'),
//                 backgroundColor: Colors.red,
//               ),
//             );
//             continue;
//           }
//           setState(() {
//             _uploadedFiles.add(file);
//           });
//         }
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error picking files: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _pickFolder() async {
//     try {
//       // For folder upload, just pick multiple files
//       await _pickMultipleFiles();

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Selected files will be uploaded'),
//           backgroundColor: Colors.blue,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error picking folder: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // ============ HELPER METHODS ============
//   String _getFileSizeString(int bytes) {
//     if (bytes < 1024) {
//       return '$bytes B';
//     } else if (bytes < 1024 * 1024) {
//       return '${(bytes / 1024).toStringAsFixed(1)} KB';
//     } else {
//       return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
//     }
//   }

//   IconData _getFileIcon(String fileName) {
//     final extension = fileName.split('.').last.toLowerCase();
//     switch (extension) {
//       case 'pdf':
//         return Icons.picture_as_pdf;
//       case 'docx':
//       case 'doc':
//         return Icons.description;
//       case 'xlsx':
//       case 'xls':
//         return Icons.table_chart;
//       case 'pptx':
//       case 'ppt':
//         return Icons.slideshow;
//       case 'txt':
//         return Icons.text_fields;
//       default:
//         return Icons.insert_drive_file;
//     }
//   }

//   Color _getFileColor(String fileName) {
//     final extension = fileName.split('.').last.toLowerCase();
//     switch (extension) {
//       case 'pdf':
//         return Colors.red;
//       case 'docx':
//       case 'doc':
//         return Colors.blue;
//       case 'xlsx':
//       case 'xls':
//         return Colors.green;
//       case 'pptx':
//       case 'ppt':
//         return Colors.orange;
//       case 'txt':
//         return Colors.grey;
//       default:
//         return Colors.indigo;
//     }
//   }

//   // ============ TEST UPLOAD CONNECTION ============
//   Future<void> _testUploadConnection() async {
//     setState(() => _isLoading = true);
//     try {
//       final result = await UploadService.testUploadConnection();

//       setState(() {
//         _isConnected = result['success'] == true;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             result['success'] == true
//                 ? '✅ Upload connection test successful!'
//                 : '❌ Upload connection failed: ${result['message']}',
//           ),
//           backgroundColor: result['success'] == true
//               ? Colors.green
//               : Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } catch (e) {
//       setState(() {
//         _isConnected = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('❌ Connection test error: $e'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   // ============ BUILD METHOD ============
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white,
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Title
//             const Text(
//               'Upload Files',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.indigo,
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Connection Status
//             Container(
//               padding: const EdgeInsets.all(8),
//               margin: const EdgeInsets.only(bottom: 16),
//               decoration: BoxDecoration(
//                 color: _isConnected ? Colors.green[50] : Colors.orange[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(
//                   color: _isConnected ? Colors.green : Colors.orange,
//                 ),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     _isConnected ? Icons.cloud_done : Icons.cloud_off,
//                     color: _isConnected ? Colors.green : Colors.orange,
//                     size: 18,
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _isConnected
//                           ? 'Connected to server: http://172.105.62.238:8000'
//                           : 'Offline mode - Saving locally only',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: _isConnected
//                             ? Colors.green[800]
//                             : Colors.orange[800],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Upload Type Selection
//             Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Upload Type',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     LayoutBuilder(
//                       builder: (context, constraints) {
//                         if (constraints.maxWidth < 600) {
//                           return Column(
//                             children: [
//                               SizedBox(
//                                 width: double.infinity,
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading
//                                       ? null
//                                       : _pickSingleFile,
//                                   icon: const Icon(Icons.insert_drive_file),
//                                   label: const Text('Single File'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 12),
//                               SizedBox(
//                                 width: double.infinity,
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading
//                                       ? null
//                                       : _pickMultipleFiles,
//                                   icon: const Icon(Icons.folder_copy),
//                                   label: const Text('Multiple Files'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 12),
//                               SizedBox(
//                                 width: double.infinity,
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading ? null : _pickFolder,
//                                   icon: const Icon(Icons.folder),
//                                   label: const Text('Entire Folder'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           );
//                         } else {
//                           return Row(
//                             children: [
//                               Expanded(
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading
//                                       ? null
//                                       : _pickSingleFile,
//                                   icon: const Icon(Icons.insert_drive_file),
//                                   label: const Text('Single File'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                     foregroundColor: Colors.indigo,
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading
//                                       ? null
//                                       : _pickMultipleFiles,
//                                   icon: const Icon(Icons.folder_copy),
//                                   label: const Text('Multiple Files'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                     foregroundColor: Colors.indigo,
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: OutlinedButton.icon(
//                                   onPressed: _isLoading ? null : _pickFolder,
//                                   icon: const Icon(Icons.folder),
//                                   label: const Text('Entire Folder'),
//                                   style: OutlinedButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 12,
//                                     ),
//                                     side: const BorderSide(
//                                       color: Colors.indigo,
//                                     ),
//                                     foregroundColor: Colors.indigo,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           );
//                         }
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 24),

//             // Single File Upload Section
//             const Text(
//               'Single File Upload',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // Upload Area
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(32),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade300, width: 2),
//                 borderRadius: BorderRadius.circular(12),
//                 color: Colors.grey.shade50,
//               ),
//               child: Column(
//                 children: [
//                   const Icon(
//                     Icons.cloud_upload,
//                     size: 64,
//                     color: Colors.indigo,
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Drag and drop a file here or click to browse',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Supports: PDF, DOCX, XLSX, PPTX, TXT',
//                     style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
//                   ),
//                   const SizedBox(height: 20),
//                   ElevatedButton.icon(
//                     onPressed: _isLoading ? null : _pickSingleFile,
//                     icon: _isLoading
//                         ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(
//                                 Colors.white,
//                               ),
//                             ),
//                           )
//                         : const Icon(Icons.upload_file),
//                     label: Text(_isLoading ? 'Opening...' : 'Select Files'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.indigo,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 24,
//                         vertical: 12,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             if (_uploadedFiles.isNotEmpty) ...[
//               const SizedBox(height: 24),
//               const Text(
//                 'Selected Files:',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               ..._uploadedFiles.map(
//                 (file) => Card(
//                   color: Colors.white,
//                   margin: const EdgeInsets.only(bottom: 8),
//                   child: ListTile(
//                     leading: Icon(
//                       _getFileIcon(file.name),
//                       color: _getFileColor(file.name),
//                     ),
//                     title: Text(file.name),
//                     subtitle: Text(_getFileSizeString(file.size)),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.close, color: Colors.red),
//                       onPressed: () {
//                         setState(() {
//                           _uploadedFiles.remove(file);
//                         });
//                       },
//                     ),
//                   ),
//                 ),
//               ),
//             ],

//             const SizedBox(height: 24),
//             const Divider(),

//             // Document Details Section
//             const Text(
//               'Document Details',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // Destination Folder
//             DropdownButtonFormField<String>(
//               initialValue: _selectedFolder,
//               decoration: InputDecoration(
//                 labelText: 'Destination Folder',
//                 prefixIcon: const Icon(Icons.folder, color: Colors.indigo),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//               ),
//               items: [
//                 DropdownMenuItem<String>(
//                   value: 'Home',
//                   child: Row(
//                     children: [
//                       const Icon(Icons.folder, color: Colors.amber),
//                       const SizedBox(width: 8),
//                       const Text('Home'),
//                     ],
//                   ),
//                 ),
//                 ...widget.folders.where((folder) => folder.name != 'Home').map((
//                   folder,
//                 ) {
//                   return DropdownMenuItem<String>(
//                     value: folder.name,
//                     child: Row(
//                       children: [
//                         const Icon(Icons.folder, color: Colors.amber),
//                         const SizedBox(width: 8),
//                         Text(folder.name),
//                       ],
//                     ),
//                   );
//                 }),
//               ],
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     _selectedFolder = value;
//                   });
//                 }
//               },
//             ),

//             const SizedBox(height: 16),

//             // Classification Dropdown with specified options
//             DropdownButtonFormField<String>(
//               initialValue: _selectedClassification,
//               decoration: InputDecoration(
//                 labelText: 'Classification',
//                 prefixIcon: const Icon(Icons.security, color: Colors.indigo),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//               ),
//               items:
//                   const [
//                     'General',
//                     'Unclassified',
//                     'Internal Use Only',
//                     'Corporate Confidential',
//                     'Restricted',
//                     'Confidential',
//                     'Secret',
//                   ].map((classification) {
//                     return DropdownMenuItem(
//                       value: classification,
//                       child: Text(classification),
//                     );
//                   }).toList(),
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     _selectedClassification = value;
//                   });
//                 }
//               },
//             ),

//             const SizedBox(height: 16),

//             // Keywords Text Field
//             TextField(
//               controller: _keywordsController,
//               decoration: InputDecoration(
//                 labelText: 'Keywords',
//                 hintText: 'Enter keywords separated by commas',
//                 prefixIcon: const Icon(Icons.label, color: Colors.indigo),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Remarks Description Box
//             TextField(
//               controller: _remarksController,
//               maxLines: 2,
//               decoration: InputDecoration(
//                 labelText: 'Remarks',
//                 hintText: 'Enter description or remarks',
//                 prefixIcon: const Icon(Icons.description, color: Colors.indigo),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//                 alignLabelWithHint: true,
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Allow Download Checkbox
//             Card(
//               color: Colors.white,
//               elevation: 1,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: CheckboxListTile(
//                 title: const Text(
//                   'Allow Download',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                 ),
//                 value: _allowDownload,
//                 onChanged: (value) {
//                   setState(() {
//                     _allowDownload = value!;
//                   });
//                 },
//                 secondary: const Icon(Icons.download, color: Colors.indigo),
//                 controlAffinity: ListTileControlAffinity.leading,
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Sharing Type Dropdown
//             DropdownButtonFormField<String>(
//               isExpanded: true,
//               initialValue: _selectedSharingType,
//               decoration: InputDecoration(
//                 labelText: 'Sharing',
//                 prefixIcon: const Icon(Icons.share, color: Colors.indigo),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//               ),
//               items: [
//                 DropdownMenuItem(
//                   value: 'Public',
//                   child: Row(
//                     children: [
//                       const Icon(Icons.public, color: Colors.green, size: 18),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           'Public - Visible in Document Library',
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 DropdownMenuItem(
//                   value: 'Private',
//                   child: Row(
//                     children: [
//                       const Icon(Icons.lock, color: Colors.red, size: 18),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           'Private - Only in My Documents',
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 DropdownMenuItem(
//                   value: 'Specific Users',
//                   child: Row(
//                     children: [
//                       const Icon(Icons.people, color: Colors.orange, size: 18),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           'Specific Users - Custom sharing',
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     _selectedSharingType = value;
//                   });
//                 }
//               },
//             ),

//             const SizedBox(height: 32),

//             // Test API Connection Button
//             OutlinedButton.icon(
//               onPressed: _isLoading ? null : _testUploadConnection,
//               icon: const Icon(Icons.wifi_tethering),
//               label: const Text('Test Upload Connection'),
//               style: OutlinedButton.styleFrom(
//                 side: const BorderSide(color: Colors.indigo),
//                 foregroundColor: Colors.indigo,
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Upload Document Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: _isLoading ? null : _uploadDocument,
//                 icon: const Icon(Icons.cloud_upload, size: 24),
//                 label: _isLoading
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                             Colors.white,
//                           ),
//                         ),
//                       )
//                     : const Text(
//                         'Upload Document',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.indigo,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   elevation: 2,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//   }
// }
// ignore_for_file: use_build_context_synchronously, unnecessary_this
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/services/upload_service.dart';
import 'package:digi_sanchika/services/folder_helper.dart'; // NEW IMPORT
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
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedFolder = '';
  String _selectedClassification = 'General';
  bool _allowDownload = true;
  String _selectedSharingType = 'Public';
  final List<PlatformFile> _uploadedFiles = [];
  bool _isLoading = false;
  final bool _isConnected = true;

  // NEW: Folder management variables
  List<Map<String, dynamic>> _availableFolders = [];
  bool _foldersLoading = false;

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

  // ============ ADD THIS CONSTANT HERE ============
  static const List<String> _allSupportedExtensions = [
    // ============ Legacy Office ============
    'doc', 'xls', 'ppt', 'rtf', 'mdb', 'pub', 'pps', 'dot', 'xlt', 'pot',

    // ============ Modern Office ============
    'docx', 'xlsx', 'pptx', 'dotx', 'xltx', 'potx', 'accdb', 'one',

    // ============ OpenDocument Format ============
    'odt', 'ods', 'odp', 'odg', 'odf',

    // ============ Apple iWork ============
    'pages', 'numbers', 'key',

    // ============ PDFs ============
    'pdf',

    // ============ Text Files ============
    'txt', 'md', 'markdown',

    // ============ CSV/Data Files ============
    'csv', 'tsv', 'xml', 'json',

    // ============ ZIP & Archives ============
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso',

    // ============ Audio Files ============
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

    // ============ Video Files ============
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

    // ============ Code Files ============
    // Python
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

    // ============ JSON Files ============
    'json', 'jsonl', 'jsonc',

    // ============ Google Files ============
    'gdoc', 'gsheet', 'gslides', 'gdraw',

    // ============ Other Important ============
    'log', 'lock', 'license', 'readme', 'gitignore', 'dockerfile', 'makefile',
  ];

  // ============ FOLDER MANAGEMENT ============
  Future<void> _loadFolders() async {
    setState(() => _foldersLoading = true);

    try {
      final folders = await FolderHelper.getFoldersFlatList();

      if (folders.isNotEmpty) {
        setState(() {
          _availableFolders = folders;

          // Set default folder to "Root" first, then Home if exists
          if (folders.any(
            (f) => f['name']?.toString().toLowerCase() == 'home',
          )) {
            final homeFolder = folders.firstWhere(
              (f) => f['name']?.toString().toLowerCase() == 'home',
            );
            _selectedFolder = homeFolder['name'].toString();
          } else if (folders.isNotEmpty) {
            _selectedFolder = folders.first['name'].toString();
          } else {
            _selectedFolder = '';
          }
        });

        if (kDebugMode) {
          print('✅ Loaded ${folders.length} folders');
          for (var folder in folders) {
            print('   - ${folder['name']} (ID: ${folder['id']})');
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠ No folders found - will use empty folder_id');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading folders: $e');
      }
    } finally {
      setState(() => _foldersLoading = false);
    }
  }

  // Get folder ID for upload
  Future<String> _getFolderIdForUpload() async {
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

  // ============ MAIN UPLOAD METHOD ============
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
      if (_availableFolders.isNotEmpty) {
        if (_availableFolders.any(
          (f) => f['name']?.toString().toLowerCase() == 'home',
        )) {
          final homeFolder = _availableFolders.firstWhere(
            (f) => f['name']?.toString().toLowerCase() == 'home',
          );
          _selectedFolder = homeFolder['name'].toString();
        } else {
          _selectedFolder = _availableFolders.first['name'].toString();
        }
      } else {
        _selectedFolder = '';
      }
    });
  }

  // Add this new method
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

  // Keep your original _pickSingleFile for other files

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

        // 🚨 CRITICAL DEBUG INFO 🚨
        if (kDebugMode) {
          print('📄 ===== FILE PICKER DEBUG =====');
          print('📄 File name: ${file.name}');
          print('📄 File path: ${file.path}');
          print('📄 File size: ${file.size} bytes');
          print(
            '📄 File extension: ${file.name.split('.').last.toLowerCase()}',
          );
          print('📄 Full file name parts: ${file.name.split('.')}');

          // Check if path exists and file is readable
          if (file.path != null) {
            final fileObj = File(file.path!);
            print('📄 File exists: ${fileObj.existsSync()}');
            print('📄 File is readable: ${fileObj.existsSync()}');
            print('📄 File absolute path: ${fileObj.absolute.path}');
          } else {
            print('❌ File path is NULL!');
          }
          print('📄 ===== END DEBUG =====');
        }

        // Check for Google Docs specific files
        final extension = file.name.split('.').last.toLowerCase();
        if (['gdoc', 'gsheet', 'gslides'].contains(extension)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Google Drive files (.gdoc, .gsheet) are links, not actual documents. '
                'Export as PDF or DOCX first.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
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

        // Check if file path is valid
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

        // Check if file actually exists
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

        // Show success message
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
        print('Error details: ${e.toString()}');
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
          // Check file extension
          final extension = file.name.split('.').last.toLowerCase();

          // Only add files with allowed extensions
          if (fileType == 'all' || selectedExtensions.contains(extension)) {
            // Check file size (500MB limit)
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

        // Show summary
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

  // Future<void> _pickMultipleFiles() async {
  //   try {
  //     setState(() => _isLoading = true);
  //     // Show a dialog to select file type
  //     String? fileType = await showDialog<String>(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //         title: const Text('Select File Type'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             ListTile(
  //               leading: const Icon(Icons.audio_file),
  //               title: const Text('Audio Files'),
  //               onTap: () => Navigator.pop(context, 'audio'),
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.video_file),
  //               title: const Text('Video Files'),
  //               onTap: () => Navigator.pop(context, 'video'),
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.image),
  //               title: const Text('Image Files'),
  //               onTap: () => Navigator.pop(context, 'image'),
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.description),
  //               title: const Text('Document Files'),
  //               onTap: () => Navigator.pop(context, 'document'),
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.insert_drive_file),
  //               title: const Text('All Files'),
  //               onTap: () => Navigator.pop(context, 'all'),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );

  //     if (fileType == null) return;

  //     // FilePickerResult? result = await FilePicker.platform.pickFiles(
  //     //   type: FileType.custom,
  //     //   allowedExtensions: [
  //     //     'pdf',
  //     //     'doc',
  //     //     'docx',
  //     //     'xls',
  //     //     'xlsx',
  //     //     'ppt',
  //     //     'pptx',
  //     //     'txt',
  //     //     'jpg',
  //     //     'jpeg',
  //     //     'png',
  //     //   ],
  //     // );
  //     FilePickerResult? result;
  //     List<String> selectedExtensions = [];

  //     switch (fileType) {
  //       case 'audio':
  //         result = await FilePicker.platform.pickFiles(
  //           type: FileType.audio,
  //           allowMultiple: true,
  //         );
  //         selectedExtensions = ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'];
  //         break;
  //       case 'video':
  //         result = await FilePicker.platform.pickFiles(
  //           type: FileType.video,
  //           allowMultiple: true,
  //         );
  //         selectedExtensions = [
  //           'mp4',
  //           'mov',
  //           'avi',
  //           'mkv',
  //           'flv',
  //           'wmv',
  //           'webm',
  //         ];
  //         break;
  //       case 'image':
  //         result = await FilePicker.platform.pickFiles(
  //           type: FileType.image,
  //           allowMultiple: true,
  //         );
  //         selectedExtensions = [
  //           'jpg',
  //           'jpeg',
  //           'png',
  //           'gif',
  //           'bmp',
  //           'webp',
  //           'svg',
  //         ];
  //         break;
  //       case 'document':
  //         result = await FilePicker.platform.pickFiles(
  //           type: FileType.custom,
  //           allowedExtensions: [
  //             'pdf',
  //             'doc',
  //             'docx',
  //             'xls',
  //             'xlsx',
  //             'ppt',
  //             'pptx',
  //             'txt',
  //           ],
  //           allowMultiple: true,
  //         );
  //         selectedExtensions = [
  //           'pdf',
  //           'doc',
  //           'docx',
  //           'xls',
  //           'xlsx',
  //           'ppt',
  //           'pptx',
  //           'txt',
  //         ];
  //         break;
  //       case 'all':
  //       default:
  //         result = await FilePicker.platform.pickFiles(
  //           type: FileType.custom,
  //           allowedExtensions: [
  //             // Audio
  //             'mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac',
  //             // Video
  //             'mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm',
  //             // Images
  //             'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg',
  //             // Documents
  //             'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
  //             // Archives
  //             'zip', 'rar', '7z', 'tar', 'gz',
  //           ],
  //           allowMultiple: true,
  //         );
  //         selectedExtensions = [
  //           'mp3',
  //           'wav',
  //           'ogg',
  //           'm4a',
  //           'flac',
  //           'aac',
  //           'mp4',
  //           'mov',
  //           'avi',
  //           'mkv',
  //           'flv',
  //           'wmv',
  //           'webm',
  //           'jpg',
  //           'jpeg',
  //           'png',
  //           'gif',
  //           'bmp',
  //           'webp',
  //           'svg',
  //           'pdf',
  //           'doc',
  //           'docx',
  //           'xls',
  //           'xlsx',
  //           'ppt',
  //           'pptx',
  //           'txt',
  //           'zip',
  //           'rar',
  //           '7z',
  //           'tar',
  //           'gz',
  //         ];
  //         break;
  //     }

  //     if (result != null && result.files.isNotEmpty && mounted) {
  //       int addedFiles = 0;
  //       int skippedFiles = 0;

  //       for (var file in result.files) {
  //         // Increased size limit from 10MB to 500MB for all file types
  //         final extension = file.name.split('.').last.toLowerCase();

  //         // Only add files with allowed extensions
  //         if (fileType == 'all' || selectedExtensions.contains(extension)) {
  //           if (file.size > 500 * 1024 * 1024) {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text('File "${file.name}" exceeds 500MB limit'),
  //                 backgroundColor: Colors.red,
  //               ),
  //             );
  //             continue;
  //           }
  //           setState(() {
  //             _uploadedFiles.add(file);
  //           });
  //           addedFiles++;
  //         } else {
  //           skippedFiles++;
  //         }
  //       }
  //       if (addedFiles > 0) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text(
  //               '✅ Added $addedFiles file(s)${skippedFiles > 0 ? ' (skipped $skippedFiles)' : ''}',
  //             ),
  //             backgroundColor: Colors.green,
  //             duration: const Duration(seconds: 3),
  //           ),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Multiple file picker error: $e');
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error picking files: ${e.toString()}'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  Future<void> _pickFolder() async {
    try {
      // For folder upload, just pick multiple files
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

  // ============ HELPER METHODS ============
  String _getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      // Documents
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

      // Programming Files - JavaScript/TypeScript
      case 'js':
      case 'jsx':
        return Icons.code;
      case 'ts':
      case 'tsx':
        return Icons.data_object;
      case 'json':
        return Icons.data_array;

      // Python
      case 'py':
      case 'pyc':
      case 'pyo':
      case 'pyd':
        return Icons.account_tree;

      // HTML/CSS
      case 'html':
      case 'htm':
        return Icons.language;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Icons.palette;

      // Node.js
      case 'node':
      case 'njs':
        return Icons.dns;

      // Java
      case 'java':
      case 'class':
      case 'jar':
        return Icons.coffee;

      // C/C++
      case 'c':
      case 'cpp':
      case 'cc':
      case 'h':
      case 'hpp':
        return Icons.memory;

      // PHP
      case 'php':
        return Icons.web;

      // Ruby
      case 'rb':
      case 'erb':
        return Icons.diamond;

      // Go
      case 'go':
        return Icons.rocket_launch;

      // Rust
      case 'rs':
        return Icons.settings;

      // Kotlin
      case 'kt':
      case 'kts':
        return Icons.android;

      // Swift
      case 'swift':
        return Icons.phone_iphone;

      // Dart/Flutter
      case 'dart':
        return Icons.flutter_dash;

      // SQL/Database
      case 'sql':
      case 'db':
      case 'sqlite':
        return Icons.storage;

      // XML/YAML
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.format_align_left;

      // Config Files
      case 'env':
      case 'config':
      case 'toml':
      case 'ini':
        return Icons.settings_applications;

      // Shell/Bash
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return Icons.terminal;

      // Audio Files
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'wma':
        return Icons.audiotrack;

      // Video Files
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'flv':
      case 'wmv':
      case 'webm':
        return Icons.videocam;

      // Image Files
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'svg':
      case 'webp':
        return Icons.image;

      // Archive Files
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Icons.archive;

      // Executables
      case 'exe':
      case 'app':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return Icons.play_arrow;

      // React/Vue/Angular specific
      case 'vue':
        return Icons.view_quilt;
      case 'svelte':
        return Icons.dashboard;

      // Package Managers
      case 'lock':
      case 'package':
        return Icons.inventory;

      // Log Files
      case 'log':
        return Icons.assignment;

      // Default for any other file type
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      // Documents
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

      // JavaScript/TypeScript - Yellow
      case 'js':
      case 'jsx':
        return Colors.yellow[700]!;
      case 'ts':
      case 'tsx':
        return Colors.blue[700]!;
      case 'json':
        return Colors.amber;

      // Python - Blue/Green
      case 'py':
      case 'pyc':
      case 'pyo':
      case 'pyd':
        return Colors.blue[400]!;

      // HTML/CSS - Orange/Blue
      case 'html':
      case 'htm':
        return Colors.deepOrange;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Colors.blue[300]!;

      // Node.js - Green
      case 'node':
      case 'njs':
        return Colors.green[600]!;

      // Java - Red/Orange
      case 'java':
      case 'class':
      case 'jar':
        return Colors.red[700]!;

      // C/C++ - Purple
      case 'c':
      case 'cpp':
      case 'cc':
      case 'h':
      case 'hpp':
        return Colors.purple;

      // PHP - Purple
      case 'php':
        return Colors.purple[400]!;

      // Ruby - Red
      case 'rb':
      case 'erb':
        return Colors.red[900]!;

      // Go - Cyan
      case 'go':
        return Colors.cyan;

      // Rust - Orange/Brown
      case 'rs':
        return Colors.deepOrange[900]!;

      // Kotlin - Purple
      case 'kt':
      case 'kts':
        return Colors.purple[600]!;

      // Swift - Orange
      case 'swift':
        return Colors.orange;

      // Dart/Flutter - Blue
      case 'dart':
        return Colors.blue[500]!;

      // SQL/Database - Brown
      case 'sql':
      case 'db':
      case 'sqlite':
        return Colors.brown;

      // XML/YAML - Green
      case 'xml':
      case 'yaml':
      case 'yml':
        return Colors.green[400]!;

      // Config Files - Grey
      case 'env':
      case 'config':
      case 'toml':
      case 'ini':
        return Colors.grey[600]!;

      // Shell/Bash - Green
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
        return Colors.green[800]!;

      // Audio Files - Purple
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'wma':
        return Colors.purple;

      // Video Files - Red/Orange
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'flv':
      case 'wmv':
      case 'webm':
        return Colors.deepOrange;

      // Image Files - Pink
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'svg':
      case 'webp':
        return Colors.pink;

      // Archive Files - Brown
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Colors.brown;

      // Executables - Green
      case 'exe':
      case 'app':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return Colors.green[700]!;

      // React/Vue/Angular
      case 'vue':
        return Colors.green[400]!;
      case 'svelte':
        return Colors.orange[300]!;

      // Package Managers - Blue Grey
      case 'lock':
      case 'package':
        return Colors.blueGrey;

      // Log Files - Grey
      case 'log':
        return Colors.grey[700]!;

      // Default for any other file type
      default:
        return Colors.indigo;
    }
  }

  // // ============ TEST UPLOAD CONNECTION ============
  // Future<void> _testUploadConnection() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final result = await UploadService.testUploadConnection();

  //     setState(() {
  //       _isConnected = result['success'] == true;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           result['success'] == true
  //               ? '✅ Upload connection test successful!'
  //               : '❌ Upload connection failed: ${result['message']}',
  //         ),
  //         backgroundColor: result['success'] == true
  //             ? Colors.green
  //             : Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   } catch (e) {
  //     setState(() {
  //       _isConnected = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('❌ Connection test error: $e'),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

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

            // Connection Status
            // Container(
            //   padding: const EdgeInsets.all(8),
            //   margin: const EdgeInsets.only(bottom: 16),
            //   decoration: BoxDecoration(
            //     color: _isConnected ? Colors.green[50] : Colors.orange[50],
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(
            //       color: _isConnected ? Colors.green : Colors.orange,
            //     ),
            //   ),
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(
            //         _isConnected ? Icons.cloud_done : Icons.cloud_off,
            //         color: _isConnected ? Colors.green : Colors.orange,
            //         size: 18,
            //       ),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: Text(
            //           _isConnected
            //               ? 'Connected to server: http://172.105.62.238:8000'
            //               : 'Offline mode - Saving locally only',
            //           style: TextStyle(
            //             fontSize: 12,
            //             color: _isConnected
            //                 ? Colors.green[800]
            //                 : Colors.orange[800],
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

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

            // // Single File Upload Section
            // const Text(
            //   'Single File Upload',
            //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 16),

            // // Upload Area
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.all(32),
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.grey.shade300, width: 2),
            //     borderRadius: BorderRadius.circular(12),
            //     color: Colors.grey.shade50,
            //   ),
            //   child: Column(
            //     children: [
            //       const Icon(
            //         Icons.cloud_upload,
            //         size: 64,
            //         color: Colors.indigo,
            //       ),
            //       const SizedBox(height: 16),
            //       const Text(
            //         'Drag and drop a file here or click to browse',
            //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            //         textAlign: TextAlign.center,
            //       ),
            //       const SizedBox(height: 8),
            //       Text(
            //         'Supports: All File Types (Documents, Code, Images, Audio, Video, Archives, etc.)',
            //         style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            //         textAlign: TextAlign.center,
            //       ),
            //       const SizedBox(height: 20),
            //       ElevatedButton.icon(
            //         onPressed: _isLoading ? null : _pickSingleFile,
            //         icon: _isLoading
            //             ? const SizedBox(
            //                 width: 16,
            //                 height: 16,
            //                 child: CircularProgressIndicator(
            //                   strokeWidth: 2,
            //                   valueColor: AlwaysStoppedAnimation<Color>(
            //                     Colors.white,
            //                   ),
            //                 ),
            //               )
            //             : const Icon(Icons.upload_file),
            //         label: Text(_isLoading ? 'Opening...' : 'Select Files'),
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: Colors.indigo,
            //           foregroundColor: Colors.white,
            //           padding: const EdgeInsets.symmetric(
            //             horizontal: 24,
            //             vertical: 12,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
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

            // Destination Folder Dropdown - UPDATED
            // Destination Folder Dropdown - SIMPLE VERSION
            DropdownButtonFormField<String>(
              initialValue: _selectedFolder, // Just use the value directly
              decoration: InputDecoration(
                labelText: 'Destination Folder',
                prefixIcon: _foldersLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder, color: Colors.indigo),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: [
                // Always include Root option
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Root (No folder)'),
                ),
                // Add folders from API
                ..._availableFolders.map((folder) {
                  final folderName = folder['name']?.toString() ?? 'Unnamed';
                  return DropdownMenuItem<String>(
                    value: folderName,
                    child: Text(folderName),
                  );
                }),
              ],
              onChanged: _foldersLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFolder = value;
                        });
                      }
                    },
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

            // Allow Download Checkbox
            // Card(
            //   color: Colors.white,
            //   elevation: 1,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: CheckboxListTile(
            //     title: const Text(
            //       'Allow Download',
            //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            //     ),
            //     value: _allowDownload,
            //     onChanged: (value) {
            //       setState(() {
            //         _allowDownload = value!;
            //       });
            //     },
            //     secondary: const Icon(Icons.download, color: Colors.indigo),
            //     controlAffinity: ListTileControlAffinity.leading,
            //   ),
            // ),
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
                // DropdownMenuItem(
                //   value: 'Specific Users',
                //   child: Row(
                //     children: [
                //       const Icon(Icons.people, color: Colors.orange, size: 18),
                //       const SizedBox(width: 10),
                //       Expanded(
                //         child: Text(
                //           'Specific Users - Custom sharing',
                //           overflow: TextOverflow.ellipsis,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
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

            // // Test API Connection Button
            // OutlinedButton.icon(
            //   onPressed: _isLoading ? null : _testUploadConnection,
            //   icon: const Icon(Icons.wifi_tethering),
            //   label: const Text('Test Upload Connection'),
            //   style: OutlinedButton.styleFrom(
            //     side: const BorderSide(color: Colors.indigo),
            //     foregroundColor: Colors.indigo,
            //   ),
            // ),
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
