import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket URL from --dart-define at build time.
/// flutter run --dart-define=WS_URL=wss://xxxx.execute-api.us-east-1.amazonaws.com/prod
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

  final List<Function(Map<String, dynamic>)> _listeners = [];

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
            for (final listener in _listeners) {
              listener(payload);
            }
          } catch (e) {
            print('[WebSocket] parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('[WebSocket] disconnected');
        },
        onError: (e) {
          _isConnected = false;
          print('[WebSocket] error: $e');
        },
      );
    } catch (e) {
      _isConnected = false;
      print('[WebSocket] connect failed: $e');
    }
  }

  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    _listeners.clear();
  }
}