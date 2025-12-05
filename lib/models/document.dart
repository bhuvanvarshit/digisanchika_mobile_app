// models/document.dart - FIXED VERSION
class Document {
  String id;
  String name;
  String type;
  String size;
  String keyword;
  String uploadDate;
  String owner;
  String details;
  String classification;
  bool allowDownload;
  String sharingType;
  String folder; // This is folder name
  String? folderId; // CHANGE: Make nullable String?
  String path;
  String fileType;

  Document({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.keyword,
    required this.uploadDate,
    required this.owner,
    required this.details,
    required this.classification,
    required this.allowDownload,
    required this.sharingType,
    required this.folder,
    required this.path,
    required this.fileType,
    this.folderId, // CHANGE: Make optional and nullable
  });

  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'size': size,
      'keyword': keyword,
      'upload_date': uploadDate,
      'owner': owner,
      'details': details,
      'classification': classification,
      'allowDownload': allowDownload,
      'sharingType': sharingType,
      'folder': folder,
      'folder_id': folderId, // Can be null
      'path': path,
      'fileType': fileType,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'size': size,
      'keyword': keyword,
      'uploadDate': uploadDate,
      'owner': owner,
      'details': details,
      'classification': classification,
      'allowDownload': allowDownload,
      'sharingType': sharingType,
      'folder': folder,
      'folderId': folderId, // Can be null
      'path': path,
      'fileType': fileType,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? '',
      uploadDate:
          json['uploadDate']?.toString() ??
          json['upload_date']?.toString() ??
          DateTime.now().toString(),
      owner: json['owner']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      classification: json['classification']?.toString() ?? 'General',
      allowDownload: json['allowDownload'] ?? true,
      sharingType: json['sharingType']?.toString() ?? 'private',
      folder: json['folder']?.toString() ?? 'General',
      folderId: json['folderId']?.toString() ?? json['folder_id']?.toString(),
      path: json['path']?.toString() ?? json['filename']?.toString() ?? '',
      fileType:
          json['fileType']?.toString() ??
          json['file_type']?.toString() ??
          'unknown',
    );
  }

  static Document fromApiJson(Map<String, dynamic> docJson) {
    return Document(
      id: (docJson['id'] ?? '').toString(),
      name: (docJson['original_name'] ?? docJson['filename'] ?? '').toString(),
      type: (docJson['file_type'] ?? 'unknown').toString(),
      size: (docJson['size'] ?? 0).toString(),
      keyword: '',
      uploadDate:
          docJson['upload_date']?.toString() ?? DateTime.now().toString(),
      owner: '',
      details: '',
      classification: (docJson['category'] ?? 'General').toString(),
      allowDownload: true,
      sharingType: 'private',
      folder: 'General',
      folderId: docJson['folder_id']?.toString(), // Can be null
      path: (docJson['filename'] ?? '').toString(),
      fileType: (docJson['file_type'] ?? 'unknown').toString(),
    );
  }
}
