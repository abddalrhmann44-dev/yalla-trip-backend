// ═══════════════════════════════════════════════════════════════
//  TALAA — User API Model
//  Matches backend UserOut schema
// ═══════════════════════════════════════════════════════════════

class UserApi {
  final int id;
  final String firebaseUid;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final bool isVerified;
  final bool isActive;
  final bool phoneVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserApi({
    required this.id,
    required this.firebaseUid,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.isVerified = false,
    this.isActive = true,
    this.phoneVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserApi.fromJson(Map<String, dynamic> j) => UserApi(
        id: j['id'] ?? 0,
        firebaseUid: j['firebase_uid'] ?? '',
        name: j['name'] ?? '',
        email: j['email'],
        phone: j['phone'],
        role: j['role'] ?? 'guest',
        avatarUrl: j['avatar_url'],
        isVerified: j['is_verified'] ?? false,
        isActive: j['is_active'] ?? true,
        phoneVerified: j['phone_verified'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
        updatedAt: DateTime.parse(j['updated_at']),
      );

  bool get isOwner => role == 'owner' || role == 'admin';
  bool get isAdmin => role == 'admin';
  bool get isGuest => role == 'guest';
}
