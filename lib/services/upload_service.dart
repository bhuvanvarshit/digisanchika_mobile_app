import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:digi_sanchika/services/api_service.dart';

class UploadService {
  static const String _baseUrl = 'http://172.105.62.238:8000';

  // Get session cookie from ApiService
  static Future<String?> _getSessionCookie() async {
    return await ApiService.getSessionCookie();
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final cookie = await _getSessionCookie();
    return cookie != null && cookie.isNotEmpty;
  }

  // ============ SINGLE FILE UPLOAD ============
  static Future<Map<String, dynamic>> uploadSingleFile({
    required File file,
    required String keywords,
    required String remarks,
    required String docClass,
    required bool allowDownload,
    required String sharing,
    required String folderId,
    String specificUsers = "[]",
    String isNewVersion = "false",
    String existingDocumentId = "",
  }) async {
    try {
      print('📤 Starting single file upload...');
      print('📄 File: ${file.path}');
      print('📏 File size: ${file.lengthSync()} bytes');

      // Check authentication
      final isAuthenticated = await _isAuthenticatedForUpload();
      if (!isAuthenticated['authenticated']) {
        return {
          'success': false,
          'message': isAuthenticated['message'],
          'requiresLogin': true,
        };
      }

      final url = Uri.parse('$_baseUrl/upload');
      final request = http.MultipartRequest('POST', url);

      // Add session cookie to request
      final sessionCookie = await _getSessionCookie();
      if (sessionCookie != null) {
        request.headers['Cookie'] = 'session_id=$sessionCookie';
        print('🍪 Added session cookie to request');
      }

      // Add the file
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: file.path.split('/').last,
        contentType: MediaType('application', 'octet-stream'),
      );
      request.files.add(multipartFile);

      // Add form fields
      request.fields['keywords'] = keywords;
      request.fields['remarks'] = remarks;
      request.fields['doc_class'] = docClass;
      request.fields['allow_download'] = allowDownload.toString();
      request.fields['sharing'] = sharing;
      request.fields['folder_id'] = folderId;
      request.fields['specific_users'] = specificUsers;
      request.fields['is_new_version'] = isNewVersion;
      request.fields['existing_document_id'] = existingDocumentId;

      print('📦 Request fields: ${request.fields}');

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: $responseBody');

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Upload successful',
          'document_id': responseData['document_id'],
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        // Authentication error - clear invalid cookie
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
          'statusCode': 401,
          'requiresLogin': true,
        };
      } else {
        final responseData = json.decode(responseBody);
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Upload failed',
          'statusCode': response.statusCode,
          'data': responseData,
        };
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // ============ MULTIPLE FILES UPLOAD ============
  static Future<Map<String, dynamic>> uploadMultipleFiles({
    required List<File> files,
    required String keywords,
    required String remarks,
    required String docClass,
    required bool allowDownload,
    required String sharing,
    required String folderId,
    String specificUsers = "[]",
    bool preserveStructure = false,
  }) async {
    try {
      print('📤 Starting multiple files upload...');
      print('📦 Files count: ${files.length}');

      // Check authentication
      final isAuthenticated = await _isAuthenticatedForUpload();
      if (!isAuthenticated['authenticated']) {
        return {
          'success': false,
          'message': isAuthenticated['message'],
          'requiresLogin': true,
        };
      }

      final url = Uri.parse('$_baseUrl/upload-multiple');
      final request = http.MultipartRequest('POST', url);

      // Add session cookie to request
      final sessionCookie = await _getSessionCookie();
      if (sessionCookie != null) {
        request.headers['Cookie'] = 'session_id=$sessionCookie';
        print('🍪 Added session cookie to request');
      }

      // Add all files
      for (var file in files) {
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final multipartFile = http.MultipartFile(
          'files',
          fileStream,
          fileLength,
          filename: file.path.split('/').last,
          contentType: MediaType('application', 'octet-stream'),
        );
        request.files.add(multipartFile);
        print('➕ Added file: ${file.path.split('/').last}');
      }

      // Add form fields
      request.fields['keywords'] = keywords;
      request.fields['remarks'] = remarks;
      request.fields['doc_class'] = docClass;
      request.fields['allow_download'] = allowDownload.toString();
      request.fields['sharing'] = sharing;
      request.fields['folder_id'] = folderId;
      request.fields['specific_users'] = specificUsers;
      request.fields['preserve_structure'] = preserveStructure.toString();

      print('📦 Request fields: ${request.fields}');

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response body: $responseBody');

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Upload successful',
          'uploaded_files': responseData['uploaded_files'] ?? [],
          'failed_files': responseData['failed_files'] ?? [],
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        // Authentication error - clear invalid cookie
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
          'statusCode': 401,
          'requiresLogin': true,
        };
      } else {
        final responseData = json.decode(responseBody);
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Upload failed',
          'statusCode': response.statusCode,
          'data': responseData,
        };
      }
    } catch (e) {
      print('❌ Multiple upload error: $e');
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // ============ FOLDER UPLOAD (NEW) ============
  static Future<Map<String, dynamic>> uploadFolder({
    required String folderName,
    required List<File> files,
    required String keywords,
    required String remarks,
    required String docClass,
    required bool allowDownload,
    required String sharing,
    required String parentFolderId,
    String specificUsers = "[]",
  }) async {
    try {
      print('📤 Starting folder upload: $folderName');
      print('📦 Files count: ${files.length}');

      // Check authentication
      final isAuthenticated = await _isAuthenticatedForUpload();
      if (!isAuthenticated['authenticated']) {
        return {
          'success': false,
          'message': isAuthenticated['message'],
          'requiresLogin': true,
        };
      }

      // Step 1: Create the folder first
      final folderResult = await _createFolder(
        folderName: folderName,
        parentFolderId: parentFolderId,
      );

      if (folderResult['success'] != true) {
        return {
          'success': false,
          'message': 'Failed to create folder: ${folderResult['message']}',
        };
      }

      final newFolderId = folderResult['folderId']?.toString() ?? '';
      print('✅ Created folder with ID: $newFolderId');

      // Step 2: Upload files to the new folder
      final uploadResult = await uploadMultipleFiles(
        files: files,
        keywords: keywords,
        remarks: remarks,
        docClass: docClass,
        allowDownload: allowDownload,
        sharing: sharing,
        folderId: newFolderId,
        specificUsers: specificUsers,
        preserveStructure: true,
      );

      return {
        'success': uploadResult['success'],
        'message': uploadResult['message'],
        'folder_id': newFolderId,
        'uploaded_files': uploadResult['uploaded_files'] ?? [],
        'failed_files': uploadResult['failed_files'] ?? [],
      };
    } catch (e) {
      print('❌ Folder upload error: $e');
      return {'success': false, 'message': 'Folder upload error: $e'};
    }
  }

  // ============ CREATE FOLDER ============
  static Future<Map<String, dynamic>> _createFolder({
    required String folderName,
    required String parentFolderId,
  }) async {
    try {
      print('📁 Creating folder: $folderName (Parent: $parentFolderId)');

      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/folders');

      final response = await http.post(
        url,
        headers: headers,
        body: {
          'name': folderName,
          'parent_id': parentFolderId.isEmpty ? '' : parentFolderId,
        },
      );

      print('📡 Create folder response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'folderId': data['id']?.toString(),
          'message': 'Folder created successfully',
        };
      } else if (response.statusCode == 401) {
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create folder (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ Create folder error: $e');
      return {'success': false, 'message': 'Create folder error: $e'};
    }
  }

  // ============ TEST UPLOAD CONNECTION ============
  static Future<Map<String, dynamic>> testUploadConnection() async {
    try {
      print('🧪 Testing upload connection...');

      // Check authentication first
      final isAuthenticated = await _isAuthenticatedForUpload();
      if (!isAuthenticated['authenticated']) {
        return {
          'success': false,
          'message': isAuthenticated['message'],
          'requiresLogin': true,
        };
      }

      // Create a dummy file for testing
      final tempFile = File('${Directory.systemTemp.path}/test_upload.txt');
      await tempFile.writeAsString('Test upload file content');

      final url = Uri.parse('$_baseUrl/upload');
      final request = http.MultipartRequest('POST', url);

      // Add session cookie to request
      final sessionCookie = await _getSessionCookie();
      if (sessionCookie != null) {
        request.headers['Cookie'] = 'session_id=$sessionCookie';
        print('🍪 Added session cookie to request');
      }

      // Add dummy file
      final fileStream = http.ByteStream(tempFile.openRead());
      final fileLength = await tempFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'test_upload.txt',
        contentType: MediaType('text', 'plain'),
      );
      request.files.add(multipartFile);

      // Add dummy form fields
      request.fields['keywords'] = 'test,upload';
      request.fields['remarks'] = 'Test upload connection';
      request.fields['doc_class'] = 'General';
      request.fields['allow_download'] = 'true';
      request.fields['sharing'] = 'private';
      request.fields['folder_id'] = '';
      request.fields['specific_users'] = '[]';
      request.fields['is_new_version'] = 'false';
      request.fields['existing_document_id'] = '';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Clean up temp file
      await tempFile.delete();

      print('📡 Test response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Upload connection successful',
          'statusCode': response.statusCode,
        };
      } else if (response.statusCode == 401) {
        await ApiService.clearSessionCookie();
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
          'statusCode': 401,
          'requiresLogin': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Upload test failed (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Test upload error: $e');
      return {'success': false, 'message': 'Test failed: $e'};
    }
  }

  // ============ PRIVATE HELPER METHODS ============

  // Check if user is authenticated for upload
  static Future<Map<String, dynamic>> _isAuthenticatedForUpload() async {
    final cookie = await _getSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      return {
        'authenticated': false,
        'message': 'Not logged in. Please login first.',
      };
    }
    return {'authenticated': true, 'message': 'Authenticated'};
  }

  // Get auth headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    final cookie = await _getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = 'session_id=$cookie';
    }

    return headers;
  }
}
