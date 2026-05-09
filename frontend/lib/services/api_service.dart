import 'dart:convert';
import 'package:http/http.dart' as http;

/// All config comes from --dart-define at build time.
/// Never hardcode API keys or URLs in source code.
///
/// Run: flutter run \
///   --dart-define=API_BASE_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/prod \
///   --dart-define=API_KEY=your-api-gateway-key
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://REPLACE_ME.execute-api.us-east-1.amazonaws.com/prod',
  );
  static const apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': ApiConfig.apiKey,
      };

  // ── Servers ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getServers({String? tenantId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/servers').replace(
      queryParameters: tenantId != null ? {'tenant_id': tenantId} : null,
    );
    return _get(uri);
  }

  // ── Alerts ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getAlerts({String? tenantId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/alerts').replace(
      queryParameters: tenantId != null ? {'tenant_id': tenantId} : null,
    );
    return _get(uri);
  }

  // ── Logs ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLogs({String? prefix, String? tenantId}) async {
    final params = <String, String>{};
    if (tenantId != null) params['tenant_id'] = tenantId;
    if (prefix != null) params['prefix'] = prefix;
    final uri = Uri.parse('${ApiConfig.baseUrl}/logs').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _get(uri);
  }

  // ── AI Chat ───────────────────────────────────────────────
  Future<Map<String, dynamic>> sendAiMessage(
    String message, {
    String? tenantId,
    String? sessionId,
    Map<String, dynamic>? contextData,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-chat');
    return _post(uri, {
      'message': message,
      if (tenantId != null) 'tenant_id': tenantId,
      if (sessionId != null) 'session_id': sessionId,
      if (contextData != null) 'context': contextData,
    });
  }

  // ── Auto-Fix ──────────────────────────────────────────────
  Future<Map<String, dynamic>> triggerFix(
    String instanceId,
    String action, {
    String? tenantId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/fix');
    return _post(uri, {
      'instance_id': instanceId,
      'action': action,
      if (tenantId != null) 'tenant_id': tenantId,
    });
  }

  // ── Private helpers ───────────────────────────────────────
  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      return _parse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Map<String, dynamic> _parse(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['error'] ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'ApiException($statusCode): $message'
      : 'ApiException: $message';
}