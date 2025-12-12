// services/shared_browse_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/models/document.dart';

class SharedBrowseService {
  static const String _baseUrl = 'http://172.105.62.238:8000';

  // Get shared folder contents using unified API
  static Future<Map<String, dynamic>> getSharedFolderContents({
    String? folderId,
  }) async {
    try {
      final headers = await _createAuthHeaders();

      // Build URL with optional folder_id parameter
      final url = folderId != null && folderId.isNotEmpty
          ? '$_baseUrl/browse-shared?folder_id=$folderId'
          : '$_baseUrl/browse-shared';

      developer.log('Calling shared browse API: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      developer.log('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse documents
        List<Document> documents = [];
        if (data['documents'] != null && data['documents'] is List) {
          documents = (data['documents'] as List).map((doc) {
            return Document(
              id: doc['id']?.toString() ?? '',
              name: doc['original_filename']?.toString() ?? 'Unnamed Document',
              type: _extractFileType(
                doc['original_filename']?.toString() ?? '',
              ),
              size: _formatFileSize(doc['file_size']?.toString() ?? '0'),
              keyword: doc['keywords']?.toString() ?? '',
              uploadDate: _formatDate(doc['upload_date']),
              owner: doc['owner']?['name']?.toString() ?? 'Unknown',
              details: doc['remarks']?.toString() ?? '',
              classification: doc['doc_class']?.toString() ?? 'General',
              allowDownload: doc['allow_download'] ?? true,
              sharingType: doc['is_public'] == true ? 'Public' : 'Private',
              folder: _getFolderPath(data['current_folder']),
              folderId: data['current_folder']?['id']?.toString(),
              path: doc['original_filename']?.toString() ?? '',
              fileType: _extractFileType(
                doc['original_filename']?.toString() ?? '',
              ),
            );
          }).toList();
        }

        // Parse subfolders
        List<Map<String, dynamic>> subfolders = [];
        if (data['folders'] != null && data['folders'] is List) {
          subfolders = (data['folders'] as List).map((folder) {
            return {
              'id': folder['id']?.toString(),
              'name': folder['name']?.toString() ?? 'Unnamed Folder',
              'owner': folder['owner']?['name']?.toString() ?? 'Unknown',
              'ownerId': folder['owner']?['id']?.toString(),
              'created_at': folder['created_at'],
              'parent_id': folder['parent_id']?.toString(),
              'item_count': folder['item_count'] ?? {'total': 0},
              'is_shared': folder['is_shared'] ?? false,
            };
          }).toList();
        }

        // Build breadcrumb
        List<Map<String, dynamic>> breadcrumb = [];
        if (data['breadcrumb'] != null && data['breadcrumb'] is List) {
          breadcrumb = (data['breadcrumb'] as List).map((item) {
            return {
              'id': item['id']?.toString(),
              'name': item['name']?.toString() ?? '',
              'has_access': item['has_access'] ?? true,
            };
          }).toList();
        }

        // Current folder info
        Map<String, dynamic> folderInfo = {};
        if (data['current_folder'] != null) {
          folderInfo = {
            'id': data['current_folder']?['id']?.toString(),
            'name':
                data['current_folder']?['name']?.toString() ?? 'Shared with Me',
            'owner':
                data['current_folder']?['owner']?['name']?.toString() ??
                'Unknown',
            'ownerId': data['current_folder']?['owner']?['id']?.toString(),
            'created_at': data['current_folder']?['created_at'],
          };
        }

        // Stats
        Map<String, dynamic> stats = {};
        if (data['stats'] != null) {
          stats = {
            'total_documents': data['stats']['total_documents'] ?? 0,
            'total_folders': data['stats']['total_folders'] ?? 0,
            'is_empty': data['stats']['is_empty'] ?? true,
          };
        }

        return {
          'success': true,
          'documents': documents,
          'folders': subfolders,
          'folderInfo': folderInfo,
          'breadcrumb': breadcrumb,
          'stats': stats,
          'isShared': true,
        };
      } else if (response.statusCode == 401) {
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'You do not have access to this shared folder.',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Shared folder not found.'};
      } else if (response.statusCode == 503) {
        return {
          'success': false,
          'error': 'Shared folder functionality not available.',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error':
                errorData['detail']?.toString() ??
                'Failed to load shared folder contents.',
          };
        } catch (e) {
          return {
            'success': false,
            'error':
                'Failed to load shared folder contents (${response.statusCode})',
          };
        }
      }
    } catch (e) {
      developer.log('❌ Error getting shared folder contents: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Download shared document
  static Future<Map<String, dynamic>> downloadSharedDocument(
    String documentId,
  ) async {
    try {
      final headers = await _createAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/shared-document/$documentId/download'),
        headers: headers,
      );

      developer.log('Download API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Parse the download response
        final contentType = response.headers['content-type'];
        final contentDisposition = response.headers['content-disposition'];

        String filename = 'shared_document';
        if (contentDisposition != null) {
          final match = RegExp(
            r'filename="(.+)"',
          ).firstMatch(contentDisposition);
          if (match != null) {
            filename = match.group(1)!;
          } else {
            final match2 = RegExp(
              r'filename=([^;]+)',
            ).firstMatch(contentDisposition);
            if (match2 != null) {
              filename = match2.group(1)!;
            }
          }
        }

        return {
          'success': true,
          'filename': filename,
          'contentType': contentType,
          'fileData': response.bodyBytes,
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['detail']?.toString() ?? 'Download failed',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Download failed (${response.statusCode})',
          };
        }
      }
    } catch (e) {
      developer.log('❌ Error downloading shared document: $e');
      return {'success': false, 'error': 'Download error: ${e.toString()}'};
    }
  }

  // Helper: Get folder path from current_folder data
  static String _getFolderPath(Map<String, dynamic>? folderData) {
    if (folderData == null) return 'Shared with Me';
    if (folderData['id'] == null) return 'Shared with Me';
    return folderData['name']?.toString() ?? 'Shared Folder';
  }

  // Helper: Extract file type
  static String _extractFileType(String filename) {
    if (filename.isEmpty) return 'Unknown';

    // Handle cases where filename might not have extension
    if (!filename.contains('.')) return 'Unknown';

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
      case 'bmp':
      case 'webp':
      case 'svg':
        return 'Image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
      case 'flv':
        return 'Video';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return 'Audio';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'Archive';
      case 'py':
        return 'Python';
      case 'js':
      case 'jsx':
        return 'JavaScript';
      case 'html':
      case 'htm':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'json':
        return 'JSON';
      case 'xml':
        return 'XML';
      case 'csv':
        return 'CSV';
      default:
        return ext.toUpperCase();
    }
  }

  // Helper: Format file size
  static String _formatFileSize(String size) {
    try {
      // Remove non-numeric characters
      final cleanSize = size.replaceAll(RegExp(r'[^0-9]'), '');
      final bytes = int.tryParse(cleanSize) ?? 0;

      if (bytes == 0) return '0 B';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      developer.log('Error formatting file size: $e for input: $size');
      return size;
    }
  }

  // Helper: Format date
  static String _formatDate(dynamic date) {
    if (date == null) return 'Unknown Date';

    try {
      final dateStr = date.toString();
      if (dateStr.contains('T')) {
        final dateTime = DateTime.parse(dateStr);
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      } else if (dateStr.contains('-')) {
        // Try parsing YYYY-MM-DD format
        final parts = dateStr.split('-');
        if (parts.length >= 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      return dateStr;
    } catch (e) {
      developer.log('Error formatting date: $e for input: $date');
      return date.toString();
    }
  }

  // Create auth headers
  static Future<Map<String, String>> _createAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      // Get session cookie from ApiService
      final cookie = await ApiService.getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookie';
        developer.log('Using session cookie for shared browse');
      } else {
        developer.log('⚠ No session cookie found for shared browse');
      }
    } catch (e) {
      developer.log('⚠ Could not get session cookie: $e');
    }

    return headers;
  }
}
