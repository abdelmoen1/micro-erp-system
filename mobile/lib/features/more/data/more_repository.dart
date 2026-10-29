import '../../../core/api/api_client.dart';
import '../../../core/config/env.dart';
import '../../auth/domain/app_user.dart';

/// A manager or employee of the store (GET /users, owner only). The owner is not in the list.
class StaffMember {
  const StaffMember({required this.id, required this.name, required this.phone, required this.role, required this.active});

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: UserRole.parse(json['role'] as String?),
    active: json['status'] != 'inactive',
  );

  final int id;
  final String name;
  final String phone;
  final UserRole role;
  final bool active;
}

/// A new invitation: the link is shown once, then only its expiry remains on the server.
class StaffInvite {
  const StaffInvite({required this.link, required this.role, required this.expiresAt});

  final String link;
  final UserRole role;
  final DateTime? expiresAt;
}

/// What the owner edits about the store (GET / PATCH /my-store).
class StoreProfile {
  const StoreProfile({required this.name, this.phone, this.address, this.area});

  factory StoreProfile.fromJson(Map<String, dynamic> json) => StoreProfile(
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    area: json['area'] as String?,
  );

  final String name;
  final String? phone;
  final String? address;
  final String? area;
}

/// A complaint sent to the Hisbah team, with its status and the team's reply.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.type,
    required this.subject,
    required this.details,
    required this.status,
    this.reply,
    this.createdAt,
    this.senderName,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: (json['id'] as num).toInt(),
    type: json['type'] as String? ?? 'other',
    subject: json['subject'] as String? ?? '',
    details: json['details'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    reply: json['reply'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    senderName: (json['user'] as Map<String, dynamic>?)?['name'] as String?,
  );

  final int id;
  final String type;
  final String subject;
  final String details;

  /// open · in_progress · closed
  final String status;
  final String? reply;
  final DateTime? createdAt;
  final String? senderName;
}

/// The «More» tab's account and store screens. Field problems come back as `ValidationFailed`
/// with the server's Arabic messages; a role without the right gets `Forbidden`.
class MoreRepository {
  MoreRepository(this._api);

  final ApiClient _api;

  Future<List<StaffMember>> staff() async {
    final body = await _api.get('/users');
    return [for (final row in body['data'] as List<dynamic>? ?? const []) StaffMember.fromJson(row as Map<String, dynamic>)];
  }

  /// POST /invitations: a link the new manager or employee opens to create their account.
  Future<StaffInvite> invite({required UserRole role, required int hours}) async {
    final body = await _api.post('/invitations', body: {'role': role.name, 'expires_in_hours': hours});
    final invitation = body['invitation'] as Map<String, dynamic>;
    final token = Uri.encodeQueryComponent(invitation['token'] as String);
    return StaffInvite(
      link: '${Env.webBaseUrl}/invite?invite=$token',
      role: UserRole.parse(invitation['role'] as String?),
      expiresAt: DateTime.tryParse(invitation['expires_at'] as String? ?? '')?.toLocal(),
    );
  }

  Future<void> changeRole(int userId, UserRole role) => _api.patch('/users/$userId/role', body: {'role': role.name});

  /// D-13: never deleted; signed out everywhere at once, their sales stay in their name.
  Future<void> deactivate(int userId) => _api.post('/users/$userId/deactivate');

  Future<StoreProfile> store() async {
    final body = await _api.get('/my-store');
    return StoreProfile.fromJson(body['store'] as Map<String, dynamic>);
  }

  /// Sends only the fields given; an empty phone, address or area clears it.
  Future<StoreProfile> updateStore({required String name, String? phone, String? address, String? area}) async {
    String? blankToNull(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final body = await _api.patch(
      '/my-store',
      body: {'name': name.trim(), 'phone': blankToNull(phone), 'address': blankToNull(address), 'area': blankToNull(area)},
    );
    return StoreProfile.fromJson(body['store'] as Map<String, dynamic>);
  }

  /// GET /support-tickets: the store's complaints (an employee's own), newest first.
  Future<List<SupportTicket>> supportTickets() async {
    final body = await _api.get('/support-tickets');
    return [for (final row in body['data'] as List<dynamic>? ?? const []) SupportTicket.fromJson(row as Map<String, dynamic>)];
  }

  /// POST /support-tickets. Reachable after the subscription ends.
  Future<void> sendSupportTicket({required String type, required String subject, required String details}) =>
      _api.post('/support-tickets', body: {'type': type, 'subject': subject.trim(), 'details': details.trim()});

  /// PATCH /me/password: this phone stays signed in, every other device is signed out.
  Future<void> changePassword({required String current, required String password, required String confirmation}) =>
      _api.patch(
        '/me/password',
        body: {'current_password': current, 'password': password, 'password_confirmation': confirmation},
      );
}
