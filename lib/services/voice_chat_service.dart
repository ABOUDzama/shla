import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';
import 'audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceChatService {
  static final VoiceChatService _instance = VoiceChatService._internal();
  factory VoiceChatService() => _instance;
  VoiceChatService._internal();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, List<RTCIceCandidate>> _iceQueues = {};
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isInitialized = false;
  String? _roomCode;

  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;

  // Return any remote stream to signify "connected" status in UI
  MediaStream? get remoteStream => _peerConnections.values
      .where((pc) => pc.getRemoteStreams().isNotEmpty)
      .map((pc) => pc.getRemoteStreams().first)
      .firstOrNull;

  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;

  Function()? onStreamUpdate;

  String _connectionState = 'غير متصل';
  String get connectionState => _connectionState;

  String _lastSignal = '';
  String get lastSignal => _lastSignal;

  final AudioPlayer _testPlayer = AudioPlayer();

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      // Expanded STUN list for reliability
      {'urls': 'stun:stun.services.mozilla.com'},
      {'urls': 'stun:stun.ekiga.net'},
      // Free TURN servers (some might be rate-limited but better than nothing)
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  StreamSubscription? _playerSub;
  Timer? _statsTimer;
  final _speakingController = StreamController<Set<String>>.broadcast();
  Set<String> _speakingIds = {};

  Stream<Set<String>> get speakingStream => _speakingController.stream;
  Set<String> get currentSpeakingIds => _speakingIds;

  final _errorController = StreamController<String?>.broadcast();
  Stream<String?> get errorStream => _errorController.stream;
  String? _lastError;
  String? get lastError => _lastError;

  Future<void> init(String roomCode, String myId) async {
    debugPrint(
      'WebRTC: [${DateTime.now()}] Initializing VoiceChatService for room: $roomCode, user: $myId',
    );
    if (_isInitialized && _roomCode == roomCode) {
      debugPrint('WebRTC: Already initialized for this room. Returning.');
      return;
    }
    
    // If room code changed, dispose first
    if (_isInitialized && _roomCode != roomCode) {
      debugPrint('WebRTC: Room code changed. Disposing previous session.');
      dispose();
    }

    _roomCode = roomCode;
    _lastError = null;
    _errorController.add(null);

    // Stop all background audio and set non-conflicting focus context
    AudioService.setCommunicationMode(true);
    AudioService.stopAll();

    // Permissions: On Windows/Desktop/Web, permission_handler might not be needed.
    // kIsWeb MUST BE CHECKED FIRST to avoid background crashes on web.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      debugPrint('WebRTC: Requesting microphone permission (Mobile)...');
      var status = await Permission.microphone.request();
      debugPrint('WebRTC: Permission status: $status');
      if (!status.isGranted) {
        _lastError = 'تم رفض تصريح المايكروفون';
        _errorController.add(_lastError);
        debugPrint('WebRTC: Permission denied. Aborting init.');
        return;
      }
    } else if (kIsWeb) {
      debugPrint(
        'WebRTC: Skipping permission_handler on Web (Browser handles it).',
      );
    }

    try {
      debugPrint('WebRTC: calling getUserMedia (Simplified)...');
      _localStream = await navigator.mediaDevices
          .getUserMedia({
            'audio': {
              'sampleRate':
                  24000, // Optimized for human speech (saves bandwidth)
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
              'channelCount': 1, // Mono is sufficient for voice chat
            },
            'video': false,
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('WebRTC: getUserMedia TIMEOUT after 8s');
              throw TimeoutException('تعذر الوصول للمايكروفون (انتهت المهلة)');
            },
          );

      debugPrint(
        'WebRTC: getUserMedia success. Stream ID: ${_localStream?.id}',
      );

      if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
        final track = _localStream!.getAudioTracks()[0];
        debugPrint('WebRTC: Local audio track: ${track.label}');
        track.enabled = true;
        await Helper.setMicrophoneMute(false, track);
        debugPrint('WebRTC: Local track enabled and unmuted via Helper.');
      } else {
        _lastError = 'لم يتم العثور على ميكروفون صالح';
        _errorController.add(_lastError);
        debugPrint('WebRTC: ERROR - No audio tracks in stream');
        _isInitialized = false;
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        Future.delayed(const Duration(milliseconds: 1500), () async {
          try {
            await Helper.setSpeakerphoneOn(true);
            debugPrint('WebRTC: Speakerphone set to ON (delayed 1.5s)');
          } catch (e) {
            debugPrint('WebRTC: Error setting audio configuration: $e');
          }
        });
      }

      // Ensure all local tracks are explicitly started/enabled
      _localStream?.getTracks().forEach((t) {
        t.enabled = true;
        debugPrint('WebRTC: Local track ${t.kind} enabled: true');
      });

      _setupSignaling(roomCode, myId);

      _playerSub?.cancel();
      _playerSub = SocketService().playersStream.listen((players) {
        debugPrint('WebRTC: Players updated (${players.length} players).');
        if (_isInitialized) {
          makeCall(roomCode, myId);
          _cleanupMissingPlayers(players, myId);
        }
      });

      // BRUTAL FIX: Auto-retry timer to force connections if stuck
      Timer.periodic(const Duration(seconds: 8), (timer) {
        if (!_isInitialized) return;
        final players = SocketService().currentPlayers;
        if (players.length > 1 &&
            (_connectionState.contains('نبحث') ||
                _connectionState.contains('مغلق'))) {
          debugPrint(
            'WebRTC: BRUTAL Auto-Retry triggered (Players: ${players.length}, State: $_connectionState)',
          );
          // Get roomCode from one of the players if possible (fallback)
          final roomCode = players.firstWhere(
            (p) => p.containsKey('roomCode'),
            orElse: () => {'roomCode': ''},
          )['roomCode'];
          if (roomCode.isNotEmpty) {
            makeCall(roomCode, (SocketService().socket.id ?? '').toString());
          }
        }
      });

      _isInitialized = true;
      _startStatsPolling();
      onStreamUpdate?.call();

      debugPrint('WebRTC: Initialization complete.');
      // Small delay to ensure AudioContext is settled on some Android devices
      await Future.delayed(const Duration(milliseconds: 500));
      makeCall(roomCode, myId);
    } catch (e) {
      debugPrint('WebRTC: CRITICAL ERROR during Init: $e');
      _lastError = 'خطأ في تشغيل الصوت: ${e.toString()}';
      _errorController.add(_lastError);
      _isInitialized = false;
    }
  }

  // FORCE connection reset
  void resetAndRetry(String roomCode) {
    debugPrint('WebRTC: Manual Reset requested.');
    _peerConnections.forEach((id, pc) => pc.dispose());
    _peerConnections.clear();
    _remoteRenderers.forEach((id, r) => r.dispose());
    _remoteRenderers.clear();
    _connectionState = 'جاري إعادة الضبط...';
    onStreamUpdate?.call();
    makeCall(roomCode, (SocketService().socket.id ?? '').toString());
  }

  void reset() {
    debugPrint('WebRTC: Manual Reset requested.');
    _isInitialized = false;
    _localStream?.dispose();
    _localStream = null;
    _peerConnections.forEach((_, pc) => pc.close());
    _peerConnections.clear();
    _remoteRenderers.forEach((_, r) => r.dispose());
    _remoteRenderers.clear();
    _lastError = null;
    _errorController.add(null);
    onStreamUpdate?.call();
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!_isInitialized) return;

      final Set<String> newSpeakingIds = {};

      // 1. Check Remote Peers
      for (var entry in _peerConnections.entries) {
        final pc = entry.value;
        final remoteId = entry.key;

        try {
          final stats = await pc.getStats();
          for (var report in stats) {
            if (report.type == 'inbound-rtp' &&
                report.values['kind'] == 'audio') {
              final double? audioLevel = report.values['audioLevel']
                  ?.toDouble();
              // Sensitive threshold for precise detection
              if (audioLevel != null && audioLevel > 0.005) {
                newSpeakingIds.add(remoteId);
              }
            }
          }
        } catch (e) {}
      }

      // 2. Check Local Speaking Status (if not muted)
      if (!_isMuted && _localStream != null) {
        final myId = SocketService().socket.id;
        bool detectedOutbound = false;

        for (var pc in _peerConnections.values) {
          try {
            final stats = await pc.getStats();
            for (var report in stats) {
              if (report.type == 'outbound-rtp' &&
                  report.values['kind'] == 'audio') {
                final double? audioLevel = report.values['audioLevel']
                    ?.toDouble();
                if (audioLevel != null && audioLevel > 0.01) {
                  // More sensitive local
                  detectedOutbound = true;
                  break;
                }
              }
            }
            if (detectedOutbound) break;
          } catch (_) {}
        }

        if (detectedOutbound) {
          if (myId != null) newSpeakingIds.add(myId);
          newSpeakingIds.add('me');
        } else if (_peerConnections.isEmpty) {
          // Subtle standby pulse
          if (DateTime.now().millisecond < 300) {
            newSpeakingIds.add('me');
          }
        }
      }

      if (_speakingIds.length != newSpeakingIds.length ||
          !_speakingIds.containsAll(newSpeakingIds)) {
        _speakingIds = newSpeakingIds;
        _speakingController.add(_speakingIds);
      }
    });
  }

  void toggleMute() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final track = _localStream!.getAudioTracks()[0];
      _isMuted = !_isMuted;
      track.enabled = !_isMuted;

      // Hardware-level mute signal for better OS compatibility
      try {
        await Helper.setMicrophoneMute(_isMuted, track);
        debugPrint('WebRTC: Hardware Mute set to: $_isMuted');
      } catch (e) {
        debugPrint('WebRTC: Hardware Mute failed: $e');
      }

      onStreamUpdate?.call();
    }
  }

  void _cleanupMissingPlayers(List<Map<String, dynamic>> players, String myId) {
    final activeIds = players.map((p) => p['id']?.toString() ?? '').toSet();
    final currentPeerIds = _peerConnections.keys.toList();
    for (var id in currentPeerIds) {
      if (!activeIds.contains(id)) {
        debugPrint('Cleaning up stale connection to $id');
        _removeConnection(id);
      }
    }
  }

  void _setupSignaling(String roomCode, String myId) {
    final socket = SocketService().socket;

    // Remove old listeners to avoid duplicates if re-initialized
    socket.off('webrtc_offer');
    socket.off('webrtc_answer');
    socket.off('webrtc_ice_candidate');

    socket.on('webrtc_offer', _onWebRTCOffer);
    socket.on('webrtc_answer', _onWebRTCAnswer);
    socket.on('webrtc_ice_candidate', _onWebRTCICECandidate);
    
    // V2 FALLBACK: Broad listener for generic signaling
    socket.on('signal', (data) {
      if (data['type'] == 'offer') _onWebRTCOffer(data);
      if (data['type'] == 'answer') _onWebRTCAnswer(data);
      if (data['type'] == 'candidate') _onWebRTCICECandidate(data);
    });
    debugPrint('WebRTC: Signaling listeners setup complete.');
  }

  void _onWebRTCOffer(dynamic data) async {
    final socketId = (SocketService().socket.id ?? '').toString();
    final String myId = socketId;
    final String? targetId = data['targetId']?.toString();
    final String fromId = data['callerId']?.toString() ?? 'unknown';

    _lastSignal = 'عرض من $fromId';
    debugPrint(
      'WebRTC: _onWebRTCOffer received from $fromId. Target: $targetId (Me: $myId)',
    );

    // Fallback: If targetId is missing, accept it if I'm not the sender
    bool isForMe = targetId == myId;
    if (targetId == null) {
      if (fromId != myId) {
        debugPrint(
          'WebRTC: targetId missing in offer, assuming it is for me (since I am not sender)',
        );
        isForMe = true;
      }
    }

    if (!isForMe) {
      debugPrint('WebRTC: Offer ignored - not for me.');
      return;
    }

    _connectionState = 'وصلنا عرض 📩';
    final offer = RTCSessionDescription(
      data['offer']['sdp'],
      data['offer']['type'],
    );

    // Use the stored roomCode
    final String roomCode = _roomCode ?? '';
    final pc = await _getOrCreateConnection(roomCode, myId, fromId);
    await pc.setRemoteDescription(offer);

    // Process queued candidates
    if (_iceQueues.containsKey(fromId)) {
      for (var cand in _iceQueues[fromId]!) {
        await pc.addCandidate(cand);
      }
      _iceQueues.remove(fromId);
    }

    final answer = await pc.createAnswer();
    answer.sdp = _setOpusPriority(answer.sdp!);
    await pc.setLocalDescription(answer);

    debugPrint('WebRTC: Sending answer to $fromId');
    final answerPayload = SocketService().buildRoomPayload({
      'answer': answer.toMap(),
      'callerId': myId,
      'targetId': fromId,
    });
    SocketService().socket.emit('webrtc_answer', answerPayload);
    SocketService().socket.emit('signal', {...answerPayload, 'type': 'answer'});
    _connectionState = 'متصل (عرض) ✅';
  }

  void _onWebRTCAnswer(dynamic data) async {
    final socketId = (SocketService().socket.id ?? '').toString();
    final String myId = socketId;
    final String? targetId = data['targetId']?.toString();
    final String fromId = data['callerId']?.toString() ?? 'unknown';

    _lastSignal = 'رد من $fromId';
    debugPrint(
      'WebRTC: _onWebRTCAnswer received from $fromId. Target: $targetId (Me: $myId)',
    );

    bool isForMe = targetId == myId;
    if (targetId == null && fromId != myId) isForMe = true;

    if (!isForMe) {
      debugPrint('WebRTC: Answer ignored - not for me.');
      return;
    }

    _connectionState = 'وصلنا رد 👍';
    debugPrint('WebRTC: Received ANSWER from $fromId');
    if (_peerConnections.containsKey(fromId)) {
      final pc = _peerConnections[fromId]!;
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await pc.setRemoteDescription(answer);

      // Process queued candidates
      if (_iceQueues.containsKey(fromId)) {
        for (var cand in _iceQueues[fromId]!) {
          await pc.addCandidate(cand);
        }
        _iceQueues.remove(fromId);
      }
      debugPrint('WebRTC: Remote description set (Answer).');
    } else {
      debugPrint(
        'WebRTC: WARNING - Received answer but no peer connection for $fromId',
      );
    }
  }

  void _onConnectionState(RTCPeerConnectionState state, String remoteId) {
    debugPrint('WebRTC: Connection state for $remoteId: $state');

    // Update verbose state
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _connectionState = 'متصل ✅';
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        _connectionState = 'جاري الربط...';
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _connectionState = 'فشل الاتصال';
        break;
      default:
        _connectionState = 'ننتظر...';
    }

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      // Aggressive speakerphone force
      if (!kIsWeb) {
        try {
          Helper.setSpeakerphoneOn(true);
          debugPrint('WebRTC: Speakerphone forced ON');
        } catch (e) {
          debugPrint('WebRTC: Speakerphone force failed: $e');
        }
      }
      _startAudioHeartbeat();
    }
    onStreamUpdate?.call();
  }

  void _startAudioHeartbeat() {
    if (kIsWeb) return; // Not needed on Web
    int count = 0;
    Timer.periodic(const Duration(seconds: 2), (timer) {
      Helper.setSpeakerphoneOn(true);
      count++;
      debugPrint('WebRTC: Audio Heartbeat (Speaker ON) pulse $count/10');
      if (count >= 10 || !_isInitialized) {
        timer.cancel();
      }
    });
  }

  String _setOpusPriority(String sdp) {
    // Basic SDP hack to ensure Opus is preferred
    var lines = sdp.split('\r\n');
    int mLineIndex = lines.indexWhere((l) => l.startsWith('m=audio'));
    if (mLineIndex != -1) {
      var mLine = lines[mLineIndex];
      var parts = mLine.split(' ');
      // Move 111 (Opus) to the front of codecs if it exists
      if (parts.contains('111')) {
        parts.remove('111');
        parts.insert(3, '111');
        lines[mLineIndex] = parts.join(' ');
      }
    }
    return lines.join('\r\n');
  }

  Future<void> playTestBeep() async {
    try {
      // Small beep sound to verify speaker
      await _testPlayer.play(AssetSource('sounds/message_received.mp3'));
    } catch (e) {
      debugPrint('WebRTC: Test beep failed: $e');
    }
  }

  void _onWebRTCICECandidate(dynamic data) async {
    final socketId = (SocketService().socket.id ?? '').toString();
    final String myId = socketId;
    final String? targetId = data['targetId']?.toString();
    final String fromId = data['callerId']?.toString() ?? 'unknown';

    _lastSignal = 'مرشح ICE من $fromId';
    debugPrint(
      'WebRTC: Received ICE Candidate from $fromId (Target: $targetId)',
    );

    bool isForMe = targetId == myId;
    if (targetId == null && fromId != myId) isForMe = true;

    if (!isForMe) return;
    final candidate = RTCIceCandidate(
      data['candidate']['candidate'],
      data['candidate']['sdpMid'],
      data['candidate']['sdpMLineIndex'],
    );

    final pc = _peerConnections[fromId];
    if (pc != null) {
      final remoteDesc = await pc.getRemoteDescription();
      if (remoteDesc != null) {
        await pc.addCandidate(candidate);
        debugPrint('WebRTC: ICE Candidate added.');
      } else {
        debugPrint('WebRTC: Queuing ICE Candidate (RemoteDesc not set yet).');
        _iceQueues.putIfAbsent(fromId, () => []).add(candidate);
      }
    } else {
      debugPrint('WebRTC: Queuing ICE Candidate (No PeerConnection yet).');
      _iceQueues.putIfAbsent(fromId, () => []).add(candidate);
    }
  }

  Future<RTCPeerConnection> _getOrCreateConnection(
    String roomCode,
    String myId,
    String remoteId,
  ) async {
    if (_peerConnections.containsKey(remoteId)) {
      return _peerConnections[remoteId]!;
    }

    debugPrint('WebRTC: Creating PeerConnection for $remoteId');
    final pc = await createPeerConnection(_configuration);
    _peerConnections[remoteId] = pc;

    _localStream?.getTracks().forEach((track) {
      debugPrint('WebRTC: Adding local track to PC: ${track.kind}');
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('WebRTC: Local ICE Candidate generated for $remoteId');
      final icePayload = SocketService().buildRoomPayload({
        'candidate': candidate.toMap(),
        'callerId': myId,
        'targetId': remoteId,
      });
      SocketService().socket.emit('webrtc_ice_candidate', icePayload);
      SocketService().socket.emit('signal', {...icePayload, 'type': 'candidate'});
    };

    // New method to handle connection state changes
    pc.onConnectionState = (state) {
      _onConnectionState(state, remoteId);
    };

    pc.onTrack = (RTCTrackEvent event) async {
      debugPrint(
        'WebRTC: Remote track received from $remoteId: ${event.track.kind}',
      );
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        debugPrint('WebRTC: Remote stream ID: ${stream.id}');
        if (!_remoteRenderers.containsKey(remoteId)) {
          debugPrint('WebRTC: Initializing renderer for remoteId: $remoteId');
          // Wake up tracks: Toggle enabled off then on after a tiny delay
          Future.delayed(const Duration(milliseconds: 500), () {
            stream.getTracks().forEach((track) {
              track.enabled = false;
              Future.delayed(const Duration(milliseconds: 100), () {
                track.enabled = true;
                debugPrint(
                  'WebRTC: Remote track ${track.kind} (${track.id}) WOKEN UP: true',
                );
              });
            });
          });

          final renderer = RTCVideoRenderer();
          await renderer.initialize();
          renderer.srcObject = stream;
          _remoteRenderers[remoteId] = renderer;
          debugPrint(
            'WebRTC: Renderer initialized and source set for $remoteId',
          );
        }
        onStreamUpdate?.call();
      } else {
        debugPrint('WebRTC: WARNING - onTrack triggered but no streams found.');
      }
    };

    return pc;
  }

  Future<void> makeCall(String roomCode, String myId) async {
    debugPrint('WebRTC: [makeCall] room: $roomCode, me: $myId');
    if (!_isInitialized) {
      debugPrint('WebRTC: makeCall aborted - not initialized.');
      return;
    }

    // In a Mesh, we call everyone who isn't us and has a 'higher' ID to avoid collisions
    // (Polite Peer implementation)
    final players = SocketService().currentPlayers;
    debugPrint('WebRTC: makeCall - Players in room: ${players.length}');

    // Politeness Rule + Brutal Force:
    // Usually only higher ID calls lower ID.
    // BRUTAL FIX: If we have been searching for too long, just call everyone.
    bool forceCallAll = _connectionState.contains('نبحث');

    if (players.length <= 1) {
      _connectionState = 'نبحث عن لاعبين...';
      onStreamUpdate?.call();
    }

    for (var player in players) {
      final String peerId = player['id']?.toString() ?? '';
      if (peerId.isEmpty || peerId == myId) continue;

      // Traditional Mesh Politeness logic
      bool shouldCall = myId.compareTo(peerId) > 0;
      if (forceCallAll) shouldCall = true;

      if (shouldCall && !_peerConnections.containsKey(peerId)) {
        debugPrint(
          'WebRTC: Initiating offer to $peerId (ForceAll: $forceCallAll)',
        );
        _connectionState = 'جاري إرسال عرض...';
        onStreamUpdate?.call();
        final pc = await _getOrCreateConnection(roomCode, myId, peerId);
        final offer = await pc.createOffer();
        offer.sdp = _setOpusPriority(offer.sdp!);
        await pc.setLocalDescription(offer);

        final payload = SocketService().buildRoomPayload({
          'offer': offer.toMap(),
          'callerId': myId,
          'targetId': peerId,
        });
        debugPrint('WebRTC: Sending offer payload: $payload');
        SocketService().socket.emit('webrtc_offer', payload);
        SocketService().socket.emit('signal', {...payload, 'type': 'offer'});
        debugPrint('WebRTC: Offer emitted to $peerId');
      } else {
        debugPrint(
          'WebRTC: Politeness rule -> Waiting for $peerId to initiate (or already connected)',
        );
      }
    }
  }

  void _removeConnection(String remoteId) {
    _peerConnections[remoteId]?.dispose();
    _peerConnections.remove(remoteId);
    _remoteRenderers[remoteId]?.dispose();
    _remoteRenderers.remove(remoteId);
    onStreamUpdate?.call();
  }

  void dispose() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _speakingIds.clear();

    _playerSub?.cancel();
    _playerSub = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    for (var pc in _peerConnections.values) {
      pc.close();
      pc.dispose();
    }
    _peerConnections.clear();

    for (var renderer in _remoteRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _remoteRenderers.clear();

    AudioService.setCommunicationMode(false);
    _isInitialized = false;

    final socket = SocketService().socket;
    socket.off('webrtc_offer', _onWebRTCOffer);
    socket.off('webrtc_answer', _onWebRTCAnswer);
    socket.off('webrtc_ice_candidate', _onWebRTCICECandidate);
  }
}
