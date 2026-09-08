import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../sync/sync_providers.dart' show kFileEndpoint;
import '../../app/supabase_bootstrap.dart';

/// Talks to the Worker's `/ai/generate` instead of a model vendor.
///
/// The app used to call Google directly with `GEMINI_API_KEY` compiled into
/// the bundle — extractable from a release APK with `unzip`. Routing through
/// the Worker moves the key server-side and puts every call behind one place
/// that can cache it, cost it, and stop it when the month's budget is spent.
///
/// The client no longer picks a model. Which model answers, and what happens
/// when it is rate-limited, is the server's decision: those are the parts that
/// change with price and availability, and they should not need an app release.
class AiGatewayClient {
  AiGatewayClient({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = (endpoint ?? kFileEndpoint).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _endpoint;

  /// Whether the app can reach the gateway at all.
  bool get configured => _endpoint.isNotEmpty;

  /// Raised when the server refused on cost grounds rather than failing.
  ///
  /// Separate from a transport error because the answer is different: waiting
  /// helps, retrying immediately does not.
  static const budgetExceededCode = 'budget';

  Future<AiGatewayResult> generate({
    required String prompt,
    List<AiGatewayImage> images = const [],
    required int maxOutputTokens,
    String operation = 'quiz',
    String? documentId,
    bool json = true,
  }) async {
    if (!configured) {
      throw const AiGatewayException(
        'AI is not configured on this build (no Worker endpoint).',
      );
    }
    final token = await supabaseAccessToken();
    if (token == null) {
      throw const AiGatewayException('Sign in to generate a quiz.');
    }

    final response = await _client.post(
      Uri.parse('$_endpoint/ai/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'operation': operation,
        if (documentId != null) 'documentId': documentId,
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'json': json,
        if (images.isNotEmpty)
          'images': [
            for (final image in images)
              {'data': base64Encode(image.bytes), 'mimeType': image.mimeType},
          ],
      }),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode == 429) {
      throw AiGatewayException(
        body['error'] as String? ?? 'AI limit reached. Try again later.',
        code: budgetExceededCode,
      );
    }
    if (response.statusCode >= 400) {
      throw AiGatewayException(
        body['error'] as String? ?? 'AI request failed (${response.statusCode}).',
      );
    }

    final text = body['text'] as String? ?? '';
    if (text.isEmpty) {
      throw const AiGatewayException('The AI returned nothing.');
    }
    final cached = body['cached'] == true;
    if (kDebugMode) {
      debugPrint(
        'AI ${body['provider']}/${body['model']} '
        '${cached ? 'cache hit (free)' : 'cost \$${body['usd']}'}',
      );
    }
    return AiGatewayResult(
      text: text,
      model: body['model'] as String? ?? '',
      provider: body['provider'] as String? ?? '',
      cached: cached,
      usd: (body['usd'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Month-to-date spend and, more usefully, the cache hit rate.
  Future<Map<String, dynamic>?> usage() async {
    if (!configured) return null;
    final token = await supabaseAccessToken();
    if (token == null) return null;
    final response = await _client.get(
      Uri.parse('$_endpoint/ai/usage'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 400) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}

class AiGatewayImage {
  const AiGatewayImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class AiGatewayResult {
  const AiGatewayResult({
    required this.text,
    required this.model,
    required this.provider,
    required this.cached,
    required this.usd,
  });

  final String text;
  final String model;
  final String provider;

  /// True when the server answered from cache — this call cost nothing.
  final bool cached;
  final double usd;
}

class AiGatewayException implements Exception {
  const AiGatewayException(this.message, {this.code});

  final String message;

  /// [AiGatewayClient.budgetExceededCode] when the server stopped on cost.
  final String? code;

  bool get isBudget => code == AiGatewayClient.budgetExceededCode;

  @override
  String toString() => message;
}

/// True when this build should use the gateway rather than a bundled key.
bool get aiGatewayAvailable => kFileEndpoint.isNotEmpty;

/// The Worker this build talks to. Resolved the same way file sync resolves
/// it, so AI and file storage can never drift onto different deployments.
String get aiGatewayEndpoint => kFileEndpoint;
