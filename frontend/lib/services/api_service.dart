import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://83zbtddxvk.execute-api.us-east-1.amazonaws.com/dev',
  );
  // AWS API Gateway key — must be supplied via --dart-define=API_KEY=xxx
  // No default — app will get 403 without this value.
  // For local dev: flutter run --dart-define=API_KEY=your_key_here
  static const apiKey = String.fromEnvironment('API_KEY');

  // Retry configuration
  static const int maxRetries      = 3;
  static const int retryBaseMs     = 500;  // 500ms base delay
  static const int retryMaxMs      = 8000; // 8s max delay
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

  // ── Tenant Registration (initial — no ARN yet) ───────────────────────────
  static Future<Map<String, dynamic>> registerTenant({
    required String name,
    required String email,
    String uid = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tenants');
    return _post(uri, {
      'name': name,
      'email': email,
      'aws_account_id': 'pending',
      'role_arn': 'pending',
      if (uid.isNotEmpty) 'uid': uid,
    });
  }

  // ── Update tenant with real ARN after AWS onboarding ─────────────────────
  static Future<Map<String, dynamic>> updateTenantArn({
    required String tenantId,
    required String roleArn,
    required String awsAccountId,
  }) async {
    // Uses the same /tenants endpoint with tenant_id to update the ARN
    final uri = Uri.parse('${ApiConfig.baseUrl}/tenants');
    return _post(uri, {
      'tenant_id':      tenantId,
      'role_arn':       roleArn,
      'aws_account_id': awsAccountId,
      'action':         'update_arn',
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _get(Uri uri) async {
    return _withRetry(() async {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parse(response);
    });
  }

  static Future<Map<String, dynamic>> _post(
      Uri uri, Map<String, dynamic> body) async {
    return _withRetry(() async {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      return _parse(response);
    }, retryOn5xx: true);
  }

  /// Retry with exponential backoff + jitter.
  /// Retries on network errors and optionally on 5xx responses.
  /// Does NOT retry on 4xx (client errors — retrying won't help).
  static Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() fn, {
    bool retryOn5xx = false,
  }) async {
    final rng = Random();
    int attempt = 0;

    while (true) {
      try {
        return await fn();
      } on ApiException catch (e) {
        // Retry on 5xx server errors if requested, but not on 4xx
        if (retryOn5xx &&
            e.statusCode != null &&
            e.statusCode! >= 500 &&
            attempt < ApiConfig.maxRetries) {
          await _backoff(attempt, rng);
          attempt++;
          continue;
        }
        rethrow;
      } catch (e) {
        // Retry on network/timeout errors
        if (attempt < ApiConfig.maxRetries) {
          await _backoff(attempt, rng);
          attempt++;
          continue;
        }
        throw ApiException('Network error after ${attempt + 1} attempts: $e');
      }
    }
  }

  /// Exponential backoff with full jitter:
  /// delay = random(0, min(maxMs, baseMs * 2^attempt))
  static Future<void> _backoff(int attempt, Random rng) async {
    final cap   = ApiConfig.retryMaxMs;
    final base  = ApiConfig.retryBaseMs;
    final delay = rng.nextInt(min(cap, base * (1 << attempt)));
    await Future.delayed(Duration(milliseconds: delay));
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