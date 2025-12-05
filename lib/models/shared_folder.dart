// models/shared_folder.dart
class SharedFolder {
  final String id;
  final String name;
  final String owner;
  final String createdAt;

  SharedFolder({
    required this.id,
    required this.name,
    required this.owner,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'owner': owner, 'createdAt': createdAt};
  }

  factory SharedFolder.fromJson(Map<String, dynamic> json) {
    return SharedFolder(
      id: (json['id'] ?? 0).toString(),
      name: json['name']?.toString() ?? 'Unknown Folder',
      owner: json['owner']?.toString() ?? 'Unknown User',
      createdAt: _formatDate(json['created_at']),
    );
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      final dateStr = date.toString();
      if (dateStr.contains('/')) return dateStr;
      return dateStr;
    }
  }
}
