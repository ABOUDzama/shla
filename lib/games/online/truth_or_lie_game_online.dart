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

class TruthOrLieGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const TruthOrLieGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<TruthOrLieGameOnline> createState() => _TruthOrLieGameOnlineState();
}

class _TruthOrLieGameOnlineState extends State<TruthOrLieGameOnline>
    with TickerProviderStateMixin {
  // Game State
  bool isPlaying = false;
  bool showResult = false;
  String currentStatement = 'بانتظار المضيف...';
  bool isTruth = true;
  String explanation = '';
  int _currentPlayerTurn = 0;
  bool _isGeneratingAi = false;

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

    if (move['gameName'] != 'truth_or_lie') return;

    final type = move['type'];
    setState(() {
      if (type == 'start_turn') {
        currentStatement = move['statement'];
        isTruth = move['isTruth'] ?? true;
        explanation = move['explanation'] ?? '';
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        isPlaying = true;
        showResult = false;
        AudioService.playTick();
        _vibrate(intensity: 100);
      } else if (type == 'reveal_result') {
        showResult = true;
        if (isTruth) {
          AudioService.playSuccess();
        } else {
          AudioService.playFailure();
        }
        _vibrate(pattern: [0, 200, 100, 200]);
      } else if (type == 'next_round_ready') {
        _currentPlayerTurn = move['currentPlayerTurn'];
        isPlaying = false;
        showResult = false;
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

    String statement = 'هل تعلم أن قنديل البحر ليس لديه دماغ؟';
    bool truth = true;
    String exp = 'صحيح! قنديل البحر يعتمد على شبكة عصبية بسيطة فقط.';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'truth_or_lie',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          statement = (item['statement'] ?? statement).toString();
          truth = (item['isTruth'] ?? truth) as bool;
          exp = (item['explanation'] ?? exp).toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'truth_or_lie',
      'type': 'start_turn',
      'statement': statement,
      'isTruth': truth,
      'explanation': exp,
      'currentPlayerTurn': _currentPlayerTurn,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitReveal() {
    if (!widget.isHost) return;
    final moveData = {'gameName': 'truth_or_lie', 'type': 'reveal_result'};
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
      'gameName': 'truth_or_lie',
      'type': 'next_round_ready',
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
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'truth_or_lie',
      title: 'حقيقة أم كذب؟ (أونلاين)',
      backgroundColor: FunkyColors.cyan,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: AnimatedSwitcher(
            duration: 600.ms,
            child: isPlaying ? _buildGameUI() : _buildLobbyUI(),
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
      key: const ValueKey('lobby'),
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: const Text('🤔', style: TextStyle(fontSize: 80))
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2.seconds)
              .shake(hz: 3, duration: 1.seconds),
        ),
        const SizedBox(height: 30),
        Text(
          'حقيقة أو هبد؟',
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,

          ),
        ),
        const SizedBox(height: 10),
        Text(
          'كشف المستور والتحفيل على الهبيدة! 😂',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 50),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
          ),
          child: Text(
            isHisTurn
                ? 'أنت اللي هتقول الحين! 🎤'
                : 'اللي هيقول الحين: $pName 👋',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.cyanAccent,
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
                  colors: [Colors.cyanAccent, Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
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
                      'ابدأ الجولة 🚀',
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
      key: const ValueKey('game'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            isMyTurn
                ? 'أنت صاحب المعلومة 🗣️'
                : 'توقع من $pName: حقيقة ولا هبد؟ 🤫',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ).animate().fadeIn().slideY(begin: -0.2),

        const SizedBox(height: 50),

        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.cyanAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                currentStatement,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              if (showResult) ...[
                const SizedBox(height: 30),
                const Divider(color: Colors.white12),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: (isTruth ? Colors.greenAccent : Colors.redAccent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTruth ? Colors.greenAccent : Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    isTruth ? 'حقيقة ✅' : 'هبد ❌',
                    style: GoogleFonts.cairo(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: isTruth ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 25),
                Text(
                  explanation,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ],
          ),
        ).animate().scale(curve: Curves.easeOutBack).fadeIn(),

        const SizedBox(height: 50),

        if (widget.isHost)
          GestureDetector(
            onTap: showResult ? _emitNext : _emitReveal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: showResult
                      ? [Colors.white12, Colors.white12]
                      : [Colors.cyanAccent, const Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  if (!showResult)
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                ],
                border: showResult ? Border.all(color: Colors.white24) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showResult
                        ? Icons.skip_next_rounded
                        : Icons.visibility_rounded,
                    color: showResult ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    showResult ? 'الجولة التالية ➡️' : 'اكشف الحقيقة 🔥',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: showResult ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().scale(),
      ],
    );
  }
}
