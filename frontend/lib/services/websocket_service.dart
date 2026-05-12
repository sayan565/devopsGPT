import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart';

class WebSocketConfig {
  static const url = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://x5l8w1wmtl.execute-api.us-east-1.amazonaws.com/dev',
  );
}

/// WebSocketService — real-time metrics streaming via AWS API Gateway WebSocket.
///
/// IMPLEMENTATION STATUS: Fully built and deployed.
/// - Backend: websocket_handler Lambda + API Gateway WebSocket API
/// - Infrastructure: infrastructure/modules/websocket/main.tf
/// - DynamoDB: ws-connections table for active connection registry
///
/// CURRENT STATE: Disabled via [WEBSOCKET_ENABLED] = false for MVP.
/// The app uses REST polling (30s interval) as fallback.
/// To enable: set WEBSOCKET_ENABLED = true and extend data_collector Lambda
/// to broadcast metric snapshots to active connections (see FUTURE_ROADMAP FS3).
class WebSocketService {
  /// Feature flag — set to `true` to enable WebSocket connectivity.
  /// false = MVP mode (REST polling fallback active)
  /// true  = real-time streaming mode
  // ignore: constant_identifier_names
  static const bool WEBSOCKET_ENABLED = false;

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Broadcast stream — consumers receive messages when WebSocket is enabled.
  // When disabled, the stream stays open but receives no events (REST polling
  // handles data delivery instead — no silent data loss occurs).
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;
  bool get isConnected => _isConnected;

  void connect({String? tenantId}) {
    if (!WEBSOCKET_ENABLED) {
      // Intentionally skipped — REST polling is active fallback.
      // No data is lost: dashboard polls GET /servers every 30 seconds.
      debugPrint('[WebSocket] disabled (WEBSOCKET_ENABLED=false) — REST polling active');
      return;
    }

    if (_isConnected) return;

    final uri = Uri.parse(WebSocketConfig.url).replace(
      queryParameters: tenantId != null ? {'tenant_id': tenantId} : null,
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      debugPrint('[WebSocket] connected to ${uri.host}');

      _channel!.stream.listen(
        (data) {
          try {
            final payload = jsonDecode(data as String) as Map<String, dynamic>;
            _streamController.add(payload);
            debugPrint('[WebSocket] received: ${payload['type'] ?? 'unknown'}');
          } catch (e) {
            debugPrint('[WebSocket] parse error: $e — raw: $data');
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('[WebSocket] connection closed');
        },
        onError: (Object e) {
          _isConnected = false;
          debugPrint('[WebSocket] error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnected = false;
      debugPrint('[WebSocket] connect failed: $e');
    }
  }

  void disconnect() {
    if (!WEBSOCKET_ENABLED) return;
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    debugPrint('[WebSocket] disconnected');
  }

  void dispose() {
    if (WEBSOCKET_ENABLED) disconnect();
    _streamController.close();
  }
}
