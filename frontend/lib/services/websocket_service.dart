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
/// NOTE: WebSocket support is currently OUT OF SCOPE for the MVP release.
/// The feature is fully implemented below but gated behind [WEBSOCKET_ENABLED].
/// Set [WEBSOCKET_ENABLED] to `true` and configure [WebSocketConfig.url] when
/// the WebSocket API Gateway endpoint is provisioned and ready for use.
///
/// See FUTURE_ROADMAP.md → FS2 for the planned enablement sprint.
class WebSocketService {
  /// Feature flag — set to `true` to enable WebSocket connectivity.
  /// Currently disabled: WebSocket is out of scope for the MVP.
  static const bool WEBSOCKET_ENABLED = false;

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  // StreamController so .stream works regardless of connection state
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;
  bool get isConnected => _isConnected;

  void connect({String? tenantId}) {
    // Guard: WebSocket is disabled for the current release.
    if (!WEBSOCKET_ENABLED) {
      debugPrint('[WebSocket] WEBSOCKET_ENABLED=false — connection skipped');
      return;
    }

    if (_isConnected) return;
    final uri = Uri.parse(WebSocketConfig.url).replace(
      queryParameters: tenantId != null ? {'tenant_id': tenantId} : null,
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _channel!.stream.listen(
        (data) {
          if (!WEBSOCKET_ENABLED) return;
          try {
            final payload = jsonDecode(data as String) as Map<String, dynamic>;
            _streamController.add(payload);
          } catch (e) {
            debugPrint('[WebSocket] parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('[WebSocket] disconnected');
        },
        onError: (e) {
          _isConnected = false;
          debugPrint('[WebSocket] error: $e');
        },
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
  }

  void dispose() {
    if (WEBSOCKET_ENABLED) {
      disconnect();
    }
    _streamController.close();
  }
}