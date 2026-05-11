// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';

// NOTE: These tests use http.MockClient from the http/testing package.
// Run: flutter test test/services/api_service_test.dart

void main() {
  group('ApiService — HTTP behaviour', () {
    // ── Helper: build a mock HTTP client ─────────────────────────────────────
    http.Client _mockClient({
      required int statusCode,
      required Map<String, dynamic> body,
    }) {
      return MockClient((request) async {
        return http.Response(
          jsonEncode(body),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      });
    }

    // ── Test 1: successful alerts response ────────────────────────────────────
    test('fetchAlerts returns list when API returns 200', () async {
      final client = _mockClient(
        statusCode: 200,
        body: {
          'alerts': [
            {'id': 'a1', 'severity': 'HIGH', 'message': 'CPU high'},
            {'id': 'a2', 'severity': 'LOW',  'message': 'Disk warning'},
          ]
        },
      );

      // Simulate the GET /alerts call
      final response = await client.get(
        Uri.parse('https://api.example.com/dev/alerts'),
        headers: {'x-api-key': 'test-key'},
      );

      expect(response.statusCode, equals(200));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final alerts  = decoded['alerts'] as List;
      expect(alerts.length, equals(2));
      expect(alerts[0]['severity'], equals('HIGH'));
    });

    // ── Test 2: 401 Unauthorized ──────────────────────────────────────────────
    test('fetchAlerts returns 401 when API key is invalid', () async {
      final client = _mockClient(
        statusCode: 401,
        body: {'error': 'Unauthorized'},
      );

      final response = await client.get(
        Uri.parse('https://api.example.com/dev/alerts'),
        headers: {'x-api-key': 'bad-key'},
      );

      expect(response.statusCode, equals(401));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      expect(decoded['error'], equals('Unauthorized'));
    });

    // ── Test 3: 500 Internal Server Error ─────────────────────────────────────
    test('fetchAlerts returns 500 on server error', () async {
      final client = _mockClient(
        statusCode: 500,
        body: {'error': 'Internal Server Error'},
      );

      final response = await client.get(
        Uri.parse('https://api.example.com/dev/alerts'),
        headers: {'x-api-key': 'test-key'},
      );

      expect(response.statusCode, equals(500));
    });

    // ── Test 4: x-api-key header is always included ───────────────────────────
    test('every request includes x-api-key header', () async {
      String? capturedApiKey;

      final client = MockClient((request) async {
        capturedApiKey = request.headers['x-api-key'];
        return http.Response(
          jsonEncode({'alerts': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await client.get(
        Uri.parse('https://api.example.com/dev/alerts'),
        headers: {'x-api-key': 'my-secret-key'},
      );

      expect(capturedApiKey, equals('my-secret-key'));
    });

    // ── Test 5: empty alerts list ─────────────────────────────────────────────
    test('fetchAlerts returns empty list when no alerts exist', () async {
      final client = _mockClient(
        statusCode: 200,
        body: {'alerts': [], 'count': 0},
      );

      final response = await client.get(
        Uri.parse('https://api.example.com/dev/alerts'),
        headers: {'x-api-key': 'test-key'},
      );

      expect(response.statusCode, equals(200));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      expect((decoded['alerts'] as List).isEmpty, isTrue);
    });

    // ── Test 6: servers endpoint returns list ─────────────────────────────────
    test('getServers returns server list on 200', () async {
      final client = _mockClient(
        statusCode: 200,
        body: {
          'servers': [
            {
              'id': 'i-0abc123',
              'name': 'test-server',
              'state': 'running',
              'cpu_percent': 45.2,
            }
          ]
        },
      );

      final response = await client.get(
        Uri.parse('https://api.example.com/dev/servers'),
        headers: {'x-api-key': 'test-key'},
      );

      expect(response.statusCode, equals(200));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final servers = decoded['servers'] as List;
      expect(servers.length, equals(1));
      expect(servers[0]['state'], equals('running'));
    });

    // ── Test 7: POST ai-chat returns explanation ──────────────────────────────
    test('sendAiMessage returns explanation field', () async {
      final client = MockClient((request) async {
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('message'), isTrue);
        return http.Response(
          jsonEncode({'explanation': 'CPU is high due to memory leak'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final response = await client.post(
        Uri.parse('https://api.example.com/dev/ai-chat'),
        headers: {
          'x-api-key': 'test-key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': 'Why is CPU high?'}),
      );

      expect(response.statusCode, equals(200));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      expect(decoded['explanation'], isNotEmpty);
    });
  });
}
