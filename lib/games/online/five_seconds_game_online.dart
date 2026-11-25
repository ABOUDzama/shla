import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

class FiveSecondsGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const FiveSecondsGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<FiveSecondsGameOnline> createState() => _FiveSecondsGameOnlineState();
}

class _FiveSecondsGameOnlineState extends State<FiveSecondsGameOnline>
    with TickerProviderStateMixin {
  // Game State
  bool isPlaying = false;
  bool showAnswer = false;
  bool isQuestionRevealed = false;
  String currentQuestion = 'بانتظار المضيف...';
  String suggestedAnswer = '';
  int timeLeft = 5;
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

    if (move['gameName'] != 'five_seconds') return;

    final type = move['type'];
    setState(() {
      if (type == 'start_turn') {
        currentQuestion = move['question'];
        suggestedAnswer = move['answer'] ?? '';
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        timeLeft = 5;
        isPlaying = true;
        showAnswer = false;
        isQuestionRevealed = true;
        _startLocalTimer();
        AudioService.playTick();
        AudioService.playEncouragement(); // Arabic encouragement
        _vibrate(intensity: 150);
      } else if (type == 'next_turn_ready') {
        _currentPlayerTurn = move['currentPlayerTurn'];
        isPlaying = false;
        showAnswer = false;
        isQuestionRevealed = false;
        timeLeft = 5;
        _stopTimer();
      }
    });
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft <= 0) {
        t.cancel();
        setState(() {
          isPlaying = false;
          showAnswer = true;
        });
        AudioService.playFailure();
        _vibrate(pattern: [0, 200, 100, 200]);
      } else {
        setState(() => timeLeft--);
        AudioService.playTick();
        // Intensifying haptics as time runs out
        if (timeLeft <= 2) {
          _vibrate(intensity: 200, duration: 100);
        } else {
          _vibrate(intensity: 100, duration: 50);
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
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

    String question = 'اذكر 3 أنواع فاكهة';
    String answer = 'تفاح، موز، مشمش';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'five_seconds',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          question = item['question']?.toString() ?? question;
          answer = item['answer']?.toString() ?? answer;
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'five_seconds',
      'type': 'start_turn',
      'question': question,
      'answer': answer,
      'currentPlayerTurn': _currentPlayerTurn,
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
      'gameName': 'five_seconds',
      'type': 'next_turn_ready',
      'currentPlayerTurn': nextIdx,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  @override
  void dispose() {
    _stopTimer();
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'five_seconds',
      title: '٥ ثواني (أونلاين)',
      backgroundColor: FunkyColors.magenta,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: AnimatedSwitcher(
            duration: 600.ms,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !isQuestionRevealed && !showAnswer
                ? _buildLobbyUI()
                : _buildGameUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyUI() {
    final currentRoomPlayer =
        (widget.roomPlayers != null &&
            _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn]
        : null;
    final pName = currentRoomPlayer?['name'] ?? 'لاعب';
    final isHisTurn = currentRoomPlayer?['id'] == SocketService().socket.id;

    return Column(
      children: [
        Container(
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Text('⏱️', style: TextStyle(fontSize: 80)),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds)
            .scale(duration: 800.ms, curve: Curves.elasticOut),
        const SizedBox(height: 30),
        Text(
          'خمس ثواني',
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,

          ),
        ),
        const SizedBox(height: 10),
        Text(
          'أسرع تحدي في العالم! 🚀',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 40),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            isHisTurn ? 'دورك الحين! استعد 🔥' : 'الدور على: $pName 👋',
            style: GoogleFonts.cairo(
              fontSize: 20,
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ).animate().fadeIn().slideY(begin: 0.2),

        const SizedBox(height: 50),

        if (widget.isHost)
          _isGeneratingAi
              ? const CircularProgressIndicator(color: Colors.pinkAccent)
              : GestureDetector(
                  onTap: _emitStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.pinkAccent, Colors.purpleAccent],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Text(
                      'ابدأ السؤال 🚀',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ).animate().scale()
        else
          Text(
            'بانتظار المضيف يبدأ الغرفة...',
            style: GoogleFonts.cairo(color: Colors.white24, fontSize: 16),
          ),
      ],
    );
  }

  Widget _buildGameUI() {
    final currentRoomPlayer =
        (widget.roomPlayers != null &&
            _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn]
        : null;
    final isMyTurn =
        currentRoomPlayer != null &&
        currentRoomPlayer['id'] == SocketService().socket.id;
    final pName = currentRoomPlayer?['name'] ?? 'لاعب';

    return Column(
      children: [
        Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? Colors.pink.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isMyTurn ? Colors.pinkAccent : Colors.white10,
                ),
              ),
              child: Text(
                isMyTurn ? 'جاوب بسرعة! 🗣️' : 'بانتظار إجابة: $pName 🤫',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isMyTurn ? Colors.pinkAccent : Colors.white70,
                ),
              ),
            )
            .animate(key: ValueKey(isMyTurn))
            .fadeIn()
            .slideX(begin: isMyTurn ? 0.1 : -0.1),

        const SizedBox(height: 40),

        // Timer Circle
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.02),
            border: Border.all(
              color: timeLeft <= 2 ? Colors.redAccent : Colors.pinkAccent,
              width: 10,
            ),
            boxShadow: [
              BoxShadow(
                color: (timeLeft <= 2 ? Colors.redAccent : Colors.pinkAccent)
                    .withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$timeLeft',
              style: GoogleFonts.cairo(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: timeLeft <= 2 ? Colors.redAccent : Colors.pinkAccent,
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ).animate(target: timeLeft <= 2 ? 1 : 0).shake(hz: 8),

        const SizedBox(height: 50),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(35),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white10, width: 1.5),
            boxShadow: [
              const BoxShadow(color: Colors.black45, blurRadius: 40),
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.02),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                currentQuestion,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              if (showAnswer) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white10),
                ),
                Text(
                  '💡 أمثلة للإجابة:',
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  suggestedAnswer,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    color: Colors.amberAccent.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().scale(duration: 400.ms),
              ],
            ],
          ),
        ).animate(key: ValueKey(currentQuestion)).fadeIn().slideY(begin: 0.1),

        const SizedBox(height: 50),

        if (widget.isHost && showAnswer)
          GestureDetector(
            onTap: _emitNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'السؤال التالي ➡️',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.2),
      ],
    );
  }
}
