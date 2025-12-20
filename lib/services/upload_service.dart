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

  // ============ MIME TYPE HELPERS ============
  static MediaType? _getMediaTypeForFile(File file) {
    final fileName = file.path.split('/').last.toLowerCase();
    final extension = fileName.split('.').last;

    // Document types (from your original list)
    switch (extension) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case 'ppt':
        return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      case 'txt':
        return MediaType('text', 'plain');

      // Image types (added for image support)
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'webp':
        return MediaType('image', 'webp');
      case 'svg':
        return MediaType('image', 'svg+xml');
      case 'tiff':
      case 'tif':
        return MediaType('image', 'tiff');
      case 'ico':
        return MediaType('image', 'x-icon');

      // Audio types
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'wav':
        return MediaType('audio', 'wav');
      case 'ogg':
        return MediaType('audio', 'ogg');
      case 'm4a':
        return MediaType('audio', 'mp4');
      case 'flac':
        return MediaType('audio', 'flac');

      // Video types
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'avi':
        return MediaType('video', 'x-msvideo');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'wmv':
        return MediaType('video', 'x-ms-wmv');
      case 'flv':
        return MediaType('video', 'x-flv');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'webm':
        return MediaType('video', 'webm');

      // Archive types
      case 'zip':
        return MediaType('application', 'zip');
      case 'rar':
        return MediaType('application', 'x-rar-compressed');
      case '7z':
        return MediaType('application', 'x-7z-compressed');
      case 'tar':
        return MediaType('application', 'x-tar');
      case 'gz':
        return MediaType('application', 'gzip');

      // Code/Text files
      case 'html':
      case 'htm':
        return MediaType('text', 'html');
      case 'css':
        return MediaType('text', 'css');
      case 'js':
        return MediaType('text', 'javascript');
      case 'json':
        return MediaType('application', 'json');
      case 'xml':
        return MediaType('application', 'xml');
      case 'csv':
        return MediaType('text', 'csv');

      // In UploadService._getMediaTypeForFile method, add Google Drive file support:

      case 'gdoc':
        return MediaType('application', 'vnd.google-apps.document');
      case 'gsheet':
        return MediaType('application', 'vnd.google-apps.spreadsheet');
      case 'gslides':
        return MediaType('application', 'vnd.google-apps.presentation');
      case 'gdraw':
        return MediaType('application', 'vnd.google-apps.drawing');
      case 'gform':
        return MediaType('application', 'vnd.google-apps.form');
      case 'gscript':
        return MediaType('application', 'vnd.google-apps.script');
      case 'gjam':
        return MediaType('application', 'vnd.google-apps.jam');
      case 'gsite':
        return MediaType('application', 'vnd.google-apps.site');
      case 'gtable':
        return MediaType('application', 'vnd.google-apps.table');

      // Also add Apple iWork file support (seen in your code):
      case 'pages':
        return MediaType('application', 'vnd.apple.pages');
      case 'numbers':
        return MediaType('application', 'vnd.apple.numbers');
      case 'key':
        return MediaType('application', 'vnd.apple.keynote');

      // Add OpenDocument format support:
      case 'odt':
        return MediaType('application', 'vnd.oasis.opendocument.text');
      case 'ods':
        return MediaType('application', 'vnd.oasis.opendocument.spreadsheet');
      case 'odp':
        return MediaType('application', 'vnd.oasis.opendocument.presentation');
      case 'odg':
        return MediaType('application', 'vnd.oasis.opendocument.graphics');
      case 'odf':
        return MediaType('application', 'vnd.oasis.opendocument.formula');

      default:
        // Fallback to octet-stream for unknown types
        if (kDebugMode) {
          print('⚠️ Unknown file extension: .$extension, using octet-stream');
        }
        return MediaType('application', 'octet-stream');
    }
  }

  // Updated to allow all file types
  static bool _isFileTypeAllowed(String fileName) {
    // Allow all file types for now (you can add restrictions if needed)

    // If you want to restrict to specific types only, use this:

    final extension = fileName.split('.').last.toLowerCase();
    final allowedExtensions = [
      // Documents
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
      // Images
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff', 'tif',
      // Audio
      'mp3', 'wav', 'ogg', 'm4a', 'flac',
      // Video
      'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm',
      // Archives
      'zip', 'rar', '7z', 'tar', 'gz',
      // Code/Text
      'html', 'htm', 'css', 'js', 'json', 'xml', 'csv',
    ];
    return allowedExtensions.contains(extension);
  }

  // Validate file before upload
  static Map<String, dynamic> _validateFileForUpload(File file) {
    final fileName = file.path.split('/').last;

    // Skip validation for Google Drive files since they're small
    final extension = fileName.split('.').last.toLowerCase();
    if (['gdoc', 'gsheet', 'gslides', 'gdraw'].contains(extension)) {
      return {
        'valid': true,
        'fileName': fileName,
        'fileSize': file.lengthSync(),
        'mediaType': _getMediaTypeForFile(file),
      };
    }
    // Check file type
    if (!_isFileTypeAllowed(fileName)) {
      return {'valid': false, 'message': 'File type not allowed: $fileName'};
    }

    // Check file size (500MB limit)
    final fileSize = file.lengthSync();
    if (fileSize > 500 * 1024 * 1024) {
      return {'valid': false, 'message': 'File exceeds 500MB limit: $fileName'};
    }

    // Check if file exists and is readable
    if (!file.existsSync()) {
      return {'valid': false, 'message': 'File does not exist: $fileName'};
    }

    return {
      'valid': true,
      'fileName': fileName,
      'fileSize': fileSize,
      'mediaType': _getMediaTypeForFile(file),
    };
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
      if (kDebugMode) {
        print('📤 Starting single file upload...');
      }

      // Validate file first
      final validation = _validateFileForUpload(file);
      if (!validation['valid']) {
        return {'success': false, 'message': validation['message']};
      }

      final fileName = validation['fileName'];
      final mediaType = validation['mediaType'] as MediaType?;

      if (kDebugMode) {
        print('📄 File: $fileName');
        print('📏 File size: ${validation['fileSize']} bytes');
        print('📝 MIME Type: ${mediaType?.mimeType}');
      }

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
        if (kDebugMode) {
          print('🍪 Added session cookie to request');
        }
      }

      // Add the file with proper MIME type
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: mediaType, // Use proper MIME type
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

      if (kDebugMode) {
        print('📦 Request fields: ${request.fields}');
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('📦 Response body: $responseBody');
      }

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
      if (kDebugMode) {
        print('❌ Upload error: $e');
      }
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
      if (kDebugMode) {
        print('📤 Starting multiple files upload...');
      }
      if (kDebugMode) {
        print('📦 Files count: ${files.length}');
      }

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
        if (kDebugMode) {
          print('🍪 Added session cookie to request');
        }
      }

      // Add all files with proper MIME types
      for (var file in files) {
        final validation = _validateFileForUpload(file);
        if (!validation['valid']) {
          if (kDebugMode) {
            print('❌ Skipping invalid file: ${validation['message']}');
          }
          continue;
        }

        final fileName = validation['fileName'];
        final mediaType = validation['mediaType'] as MediaType?;

        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final multipartFile = http.MultipartFile(
          'files',
          fileStream,
          fileLength,
          filename: fileName,
          contentType: mediaType, // Use proper MIME type
        );
        request.files.add(multipartFile);
        if (kDebugMode) {
          print('➕ Added file: $fileName (${mediaType?.mimeType})');
        }
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

      if (kDebugMode) {
        print('📦 Request fields: ${request.fields}');
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('📦 Response body: $responseBody');
      }

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
      if (kDebugMode) {
        print('❌ Multiple upload error: $e');
      }
      return {'success': false, 'message': 'Upload error: $e'};
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
    final headers = <String, String>{'Accept': 'application/json'};

    final cookie = await _getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = 'session_id=$cookie';
    }

    return headers;
  }
}
