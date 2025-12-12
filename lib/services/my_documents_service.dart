// services/my_documents_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/models/folder.dart';

class MyDocumentsService {
  // Singleton instance
  static final MyDocumentsService _instance = MyDocumentsService._internal();
  factory MyDocumentsService() => _instance;
  MyDocumentsService._internal();

  // ============ GET DOCUMENTS & FOLDERS ============
  static Future<Map<String, dynamic>> fetchMyDocuments({int? folderId}) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'documents': [],
          'folders': [],
          'error': 'Offline mode',
        };
      }

      final headers = await _createAuthHeaders();
      String url = '${ApiService.currentBaseUrl}/my-documents';
      if (folderId != null) url += '?folder_id=$folderId';

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final documents = _mapBackendDocuments(responseData['documents'] ?? []);
        final folders = _mapBackendFolders(
          responseData['folders'] ?? [],
          folderId,
        );

        return {
          'success': true,
          'documents': documents,
          'folders': folders,
          'total': documents.length,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication required',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load documents (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ DELETE DOCUMENT ============
  static Future<Map<String, dynamic>> deleteDocument(String documentId) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiService.currentBaseUrl}/documents/$documentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Document deleted successfully'};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete document (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ CREATE FOLDER ============
  static Future<Map<String, dynamic>> createFolder({
    required String folderName,
    int? parentFolderId,
  }) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiService.currentBaseUrl}/folders'),
        headers: headers,
        body: {
          'name': folderName,
          'parent_id': parentFolderId?.toString() ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final folder = Folder(
          id: data['id'].toString(),
          name: data['name'],
          documents: [],
          createdAt: DateTime.parse(data['created_at']),
          owner: data['owner'] ?? 'User',
        );
        return {
          'success': true,
          'folder': folder,
          'message': 'Folder created successfully',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create folder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ DELETE FOLDER ============
  static Future<Map<String, dynamic>> deleteFolder(String folderId) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiService.currentBaseUrl}/folders/$folderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Folder deleted successfully'};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete folder (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ DOWNLOAD DOCUMENT ============
  static Future<Map<String, dynamic>> downloadDocument(
    String documentId,
  ) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '${ApiService.currentBaseUrl}/documents/$documentId/download',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'filename':
              response.headers['content-disposition']
                  ?.split('filename=')[1]
                  .replaceAll('"', '') ??
              'document',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Download failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ GET DOCUMENT VERSIONS ============
  static Future<Map<String, dynamic>> getDocumentVersions(
    String documentId,
  ) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '${ApiService.currentBaseUrl}/documents/$documentId/versions',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'versions': data['versions'] ?? []};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get versions (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ GET DOCUMENT DETAILS ============
  static Future<Map<String, dynamic>> getDocumentDetails(
    String documentId,
  ) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.currentBaseUrl}/documents/$documentId/details'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'details': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get details (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ ENHANCED SEARCH ============
  static Future<Map<String, dynamic>> enhancedSearch({
    required Map<String, dynamic> criteria,
    required String scope,
  }) async {
    try {
      final headers = await _createAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse('${ApiService.currentBaseUrl}/enhanced-search'),
        headers: headers,
        body: json.encode({'criteria': criteria, 'scope': scope}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = _mapBackendDocuments(data['documents'] ?? []);
        return {'success': true, 'documents': documents};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Search failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ GET USERS FOR SHARING ============
  static Future<Map<String, dynamic>> getUsersForSharing() async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.currentBaseUrl}/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final users = json.decode(response.body) as List;
        return {'success': true, 'users': users};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get users (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ SHARE DOCUMENT ============
  static Future<Map<String, dynamic>> shareDocument({
    required String documentId,
    required List<String> userIds,
  }) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiService.currentBaseUrl}/share-document'),
        headers: headers,
        body: {'document_id': documentId, 'user_ids': json.encode(userIds)},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Document shared successfully'};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Share failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ SHARE FOLDER ============
  static Future<Map<String, dynamic>> shareFolder({
    required String folderId,
    required List<String> userIds,
  }) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiService.currentBaseUrl}/share-folder'),
        headers: headers,
        body: {'folder_id': folderId, 'user_ids': json.encode(userIds)},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Folder shared successfully'};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Share failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Exception: $e'};
    }
  }

  // ============ HELPER METHODS ============
  static Future<Map<String, String>> _createAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    try {
      final cookie = await ApiService.getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookie';
      }
    } catch (e) {
      if (kDebugMode) print('⚠ Could not get session cookie: $e');
    }

    return headers;
  }

  static List<Document> _mapBackendDocuments(List<dynamic> backendDocs) {
    final List<Document> documents = [];

    for (var docJson in backendDocs) {
      try {
        final docData = Map<String, dynamic>.from(docJson);
        final filename = docData['original_filename']?.toString() ?? '';
        final fileType = _extractFileType(filename);
        final isPublic = docData['is_public'] == true;
        final sharingType = isPublic ? 'Public' : 'Private';

        documents.add(
          Document(
            id: docData['id']?.toString() ?? '',
            name: filename.isNotEmpty ? filename : 'Untitled Document',
            type: fileType,
            size: _getFileSize(docData),
            keyword: docData['keywords']?.toString() ?? '',
            uploadDate: _formatUploadDate(docData['upload_date']),
            owner: docData['owner']?['name']?.toString() ?? 'Unknown',
            details: docData['remarks']?.toString() ?? '',
            classification: docData['doc_class']?.toString() ?? 'General',
            allowDownload: docData['allow_download'] == true,
            sharingType: sharingType,
            folder: docData['folder_path']?.toString() ?? 'Home',
            path: filename,
            fileType: fileType,
          ),
        );
      } catch (e) {
        if (kDebugMode) print('❌ Error mapping document: $e');
      }
    }

    return documents;
  }

  static List<Folder> _mapBackendFolders(
    List<dynamic> backendFolders,
    int? parentId,
  ) {
    final List<Folder> folders = [];

    for (var folderJson in backendFolders) {
      try {
        final folderData = Map<String, dynamic>.from(folderJson);
        folders.add(
          Folder(
            id: folderData['id']?.toString() ?? '',
            name: folderData['name']?.toString() ?? 'Unnamed Folder',
            documents: [],
            parentId: parentId?.toString(),
            createdAt: DateTime.parse(
              folderData['created_at']?.toString() ?? DateTime.now().toString(),
            ),
            owner: folderData['owner']?.toString() ?? 'User',
          ),
        );
      } catch (e) {
        if (kDebugMode) print('❌ Error mapping folder: $e');
      }
    }

    return folders;
  }

  static String _extractFileType(String filename) {
    if (filename.isEmpty) return 'unknown';
    final extension = filename.split('.').last.toLowerCase();

    final typeMap = {
      'pdf': 'PDF',
      'doc': 'DOC',
      'docx': 'DOCX',
      'xls': 'XLS',
      'xlsx': 'XLSX',
      'ppt': 'PPT',
      'pptx': 'PPTX',
      'txt': 'TXT',
      'csv': 'CSV',
      'jpg': 'JPG',
      'jpeg': 'JPEG',
      'png': 'PNG',
      'zip': 'ZIP',
      'rar': 'RAR',
    };

    return typeMap[extension] ?? extension.toUpperCase();
  }

  static String _getFileSize(Map<String, dynamic> docData) {
    final sizeValue = docData['file_size'];
    if (sizeValue != null) {
      try {
        final int sizeInBytes = int.tryParse(sizeValue.toString()) ?? 0;
        if (sizeInBytes == 0) return '0 KB';

        const int kb = 1024;
        const int mb = kb * 1024;
        const int gb = mb * 1024;

        if (sizeInBytes >= gb) {
          return '${(sizeInBytes / gb).toStringAsFixed(1)} GB';
        } else if (sizeInBytes >= mb) {
          return '${(sizeInBytes / mb).toStringAsFixed(1)} MB';
        } else if (sizeInBytes >= kb) {
          return '${(sizeInBytes / kb).toStringAsFixed(1)} KB';
        } else {
          return '$sizeInBytes B';
        }
        // ignore: empty_catches
      } catch (e) {}
    }
    return 'Unknown Size';
  }

  static String _formatUploadDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now().toString();
    try {
      final dateStr = dateValue.toString();
      if (dateStr.contains('T')) {
        final dateTime = DateTime.parse(dateStr);
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      }
      return dateStr;
    } catch (e) {
      return dateValue.toString();
    }
  }
}
