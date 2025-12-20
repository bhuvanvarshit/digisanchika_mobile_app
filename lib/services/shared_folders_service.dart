// services/shared_folders_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/models/shared_folder.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:flutter/material.dart';

class SharedFoldersService {
  /// Fetches shared folders from the backend
  // services/shared_folders_service.dart - Updated fetchSharedFolders method
  Future<List<SharedFolder>> fetchSharedFolders() async {
    try {
      // Check internet connection
      if (!ApiService.isConnected) {
        debugPrint('No internet connection available');
        throw Exception('No internet connection. Please check your network.');
      }

      // Get authentication headers
      final headers = await _getAuthHeaders();

      // API endpoint for shared folders - try different endpoints
      final endpoints = [
        '${ApiService.currentBaseUrl}/shared-folders',
        '${ApiService.currentBaseUrl}/shared/folders',
        '${ApiService.currentBaseUrl}/folders/shared',
        '${ApiService.currentBaseUrl}/documents/shared-folders',
      ];

      http.Response? response;
      String usedEndpoint = '';

      // Try each endpoint until one works
      for (final endpoint in endpoints) {
        try {
          usedEndpoint = endpoint;
          final url = Uri.parse(endpoint);

          developer.log(
            '🔗 Trying to fetch shared folders from: $endpoint',
            name: 'SharedFoldersService',
          );

          response = await http
              .get(url, headers: headers)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException('Request timed out');
                },
              );

          // If we get a 200 response, break out of the loop
          if (response.statusCode == 200) {
            developer.log(
              '✅ Found working endpoint: $endpoint',
              name: 'SharedFoldersService',
            );
            break;
          }
        } catch (e) {
          developer.log(
            '⚠️ Endpoint $endpoint failed: $e',
            name: 'SharedFoldersService',
          );
          continue; // Try next endpoint
        }
      }

      // Check if we got a response
      if (response == null) {
        throw Exception('Could not connect to shared folders API');
      }

      developer.log(
        '📡 Response status: ${response.statusCode} from $usedEndpoint',
        name: 'SharedFoldersService',
      );

      if (response.statusCode == 200) {
        final dynamic responseBody = json.decode(response.body);

        List<dynamic> foldersData;

        // Handle different possible response formats
        if (responseBody is Map<String, dynamic>) {
          final Map<String, dynamic> responseData = responseBody;

          if (responseData.containsKey('folders')) {
            foldersData = responseData['folders'] ?? [];
          } else if (responseData.containsKey('data')) {
            final data = responseData['data'];
            foldersData = data is List ? data : [];
          } else if (responseData.containsKey('shared_folders')) {
            foldersData = responseData['shared_folders'] ?? [];
          } else {
            // Try to find any array in the response
            final dynamicValues = responseData.values
                .where((value) => value is List)
                .toList();
            if (dynamicValues.isNotEmpty) {
              foldersData = dynamicValues.first as List<dynamic>;
            } else {
              // No folders found in response
              developer.log(
                '⚠️ No folders found in response, returning empty list',
                name: 'SharedFoldersService',
              );
              return [];
            }
          }
        } else if (responseBody is List) {
          // Direct array response
          foldersData = responseBody;
        } else {
          // Unknown response format
          developer.log(
            '⚠️ Unknown response format: ${responseBody.runtimeType}',
            name: 'SharedFoldersService',
          );
          return [];
        }

        developer.log(
          '✅ Parsing ${foldersData.length} shared folders',
          name: 'SharedFoldersService',
        );

        // Parse folders using your existing model
        final List<SharedFolder> folders = [];
        for (var folderData in foldersData) {
          try {
            if (folderData is Map<String, dynamic>) {
              final folder = SharedFolder.fromJson(folderData);
              folders.add(folder);
            } else if (folderData is String) {
              // Handle simple string folder names
              final folder = SharedFolder(
                id: folderData.hashCode.toString(),
                name: folderData,
                owner: 'Unknown User',
                createdAt: DateTime.now().toString(),
              );
              folders.add(folder);
            }
          } catch (e) {
            developer.log(
              '⚠️ Error parsing folder: $e - Data: $folderData',
              name: 'SharedFoldersService',
            );
          }
        }

        return folders;
      } else if (response.statusCode == 401) {
        // Authentication failed
        developer.log(
          '🔐 Authentication failed - clearing session',
          name: 'SharedFoldersService',
        );
        await ApiService.clearSessionCookie();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to view shared folders');
      } else if (response.statusCode == 404) {
        // API endpoint not found - return empty list
        developer.log(
          '⚠️ Shared folders endpoint not found (404), returning empty list',
          name: 'SharedFoldersService',
        );
        return [];
      } else {
        developer.log(
          '❌ Failed to fetch shared folders: ${response.statusCode}',
          name: 'SharedFoldersService',
        );
        developer.log(
          '❌ Response body: ${response.body}',
          name: 'SharedFoldersService',
        );

        // Try to parse error message
        String errorMessage = 'Failed to load shared folders';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic>) {
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'].toString();
            } else if (errorData.containsKey('error')) {
              errorMessage = errorData['error'].toString();
            }
          }
        } catch (e) {
          // Ignore parsing error
        }

        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } on SocketException catch (e) {
      developer.log('🌐 Network error: $e', name: 'SharedFoldersService');
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException catch (e) {
      developer.log('⏰ Request timeout: $e', name: 'SharedFoldersService');
      throw Exception('Request timed out. Please try again.');
    } on HttpException catch (e) {
      developer.log('🔗 HTTP error: $e', name: 'SharedFoldersService');
      throw Exception('Server error. Please try again later.');
    } on FormatException catch (e) {
      developer.log('📝 JSON format error: $e', name: 'SharedFoldersService');
      throw Exception('Invalid response from server.');
    } catch (e) {
      developer.log('❌ Unexpected error: $e', name: 'SharedFoldersService');
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Fetches contents of a specific shared folder
  Future<Map<String, dynamic>> fetchSharedFolderContents(
    String folderId, {
    String? searchQuery,
    String? sortBy = 'name',
    String? order = 'asc',
  }) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'error': 'No internet connection',
          'message': 'Please check your internet connection',
        };
      }

      final headers = await _getAuthHeaders();

      // Build query parameters
      final Map<String, String> queryParams = {
        'folder_id': folderId,
        'sort_by': sortBy!,
        'order': order!,
      };

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      // Try different endpoints
      final endpoints = [
        '${ApiService.currentBaseUrl}/shared-folder-contents',
        '${ApiService.currentBaseUrl}/shared/folders/$folderId/contents',
        '${ApiService.currentBaseUrl}/folders/shared/$folderId/contents',
      ];

      http.Response? response;
      String? errorMessage;

      for (final endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint).replace(queryParameters: queryParams);

          developer.log(
            '🔗 Trying to fetch folder contents from: $endpoint',
            name: 'SharedFoldersService',
          );

          response = await http
              .get(url, headers: headers)
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = json.decode(
              response.body,
            );

            // Handle different response formats
            Map<String, dynamic> result = {
              'success': true,
              'documents': [],
              'subfolders': [],
              'folder': {},
              'message': 'Folder contents loaded successfully',
            };

            if (responseData.containsKey('documents')) {
              result['documents'] = responseData['documents'] ?? [];
            } else if (responseData.containsKey('files')) {
              result['documents'] = responseData['files'] ?? [];
            }

            if (responseData.containsKey('subfolders')) {
              result['subfolders'] = responseData['subfolders'] ?? [];
            } else if (responseData.containsKey('folders')) {
              result['subfolders'] = responseData['folders'] ?? [];
            }

            if (responseData.containsKey('folder')) {
              result['folder'] = responseData['folder'] ?? {};
            }

            return result;
          } else if (response.statusCode == 404) {
            continue; // Try next endpoint
          } else {
            errorMessage = 'Failed with status: ${response.statusCode}';
            break;
          }
        } catch (e) {
          developer.log('⚠️ Endpoint failed: $e', name: 'SharedFoldersService');
          continue;
        }
      }

      // If all endpoints failed, return error
      return {
        'success': false,
        'error': errorMessage ?? 'All endpoints failed',
        'message': 'Unable to fetch folder contents',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timeout',
        'message': 'Request timed out. Please try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'error': 'No internet connection',
        'message': 'Please check your internet connection',
      };
    } catch (e) {
      developer.log(
        '❌ Error fetching folder contents: $e',
        name: 'SharedFoldersService',
      );
      return {
        'success': false,
        'error': e.toString(),
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Gets detailed information about a shared folder
  Future<Map<String, dynamic>> getSharedFolderDetails(String folderId) async {
    try {
      if (!ApiService.isConnected) {
        return {
          'success': false,
          'error': 'No internet connection',
          'message': 'Please check your internet connection',
        };
      }

      final headers = await _getAuthHeaders();

      // Try different endpoints
      final endpoints = [
        '${ApiService.currentBaseUrl}/shared-folders/$folderId/details',
        '${ApiService.currentBaseUrl}/shared/folders/$folderId',
        '${ApiService.currentBaseUrl}/folders/$folderId/details',
      ];

      for (final endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);

          developer.log(
            '🔗 Getting folder details from: $endpoint',
            name: 'SharedFoldersService',
          );

          final response = await http.get(url, headers: headers);

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = json.decode(
              response.body,
            );

            return {
              'success': true,
              'data': responseData,
              'message': 'Folder details retrieved',
            };
          } else if (response.statusCode == 404) {
            continue; // Try next endpoint
          }
        } catch (e) {
          developer.log('⚠️ Endpoint failed: $e', name: 'SharedFoldersService');
          continue;
        }
      }

      return {
        'success': false,
        'error': 'Folder not found',
        'message': 'Could not retrieve folder details',
      };
    } catch (e) {
      developer.log(
        '❌ Error getting folder details: $e',
        name: 'SharedFoldersService',
      );
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error getting folder details',
      };
    }
  }

  /// Helper method to get authentication headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Get session cookie
    final cookie = await ApiService.getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = 'session_id=$cookie';
      debugPrint('🍪 Adding session cookie to headers');
    }

    return headers;
  }

  /// Refresh shared folders data
  Future<List<SharedFolder>> refreshSharedFolders() async {
    debugPrint('🔄 Refreshing shared folders...');
    return await fetchSharedFolders();
  }

  /// Search shared folders by name or owner
  Future<List<SharedFolder>> searchSharedFolders(String query) async {
    try {
      if (!ApiService.isConnected) {
        throw Exception('No internet connection');
      }

      final folders = await fetchSharedFolders();
      if (query.isEmpty) {
        return folders;
      }

      final lowercaseQuery = query.toLowerCase();
      return folders.where((folder) {
        return folder.name.toLowerCase().contains(lowercaseQuery) ||
            folder.owner.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      developer.log(
        '❌ Error searching shared folders: $e',
        name: 'SharedFoldersService',
      );
      throw Exception('Error searching shared folders: ${e.toString()}');
    }
  }

  /// Gets statistics about shared folders
  Future<Map<String, dynamic>> getSharedFolderStats() async {
    try {
      final folders = await fetchSharedFolders();

      return {
        'success': true,
        'stats': {
          'total_folders': folders.length,
          'recent_folders': folders.take(5).toList(),
          'folders_by_owner': _groupFoldersByOwner(folders),
        },
        'message': 'Statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get statistics',
      };
    }
  }

  /// Helper method to group folders by owner
  Map<String, int> _groupFoldersByOwner(List<SharedFolder> folders) {
    final Map<String, int> ownerCount = {};

    for (final folder in folders) {
      ownerCount[folder.owner] = (ownerCount[folder.owner] ?? 0) + 1;
    }

    return ownerCount;
  }
}
