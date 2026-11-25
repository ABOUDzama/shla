import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/voice_chat_service.dart';
import '../services/socket_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:ui';
import '../theme/funky_theme.dart';

class VoiceChatWidget extends StatefulWidget {
  final String roomCode;
  final String myId;

  const VoiceChatWidget({
    super.key,
    required this.roomCode,
    required this.myId,
  });

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget> {
  final VoiceChatService _voiceService = VoiceChatService();
  StreamSubscription? _speakingSub;
  StreamSubscription? _errorSub;
  Set<String> _currentSpeakingIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _voiceService.onStreamUpdate = () {
      if (mounted) setState(() {});
    };

    _errorSub = _voiceService.errorStream.listen((err) {
      if (mounted) setState(() => _error = err);
    });

    if (!_voiceService.isInitialized) {
       _voiceService.init(widget.roomCode, widget.myId);
    } else {
       _voiceService.makeCall(widget.roomCode, widget.myId);
    }

    _speakingSub = _voiceService.speakingStream.listen((ids) {
      if (mounted) {
        setState(() {
          _currentSpeakingIds = ids;
        });
      }
    });
  }

  @override
  void dispose() {
    _speakingSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  void _toggleMute() {
    if (_error != null) {
      _voiceService.init(widget.roomCode, widget.myId);
    } else {
      _voiceService.toggleMute();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMuted = _voiceService.isMuted;
    bool isConnected = _voiceService.remoteStream != null;
    bool isInit = _voiceService.isInitialized;
    final String myId = SocketService().socket.id ?? widget.myId;
    bool isISpeaking = _currentSpeakingIds.contains(myId) || _currentSpeakingIds.contains('me');

    return GestureDetector(
      onTap: _toggleMute,
      onLongPress: () {
        debugPrint('UI: Long press detected - forcing connection reset');
        _voiceService.resetAndRetry(widget.roomCode);
      },
      child: Stack(
        children: [
          // Hidden remote renderers (Required for audio to stay active)
          Opacity(
            opacity: 0.01,
            child: SizedBox(
              width: 1,
              height: 1,
              child: Stack(
                children: _voiceService.remoteRenderers.values.map((renderer) {
                  return RTCVideoView(renderer);
                }).toList(),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: FunkyColors.cardLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _error != null ? Icons.error_outline_rounded : (isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                  color: _error != null ? Colors.redAccent : (isMuted ? Colors.redAccent : (isISpeaking ? Colors.greenAccent : Colors.white)),
                  size: 20,
                ),
              ),
            ),
          ),
          // Connection activity dot (Minimalist)
          if (isInit && !isMuted && _error == null)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: FunkyColors.cardLight, width: 1.5),
                ),
              ).animate(onPlay: (c) => c.repeat())
               .fadeIn(duration: 500.ms)
               .fadeOut(delay: 500.ms),
            ),
        ],
      ),
    );
  }
}
