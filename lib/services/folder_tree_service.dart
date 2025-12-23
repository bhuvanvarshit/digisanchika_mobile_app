// lib/services/folder_tree_service.dart

import 'package:flutter/foundation.dart';
import 'package:digi_sanchika/models/folder_tree_node.dart';
import 'package:digi_sanchika/services/api_service.dart';

class FolderTreeService {
  // Singleton pattern
  static final FolderTreeService _instance = FolderTreeService._internal();
  factory FolderTreeService() => _instance;
  FolderTreeService._internal();

  // Cache
  List<FolderTreeNode>? _cachedTree;
  FolderTreeNode? _currentNode;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  // Current navigation state
  List<FolderTreeNode> _navigationHistory = [];

  // Getters
  List<FolderTreeNode>? get cachedTree => _cachedTree;
  FolderTreeNode? get currentNode => _currentNode;
  List<FolderTreeNode> get navigationHistory => _navigationHistory;

  /// Fetch folder tree from backend
  Future<List<FolderTreeNode>> fetchFolderTree({bool forceRefresh = false}) async {
    try {
      // Check cache validity
      if (!forceRefresh &&
          _cachedTree != null &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        if (kDebugMode) {
          print('📦 Using cached folder tree');
        }
        return _cachedTree!;
      }

      if (kDebugMode) {
        print('🔄 Fetching folder tree from backend...');
      }

      // Fetch from API
      final response = await ApiService.getMyFolders();

      if (response.isEmpty) {
        if (kDebugMode) {
          print('📁 No folders found');
        }
        _cachedTree = [];
        _lastFetchTime = DateTime.now();
        return [];
      }

      // Build tree structure
      final tree = buildTreeFromResponse(response);

      // Sort tree
      for (var node in tree) {
        node.sortChildren();
      }

      // Cache result
      _cachedTree = tree;
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        print('✅ Folder tree loaded: ${tree.length} root folders');
      }

      return tree;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching folder tree: $e');
      }
      // Return cached data if available
      return _cachedTree ?? [];
    }
  }

  /// Build tree structure from backend response
  List<FolderTreeNode> buildTreeFromResponse(List<dynamic> data,
      {int depth = 0}) {
    final nodes = <FolderTreeNode>[];

    for (var folderData in data) {
      final node = FolderTreeNode(
        id: folderData['id'] as int,
        name: folderData['name'] as String,
        parentId: folderData['parent_id'] as int?,
        createdAt: DateTime.parse(folderData['created_at'] as String),
        owner: 'Current User', // Could be extracted from folderData
        depth: depth,
      );

      // Recursively build children
      if (folderData['children'] != null && folderData['children'] is List) {
        final childrenData = folderData['children'] as List;
        for (var childData in childrenData) {
          final childNode = _buildSingleNode(childData, depth + 1);
          if (childNode != null) {
            node.addChild(childNode);
          }
        }
      }

      nodes.add(node);
    }

    return nodes;
  }

  /// Build a single node recursively
  FolderTreeNode? _buildSingleNode(dynamic data, int depth) {
    try {
      final node = FolderTreeNode(
        id: data['id'] as int,
        name: data['name'] as String,
        parentId: data['parent_id'] as int?,
        createdAt: DateTime.parse(data['created_at'] as String),
        owner: 'Current User',
        depth: depth,
      );

      if (data['children'] != null && data['children'] is List) {
        final childrenData = data['children'] as List;
        for (var childData in childrenData) {
          final childNode = _buildSingleNode(childData, depth + 1);
          if (childNode != null) {
            node.addChild(childNode);
          }
        }
      }

      return node;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error building node: $e');
      }
      return null;
    }
  }

  /// Navigate to a specific folder
  void navigateToFolder(FolderTreeNode node) {
    _currentNode = node;
    _navigationHistory.add(node);
    if (kDebugMode) {
      print('📂 Navigated to: ${node.name}');
    }
  }

  /// Navigate to parent folder
  void navigateToParent() {
    if (_navigationHistory.length > 1) {
      _navigationHistory.removeLast();
      _currentNode = _navigationHistory.last;
      if (kDebugMode) {
        print('⬆️ Navigated to parent: ${_currentNode?.name}');
      }
    } else {
      navigateToRoot();
    }
  }

  /// Navigate to root
  void navigateToRoot() {
    _currentNode = null;
    _navigationHistory.clear();
    if (kDebugMode) {
      print('🏠 Navigated to root');
    }
  }

  /// Get breadcrumb path for current folder
  List<FolderTreeNode> getBreadcrumbPath() {
    if (_currentNode == null || _cachedTree == null) {
      return [];
    }
    return _currentNode!.getPath(_cachedTree!);
  }

  /// Find node by ID in the entire tree
  FolderTreeNode? findNodeById(int id) {
    if (_cachedTree == null) return null;

    for (var rootNode in _cachedTree!) {
      final found = rootNode.findNodeById(id);
      if (found != null) return found;
    }

    return null;
  }

  /// Expand a folder by ID
  void expandFolder(int folderId) {
    final node = findNodeById(folderId);
    if (node != null) {
      node.isExpanded = true;
      if (kDebugMode) {
        print('📂 Expanded: ${node.name}');
      }
    }
  }

  /// Collapse a folder by ID
  void collapseFolder(int folderId) {
    final node = findNodeById(folderId);
    if (node != null) {
      node.isExpanded = false;
      if (kDebugMode) {
        print('📁 Collapsed: ${node.name}');
      }
    }
  }

  /// Toggle folder expansion
  void toggleFolderExpansion(int folderId) {
    final node = findNodeById(folderId);
    if (node != null) {
      node.toggleExpanded();
    }
  }

  /// Expand all folders in tree
  void expandAll() {
    if (_cachedTree == null) return;
    for (var node in _cachedTree!) {
      node.expandAll();
    }
    if (kDebugMode) {
      print('📂 Expanded all folders');
    }
  }

  /// Collapse all folders in tree
  void collapseAll() {
    if (_cachedTree == null) return;
    for (var node in _cachedTree!) {
      node.collapseAll();
    }
    if (kDebugMode) {
      print('📁 Collapsed all folders');
    }
  }

  /// Get all folders as flat list (for selection)
  List<FolderTreeNode> getFlatList() {
    if (_cachedTree == null) return [];

    List<FolderTreeNode> flatList = [];

    void addToList(FolderTreeNode node) {
      flatList.add(node);
      for (var child in node.children) {
        addToList(child);
      }
    }

    for (var rootNode in _cachedTree!) {
      addToList(rootNode);
    }

    return flatList;
  }

  /// Get folders by parent ID
  List<FolderTreeNode> getFoldersByParentId(int? parentId) {
    if (_cachedTree == null) return [];

    if (parentId == null) {
      // Return root folders
      return _cachedTree!;
    }

    // Find parent node and return its children
    final parentNode = findNodeById(parentId);
    return parentNode?.children ?? [];
  }

  /// Search folders by name
  List<FolderTreeNode> searchFolders(String query) {
    if (_cachedTree == null || query.isEmpty) return [];

    final results = <FolderTreeNode>[];
    final lowerQuery = query.toLowerCase();

    void searchInNode(FolderTreeNode node) {
      if (node.name.toLowerCase().contains(lowerQuery)) {
        results.add(node);
      }
      for (var child in node.children) {
        searchInNode(child);
      }
    }

    for (var rootNode in _cachedTree!) {
      searchInNode(rootNode);
    }

    return results;
  }

  /// Clear cache and force refresh on next fetch
  void clearCache() {
    _cachedTree = null;
    _lastFetchTime = null;
    _currentNode = null;
    _navigationHistory.clear();
    if (kDebugMode) {
      print('🗑️ Folder tree cache cleared');
    }
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    if (_cachedTree == null) {
      return {'total': 0, 'root': 0, 'max_depth': 0};
    }

    int totalCount = 0;
    int maxDepth = 0;

    void countNodes(FolderTreeNode node) {
      totalCount++;
      if (node.depth > maxDepth) {
        maxDepth = node.depth;
      }
      for (var child in node.children) {
        countNodes(child);
      }
    }

    for (var rootNode in _cachedTree!) {
      countNodes(rootNode);
    }

    return {
      'total': totalCount,
      'root': _cachedTree!.length,
      'max_depth': maxDepth,
    };
  }

  /// Check if cache is valid
  bool get isCacheValid {
    return _cachedTree != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }
}
