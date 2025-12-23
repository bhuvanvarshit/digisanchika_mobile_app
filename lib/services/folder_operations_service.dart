// lib/services/folder_operations_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/models/folder_tree_node.dart';

class FolderOperationsService {
  // Singleton pattern
  static final FolderOperationsService _instance =
      FolderOperationsService._internal();
  factory FolderOperationsService() => _instance;
  FolderOperationsService._internal();

  /// Create a new folder
  Future<Map<String, dynamic>> createFolder({
    required String name,
    int? parentId,
  }) async {
    try {
      // Validate folder name first
      final validation = validateFolderName(name);
      if (!validation['valid']) {
        return {
          'success': false,
          'error': validation['error'],
        };
      }

      if (kDebugMode) {
        print('📁 Creating folder: $name (parent: $parentId)');
      }

      // Get auth headers
      final headers = await _createAuthHeaders();

      // Make API request
      final response = await http.post(
        Uri.parse('${ApiService.currentBaseUrl}/folders'),
        headers: headers,
        body: {
          'name': name,
          'parent_id': parentId?.toString() ?? '',
        },
      );

      if (kDebugMode) {
        print('📡 Create folder response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('✅ Folder created successfully: ${data['folder_id']}');
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Folder created successfully',
          'folder_id': data['folder_id'],
          'folder': FolderTreeNode(
            id: data['folder_id'] as int,
            name: name,
            parentId: parentId,
            createdAt: DateTime.now(),
            owner: 'Current User',
          ),
        };
      } else if (response.statusCode == 400) {
        // Duplicate folder or validation error
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['detail'] ?? 'Folder already exists',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'requiresLogin': true,
        };
      } else if (response.statusCode == 503) {
        return {
          'success': false,
          'error': 'Folder functionality not available',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create folder (${response.statusCode})',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating folder: $e');
      }
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Delete a folder
  Future<Map<String, dynamic>> deleteFolder(int folderId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting folder: $folderId');
      }

      // Get auth headers
      final headers = await _createAuthHeaders();

      // Make API request
      final response = await http.delete(
        Uri.parse('${ApiService.currentBaseUrl}/folders/$folderId'),
        headers: headers,
      );

      if (kDebugMode) {
        print('📡 Delete folder response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('✅ Folder deleted successfully');
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Folder deleted successfully',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Folder not found or already deleted',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'requiresLogin': true,
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'You do not have permission to delete this folder',
        };
      } else if (response.statusCode == 503) {
        return {
          'success': false,
          'error': 'Folder functionality not available',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete folder (${response.statusCode})',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting folder: $e');
      }
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Validate folder name
  Map<String, dynamic> validateFolderName(String name) {
    // Trim whitespace
    final trimmedName = name.trim();

    // Check if empty
    if (trimmedName.isEmpty) {
      return {
        'valid': false,
        'error': 'Folder name cannot be empty',
      };
    }

    // Check length (1-100 characters)
    if (trimmedName.length > 100) {
      return {
        'valid': false,
        'error': 'Folder name too long (max 100 characters)',
      };
    }

    // Check for invalid characters: < > : " / \ | ? *
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(trimmedName)) {
      return {
        'valid': false,
        'error': 'Folder name contains invalid characters',
      };
    }

    // Check for reserved names (Windows-style)
    final reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'LPT1',
      'LPT2',
      'LPT3',
    ];
    if (reservedNames.contains(trimmedName.toUpperCase())) {
      return {
        'valid': false,
        'error': 'This is a reserved folder name',
      };
    }

    // Check for leading/trailing dots or spaces
    if (trimmedName.startsWith('.') || 
        trimmedName.endsWith('.') ||
        trimmedName.startsWith(' ') || 
        trimmedName.endsWith(' ')) {
      return {
        'valid': false,
        'error': 'Folder name cannot start or end with dots or spaces',
      };
    }

    return {
      'valid': true,
      'cleanName': trimmedName,
    };
  }

  /// Sanitize folder name (remove invalid characters)
  String sanitizeFolderName(String name) {
    String sanitized = name.trim();
    
    // Replace invalid characters with underscore
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    // Remove leading/trailing dots and spaces
    sanitized = sanitized.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
    
    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    
    return sanitized;
  }

  /// Check if folder name is available at a specific location
  Future<bool> isNameAvailable({
    required String name,
    int? parentId,
    required List<FolderTreeNode> existingFolders,
  }) async {
    try {
      // Get folders at the same level
      final siblingFolders = existingFolders.where((folder) {
        return folder.parentId == parentId;
      }).toList();

      // Check for duplicate names (case-insensitive)
      final lowerName = name.toLowerCase().trim();
      for (var folder in siblingFolders) {
        if (folder.name.toLowerCase().trim() == lowerName) {
          return false; // Name already exists
        }
      }

      return true; // Name is available
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking name availability: $e');
      }
      return true; // Assume available on error
    }
  }

  /// Get folder info by ID
  Future<Map<String, dynamic>> getFolderInfo(int folderId) async {
    try {
      final headers = await _createAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiService.currentBaseUrl}/folders/$folderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'folder': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get folder info',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting folder info: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create auth headers
  Future<Map<String, String>> _createAuthHeaders() async {
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
      if (kDebugMode) {
        print('⚠️ Could not get session cookie: $e');
      }
    }

    return headers;
  }

  /// Batch create folders (for import/migration)
  Future<Map<String, dynamic>> batchCreateFolders(
    List<Map<String, dynamic>> folders,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    final errors = <String>[];

    for (var folderData in folders) {
      final result = await createFolder(
        name: folderData['name'] as String,
        parentId: folderData['parent_id'] as int?,
      );

      if (result['success'] == true) {
        successCount++;
      } else {
        failureCount++;
        errors.add('${folderData['name']}: ${result['error']}');
      }
    }

    return {
      'success': failureCount == 0,
      'total': folders.length,
      'success_count': successCount,
      'failure_count': failureCount,
      'errors': errors,
    };
  }
}
