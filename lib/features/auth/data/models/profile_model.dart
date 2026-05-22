class ProfileModel {
  final String id;
  final String fullName;
  final String? username;
  final String? phone;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    this.username,
    this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'Admin';
  bool get isStaff => role == 'Staff';
  bool get isActive => status == 'Active';

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        username: json['username'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'username': username,
        'phone': phone,
        'role': role,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ProfileModel copyWith({
    String? fullName,
    String? username,
    String? phone,
    String? role,
    String? status,
  }) =>
      ProfileModel(
        id: id,
        fullName: fullName ?? this.fullName,
        username: username ?? this.username,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
