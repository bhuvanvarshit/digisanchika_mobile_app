// widgets/folder_card.dart
import 'package:flutter/material.dart';
import 'package:digi_sanchika/models/folder.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const FolderCard({
    Key? key,
    required this.folder,
    required this.index,
    required this.onDelete,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening folder: ${folder.name}')),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder, color: Colors.amber.shade700, size: 36),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        folder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${folder.documents.length} item${folder.documents.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Text('Share Folder'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Folder'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'share') {
                    onShare();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
