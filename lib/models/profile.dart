// lib/models/profile.dart
class UserProfile {
  final String employeeName;
  final String employeeId;
  final String department;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final String? createdAt;

  UserProfile({
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.email,
    required this.isAdmin,
    required this.isActive,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      employeeName: json['employeeName'] ?? 'Unknown',
      employeeId: json['employeeId'] ?? 'Unknown',
      department: json['department'] ?? 'Not Assigned',
      email: json['email'] ?? 'Not Provided',
      isAdmin: json['isAdmin'] ?? false,
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeName': employeeName,
      'employeeId': employeeId,
      'department': department,
      'email': email,
      'isAdmin': isAdmin,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}
