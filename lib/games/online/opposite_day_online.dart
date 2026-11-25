import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

class OppositeDayOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const OppositeDayOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<OppositeDayOnline> createState() => _OppositeDayOnlineState();
}

class _OppositeDayOnlineState extends State<OppositeDayOnline>
    with TickerProviderStateMixin {
  // Game State
  bool _gameActive = false;
  int _secondsLeft = 5;
  String currentQuestion = 'في انتظار المضيف...';
  int _currentPlayerTurn = 0;
  bool _isGeneratingAi = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onGameMove);
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['gameName'] != 'opposite_day') return;

    final type = move['type'];
    setState(() {
      if (type == 'sync_question') {
        _gameActive = true;
        _secondsLeft = 5;
        currentQuestion = move['question'] ?? 'جهز نفسك!';
        _currentPlayerTurn = move['turn'] ?? 0;
        _startTimer();
        AudioService.playTick();
        _vibrate(intensity: 100);
      } else if (type == 'handle_result') {
        _gameActive = false;
        _timer?.cancel();
        if (move['success'] == true) {
          AudioService.playSuccess();
        } else {
          AudioService.playFailure();
        }
      } else if (type == 'next_player_ready') {
        _currentPlayerTurn = move['turn'];
        _gameActive = false;
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        _vibrate(pattern: [0, 200, 100, 200]);
      } else {
        setState(() => _secondsLeft--);
        AudioService.playTick();
      }
    });
  }

  void _vibrate({int? duration, int? intensity, List<int>? pattern}) {
    HapticService.vibrate(
      duration: duration ?? 50,
      amplitude: intensity,
      pattern: pattern,
    );
  }

  Future<void> _emitStart() async {
    if (!widget.isHost || _isGeneratingAi) return;

    setState(() => _isGeneratingAi = true);

    String question = 'هل تحب المدرسة؟ (جاوب بالعكس)';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'opposite_day',
          count: 1,
        );
        if (content.isNotEmpty) {
          question = (content[0]['question'] ?? question).toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'opposite_day',
      'type': 'sync_question',
      'question': question,
      'turn': _currentPlayerTurn,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitResult(bool success) {
    if (!widget.isHost) return;
    final moveData = {
      'gameName': 'opposite_day',
      'type': 'handle_result',
      'success': success,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitNext() {
    if (!widget.isHost) return;
    int nextIdx = (_currentPlayerTurn + 1) % (widget.roomPlayers?.length ?? 1);
    final moveData = {
      'gameName': 'opposite_day',
      'type': 'next_player_ready',
      'turn': nextIdx,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().socket.off('game_move');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRoomPlayer =
        (widget.roomPlayers != null &&
            _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn]
        : null;
    bool isMyTurn =
        currentRoomPlayer != null &&
        currentRoomPlayer['id'] == SocketService().socket.id;

    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'opposite_day',
      title: 'اليوم العكسي (أونلاين)',
      backgroundColor: FunkyColors.lime,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: AnimatedSwitcher(
                duration: 600.ms,
                child: _gameActive
                    ? _buildGameUI(isMyTurn, currentRoomPlayer)
                    : _buildLobbyUI(isMyTurn, currentRoomPlayer),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyUI(bool isMe, dynamic player) {
    final pName = player?['name'] ?? 'لاعب';

    return Column(
      key: const ValueKey('lobby'),
      children: [
        Transform.rotate(
              angle: pi,
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text('🙃', style: TextStyle(fontSize: 80)),
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds)
            .shake(hz: 3, duration: 2.seconds),

        const SizedBox(height: 30),
        Text(
          'عكس العكاس',
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'جاوب بالعكس في 5 ثواني! 🔄',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 50),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            isMe ? 'دورك الحين! اقلب الدنيا! 🙃' : 'المستهدف الآن: $pName 👋',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ).animate().fadeIn().scale(),

        const SizedBox(height: 50),

        if (widget.isHost)
          GestureDetector(
            onTap: _emitStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orangeAccent, Colors.deepOrangeAccent],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  const BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: _isGeneratingAi
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'ابدأ السؤال 🚀',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ).animate().scale()
        else
          Text(
            'بانتظار المضيف يبدأ... 💤',
            style: GoogleFonts.cairo(color: Colors.white38, fontSize: 18),
          ),
      ],
    );
  }

  Widget _buildGameUI(bool isMe, dynamic player) {
    final pName = player?['name'] ?? 'لاعب';

    return Column(
      key: const ValueKey('game'),
      children: [
        Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: _secondsLeft <= 2
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.orangeAccent.withValues(alpha: 0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_secondsLeft <= 2
                                ? Colors.redAccent
                                : Colors.orangeAccent)
                            .withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_secondsLeft',
                  style: GoogleFonts.cairo(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: _secondsLeft <= 2 ? Colors.redAccent : Colors.white,
                  ),
                ),
              ),
            )
            .animate(target: _secondsLeft <= 2 ? 1 : 0)
            .shake(hz: 10, curve: Curves.easeInOut)
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),

        const SizedBox(height: 50),

        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white12, width: 1.5),
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMe ? Icons.psychology_outlined : Icons.hearing_outlined,
                  color: Colors.orangeAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                isMe ? 'جاوب بالعكس:' : 'اسمع إجابة $pName:',
                style: GoogleFonts.cairo(
                  color: Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isMe ? currentQuestion : 'السؤال سري مع $pName 🤫',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(curve: Curves.easeOutBack),

        const SizedBox(height: 50),

        if (widget.isHost)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    'إجابة خاطئة ❌',
                    Colors.redAccent,
                    () => _emitResult(false),
                  ),
                  const SizedBox(width: 20),
                  _buildActionButton(
                    'إجابة صحيحة ✅',
                    Colors.greenAccent,
                    () => _emitResult(true),
                  ),
                ],
              ),
              if (!_gameActive)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: GestureDetector(
                    onTap: _emitNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'اللاعب التالي ➡️',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().scale(),
                ),
            ],
          ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
