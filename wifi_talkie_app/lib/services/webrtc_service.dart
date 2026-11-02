import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final Map<String, RTCPeerConnection> _peers = {};
  MediaStream? _localStream;
  bool _hasMicPermission = false;

  final StreamController<MediaStream> _onRemoteStream =
      StreamController<MediaStream>.broadcast();
  final StreamController<String> _onRemoteStreamRemoved =
      StreamController<String>.broadcast();
  final StreamController<String> _onError =
      StreamController<String>.broadcast();

  Stream<MediaStream> get onRemoteStream => _onRemoteStream.stream;
  Stream<String> get onRemoteStreamRemoved => _onRemoteStreamRemoved.stream;
  Stream<String> get onError => _onError.stream;
  bool get hasLocalStream => _localStream != null;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<bool> initMic() async {
    try {
      final mediaDevices = navigator.mediaDevices;
      _localStream = await mediaDevices.getUserMedia({'audio': true, 'video': false});
      _hasMicPermission = true;
      return true;
    } catch (e) {
      _hasMicPermission = false;
      _onError.add('Microphone access denied');
      return false;
    }
  }

  Future<void> startCall({
    required String peerId,
    required void Function(Map<String, dynamic>) sendSignaling,
  }) async {
    await _ensureLocalStream();
    if (_localStream == null) return;

    _cleanupPeer(peerId);

    final pc = await _createPeerConnection();
    _peers[peerId] = pc;

    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        sendSignaling({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _cleanupPeer(peerId);
      }
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio') {
        _onRemoteStream.add(event.streams[0]);
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    sendSignaling({
      'type': 'call-offer',
      'sdp': pc.localDescription?.toMap(),
    });
  }

  Future<void> handleOffer({
    required String peerId,
    required Map<String, dynamic> sdp,
    required void Function(Map<String, dynamic>) sendSignaling,
  }) async {
    _cleanupPeer(peerId);

    final pc = await _createPeerConnection();
    _peers[peerId] = pc;

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        sendSignaling({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _cleanupPeer(peerId);
      }
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio') {
        _onRemoteStream.add(event.streams[0]);
      }
    };

    await pc.setRemoteDescription(RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    sendSignaling({
      'type': 'call-answer',
      'sdp': pc.localDescription?.toMap(),
    });
  }

  Future<void> handleAnswer(String peerId, Map<String, dynamic> sdp) async {
    final pc = _peers[peerId];
    if (pc != null && pc.remoteDescription == null) {
      await pc.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?),
      );
    }
  }

  Future<void> handleCandidate(String peerId, Map<String, dynamic> candidate) async {
    final pc = _peers[peerId];
    if (pc != null) {
      await pc.addCandidate(RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    }
  }

  void endCall(String peerId) {
    _cleanupPeer(peerId);
  }

  void endAllCalls() {
    for (final id in _peers.keys.toList()) {
      _cleanupPeer(id);
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    return await createPeerConnection(_iceServers);
  }

  Future<void> _ensureLocalStream() async {
    if (_localStream == null) {
      await initMic();
    }
    // Re-acquire if tracks are ended
    if (_localStream != null) {
      final active = _localStream!.getAudioTracks().any((t) => t.enabled);
      if (!active) {
        await initMic();
      }
    }
  }

  void _cleanupPeer(String peerId) {
    final pc = _peers.remove(peerId);
    if (pc != null) {
      pc.close();
      _onRemoteStreamRemoved.add(peerId);
    }
  }

  void stopLocalStream() {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      _localStream = null;
    }
  }

  void dispose() {
    endAllCalls();
    stopLocalStream();
    _onRemoteStream.close();
    _onRemoteStreamRemoved.close();
    _onError.close();
  }
}
