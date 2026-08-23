import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/sync/sync_providers.dart';

class VoucherValidation {
  const VoucherValidation({
    required this.valid,
    required this.code,
    this.discountRate,
    this.label,
  });

  final bool valid;
  final String code;
  final double? discountRate;
  final String? label;

  factory VoucherValidation.fromJson(Map<String, dynamic> json) {
    return VoucherValidation(
      valid: json['valid'] as bool? ?? false,
      code: json['code'] as String? ?? '',
      discountRate: (json['discountRate'] as num?)?.toDouble(),
      label: json['label'] as String?,
    );
  }
}

class AdminVoucherRow {
  const AdminVoucherRow({
    required this.code,
    required this.discountRate,
    required this.active,
    required this.createdAt,
    required this.usedCount,
    this.label,
    this.expiresAt,
    this.maxUses,
  });

  final String code;
  final double discountRate;
  final String? label;
  final bool active;
  final String createdAt;
  final String? expiresAt;
  final int? maxUses;
  final int usedCount;

  int get discountPercent => (discountRate * 100).round();

  factory AdminVoucherRow.fromJson(Map<String, dynamic> json) {
    return AdminVoucherRow(
      code: json['code'] as String,
      discountRate: (json['discountRate'] as num).toDouble(),
      label: json['label'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      maxUses: json['maxUses'] as int?,
      usedCount: json['usedCount'] as int? ?? 0,
    );
  }
}

Future<VoucherValidation?> validateVoucherCode(String rawCode) async {
  final endpoint = kFileEndpoint.trim();
  if (endpoint.isEmpty) return null;
  final code = rawCode.trim();
  if (code.isEmpty) {
    return const VoucherValidation(valid: false, code: '');
  }

  final uri = Uri.parse('$endpoint/billing/vouchers/validate').replace(
    queryParameters: {'code': code},
  );
  final response = await http.get(uri, headers: {'Accept': 'application/json'});
  final body = jsonDecode(response.body);
  if (response.statusCode >= 400 || body is! Map<String, dynamic>) {
    return VoucherValidation(valid: false, code: code.toUpperCase());
  }
  return VoucherValidation.fromJson(body);
}

class VoucherAdminService {
  VoucherAdminService({
    required this.endpoint,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final Future<String> Function() idToken;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$endpoint$path');

  Future<Map<String, String>> _authHeaders() async {
    final token = await idToken();
    if (token.isEmpty) throw StateError('Sign in required.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<AdminVoucherRow>> listVouchers() async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri('/admin/vouchers'), headers: headers);
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Could not load vouchers.');
    }
    final list = (body as Map<String, dynamic>)['vouchers'] as List<dynamic>? ?? [];
    return list
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
    bool clearMaxUses = false,
    bool clearExpiresAt = false,
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
        if (clearExpiresAt)
          'expiresAt': null
        else if (expiresAt != null)
          'expiresAt': expiresAt,
        if (clearMaxUses)
          'maxUses': null
        else if (maxUses != null)
          'maxUses': maxUses,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Could not save voucher.');
    }
    return AdminVoucherRow.fromJson(
      (body as Map<String, dynamic>)['voucher'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteVoucher(String code) async {
    final headers = await _authHeaders();
    final encoded = Uri.encodeComponent(code.trim().toUpperCase());
    final response = await _client.delete(
      _uri('/admin/vouchers/$encoded'),
      headers: headers,
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Could not delete voucher.');
    }
  }
}
