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
  // Current tenant id — set after login/signup
  static String currentTenantId = '';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': ApiConfig.apiKey,
  };

  // ── Servers ──────────────────────────────────────────────
  static Future<List<dynamic>> getServers({String? tenantId}) async {
    final tid = tenantId ?? currentTenantId;
    final uri = Uri.parse('${ApiConfig.baseUrl}/servers').replace(
      queryParameters: tid.isNotEmpty ? {'tenant_id': tid} : null,
    );
    final res = await _get(uri);
    return res['servers'] ?? [];
  }

  // ── Alerts ───────────────────────────────────────────────
  static Future<List<dynamic>> getAlerts({String? tenantId}) async {
    final tid = tenantId ?? currentTenantId;
    final uri = Uri.parse('${ApiConfig.baseUrl}/alerts').replace(
      queryParameters: tid.isNotEmpty ? {'tenant_id': tid} : null,
    );
    final res = await _get(uri);
    return res['alerts'] ?? [];
  }

  // ── Logs ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLogs({String? prefix, String? tenantId}) async {
    final params = <String, String>{};
    final tid = tenantId ?? currentTenantId;
    if (tid.isNotEmpty) params['tenant_id'] = tid;
    if (prefix != null) params['prefix'] = prefix;
    final uri = Uri.parse('${ApiConfig.baseUrl}/logs').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _get(uri);
  }

  // ── Tenant Registration ───────────────────────────────────
  static Future<Map<String, dynamic>> registerTenant({
    required String name,
    required String email,
    required String uid,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tenants');
    return _post(uri, {
      'name': name,
      'email': email,
      'aws_account_id': '',
      'role_arn': '',
      'uid': uid,
    });
  }

  // ── AI Chat ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendAiMessage(
    String message, {
    String? tenantId,
    String? sessionId,
    Map<String, dynamic>? contextData,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-chat');
    return _post(uri, {
      'message': message,
      'tenant_id': ?tenantId,
      'session_id': ?sessionId,
      'context': ?contextData,
    });
  }

  // ── AI Chat with history ──────────────────────────────────
  static Future<Map<String, dynamic>> sendAiMessageWithHistory(
    String message,
    List<Map<String, dynamic>> history, {
    String? tenantId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ai-chat');
    return _post(uri, {
      'message': message,
      'history': history,
      'tenant_id': ?tenantId,
    });
  }

  // ── Auto-Fix ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> triggerFix(
    String instanceId,
    String action, {
    String? tenantId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/fix');
    return _post(uri, {
      'instance_id': instanceId,
      'action': action,
      'tenant_id': ?tenantId,
    });
  }

  // ── Fix Server (alias) ────────────────────────────────────
  static Future<Map<String, dynamic>> fixServer(
    String instanceId,
    String action, {
    String? tenantId,
  }) async {
    return triggerFix(instanceId, action, tenantId: tenantId);
  }

  // ── Private helpers ───────────────────────────────────────
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