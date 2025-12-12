// services/folder_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/models/folder.dart';
import 'package:digi_sanchika/models/document.dart';

class FolderService {
  static const String _baseUrl = 'http://172.105.62.238:8000';

  // Get folder contents (documents + subfolders)
  static Future<Map<String, dynamic>> getFolderContents(String folderId) async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/my-documents?folder_id=$folderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Convert documents
        List<Document> documents = [];
        if (data['documents'] != null) {
          documents = (data['documents'] as List).map((doc) {
            return Document(
              id: doc['id'].toString(),
              name: doc['original_filename'],
              type: _extractFileType(doc['original_filename']),
              size: '${doc['file_size'] ?? 'Unknown'} bytes',
              keyword: doc['keywords'] ?? '',
              uploadDate: doc['upload_date']?.toString() ?? '',
              owner: doc['owner']['name'] ?? 'Unknown',
              details: doc['remarks'] ?? '',
              classification: doc['doc_class'] ?? 'General',
              allowDownload: doc['allow_download'] ?? true,
              sharingType: doc['is_public'] ? 'Public' : 'Private',
              folder: doc['folder_path'] ?? 'Home',
              folderId: doc['folder_id']?.toString(),
              path: doc['original_filename'],
              fileType: _extractFileType(doc['original_filename']),
            );
          }).toList();
        }

        // Convert subfolders
        List<Folder> subfolders = [];
        if (data['folders'] != null) {
          subfolders = (data['folders'] as List).map((folder) {
            return Folder(
              name: folder['name'] ?? 'Unnamed',
              id: folder['id'].toString(),
              owner: 'User', // You might want to get from response
              documents: [], // Empty initially
              createdAt: DateTime.parse(
                folder['created_at'] ?? DateTime.now().toString(),
              ),
              parentId: folder['parent_id']?.toString(),
            );
          }).toList();
        }

        return {
          'success': true,
          'documents': documents,
          'subfolders': subfolders,
          'folderName': data['folder_name'] ?? 'Folder',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting folder contents: $e');
      }
    }
    return {'success': false, 'error': 'Failed to load folder contents'};
  }

  // Get folder tree/hierarchy
  static Future<Map<String, dynamic>> getFolderTree() async {
    try {
      final headers = await _createAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/my-folders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> foldersData = jsonDecode(response.body);

        // Extract all folder IDs
        List<String> extractFolderIds(List<dynamic> folderList) {
          List<String> ids = [];
          for (var folder in folderList) {
            ids.add(folder['id'].toString());
            if (folder['children'] != null && folder['children'].isNotEmpty) {
              ids.addAll(extractFolderIds(folder['children']));
            }
          }
          return ids;
        }

        List<String> allFolderIds = extractFolderIds(foldersData);

        return {
          'success': true,
          'folders': foldersData,
          'allFolderIds': allFolderIds,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting folder tree: $e');
      }
    }
    return {'success': false, 'error': 'Failed to load folder tree'};
  }

  // Get folder path/breadcrumb
  static Future<List<Map<String, dynamic>>> getFolderPath(
    String folderId,
  ) async {
    // This would need a backend endpoint like /folders/{id}/path
    // For now, return mock data
    return [
      {'id': 'home', 'name': 'Home'},
      {'id': folderId, 'name': 'Folder'},
    ];
  }

  // Helper: Extract file type
  static String _extractFileType(String filename) {
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
      default:
        return ext.toUpperCase();
    }
  }

  // Create auth headers
  static Future<Map<String, String>> _createAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      // Add your auth token/cookie from ApiService
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookie';
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Could not get session cookie: $e');
      }
    }

    return headers;
  }

  static Future<String?> _getSessionCookie() async {
    // Get from your existing auth system
    return ApiService.getSessionCookie.call();
  }
}
