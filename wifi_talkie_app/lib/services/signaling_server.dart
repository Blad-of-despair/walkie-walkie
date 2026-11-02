import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../models/user.dart';

class SignalingServer {
  HttpServer? _server;
  final Map<WebSocket, _ClientInfo> _clients = {};
  int _port = 0;

  int get port => _port;

  Future<bool> start(int port) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _port = port;
      _server!.listen(_handleRequest);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(_handleConnection);
    } else {
      request.response.statusCode = 404;
      request.response.close();
    }
  }

  void _handleConnection(WebSocket ws) {
    final id = _generateId();
    _clients[ws] = _ClientInfo(id: id, nickname: null);

    ws.listen(
      (data) => _handleMessage(ws, data),
      onDone: () => _removeClient(ws),
      onError: (_) => _removeClient(ws),
    );
  }

  void _handleMessage(WebSocket ws, dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final client = _clients[ws];
    if (client == null) return;

    final type = msg['type'] as String?;

    switch (type) {
      case 'register':
        client.nickname = msg['nickname'] as String?;
        _send(ws, {'type': 'registered', 'id': client.id});
        _broadcastUserList();
        break;

      case 'call-offer':
        _forwardTo(client, msg['target'] as String?, {
          'type': 'call-offer',
          'from': client.id,
          'fromNickname': client.nickname,
          'sdp': msg['sdp'],
        });
        break;

      case 'call-answer':
        _forwardTo(client, msg['target'] as String?, {
          'type': 'call-answer',
          'from': client.id,
          'sdp': msg['sdp'],
        });
        break;

      case 'ice-candidate':
        _forwardTo(client, msg['target'] as String?, {
          'type': 'ice-candidate',
          'from': client.id,
          'candidate': msg['candidate'],
        });
        break;

      case 'talking-start': {
        String? targetNick;
        for (final c in _clients.values) {
          if (c.id == msg['target']) {
            targetNick = c.nickname;
            break;
          }
        }
        _broadcastExcept(ws, {
          'type': 'talking-start',
          'from': client.id,
          'fromNickname': client.nickname,
          'target': msg['target'],
          'targetNickname': targetNick,
        });
        break;
      }

      case 'talking-stop':
        _broadcastExcept(ws, {
          'type': 'talking-stop',
          'from': client.id,
        });
        break;
    }
  }

  void _forwardTo(_ClientInfo sender, String? targetId, Map<String, dynamic> msg) {
    for (final entry in _clients.entries) {
      if (entry.value.id == targetId && entry.key.readyState == WebSocket.open) {
        _send(entry.key, msg);
        return;
      }
    }
    for (final entry in _clients.entries) {
      if (entry.value.id == sender.id && entry.key.readyState == WebSocket.open) {
        _send(entry.key, {'type': 'error', 'message': 'Target user unavailable'});
        break;
      }
    }
  }

  void _broadcastExcept(WebSocket sender, Map<String, dynamic> msg) {
    for (final entry in _clients.entries) {
      if (entry.key != sender && entry.key.readyState == WebSocket.open) {
        _send(entry.key, msg);
      }
    }
  }

  void _broadcastUserList() {
    final users = <Map<String, dynamic>>[];
    for (final c in _clients.values) {
      if (c.nickname != null) {
        users.add({'id': c.id, 'nickname': c.nickname});
      }
    }
    final msg = {'type': 'userlist', 'users': users};
    for (final entry in _clients.entries) {
      if (entry.key.readyState == WebSocket.open) {
        _send(entry.key, msg);
      }
    }
  }

  void _send(WebSocket ws, Map<String, dynamic> msg) {
    ws.add(jsonEncode(msg));
  }

  void _removeClient(WebSocket ws) {
    _clients.remove(ws);
    _broadcastUserList();
  }

  String _generateId() {
    final bytes = List<int>.generate(8, (_) => Random().nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void stop() {
    for (final ws in _clients.keys) {
      ws.close();
    }
    _clients.clear();
    _server?.close();
    _server = null;
  }
}

class _ClientInfo {
  final String id;
  String? nickname;

  _ClientInfo({required this.id, this.nickname});
}
