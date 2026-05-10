import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart';

class WebSocketConfig {
  static const url = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://REPLACE_ME.execute-api.us-east-1.amazonaws.com/prod',
  );
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  // ← FIXED: added StreamController so .stream works
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;
  bool get isConnected => _isConnected;

  void connect({String? tenantId}) {
    if (_isConnected) return;
    final uri = Uri.parse(WebSocketConfig.url).replace(
      queryParameters: tenantId != null ? {'tenant_id': tenantId} : null,
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _channel!.stream.listen(
        (data) {
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
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _streamController.close();
  }
}