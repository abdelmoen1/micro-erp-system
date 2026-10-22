enum UserRole {
  owner,
  manager,
  employee;

  static UserRole parse(String? value) =>
      UserRole.values.firstWhere((r) => r.name == value, orElse: () => UserRole.employee);

  /// Role landing (US-1505): employees start on POS, owners and managers on Home.
  bool get landsOnPos => this == UserRole.employee;
}

/// The signed-in user as returned by `POST /login` and `GET /me` (docs/api/auth.http).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.storeId,
    required this.storeName,
    required this.storeTimezone,
    this.storePhone,
    this.storeAddress,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final store = json['store'] is Map<String, dynamic> ? json['store'] as Map<String, dynamic> : const {};
    return AppUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.parse(json['role'] as String?),
      storeId: (json['store_id'] as num?)?.toInt(),
      storeName: store['name'] as String? ?? '',
      storeTimezone: store['timezone'] as String? ?? 'Asia/Gaza',
      storePhone: store['phone'] as String?,
      storeAddress: store['address'] as String?,
    );
  }

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final int? storeId;
  final String storeName;
  final String storeTimezone;

  /// Printed at the top of the receipt (M-06) when the owner entered them.
  final String? storePhone;
  final String? storeAddress;

  /// D-26 / D-06: only an owner or manager may override a credit limit or void a sale.
  bool get canOverride => role != UserRole.employee;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'store_id': storeId,
    'store': {'name': storeName, 'timezone': storeTimezone, 'phone': storePhone, 'address': storeAddress},
  };
}
