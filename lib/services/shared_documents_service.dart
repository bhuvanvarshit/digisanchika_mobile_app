// services/shared_documents_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/models/shared_folder.dart';
import 'package:digi_sanchika/services/api_service.dart';

/// Response model for shared documents API
class SharedDocumentsResponse {
  final List<Document> documents;
  final List<SharedFolder> folders;

  SharedDocumentsResponse({required this.documents, required this.folders});

  factory SharedDocumentsResponse.fromJson(Map<String, dynamic> json) {
    // Parse documents
    final documents = <Document>[];
    if (json['documents'] is List) {
      for (var docJson in json['documents']) {
        try {
          final document = Document(
            id: (docJson['id'] ?? 0).toString(),
            name:
                docJson['original_filename']?.toString() ?? 'Unknown Document',
            type: _extractFileType(
              docJson['original_filename']?.toString() ?? '',
            ),
            size: (docJson['file_size']?.toString() ?? '0 KB'),
            keyword: docJson['keywords']?.toString() ?? '',
            uploadDate: _formatDate(docJson['upload_date']),
            owner: docJson['owner']?['name']?.toString() ?? 'Unknown User',
            details: docJson['remarks']?.toString() ?? '',
            classification: docJson['doc_class']?.toString() ?? 'General',
            allowDownload: docJson['allow_download'] ?? true,
            sharingType: 'shared',
            folder: docJson['folder_path']?.toString() ?? 'Home',
            folderId: docJson['folder_id']?.toString(),
            path: docJson['original_filename']?.toString() ?? '',
            fileType: _extractFileType(
              docJson['original_filename']?.toString() ?? '',
            ),
          );
          documents.add(document);
        } catch (e) {
          debugPrint('Error parsing document: $e');
        }
      }
    }

    // Parse folders
    final folders = <SharedFolder>[];
    if (json['folders'] is List) {
      for (var folderJson in json['folders']) {
        try {
          final folder = SharedFolder(
            id: (folderJson['id'] ?? 0).toString(),
            name: folderJson['name']?.toString() ?? 'Unknown Folder',
            owner: folderJson['owner']?['name']?.toString() ?? 'Unknown User',
            createdAt: _formatDate(folderJson['created_at']),
          );
          folders.add(folder);
        } catch (e) {
          debugPrint('Error parsing folder: $e');
        }
      }
    }

    return SharedDocumentsResponse(documents: documents, folders: folders);
  }

  static String _extractFileType(String filename) {
    if (filename.isEmpty) return 'unknown';
    final parts = filename.split('.');
    if (parts.length > 1) {
      final ext = parts.last.toLowerCase();
      // Map to common types
      if (ext == 'pdf') return 'pdf';
      if (ext == 'doc' || ext == 'docx') return 'docx';
      if (ext == 'xls' || ext == 'xlsx') return 'xlsx';
      if (ext == 'ppt' || ext == 'pptx') return 'pptx';
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') return 'image';
      if (ext == 'txt') return 'txt';
      if (ext == 'csv') return 'csv';
      return ext;
    }
    return 'unknown';
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      // Try to handle different date formats
      final dateStr = date.toString();
      // If it's already in dd/mm/yyyy format, return as is
      if (dateStr.contains('/')) return dateStr;
      return dateStr;
    }
  }
}

/// Service specifically for handling shared documents API calls
class SharedDocumentsService {
  /// Fetches shared documents from the backend
  Future<SharedDocumentsResponse> fetchSharedDocuments() async {
    try {
      // Using your existing ApiService.isConnected to check connection
      if (!ApiService.isConnected) {
        debugPrint('No internet connection');
        throw Exception('No internet connection. Please check your network.');
      }

      // Get headers - need to access the private method via a public wrapper
      final headers = await _getAuthHeaders();
      final url = Uri.parse('${ApiService.currentBaseUrl}/shared-documents');

      debugPrint('🔗 Fetching shared documents from: $url');

      final response = await http.get(url, headers: headers);

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint(
          '✅ Successfully fetched ${data['documents']?.length ?? 0} documents',
        );
        debugPrint(
          '✅ Successfully fetched ${data['folders']?.length ?? 0} folders',
        );

        return SharedDocumentsResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        debugPrint('🔐 Authentication failed - clearing session');
        await ApiService.clearSessionCookie();
        throw Exception('Session expired. Please login again.');
      } else {
        debugPrint(
          '❌ Failed to fetch shared documents: ${response.statusCode}',
        );
        debugPrint('❌ Response body: ${response.body}');
        throw Exception(
          'Failed to load shared documents. Status: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('🌐 Network error: $e');
      throw Exception('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      debugPrint('🔗 HTTP error: $e');
      throw Exception('Server error. Please try again later.');
    } on FormatException catch (e) {
      debugPrint('📝 Format error: $e');
      throw Exception('Invalid response from server.');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      throw Exception('An unexpected error occurred.');
    }
  }

  /// Check if we can access a shared folder (using same endpoint as my-documents)
  Future<bool> canAccessSharedFolder(String folderId) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiService.currentBaseUrl}/my-documents?folder_id=$folderId',
      );

      debugPrint('🔍 Checking access to shared folder: $folderId');

      final response = await http.get(url, headers: headers);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error checking folder access: $e');
      return false;
    }
  }

  /// Downloads a shared document
  Future<Map<String, dynamic>> downloadDocument(String documentId) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'error': 'No internet connection',
          'message': 'Please check your internet connection',
        };
      }

      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiService.currentBaseUrl}/documents/$documentId/download',
      );

      debugPrint('📥 Downloading from: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        debugPrint('✅ Download successful for document: $documentId');

        // Get filename from content-disposition header
        String? filename = documentId;
        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          final match = RegExp(
            r'filename="([^"]+)"',
          ).firstMatch(contentDisposition);
          if (match != null) {
            filename = match.group(1);
          }
        }

        return {
          'success': true,
          'fileData': response.bodyBytes,
          'filename': filename,
          'contentType':
              response.headers['content-type'] ?? 'application/octet-stream',
          'message': 'Download completed successfully',
        };
      } else if (response.statusCode == 401) {
        debugPrint('🔐 Authentication failed for download');
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'Permission denied',
          'message': 'You do not have permission to download this document',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Not found',
          'message': 'Document not found',
        };
      } else {
        debugPrint('❌ Download failed: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Download failed',
          'message': 'Unable to download the document (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error downloading document',
      };
    }
  }

  /// Previews a shared document
  Future<Map<String, dynamic>> previewDocument(String documentId) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'error': 'No internet connection',
          'message': 'Please check your internet connection',
        };
      }

      // First try to convert for preview
      final convertResponse = await _convertDocumentForPreview(documentId);
      if (convertResponse['success'] == true) {
        return convertResponse;
      }

      // If conversion fails, try to download and open
      final downloadResponse = await downloadDocument(documentId);
      if (downloadResponse['success'] == true) {
        return {
          'success': true,
          'type': 'download',
          'fileData': downloadResponse['fileData'],
          'filename': downloadResponse['filename'],
          'contentType': downloadResponse['contentType'],
          'message': 'Document ready for viewing',
        };
      }

      return downloadResponse;
    } catch (e) {
      debugPrint('❌ Preview error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error previewing document',
      };
    }
  }

  /// Convert document to HTML for preview
  Future<Map<String, dynamic>> _convertDocumentForPreview(
    String documentId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiService.currentBaseUrl}/documents/$documentId/convert',
      );

      debugPrint('🔄 Converting document for preview: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'type': data['type'] ?? 'html',
          'content': data['content'] ?? '',
          'message': data['message'] ?? 'Preview generated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Conversion failed',
          'message': 'Unable to convert document for preview',
        };
      }
    } catch (e) {
      debugPrint('❌ Conversion error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error converting document',
      };
    }
  }

  /// Gets document details by ID
  Future<Map<String, dynamic>> getDocumentDetails(String documentId) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiService.currentBaseUrl}/documents/$documentId/details',
      );

      debugPrint('📋 Getting document details: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'message': 'Document details retrieved',
        };
      } else if (response.statusCode == 401) {
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get details',
          'message': 'Unable to retrieve document details',
        };
      }
    } catch (e) {
      debugPrint('❌ Document details error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error getting document details',
      };
    }
  }

  /// Gets document versions
  Future<Map<String, dynamic>> getDocumentVersions(String documentId) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiService.currentBaseUrl}/documents/$documentId/versions',
      );

      debugPrint('🔄 Getting document versions: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'message': 'Document versions retrieved',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get versions',
          'message': 'Unable to retrieve document versions',
        };
      }
    } catch (e) {
      debugPrint('❌ Document versions error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error getting document versions',
      };
    }
  }

  /// Helper method to get authenticated headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Get session cookie using ApiService's public method
    final cookie = await ApiService.getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = 'session_id=$cookie';
      if (kDebugMode) {
        print('🍪 Adding session cookie to headers');
      }
    }

    return headers;
  }

  /// Check if user is logged in (uses your ApiService method)
  Future<bool> isLoggedIn() async {
    return await ApiService.isLoggedIn();
  }

  /// Check internet connection (uses your ApiService method)
  bool get isConnected => ApiService.isConnected;
}
