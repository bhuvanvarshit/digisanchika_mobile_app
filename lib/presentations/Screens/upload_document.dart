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

  // ============ FILE PICKING METHODS ============
  Future<void> _pickSingleFile() async {
    try {
      setState(() => _isLoading = true);
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'xlsx',
          'xls',
          'pptx',
          'ppt',
          'txt',
        ],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        PlatformFile file = result.files.first;

        if (file.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" exceeds 10MB limit'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
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

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'xlsx',
          'xls',
          'pptx',
          'ppt',
          'txt',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        for (var file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "${file.name}" exceeds 10MB limit'),
                backgroundColor: Colors.red,
              ),
            );
            continue;
          }
          setState(() {
            _uploadedFiles.add(file);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
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
      case 'txt':
        return Icons.text_fields;
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
      case 'doc':
        return Colors.blue;
      case 'xlsx':
      case 'xls':
        return Colors.green;
      case 'pptx':
      case 'ppt':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
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

            // Single File Upload Section
            const Text(
              'Single File Upload',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Upload Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_upload,
                    size: 64,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Drag and drop a file here or click to browse',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports: PDF, DOCX, XLSX, PPTX, TXT',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickSingleFile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isLoading ? 'Opening...' : 'Select Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: CheckboxListTile(
                title: const Text(
                  'Allow Download',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                value: _allowDownload,
                onChanged: (value) {
                  setState(() {
                    _allowDownload = value!;
                  });
                },
                secondary: const Icon(Icons.download, color: Colors.indigo),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),

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
