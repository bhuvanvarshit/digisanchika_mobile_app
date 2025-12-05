// lib/services/folder_helper.dart
import 'package:digi_sanchika/services/api_service.dart';

class FolderHelper {
  // Get all folders as a flat list with IDs
  static Future<List<Map<String, dynamic>>> getFoldersFlatList() async {
    final foldersTree = await ApiService.getMyFolders();
    return _flattenFolderTree(foldersTree);
  }

  // Flatten the nested folder tree into a flat list
  static List<Map<String, dynamic>> _flattenFolderTree(
    List<dynamic> folders, {
    String path = '',
  }) {
    final List<Map<String, dynamic>> flatList = [];

    for (var folder in folders) {
      final folderMap = Map<String, dynamic>.from(folder);
      final currentPath = path.isNotEmpty
          ? '$path/${folderMap['name']}'
          : folderMap['name'];

      // Add current folder
      flatList.add({
        'id': folderMap['id'],
        'name': folderMap['name'],
        'path': currentPath,
        'displayName': currentPath,
      });

      // Add children recursively
      if (folderMap['children'] != null && folderMap['children'] is List) {
        final children = _flattenFolderTree(
          folderMap['children'] as List,
          path: currentPath,
        );
        flatList.addAll(children);
      }
    }

    return flatList;
  }

  // Find folder ID by name (handles "Home" specially)
  static Future<int?> findFolderIdByName(String folderName) async {
    if (folderName.isEmpty) return null;

    final folders = await getFoldersFlatList();

    // Try exact match first
    for (var folder in folders) {
      if (folder['name']?.toString().toLowerCase() ==
          folderName.toLowerCase()) {
        return folder['id'] as int?;
      }
    }

    // If "Home" not found, try to find root or return null
    if (folderName.toLowerCase() == 'home') {
      // Return first folder or null
      return folders.isNotEmpty ? folders.first['id'] as int? : null;
    }

    return null;
  }

  // Get default folder (Home or first available)
  static Future<Map<String, dynamic>?> getDefaultFolder() async {
    final folders = await getFoldersFlatList();

    if (folders.isEmpty) {
      return null;
    }

    // Try to find "Home" folder
    final homeFolder = folders.firstWhere(
      (folder) => folder['name']?.toString().toLowerCase() == 'home',
      orElse: () => folders.first,
    );

    return homeFolder;
  }
}
