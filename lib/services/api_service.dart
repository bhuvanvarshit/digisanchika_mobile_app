// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:core';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Static variables - Your remote server URL
  static String _currentBaseUrl = 'http://172.105.62.238:8000';
  static bool _isConnected = false;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Get current base URL
  static String get currentBaseUrl => _currentBaseUrl;
  static bool get isConnected => _isConnected;
  static String get baseUrl => _currentBaseUrl;

  static void setBaseUrl(String url) {
    _currentBaseUrl = url;
    if (kDebugMode) {
      print('Base URL changed to: $url');
    }
  }

  // ==================== COOKIE MANAGEMENT ====================

  // Store session cookie after login
  static Future<void> storeSessionCookie(String cookie) async {
    // Extract just the session_id value from cookie string
    final sessionMatch = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
    if (sessionMatch != null) {
      final sessionId = sessionMatch.group(1)!;
      await _secureStorage.write(key: 'session_cookie', value: sessionId);
      if (kDebugMode) {
        print('✅ Session cookie stored: $sessionId');
      }
    } else {
      // If no session_id found, store the whole cookie
      await _secureStorage.write(key: 'session_cookie', value: cookie);
      if (kDebugMode) {
        print('✅ Raw cookie stored: $cookie');
      }
    }
  }

  // Get session cookie
  static Future<String?> getSessionCookie() async {
    return await _secureStorage.read(key: 'session_cookie');
  }

  // Clear session cookie on logout
  static Future<void> clearSessionCookie() async {
    await _secureStorage.delete(key: 'session_cookie');
    if (kDebugMode) {
      print('✅ Session cookie cleared');
    }
  }

  // Check if user is logged in (has session cookie)
  static Future<bool> isLoggedIn() async {
    final cookie = await getSessionCookie();
    return cookie != null && cookie.isNotEmpty;
  }

  // Get headers with cookie for authenticated requests - SINGLE VERSION
  static Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final cookie = await getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookie';
        if (kDebugMode) {
          print('🍪 Adding session cookie to headers');
        }
      }
    }

    return headers;
  }

  // ==================== CONNECTION METHODS ====================

  static Future<void> initialize() async {
    try {
      final response = await http
          .get(Uri.parse('$_currentBaseUrl/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isConnected = true;
        if (kDebugMode) {
          print('✓ Backend connected at: $_currentBaseUrl');
        }
      } else {
        _isConnected = false;
        if (kDebugMode) {
          print('⚠ Backend returned ${response.statusCode}');
        }
      }
    } catch (e) {
      _isConnected = false;
      if (kDebugMode) {
        print('Backend connection failed: $e');
      }
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_currentBaseUrl/'))
          .timeout(const Duration(seconds: 5));

      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // ==================== AUTH API METHODS ====================

  static Future<Map<String, dynamic>> login(
    String employeeId,
    String password,
  ) async {
    try {
      print('🔐 Login API: $_currentBaseUrl/login');
      print('👤 Employee ID: $employeeId');
      print('🔑 Password: $password');

      final url = Uri.parse('$_currentBaseUrl/login');
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };

      final body =
          'employee_id=${Uri.encodeComponent(employeeId)}&password=${Uri.encodeComponent(password)}';
      print('📦 Form Body: $body');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      // Check for session cookie
      final cookies = response.headers['set-cookie'];
      if (cookies != null) {
        print('🍪 Session cookie received: $cookies');
        // Store the cookie for future authenticated requests
        await storeSessionCookie(cookies);
      } else {
        print('⚠ No session cookie received from server');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'Login successful',
          'data': responseData,
          'cookies': cookies,
        };
      } else if (response.statusCode == 401) {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Invalid credentials',
          'statusCode': 401,
          'data': responseData,
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['detail']?.toString() ?? 'Login failed',
          'statusCode': response.statusCode,
          'data': responseData,
        };
      }
    } on TimeoutException {
      print('⏰ Request timeout');
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
      };
    } on SocketException {
      print('🌐 Network error');
      return {
        'success': false,
        'message': 'Network error. Check your internet connection.',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Logout method
  static Future<Map<String, dynamic>> logout() async {
    try {
      final url = Uri.parse('$_currentBaseUrl/logout');
      final headers = await _getHeaders(includeAuth: true);

      final response = await http
          .post(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      // Clear local session cookie regardless of server response
      await clearSessionCookie();

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Logout successful'};
      } else {
        return {
          'success': false,
          'message': 'Logout failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      // Still clear cookie even if network error
      await clearSessionCookie();
      return {'success': false, 'message': 'Error during logout: $e'};
    }
  }

  // ==================== DOCUMENT API METHODS ====================

  static Future<List<Document>> fetchDocuments({bool isPublic = false}) async {
    if (!_isConnected) {
      return LocalStorageService.loadDocuments(isPublic: isPublic);
    }

    try {
      final url = Uri.parse('$_currentBaseUrl/api/documents');
      final headers = await _getHeaders(includeAuth: true);

      final response = await http.get(url, headers: headers);
      print('📡 Fetch documents status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('status') &&
            responseData['status'] == 'success' &&
            responseData.containsKey('documents')) {
          final List<dynamic> documentsData = responseData['documents'];

          try {
            final List<Document> documents = documentsData
                .map((docJson) => Document.fromJson(docJson))
                .toList();

            await LocalStorageService.saveDocuments(
              documents,
              isPublic: isPublic,
            );

            if (kDebugMode) {
              print('Fetched ${documents.length} documents from API');
            }
            return documents;
          } catch (e) {
            if (kDebugMode) {
              print('Using manual document creation: $e');
            }

            final List<Document> documents = documentsData.map((docJson) {
              return Document(
                id:
                    (docJson['id'] ??
                            DateTime.now().millisecondsSinceEpoch.toString())
                        .toString(),
                name:
                    (docJson['original_name'] ??
                            docJson['filename'] ??
                            'Document')
                        .toString(),
                type: (docJson['file_type'] ?? 'unknown').toString(),
                size: (docJson['size']?.toString() ?? '0'),
                keyword: (docJson['tags'] ?? '').toString(),
                uploadDate:
                    docJson['upload_date']?.toString() ??
                    DateTime.now().toString(),
                owner: '',
                details: '',
                classification: (docJson['category'] ?? 'General').toString(),
                allowDownload: true,
                sharingType: 'private',
                folder: 'General',
                path: (docJson['filename'] ?? '').toString(),
                fileType: (docJson['file_type'] ?? 'unknown').toString(),
              );
            }).toList();

            await LocalStorageService.saveDocuments(
              documents,
              isPublic: isPublic,
            );
            return documents;
          }
        }
      } else if (response.statusCode == 401) {
        print('⚠ Authentication required for fetching documents');
        // Clear invalid session cookie
        await clearSessionCookie();
      }
      return LocalStorageService.loadDocuments(isPublic: isPublic);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching documents: $e');
      }
      return LocalStorageService.loadDocuments(isPublic: isPublic);
    }
  }

  // ==================== FOLDER API METHODS ====================

  static Future<List<Map<String, dynamic>>> getMyFolders() async {
    try {
      print('📁 Fetching user folders...');

      if (!_isConnected) {
        // Return empty list if offline
        print('⚠ Offline - cannot fetch folders');
        return [];
      }

      final url = Uri.parse('$_currentBaseUrl/my-folders');
      final headers = await _getHeaders(includeAuth: true);

      final response = await http.get(url, headers: headers);

      print('📡 Get folders status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        print('📁 Found ${responseData.length} folders');

        // Convert to List<Map<String, dynamic>>
        return List<Map<String, dynamic>>.from(responseData);
      } else if (response.statusCode == 401) {
        // Authentication error
        print('⚠ Authentication required for folders');
        await clearSessionCookie();
        return [];
      } else {
        print('⚠ Failed to fetch folders: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching folders: $e');
      return [];
    }
  }

  // Test authenticated connection
  static Future<Map<String, dynamic>> testAuthConnection() async {
    try {
      final url = Uri.parse('$_currentBaseUrl/api/test-auth');
      final headers = await _getHeaders(includeAuth: true);

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'authenticated': response.statusCode != 401,
        'message': response.statusCode == 200
            ? 'Authenticated successfully'
            : 'Authentication failed (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection test failed: $e'};
    }
  }

  // ==================== NEW METHOD: Fetch My Documents ====================
  // This method will be used by MyDocumentsService
  static Future<Map<String, dynamic>> fetchMyDocumentsFromBackend({
    int? folderId,
  }) async {
    try {
      if (!_isConnected) {
        return {
          'success': false,
          'error': 'Offline mode',
          'documents': [],
          'folders': [],
        };
      }

      // Build URL
      String url = '$_currentBaseUrl/my-documents';
      if (folderId != null) {
        url += '?folder_id=$folderId';
      }

      final headers = await _getHeaders(includeAuth: true);
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'success': true,
          'documents': data['documents'] ?? [],
          'folders': data['folders'] ?? [],
        };
      } else if (response.statusCode == 401) {
        await clearSessionCookie();
        return {
          'success': false,
          'error': 'Authentication required',
          'documents': [],
          'folders': [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch documents (${response.statusCode})',
          'documents': [],
          'folders': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'documents': [],
        'folders': [],
      };
    }
  }
}
