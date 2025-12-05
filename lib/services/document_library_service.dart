// services/document_library_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/local_storage.dart';

class DocumentLibraryService {
  static final DocumentLibraryService _instance =
      DocumentLibraryService._internal();

  factory DocumentLibraryService() => _instance;

  DocumentLibraryService._internal();

  // 1. Fetch all public documents from library
  Future<List<Document>> fetchLibraryDocuments() async {
    try {
      if (!ApiService.isConnected) {
        return await LocalStorageService.loadDocuments(isPublic: true);
      }

      final url = Uri.parse('${ApiService.baseUrl}/library-documents');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final List<Document> documents = _convertToDocumentList(responseData);

        // Save to local storage for offline use
        await LocalStorageService.saveDocuments(documents, isPublic: true);

        return documents;
      } else if (response.statusCode == 401) {
        print('⚠ Authentication required for library documents');
        await ApiService.clearSessionCookie();
        return await LocalStorageService.loadDocuments(isPublic: true);
      } else {
        print('⚠ Failed to fetch library documents: ${response.statusCode}');
        return await LocalStorageService.loadDocuments(isPublic: true);
      }
    } catch (e) {
      print('❌ Error fetching library documents: $e');
      return await LocalStorageService.loadDocuments(isPublic: true);
    }
  }

  // 2. Get document versions (if needed)
  Future<Map<String, dynamic>> getDocumentVersions(String documentId) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'error': 'Cannot fetch versions while offline',
          'versions': [],
        };
      }

      final url = Uri.parse(
        '${ApiService.baseUrl}/documents/$documentId/versions',
      );
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'success': true,
          'document_name': data['document_name'],
          'versions': data['versions'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch versions: ${response.statusCode}',
          'versions': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching versions: $e',
        'versions': [],
      };
    }
  }

  // 3. Download document from library
  Future<Map<String, dynamic>> downloadDocument(
    String documentId,
    String filename,
  ) async {
    try {
      if (!ApiService.isConnected) {
        return {'success': false, 'error': 'Cannot download while offline'};
      }

      final url = Uri.parse(
        '${ApiService.baseUrl}/documents/$documentId/download',
      );
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'filename': filename,
          'contentType': response.headers['content-type'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['detail'] ?? 'Download failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Download error: $e'};
    }
  }

  // 4. Delete document (if you own it)
  Future<Map<String, dynamic>> deleteDocument(String documentId) async {
    try {
      if (!ApiService.isConnected) {
        return {'success': false, 'error': 'Cannot delete while offline'};
      }

      final url = Uri.parse('${ApiService.baseUrl}/documents/$documentId');
      final headers = await _getAuthHeaders();

      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Document deleted successfully'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['detail'] ?? 'Delete failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Delete error: $e'};
    }
  }

  // 5. Get document preview (if needed)
  Future<Map<String, dynamic>> getDocumentPreview(String documentId) async {
    try {
      if (!ApiService.isConnected) {
        return {'success': false, 'error': 'Cannot preview while offline'};
      }

      final url = Uri.parse(
        '${ApiService.baseUrl}/documents/$documentId/convert',
      );
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return {'success': true, 'preview_data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Preview failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Preview error: $e'};
    }
  }

  // Helper: Convert API response to Document list
  List<Document> _convertToDocumentList(List<dynamic> data) {
    return data.map((docJson) {
      return Document(
        id: docJson['id'].toString(),
        name: docJson['original_filename'] ?? 'Document',
        type: _extractFileType(docJson['original_filename'] ?? ''),
        size: _formatFileSize(docJson['file_size'] ?? 0),
        keyword: docJson['keywords'] ?? '',
        uploadDate:
            docJson['upload_date']?.toString() ?? DateTime.now().toString(),
        owner: docJson['owner']?['name'] ?? 'Unknown',
        details: docJson['remarks'] ?? '',
        classification: docJson['doc_class'] ?? 'General',
        allowDownload: docJson['allow_download'] ?? true,
        sharingType: 'Public', // Library documents are always public
        folder: docJson['folder_path'] ?? 'Home',
        folderId: docJson['folder_id']?.toString(),
        path: docJson['original_filename'] ?? '',
        fileType: _extractFileType(docJson['original_filename'] ?? ''),
      );
    }).toList();
  }

  // Helper: Extract file type from filename
  String _extractFileType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'DOCX';
      case 'xls':
      case 'xlsx':
        return 'XLSX';
      case 'ppt':
      case 'pptx':
        return 'PPTX';
      case 'txt':
        return 'TXT';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'IMAGE';
      default:
        return ext.toUpperCase();
    }
  }

  // Helper: Format file size
  String _formatFileSize(dynamic size) {
    try {
      final bytes = int.tryParse(size.toString()) ?? 0;
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824)
        return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Helper: Get authentication headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final cookie = await ApiService.getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = 'session_id=$cookie';
    }

    return headers;
  }
}
