// lib/services/profile_service.dart
import 'dart:convert';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ProfileService {
  static const String _profileEndpoint = '/user/profile';

  // Get user profile data
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      if (!ApiService.isConnected) {
        return {'success': false, 'message': 'No internet connection'};
      }

      final url = Uri.parse('${ApiService.baseUrl}$_profileEndpoint');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (kDebugMode) {
        print('📡 Profile response status: ${response.statusCode}');
        print('📦 Profile response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {'success': true, 'data': responseData};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication required',
          'statusCode': 401,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? 'Failed to fetch profile',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching profile: $e');
      }
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Helper method to get authentication headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final cookie = await ApiService.getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$cookie';
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Could not get session cookie for profile: $e');
      }
    }

    return headers;
  }
}
