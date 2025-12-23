// lib/widgets/breadcrumb_widget.dart

import 'package:flutter/material.dart';
import 'package:digi_sanchika/models/folder_tree_node.dart';

class BreadcrumbWidget extends StatelessWidget {
  final List<FolderTreeNode> path;
  final Function(FolderTreeNode?) onFolderTap;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? activeColor;

  const BreadcrumbWidget({
    super.key,
    required this.path,
    required this.onFolderTap,
    this.backgroundColor,
    this.textColor,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Home icon - always clickable
            _buildHomeItem(),

            // Path items
            if (path.isNotEmpty) ..._buildPathItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeItem() {
    final isActive = path.isEmpty;

    return InkWell(
      onTap: () => onFolderTap(null),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (activeColor ?? Colors.indigo.shade50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_rounded,
              size: 18,
              color: isActive
                  ? (activeColor ?? Colors.indigo)
                  : (textColor ?? Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              'Home',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? (activeColor ?? Colors.indigo)
                    : (textColor ?? Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPathItems() {
    final items = <Widget>[];

    // Handle overflow - show first, ellipsis, and last 2 items if path is long
    final shouldShowEllipsis = path.length > 4;
    final List<FolderTreeNode> displayPath;

    if (shouldShowEllipsis) {
      // Show first item, ..., and last 2 items
      displayPath = [path.first, ...path.sublist(path.length - 2)];
    } else {
      displayPath = path;
    }

    for (int i = 0; i < displayPath.length; i++) {
      final node = displayPath[i];
      final isLast = i == displayPath.length - 1;
      final isActive = isLast && path.length == displayPath.length;

      // Add chevron separator
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: Colors.grey.shade400,
          ),
        ),
      );

      // Add ellipsis if needed
      if (shouldShowEllipsis && i == 1) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PopupMenuButton<FolderTreeNode>(
              icon: Icon(
                Icons.more_horiz,
                size: 16,
                color: Colors.grey.shade600,
              ),
              tooltip: 'Show hidden folders',
              itemBuilder: (context) {
                // Show the hidden folders
                final hiddenFolders = path.sublist(1, path.length - 2);
                return hiddenFolders.map((folder) {
                  return PopupMenuItem<FolderTreeNode>(
                    value: folder,
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(folder.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList();
              },
              onSelected: (folder) => onFolderTap(folder),
            ),
          ),
        );

        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ),
        );
      }

      // Add folder breadcrumb
      items.add(
        InkWell(
          onTap: isActive ? null : () => onFolderTap(node),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? (activeColor ?? Colors.indigo.shade50)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder,
                  size: 16,
                  color: isActive
                      ? Colors.amber.shade700
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? (activeColor ?? Colors.indigo)
                        : (textColor ?? Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }
}

/// Compact breadcrumb for smaller spaces
class CompactBreadcrumbWidget extends StatelessWidget {
  final List<FolderTreeNode> path;
  final Function(FolderTreeNode?) onFolderTap;

  const CompactBreadcrumbWidget({
    super.key,
    required this.path,
    required this.onFolderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_rounded, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            'Home',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      );
    }

    final currentFolder = path.last;

    return PopupMenuButton<FolderTreeNode?>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, size: 14, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            Text(
              currentFolder.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<FolderTreeNode?>>[];

        // Add Home
        items.add(
          PopupMenuItem<FolderTreeNode?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.home_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text('Home', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );

        // Add all folders in path
        for (var folder in path) {
          items.add(
            PopupMenuItem<FolderTreeNode?>(
              value: folder,
              child: Row(
                children: [
                  SizedBox(width: folder.depth * 12.0),
                  Icon(Icons.folder, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(folder.name, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (folder) => onFolderTap(folder),
    );
  }
}
