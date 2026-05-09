import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  // ── Replace with your real WebSocket URL when ready ──
  static const String wsUrl =
      'wss://zotz37x8f2.execute-api.us-east-1.amazonaws.com/production';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;
  bool _enabled  = true; // URL is set — enabled by default

  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  void connect() {
    // Skip connection if disabled
    if (!_enabled) return;
    if (_disposed) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _subscription = _channel!.stream.listen(
        (data) {
          if (_disposed) return;
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              _controller.add(decoded);
            }
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('WebSocket error: $e');
          _reconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed — reconnecting');
          _reconnect();
        },
        cancelOnError: false,
      );
      debugPrint('WebSocket connected!');
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    if (_disposed || !_enabled) return;
    _subscription?.cancel();
    _channel = null;
    Future.delayed(const Duration(seconds: 3), connect);
  }

  /// Call this once you have a real WebSocket URL to enable live updates.
  void enable() {
    _enabled = true;
    connect();
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }
}

// Global singleton instance
final wsService = WebSocketService();

// ignore: avoid_print
void debugPrint(String msg) => print(msg);
