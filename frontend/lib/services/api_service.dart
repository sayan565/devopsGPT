import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  // ═══════════════════════════════════════════
  // PASTE YOUR VALUES HERE
  // ═══════════════════════════════════════════
  static const String baseUrl =
      'https://a5kwqq0t12.execute-api.us-east-1.amazonaws.com/prod1';
  // Example: 'https://abc123.execute-api.us-east-1.amazonaws.com/prod'

  static const String apiKey = 'Lxi87EXr549hbPxuLmJEV96ZBxwz2eKg1NSDNwq3';
  // Example: 'aBcDeFgHiJkLmNoPqRsTuVwXyZ123456'
  // ═══════════════════════════════════════════

  // This sends API key with every request automatically
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  // ── GET /servers ─────────────────────────────
  // Returns list of servers from DynamoDB
  static Future<List<dynamic>> getServers() async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/servers'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      // Handle both list and wrapped object
      if (decoded is List) {
        return decoded;
      } else if (decoded is Map && decoded.containsKey('Items')) {
        return decoded['Items'] as List;
      } else if (decoded is Map && decoded.containsKey('body')) {
        final body = jsonDecode(decoded['body']);
        return body is List ? body : [];
      }
      return [];
    }
    throw Exception('Failed: ${response.statusCode}');
  } catch (e) {
    throw Exception('getServers error: $e');
  }
}

  // ── GET /alerts ──────────────────────────────
  // Returns list of alerts from DynamoDB
  static Future<List<dynamic>> getAlerts() async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/alerts'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded;
      } else if (decoded is Map && decoded.containsKey('Items')) {
        return decoded['Items'] as List;
      } else if (decoded is Map && decoded.containsKey('body')) {
        final body = jsonDecode(decoded['body']);
        return body is List ? body : [];
      }
      return [];
    }
    throw Exception('Failed: ${response.statusCode}');
  } catch (e) {
    throw Exception('getAlerts error: $e');
  }
}

  // ── GET /logs ────────────────────────────────
  // Returns list of logs from DynamoDB
 static Future<List<dynamic>> getLogs() async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/logs'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded;
      } else if (decoded is Map && decoded.containsKey('Items')) {
        return decoded['Items'] as List;
      } else if (decoded is Map && decoded.containsKey('body')) {
        final body = jsonDecode(decoded['body']);
        return body is List ? body : [];
      }
      return [];
    }
    throw Exception('Failed: ${response.statusCode}');
  } catch (e) {
    throw Exception('getLogs error: $e');
  }
}

  // ── POST /ai-chat ────────────────────────────
  // Sends message to AI Lambda and gets response
  static Future<Map<String, dynamic>> sendAiMessage(
    String message) async {
  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ai-chat'),
          headers: headers,
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Handle wrapped body
      if (decoded is Map && decoded.containsKey('body')) {
        final body = decoded['body'];
        if (body is String) {
          return jsonDecode(body) as Map<String, dynamic>;
        }
        return body as Map<String, dynamic>;
      }
      return decoded as Map<String, dynamic>;
    }
    throw Exception('Failed: ${response.statusCode}');
  } catch (e) {
    throw Exception('sendAiMessage error: $e');
  }
}
// ── POST /ai-chat with conversation history ───
static Future<Map<String, dynamic>>
    sendAiMessageWithHistory(
  String message,
  List<Map<String, String>> history,
) async {
  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ai-chat'),
          headers: headers,
          body: jsonEncode({
            'message': message,
            'history': history,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map &&
          decoded.containsKey('body')) {
        final body = decoded['body'];
        if (body is String) {
          return jsonDecode(body)
              as Map<String, dynamic>;
        }
        return body as Map<String, dynamic>;
      }
      return decoded as Map<String, dynamic>;
    }
    throw Exception('Failed: ${response.statusCode}');
  } catch (e) {
    throw Exception('sendAiMessage error: $e');
  }
}

  // ── POST /fix ────────────────────────────────
  // Sends fix action to EC2 via SSM
  static Future<Map<String, dynamic>> fixServer(
      String serverId, String action) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/fix'),
            headers: headers,
            body: jsonEncode({
              'serverId': serverId,
              'action': action,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('fixServer error: $e');
    }
  }
}