import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SignalingClient {
  WebSocket? _ws;
  String? _host;
  int? _port;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  bool get isConnected => _ws?.readyState == WebSocket.open;

  Future<bool> connect(String host, int port) async {
    _host = host;
    _port = port;
    try {
      _ws = await WebSocket.connect('ws://$host:$port');
      _ws!.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _connectionController.add(false);
        },
        onError: (_) {
          _connectionController.add(false);
        },
      );
      _connectionController.add(true);
      return true;
    } catch (e) {
      _connectionController.add(false);
      return false;
    }
  }

  void send(Map<String, dynamic> msg) {
    if (_ws?.readyState == WebSocket.open) {
      _ws!.add(jsonEncode(msg));
    }
  }

  void disconnect() {
    _ws?.close();
    _ws = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
