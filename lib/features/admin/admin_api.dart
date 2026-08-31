import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/sync/sync_providers.dart';
import 'admin_auth_providers.dart';
import 'admin_supabase.dart';
import 'voucher_api.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AdminOverview {
  const AdminOverview({
    required this.totalUsers,
    required this.premiumAccounts,
    required this.mrrPhp,
    required this.aiSpendEstimateUsd,
    required this.openBugs,
    required this.storageBytes,
    required this.fileCount,
    required this.aiEventsInPeriod,
    required this.periodDays,
  });

  final int totalUsers;
  final int premiumAccounts;
  final int mrrPhp;
  final double aiSpendEstimateUsd;
  final int openBugs;
  final int storageBytes;
  final int fileCount;
  final int aiEventsInPeriod;
  final int periodDays;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      totalUsers: json['totalUsers'] as int? ?? 0,
      premiumAccounts: json['premiumAccounts'] as int? ?? 0,
      mrrPhp: json['mrrPhp'] as int? ?? 0,
      aiSpendEstimateUsd: (json['aiSpendEstimateUsd'] as num?)?.toDouble() ?? 0,
      openBugs: json['openBugs'] as int? ?? 0,
      storageBytes: json['storageBytes'] as int? ?? 0,
      fileCount: json['fileCount'] as int? ?? 0,
      aiEventsInPeriod: json['aiEventsInPeriod'] as int? ?? 0,
      periodDays: json['periodDays'] as int? ?? 30,
    );
  }
}

class AdminUserRow {
  const AdminUserRow({
    required this.uid,
    required this.storageBytes,
    required this.fileCount,
    required this.isPremium,
    this.email,
    this.displayName,
    this.lastSeenAt,
    this.plan,
    this.premiumExpiresAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? lastSeenAt;
  final int storageBytes;
  final int fileCount;
  final bool isPremium;
  final String? plan;
  final String? premiumExpiresAt;

  factory AdminUserRow.fromJson(Map<String, dynamic> json) {
    return AdminUserRow(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      lastSeenAt: json['lastSeenAt'] as String?,
      storageBytes: json['storageBytes'] as int? ?? 0,
      fileCount: json['fileCount'] as int? ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      plan: json['plan'] as String?,
      premiumExpiresAt: json['premiumExpiresAt'] as String?,
    );
  }
}

class AdminDeleteUserResult {
  const AdminDeleteUserResult({
    required this.authDeleted,
    this.deletedObjects = 0,
    this.authError,
  });

  final bool authDeleted;
  final int deletedObjects;
  final String? authError;
}

class AdminSubscriptionRow {
  const AdminSubscriptionRow({
    required this.uid,
    required this.isPremium,
    required this.source,
    required this.updatedAt,
    required this.mrrPhp,
    this.email,
    this.plan,
    this.expiresAt,
  });

  final String uid;
  final String? email;
  final bool isPremium;
  final String? plan;
  final String? expiresAt;
  final String source;
  final String updatedAt;
  final double mrrPhp;

  factory AdminSubscriptionRow.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionRow(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      plan: json['plan'] as String?,
      expiresAt: json['expiresAt'] as String?,
      source: json['source'] as String? ?? 'paymongo',
      updatedAt: json['updatedAt'] as String? ?? '',
      mrrPhp: (json['mrrPhp'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One settled payment from the per-user ledger.
class AdminPaymentRow {
  const AdminPaymentRow({
    required this.uid,
    required this.plan,
    required this.amountPhp,
    required this.paidAt,
    required this.expiresAt,
    this.email,
    this.paymentIntentId,
    this.method,
  });

  final String uid;
  final String? email;
  final String? paymentIntentId;
  final String plan;

  /// card | gcash | paymaya | qrph, or null for admin/voucher grants.
  final String? method;

  final double amountPhp;
  final String paidAt;
  final String expiresAt;

  factory AdminPaymentRow.fromJson(Map<String, dynamic> json) {
    return AdminPaymentRow(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      paymentIntentId: json['paymentIntentId'] as String?,
      plan: json['plan'] as String? ?? '',
      method: json['method'] as String?,
      amountPhp: (json['amountPhp'] as num?)?.toDouble() ?? 0,
      paidAt: json['paidAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
    );
  }

  /// How the payment reached us, for display.
  String get methodLabel => switch (method) {
        'card' => 'Card',
        'gcash' => 'GCash',
        'paymaya' => 'Maya',
        'qrph' => 'QR Ph',
        null => 'Granted',
        _ => method!,
      };
}

class AdminDocumentRow {
  const AdminDocumentRow({
    required this.uid,
    required this.storageBytes,
    required this.fileCount,
    this.email,
  });

  final String uid;
  final String? email;
  final int storageBytes;
  final int fileCount;

  factory AdminDocumentRow.fromJson(Map<String, dynamic> json) {
    return AdminDocumentRow(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      storageBytes: json['storageBytes'] as int? ?? 0,
      fileCount: json['fileCount'] as int? ?? 0,
    );
  }
}

class AdminBugAttachment {
  const AdminBugAttachment({
    required this.key,
    required this.name,
    required this.mime,
  });

  final String key;
  final String name;
  final String mime;

  factory AdminBugAttachment.fromJson(Map<String, dynamic> json) {
    return AdminBugAttachment(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? 'screenshot',
      mime: json['mime'] as String? ?? 'image/jpeg',
    );
  }
}

class AdminBugReport {
  const AdminBugReport({
    required this.id,
    required this.uid,
    required this.category,
    required this.subject,
    required this.description,
    required this.device,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.attachments = const [],
    this.adminReply,
    this.adminReplyAt,
  });

  final String id;
  final String uid;
  final String? email;
  final String category;
  final String subject;
  final String description;
  final String device;
  final String status;
  final String createdAt;
  final String updatedAt;
  final List<AdminBugAttachment> attachments;
  final String? adminReply;
  final String? adminReplyAt;

  factory AdminBugReport.fromJson(Map<String, dynamic> json) {
    return AdminBugReport(
      id: json['id'] as String,
      uid: json['uid'] as String,
      email: json['email'] as String?,
      category: json['category'] as String? ?? 'other',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      device: json['device'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      attachments: [
        for (final e in json['attachments'] as List<dynamic>? ?? [])
          if (e is Map<String, dynamic>) AdminBugAttachment.fromJson(e),
      ],
      adminReply: json['adminReply'] as String?,
      adminReplyAt: json['adminReplyAt'] as String?,
    );
  }
}

class AdminAiUsage {
  const AdminAiUsage({
    required this.totalEvents,
    required this.totalPromptTokens,
    required this.totalOutputTokens,
    required this.estimatedSpendUsd,
    required this.byUser,
    required this.recent,
  });

  final int totalEvents;
  final int totalPromptTokens;
  final int totalOutputTokens;
  final double estimatedSpendUsd;
  final List<AdminAiUserUsage> byUser;
  final List<AdminAiEvent> recent;

  factory AdminAiUsage.fromJson(Map<String, dynamic> json) {
    final byUser = (json['byUser'] as List<dynamic>? ?? [])
        .map((e) => AdminAiUserUsage.fromJson(e as Map<String, dynamic>))
        .toList();
    final recent = (json['recent'] as List<dynamic>? ?? [])
        .map((e) => AdminAiEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminAiUsage(
      totalEvents: json['totalEvents'] as int? ?? 0,
      totalPromptTokens: json['totalPromptTokens'] as int? ?? 0,
      totalOutputTokens: json['totalOutputTokens'] as int? ?? 0,
      estimatedSpendUsd: (json['estimatedSpendUsd'] as num?)?.toDouble() ?? 0,
      byUser: byUser,
      recent: recent,
    );
  }
}

class AdminAiUserUsage {
  const AdminAiUserUsage({
    required this.uid,
    required this.events,
    required this.tokens,
  });

  final String uid;
  final int events;
  final int tokens;

  factory AdminAiUserUsage.fromJson(Map<String, dynamic> json) {
    return AdminAiUserUsage(
      uid: json['uid'] as String,
      events: json['events'] as int? ?? 0,
      tokens: json['tokens'] as int? ?? 0,
    );
  }
}

class AdminAiEvent {
  const AdminAiEvent({
    required this.id,
    required this.uid,
    required this.feature,
    required this.promptTokens,
    required this.outputTokens,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String feature;
  final int promptTokens;
  final int outputTokens;
  final String createdAt;

  factory AdminAiEvent.fromJson(Map<String, dynamic> json) {
    return AdminAiEvent(
      id: json['id'] as String,
      uid: json['uid'] as String,
      feature: json['feature'] as String? ?? 'quiz',
      promptTokens: json['promptTokens'] as int? ?? 0,
      outputTokens: json['outputTokens'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AdminTeamMember {
  const AdminTeamMember({
    required this.uid,
    required this.role,
    required this.addedAt,
    this.email,
    this.addedBy,
  });

  final String uid;
  final String? email;
  final String role;
  final String addedAt;
  final String? addedBy;

  factory AdminTeamMember.fromJson(Map<String, dynamic> json) {
    return AdminTeamMember(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'admin',
      addedAt: json['addedAt'] as String? ?? '',
      addedBy: json['addedBy'] as String?,
    );
  }
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.actorUid,
    required this.action,
    required this.createdAt,
    this.actorEmail,
    this.target,
    this.detail,
  });

  final String id;
  final String actorUid;
  final String? actorEmail;
  final String action;
  final String? target;
  final String? detail;
  final String createdAt;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditEntry(
      id: json['id'] as String,
      actorUid: json['actorUid'] as String,
      actorEmail: json['actorEmail'] as String?,
      action: json['action'] as String? ?? '',
      target: json['target'] as String?,
      detail: json['detail'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AdminApiService {
  AdminApiService({
    required this.endpoint,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final Future<String> Function() idToken;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$endpoint$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await idToken();
    if (token.isEmpty) throw StateError('Sign in required.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Request failed (${response.statusCode}).');
    }
    if (body is! Map<String, dynamic>) {
      throw StateError('Unexpected response.');
    }
    return body;
  }

  Future<AdminOverview> fetchOverview({int days = 30}) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/admin/overview', {'days': '$days'}),
      headers: headers,
    );
    final body = await _decode(response);
    return AdminOverview.fromJson(body['overview'] as Map<String, dynamic>);
  }

  Future<List<AdminUserRow>> fetchUsers({String query = ''}) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/admin/users', query.isEmpty ? null : {'q': query}),
      headers: headers,
    );
    final body = await _decode(response);
    return (body['users'] as List<dynamic>? ?? [])
        .map((e) => AdminUserRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminSubscriptionRow>> fetchSubscriptions() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/subscriptions'), headers: headers);
    final body = await _decode(response);
    return (body['subscriptions'] as List<dynamic>? ?? [])
        .map((e) => AdminSubscriptionRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminPaymentRow>> fetchPayments() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/payments'), headers: headers);
    final body = await _decode(response);
    return (body['payments'] as List<dynamic>? ?? [])
        .map((e) => AdminPaymentRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSubscription(
    String uid, {
    required bool isPremium,
    String? plan,
    String? expiresAt,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.patch(
      _uri('/admin/subscriptions/${Uri.encodeComponent(uid)}'),
      headers: headers,
      body: jsonEncode({
        'isPremium': isPremium,
        if (plan != null) 'plan': plan,
        if (expiresAt != null) 'expiresAt': expiresAt,
      }),
    );
    await _decode(response);
  }

  /// Update display name / email label and optionally membership.
  Future<void> updateUser(
    String uid, {
    String? email,
    String? displayName,
    bool? isPremium,
    String? plan,
    String? expiresAt,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.patch(
      _uri('/admin/users/${Uri.encodeComponent(uid)}'),
      headers: headers,
      body: jsonEncode({
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (isPremium != null) 'isPremium': isPremium,
        if (plan != null) 'plan': plan,
        if (expiresAt != null) 'expiresAt': expiresAt,
      }),
    );
    await _decode(response);
  }

  /// Deletes R2 user data (+ Auth user when the admin RPC or service role works).
  Future<AdminDeleteUserResult> deleteUser(String uid) async {
    final headers = await _authHeaders();
    final response = await _client.delete(
      _uri('/admin/users/${Uri.encodeComponent(uid)}'),
      headers: headers,
    );
    final body = await _decode(response);
    return AdminDeleteUserResult(
      authDeleted: body['authDeleted'] as bool? ?? false,
      deletedObjects: body['deletedObjects'] as int? ?? 0,
      authError: body['authError'] as String?,
    );
  }

  Future<List<AdminDocumentRow>> fetchDocuments() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/documents'), headers: headers);
    final body = await _decode(response);
    return (body['documents'] as List<dynamic>? ?? [])
        .map((e) => AdminDocumentRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> deleteUserFiles(String uid) async {
    final headers = await _authHeaders();
    final response = await _client.delete(
      _uri('/admin/documents/${Uri.encodeComponent(uid)}'),
      headers: headers,
    );
    final body = await _decode(response);
    return body['deletedObjects'] as int? ?? 0;
  }

  Future<List<AdminBugReport>> fetchBugs() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/bugs'), headers: headers);
    final body = await _decode(response);
    return (body['reports'] as List<dynamic>? ?? [])
        .map((e) => AdminBugReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateBugStatus(String id, String status) async {
    await updateBug(id, status: status);
  }

  Future<void> updateBug(
    String id, {
    String? status,
    String? reply,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.patch(
      _uri('/admin/bugs/${Uri.encodeComponent(id)}'),
      headers: headers,
      body: jsonEncode({
        if (status != null) 'status': status,
        if (reply != null) 'reply': reply,
      }),
    );
    await _decode(response);
  }

  Future<List<int>> fetchBugAttachment(String id, int index) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/admin/bugs/${Uri.encodeComponent(id)}/files/$index'),
      headers: headers,
    );
    if (response.statusCode >= 400) {
      throw StateError('Could not load attachment.');
    }
    return response.bodyBytes;
  }

  Future<AdminAiUsage> fetchAiUsage({int days = 30}) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/admin/ai', {'days': '$days'}),
      headers: headers,
    );
    final body = await _decode(response);
    return AdminAiUsage.fromJson(body['usage'] as Map<String, dynamic>);
  }

  Future<List<AdminTeamMember>> fetchTeam() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/team'), headers: headers);
    final body = await _decode(response);
    return (body['members'] as List<dynamic>? ?? [])
        .map((e) => AdminTeamMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Whether the current session may use the admin console (env + R2 team).
  Future<bool> checkAdminAccess() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/me'), headers: headers);
    final body = await _decode(response);
    return body['admin'] as bool? ?? false;
  }

  /// Creates a Supabase Auth user and adds them as an admin on the team list.
  Future<AdminTeamMember> createAdminAccount({
    required String email,
    required String password,
    String? name,
    String role = 'admin',
  }) async {
    final headers = await _authHeaders();
    final response = await _client.post(
      _uri('/admin/team/create'),
      headers: headers,
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'role': role,
      }),
    );
    final body = await _decode(response);
    return AdminTeamMember.fromJson(body['member'] as Map<String, dynamic>);
  }

  Future<AdminTeamMember> addTeamMember({
    required String uid,
    String? email,
    String role = 'admin',
  }) async {
    final headers = await _authHeaders();
    final response = await _client.post(
      _uri('/admin/team'),
      headers: headers,
      body: jsonEncode({
        'uid': uid.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'role': role,
      }),
    );
    final body = await _decode(response);
    return AdminTeamMember.fromJson(body['member'] as Map<String, dynamic>);
  }

  Future<void> removeTeamMember(String uid) async {
    final headers = await _authHeaders();
    final response = await _client.delete(
      _uri('/admin/team/${Uri.encodeComponent(uid)}'),
      headers: headers,
    );
    await _decode(response);
  }

  Future<List<AdminAuditEntry>> fetchAudit() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/audit'), headers: headers);
    final body = await _decode(response);
    return (body['entries'] as List<dynamic>? ?? [])
        .map((e) => AdminAuditEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> clearAudit() async {
    final headers = await _authHeaders();
    final response = await _client.delete(_uri('/admin/audit'), headers: headers);
    final body = await _decode(response);
    return body['cleared'] as int? ?? 0;
  }

  Future<List<AdminVoucherRow>> listVouchers() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/vouchers'), headers: headers);
    final body = await _decode(response);
    return (body['vouchers'] as List<dynamic>? ?? [])
        .map((e) => AdminVoucherRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminVoucherRow> upsertVoucher({
    required String code,
    required int discountPercent,
    String? label,
    bool active = true,
    String? expiresAt,
    int? maxUses,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.post(
      _uri('/admin/vouchers'),
      headers: headers,
      body: jsonEncode({
        'code': code.trim(),
        'discountPercent': discountPercent,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        'active': active,
        if (expiresAt != null) 'expiresAt': expiresAt,
        if (maxUses != null) 'maxUses': maxUses,
      }),
    );
    final body = await _decode(response);
    return AdminVoucherRow.fromJson(body['voucher'] as Map<String, dynamic>);
  }

  Future<void> deleteVoucher(String code) async {
    final headers = await _authHeaders();
    final encoded = Uri.encodeComponent(code.trim().toUpperCase());
    final response = await _client.delete(_uri('/admin/vouchers/$encoded'), headers: headers);
    await _decode(response);
  }
}

final adminApiServiceProvider = Provider<AdminApiService?>((ref) {
  final endpoint = kFileEndpoint.trim();
  if (endpoint.isEmpty) return null;
  final user = ref.watch(adminAuthStateProvider).asData?.value;
  if (user == null) return null;
  return AdminApiService(
    endpoint: endpoint,
    idToken: () async {
      final token = await adminAccessToken();
      return token ?? '';
    },
  );
});

final voucherAdminServiceProvider = Provider<VoucherAdminService?>((ref) {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return null;
  return VoucherAdminService(
    endpoint: api.endpoint,
    idToken: api.idToken,
  );
});

final adminOverviewProvider = FutureProvider.family<AdminOverview, int>((ref, days) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) throw StateError('Configure NOTABLY_FILE_ENDPOINT and sign in.');
  return api.fetchOverview(days: days);
});

final adminUsersProvider = FutureProvider.family<List<AdminUserRow>, String>((ref, query) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchUsers(query: query);
});

final adminSubscriptionsProvider = FutureProvider<List<AdminSubscriptionRow>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchSubscriptions();
});

final adminPaymentsProvider = FutureProvider<List<AdminPaymentRow>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchPayments();
});

final adminDocumentsProvider = FutureProvider<List<AdminDocumentRow>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchDocuments();
});

final adminBugsProvider = FutureProvider<List<AdminBugReport>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchBugs();
});

final adminAiProvider = FutureProvider.family<AdminAiUsage, int>((ref, days) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) throw StateError('Configure NOTABLY_FILE_ENDPOINT and sign in.');
  return api.fetchAiUsage(days: days);
});

final adminTeamProvider = FutureProvider<List<AdminTeamMember>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchTeam();
});

final adminAuditProvider = FutureProvider<List<AdminAuditEntry>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.fetchAudit();
});

final adminVouchersProvider = FutureProvider<List<AdminVoucherRow>>((ref) async {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) return [];
  return api.listVouchers();
});

/// Live badge counts for the admin sidebar — refreshes every 15s.
class AdminBadgeCounts {
  const AdminBadgeCounts({
    this.openBugs = 0,
    this.activeVouchers = 0,
    this.premiumUsers = 0,
  });

  final int openBugs;
  final int activeVouchers;
  final int premiumUsers;
}

final adminBadgeCountsProvider = StreamProvider<AdminBadgeCounts>((ref) async* {
  final api = ref.watch(adminApiServiceProvider);
  if (api == null) {
    yield const AdminBadgeCounts();
    return;
  }

  Future<AdminBadgeCounts> load() async {
    try {
      final results = await Future.wait([
        api.fetchBugs(),
        api.listVouchers(),
        api.fetchSubscriptions(),
      ]);
      final bugs = results[0] as List<AdminBugReport>;
      final vouchers = results[1] as List<AdminVoucherRow>;
      final subs = results[2] as List<AdminSubscriptionRow>;
      return AdminBadgeCounts(
        openBugs: bugs
            .where((b) => b.status == 'open' || b.status == 'triaged')
            .length,
        activeVouchers: vouchers.where((v) => v.active).length,
        premiumUsers: subs.where((s) => s.isPremium).length,
      );
    } catch (_) {
      return const AdminBadgeCounts();
    }
  }

  yield await load();

  // Keep sidebar badges fresh while the admin console is open.
  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield await load();
  }
});

String formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatPhp(int amount) => '₱${amount.toString()}';

String shortUid(String uid) => uid.length <= 10 ? uid : '${uid.substring(0, 8)}…';
