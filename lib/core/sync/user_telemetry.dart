import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/supabase_bootstrap.dart';
import '../../core/sync/sync_providers.dart';

class BugReportSubmitResult {
  const BugReportSubmitResult._({required this.ok, this.error});

  const BugReportSubmitResult.success() : this._(ok: true);
  const BugReportSubmitResult.failure(String error)
      : this._(ok: false, error: error);

  final bool ok;
  final String? error;
}

/// Fire-and-forget calls to the worker for admin analytics.
abstract final class UserTelemetry {
  static Future<String?> _token() => supabaseAccessToken();

  static Future<void> heartbeat({String? displayName}) async {
    final endpoint = kFileEndpoint.trim();
    if (endpoint.isEmpty) return;
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('$endpoint/user/heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (displayName != null) 'displayName': displayName,
        }),
      );
    } catch (e) {
      debugPrint('User heartbeat failed: $e');
    }
  }

  /// Posts to the Worker; reports show up under Admin → Bug reports.
  static Future<BugReportSubmitResult> submitBugReport({
    required String category,
    required String subject,
    required String description,
    required String device,
    List<Map<String, String>> attachments = const [],
  }) async {
    final endpoint = kFileEndpoint.trim();
    if (endpoint.isEmpty) {
      return const BugReportSubmitResult.failure(
        'File endpoint is not configured (NOTABLY_FILE_ENDPOINT).',
      );
    }
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        return const BugReportSubmitResult.failure(
          'Sign in required to send a bug report.',
        );
      }
      final response = await http.post(
        Uri.parse('$endpoint/user/bug-report'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'category': category,
          'subject': subject,
          'description': description,
          'device': device,
          if (attachments.isNotEmpty) 'attachments': attachments,
        }),
      );
      if (response.statusCode < 400) {
        return const BugReportSubmitResult.success();
      }
      String message = 'Server error (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) {
          message = body['error'] as String;
        }
      } catch (_) {}
      return BugReportSubmitResult.failure(message);
    } catch (e) {
      debugPrint('Bug report submit failed: $e');
      return BugReportSubmitResult.failure('$e');
    }
  }

  static Future<void> recordAiUsage({
    required String feature,
    required int promptTokens,
    required int outputTokens,
  }) async {
    final endpoint = kFileEndpoint.trim();
    if (endpoint.isEmpty) return;
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('$endpoint/user/ai-usage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'feature': feature,
          'promptTokens': promptTokens,
          'outputTokens': outputTokens,
        }),
      );
    } catch (e) {
      debugPrint('AI usage telemetry failed: $e');
    }
  }
}
