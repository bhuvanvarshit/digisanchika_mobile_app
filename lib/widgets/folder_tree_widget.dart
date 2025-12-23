// lib/widgets/folder_tree_widget.dart

import 'package:flutter/material.dart';
import 'package:digi_sanchika/models/folder_tree_node.dart';

class FolderTreeWidget extends StatefulWidget {
  final List<FolderTreeNode> rootNodes;
  final Function(FolderTreeNode) onFolderTap;
  final Function(FolderTreeNode)? onFolderLongPress;
  final Function(FolderTreeNode)? onCreateSubfolder;
  final Function(FolderTreeNode)? onDeleteFolder;
  final FolderTreeNode? selectedFolder;
  final bool showActions;
  final bool enableSelection;

  const FolderTreeWidget({
    super.key,
    required this.rootNodes,
    required this.onFolderTap,
    this.onFolderLongPress,
    this.onCreateSubfolder,
    this.onDeleteFolder,
    this.selectedFolder,
    this.showActions = true,
    this.enableSelection = false,
  });

  @override
  State<FolderTreeWidget> createState() => _FolderTreeWidgetState();
}

class _FolderTreeWidgetState extends State<FolderTreeWidget>
    with SingleTickerProviderStateMixin {
  FolderTreeNode? _hoveredNode;

  @override
  Widget build(BuildContext context) {
    if (widget.rootNodes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(), // FIX: Add this
      shrinkWrap: true, // FIX: Add this
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.rootNodes.length,
      itemBuilder: (context, index) {
        return _buildTreeNode(widget.rootNodes[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Folders Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first folder to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(FolderTreeNode node) {
    final isSelected = widget.selectedFolder?.id == node.id;
    final isHovered = _hoveredNode?.id == node.id;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current folder row
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredNode = node),
          onExit: (_) => setState(() => _hoveredNode = null),
          child: InkWell(
            onTap: () => widget.onFolderTap(node),
            onLongPress: widget.onFolderLongPress != null
                ? () => widget.onFolderLongPress!(node)
                : null,
            child: Container(
              margin: EdgeInsets.only(
                left: node.depth * 20.0,
                right: 8,
                bottom: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.indigo.shade50
                    : isHovered
                    ? Colors.grey.shade100
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.indigo.shade200
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Expand/Collapse button
                  if (hasChildren)
                    InkWell(
                      onTap: () {
                        setState(() {
                          node.toggleExpanded();
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: AnimatedRotation(
                          turns: node.isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 28),

                  // Folder icon
                  Icon(
                    hasChildren && node.isExpanded
                        ? Icons.folder_open
                        : Icons.folder,
                    size: 22,
                    color: isSelected
                        ? Colors.amber.shade700
                        : Colors.amber.shade600,
                  ),

                  const SizedBox(width: 12),

                  // Folder name
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.indigo.shade700
                            : Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),

                  // Item count badge
                  if (hasChildren)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.indigo.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${node.children.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.indigo.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),

                  // Action buttons (show on hover or selected)
                  if (widget.showActions && (isHovered || isSelected))
                    _buildActionButtons(node),
                ],
              ),
            ),
          ),
        ),

        // Children (if expanded)
        if (hasChildren && node.isExpanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Column(
              children: node.children
                  .map((child) => _buildTreeNode(child))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(FolderTreeNode node) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Create subfolder button
        if (widget.onCreateSubfolder != null)
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 18),
            tooltip: 'Create subfolder',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            color: Colors.indigo.shade600,
            onPressed: () => widget.onCreateSubfolder!(node),
          ),

        const SizedBox(width: 4),

        // Delete folder button
        if (widget.onDeleteFolder != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete folder',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            color: Colors.red.shade400,
            onPressed: () => widget.onDeleteFolder!(node),
          ),
      ],
    );
  }
}

/// Compact folder tree for selection dialogs
class CompactFolderTreeWidget extends StatefulWidget {
  final List<FolderTreeNode> rootNodes;
  final Function(FolderTreeNode) onFolderSelect;
  final FolderTreeNode? selectedFolder;

  const CompactFolderTreeWidget({
    super.key,
    required this.rootNodes,
    required this.onFolderSelect,
    this.selectedFolder,
  });

  @override
  State<CompactFolderTreeWidget> createState() =>
      _CompactFolderTreeWidgetState();
}

class _CompactFolderTreeWidgetState extends State<CompactFolderTreeWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(), // FIX: Add this
      shrinkWrap: true, // FIX: Add this
      padding: const EdgeInsets.all(8),
      itemCount: widget.rootNodes.length,
      itemBuilder: (context, index) {
        return _buildCompactNode(widget.rootNodes[index]);
      },
    );
  }

  Widget _buildCompactNode(FolderTreeNode node) {
    final isSelected = widget.selectedFolder?.id == node.id;
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onFolderSelect(node),
          child: Container(
            margin: EdgeInsets.only(left: node.depth * 16.0, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.indigo.shade300 : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse
                if (hasChildren)
                  InkWell(
                    onTap: () => setState(() => node.toggleExpanded()),
                    child: Icon(
                      node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  const SizedBox(width: 18),

                const SizedBox(width: 4),

                // Folder icon
                Icon(
                  Icons.folder,
                  size: 18,
                  color: isSelected
                      ? Colors.amber.shade700
                      : Colors.amber.shade600,
                ),

                const SizedBox(width: 8),

                // Folder name
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.indigo.shade700
                          : Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.indigo.shade600,
                  ),
              ],
            ),
          ),
        ),

        // Children
        if (hasChildren && node.isExpanded)
          Column(
            children: node.children
                .map((child) => _buildCompactNode(child))
                .toList(),
          ),
      ],
    );
  }
}

/// Folder grid view (alternative layout)
/// Folder grid view (alternative layout)
class FolderGridWidget extends StatelessWidget {
  final List<FolderTreeNode> folders;
  final Function(FolderTreeNode) onFolderTap;
  final Function(FolderTreeNode)? onFolderLongPress;
  final FolderTreeNode? selectedFolder;

  const FolderGridWidget({
    super.key,
    required this.folders,
    required this.onFolderTap,
    this.onFolderLongPress,
    this.selectedFolder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(12), // Reduced padding
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Changed from 3 to 2 for more horizontal space
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1, // Slightly wider
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = selectedFolder?.id == folder.id;

        return InkWell(
          onTap: () => onFolderTap(folder),
          onLongPress: onFolderLongPress != null
              ? () => onFolderLongPress!(folder)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.indigo.shade300
                    : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Icon container with proper sizing
                Container(
                  height: 50, // Fixed height for icon container
                  width: 50, // Fixed width for icon container
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.indigo.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                  ),
                  child: Icon(
                    folder.children.isNotEmpty
                        ? Icons.folder_open_rounded
                        : Icons.folder_rounded,
                    size: 30,
                    color: isSelected
                        ? Colors.amber.shade700
                        : Colors.amber.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                // Folder name with proper constraints
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.indigo.shade700
                          : Colors.grey.shade800,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Item count (only show if there are children)
                if (folder.children.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.indigo.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${folder.children.length} items',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.indigo.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
