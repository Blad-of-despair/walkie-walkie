import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/signaling_client.dart';
import '../services/signaling_server.dart';
import '../services/webrtc_service.dart';
import '../widgets/ptt_button.dart';
import '../widgets/user_tile.dart';

class MainScreen extends StatefulWidget {
  final String mode;
  final String nickname;
  final String? host;
  final int port;

  const MainScreen({
    super.key,
    required this.mode,
    required this.nickname,
    this.host,
    required this.port,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  SignalingServer? _server;
  late SignalingClient _client;
  late WebRTCService _webrtc;

  String? _myId;
  final List<User> _users = [];
  User? _selectedUser;
  bool _isPTT = false;
  bool _isReceiving = false;
  String _statusText = 'Connecting...';
  bool _connected = false;
  String? _receivingFromId;
  String? _hostInfo;

  StreamSubscription? _messageSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _remoteStreamSub;
  StreamSubscription? _remoteStreamRemovedSub;
  StreamSubscription? _webrtcErrorSub;

  @override
  void initState() {
    super.initState();
    _webrtc = WebRTCService();
    _client = SignalingClient();

    _setupListeners();
    _init();
  }

  Future<void> _init() async {
    if (widget.mode == 'host') {
      _server = SignalingServer();
      final started = await _server!.start(widget.port);
      if (!started && mounted) {
        _setStatus('Port ${widget.port} is in use — try a different port');
        _showToast('Failed to start server on port ${widget.port}');
        return;
      }
      // Show host IP so others can join
      try {
        final ip = await NetworkInfo().getWifiIP();
        if (mounted && ip != null) {
          setState(() => _hostInfo = '$ip:${widget.port}');
        }
      } catch (_) {}
      // Connect to self
      final ok = await _client.connect('127.0.0.1', widget.port);
      if (!ok && mounted) {
        _setStatus('Internal connection failed — restart the app');
        return;
      }
    } else {
      final ok = await _client.connect(widget.host!, widget.port);
      if (!ok && mounted) {
        _setStatus('Cannot reach ${widget.host}:${widget.port}');
        _showToast('Check the IP, port, and that both devices are on the same Wi-Fi');
        return;
      }
    }

    // Register
    _client.send(createRegister(widget.nickname));
  }

  void _setupListeners() {
    _messageSub = _client.onMessage.listen(_handleMessage);
    _connectionSub = _client.onConnectionChange.listen((connected) {
      if (mounted) {
        setState(() {
          _connected = connected;
          if (!connected) {
            _setStatus('Disconnected');
            _users.clear();
          }
        });
      }
    });

    _remoteStreamSub = _webrtc.onRemoteStream.listen((stream) {
      // Play remote audio automatically via flutter_webrtc
    });

    _remoteStreamRemovedSub = _webrtc.onRemoteStreamRemoved.listen((peerId) {
      if (mounted && _receivingFromId == peerId) {
        setState(() {
          _receivingFromId = null;
          _isReceiving = false;
        });
      }
    });

    _webrtcErrorSub = _webrtc.onError.listen((msg) {
      _showToast(msg);
    });
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = getMessageType(msg);

    switch (type) {
      case 'registered':
        setState(() {
          _myId = msg['id'] as String?;
          _connected = true;
          _setStatus('Select someone to talk to');
        });
        break;

      case 'userlist':
        final list = (msg['users'] as List)
            .cast<Map<String, dynamic>>()
            .map((j) => User.fromJson(j))
            .where((u) => u.id != _myId)
            .toList();
        setState(() {
          _users
            ..clear()
            ..addAll(list);
          // Preserve talking state
          for (final u in _users) {
            final existing = _talkingUsers
                .where((t) => t == u.id)
                .isNotEmpty;
            u.isTalking = existing;
          }
          if (_selectedUser != null) {
            final stillExists = _users.any((u) => u.id == _selectedUser!.id);
            if (!stillExists) {
              _selectedUser = _users.isNotEmpty ? _users.first : null;
              _updatePTTState();
            }
          } else if (_users.isNotEmpty) {
            _selectedUser = _users.first;
            _updatePTTState();
          } else {
            _selectedUser = null;
            _updatePTTState();
          }
        });
        break;

      case 'call-offer':
        _webrtc.handleOffer(
          peerId: msg['from'] as String,
          sdp: msg['sdp'] as Map<String, dynamic>,
          sendSignaling: (m) => _client.send(m),
        );
        break;

      case 'call-answer':
        _webrtc.handleAnswer(
          msg['from'] as String,
          msg['sdp'] as Map<String, dynamic>,
        );
        break;

      case 'ice-candidate':
        _webrtc.handleCandidate(
          msg['from'] as String,
          msg['candidate'] as Map<String, dynamic>,
        );
        break;

      case 'talking-start':
        final fromId = msg['from'] as String;
        final fromNick = msg['fromNickname'] as String? ?? 'Someone';
        final targetId = msg['target'] as String?;
        _talkingUsers.add(fromId);

        // Vibrate receiver slightly when someone talks to them
        if (targetId == _myId || fromId == _selectedUser?.id) {
          try { HapticFeedback.lightImpact(); } catch {}
        }

        setState(() {
          for (final u in _users) {
            if (u.id == fromId) u.isTalking = true;
          }
          if (fromId == _selectedUser?.id) {
            _isReceiving = true;
            _receivingFromId = fromId;
            _setStatus('🔊 $fromNick is talking...');
          } else if (targetId == _myId) {
            _receivingFromId = fromId;
            _setStatus('🔊 $fromNick is talking to you');
          } else {
            _setStatus('$fromNick is talking');
          }
        });
        break;

      case 'talking-stop':
        final fromId = msg['from'] as String;
        _talkingUsers.remove(fromId);
        setState(() {
          for (final u in _users) {
            if (u.id == fromId) u.isTalking = false;
          }
          if (_receivingFromId == fromId) {
            _receivingFromId = null;
            _isReceiving = false;
          }
          if (_talkingUsers.isEmpty) {
            _setStatus(
              _selectedUser != null
                  ? 'Target: ${_selectedUser!.nickname} — Hold to talk'
                  : 'Select someone to talk to',
            );
          }
        });
        break;

      case 'error':
        _showToast(msg['message'] as String? ?? 'Error');
        break;
    }
  }

  final Set<String> _talkingUsers = {};

  void _setStatus(String text) {
    setState(() => _statusText = text);
  }

  void _selectUser(User user) {
    if (_selectedUser?.id == user.id) return;
    setState(() {
      _selectedUser = user;
      _setStatus('Target: ${user.nickname} — Hold to talk');
    });
  }

  Future<void> _startPTT() async {
    if (_isPTT || _selectedUser == null) return;
    setState(() => _isPTT = true);

    _client.send(createTalkingStart(_selectedUser!.id));

    await _webrtc.startCall(
      peerId: _selectedUser!.id,
      sendSignaling: (m) => _client.send(m),
    );

    setState(() {
      _setStatus('🔴 Talking to ${_selectedUser!.nickname}...');
    });
  }

  void _stopPTT() {
    if (!_isPTT) return;
    setState(() => _isPTT = false);

    _client.send(createTalkingStop());

    _webrtc.endAllCalls();

    setState(() {
      _setStatus(
        _selectedUser != null
            ? 'Target: ${_selectedUser!.nickname} — Hold to talk'
            : 'Select someone to talk to',
      );
    });
  }

  void _updatePTTState() {
    setState(() {
      if (_selectedUser != null) {
        _setStatus('Target: ${_selectedUser!.nickname} — Hold to talk');
      } else {
        _setStatus('Select someone to talk to');
      }
    });
  }

  void _disconnect() {
    _stopPTT();
    _client.disconnect();
    _server?.stop();
    _webrtc.dispose();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _remoteStreamSub?.cancel();
    _remoteStreamRemovedSub?.cancel();
    _webrtcErrorSub?.cancel();
    _stopPTT();
    _client.disconnect();
    _server?.stop();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1124),
                border: Border(
                  bottom: BorderSide(color: Color(0x0AFFFFFF)),
                ),
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      const Text(
                        'WiFi Talkie',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF1F5F9),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connected
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          boxShadow: _connected
                              ? [
                                  BoxShadow(
                                    color: const Color(0x4010B981),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141628),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.nickname,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _disconnect,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Leave',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Host info banner
            if (_hostInfo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: const Color(0xFF141628),
                child: Text(
                  'Others can join at  $_hostInfo',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // User list
            Expanded(
              child: _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📡', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 12),
                          Text(
                            _connected ? 'No one else is online' : 'Connecting...',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      itemCount: _users.length + 1, // +1 for header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ONLINE',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  '${_users.length}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final user = _users[index - 1];
                        return UserTile(
                          user: user,
                          isSelected: _selectedUser?.id == user.id,
                          onTap: () => _selectUser(user),
                        );
                      },
                    ),
            ),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isPTT || _isReceiving
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _isPTT
                      ? const Color(0xFFEF4444)
                      : _isReceiving
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                ),
              ),
            ),

            // PTT button
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PttButton(
                enabled: _selectedUser != null && _connected,
                isActive: _isPTT,
                isReceiving: _isReceiving,
                targetName: _selectedUser?.nickname ?? '',
                onPress: _startPTT,
                onRelease: _stopPTT,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
