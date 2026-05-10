import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://83zbtddxvk.execute-api.us-east-1.amazonaws.com/dev',
  );
  static const apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
}

class ApiService {
  // ── Set this after login — every call uses it automatically ──────────────
  static String currentTenantId = '';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': ApiConfig.apiKey,
  };

  // Builds query params and auto-injects tenant_id if set
  static Map<String, String> _params([Map<String, String>? extra]) {
    final p = <String, String>{};
    if (currentTenantId.isNotEmpty) p['tenant_id'] = currentTenantId;
    if (extra != null) p.addAll(extra);
    return p;
  }

  // ── Tenant lookup by email (called right after login) ────────────────────
  static Future<Map<String, dynamic>> getTenantByEmail(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tenants-lookup')
        .replace(queryParameters: {'email': email});
    return _get(uri);
  }

  // ── Servers ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getServers() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/servers')
        .replace(queryParameters: _params());
    final res = await _get(uri);
    return res['servers'] ?? [];
  }

  // ── Alerts ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getAlerts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/alerts')
        .replace(queryParameters: _params());
    final res = await _get(uri);
    return res['alerts'] ?? [];
  }

  // ── Logs ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLogs({String? prefix}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/logs').replace(
      queryParameters: _params(prefix != null ? {'prefix': prefix} : null),
    );
    return _get(uri);
  }

  // ── AI Chat ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendAiMessage(
    String message, {
    String? sessionId,
    Map<String, dynamic>? contextData,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-chat');
    return _post(uri, {
      'message': message,
      if (currentTenantId.isNotEmpty) 'tenant_id': currentTenantId,
      if (sessionId != null)   'session_id': sessionId,
      if (contextData != null) 'context': contextData,
    });
  }

  // ── AI Chat with history ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendAiMessageWithHistory(
    String message,
    List<Map<String, dynamic>> history,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-chat');
    return _post(uri, {
      'message': message,
      'history': history,
      if (currentTenantId.isNotEmpty) 'tenant_id': currentTenantId,
    });
  }

  // ── Auto-Fix ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> triggerFix(
    String instanceId,
    String action,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/fix');
    return _post(uri, {
      'instance_id': instanceId,
      'action': action,
      if (currentTenantId.isNotEmpty) 'tenant_id': currentTenantId,
    });
  }

  // ── Fix Server (alias) ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fixServer(
      String instanceId, String action) async {
    return triggerFix(instanceId, action);
  }

  // ── Tenant Registration ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerTenant({
    required String name,
    required String email,
    String uid = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tenants');
    return _post(uri, {
      'name': name,
      'aws_account_id': '',
      'role_arn': '',
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> _post(
      Uri uri, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      return _parse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  static Map<String, dynamic> _parse(http.Response response) {
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