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

class WordChainGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const WordChainGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<WordChainGameOnline> createState() => _WordChainGameOnlineState();
}

class _WordChainGameOnlineState extends State<WordChainGameOnline>
    with TickerProviderStateMixin {
  // Game State
  bool isPlaying = false;
  String currentWord = 'في انتظار المضيف...';
  String _currentDefinition = '';
  int _secondsLeft = 60;
  int _currentPlayerTurn = 0;
  int _scoreCount = 0;
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

    if (move['gameName'] != 'word_chain') return;

    final action = move['action'];
    setState(() {
      if (action == 'start_round') {
        isPlaying = true;
        _secondsLeft = move['secondsLeft'] ?? 60;
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        currentWord = move['word'] ?? '---';
        _currentDefinition = move['definition'] ?? '';
        _scoreCount = move['score'] ?? 0;
        _startTimer();
        AudioService.playTick();
        _vibrate(intensity: 100);
      } else if (action == 'next_word') {
        currentWord = move['word'];
        _currentDefinition = move['definition'] ?? '';
        _scoreCount = move['score'] ?? _scoreCount;
        if (move['correct'] == true) {
          AudioService.playSuccess();
          _vibrate(intensity: 80);
        } else {
          _vibrate(intensity: 40);
        }
      } else if (action == 'game_over') {
        isPlaying = false;
        _timer?.cancel();
        AudioService.playFailure();
        _vibrate(pattern: [0, 400, 100, 400]);
      } else if (action == 'lobby_ready') {
        isPlaying = false;
        _currentPlayerTurn = move['currentPlayerTurn'];
        _timer?.cancel();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (widget.isHost) _emitGameOver();
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

    String word = 'تفاح';
    String def = 'نوع من الفاكهة لونه أحمر أو أخضر';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'word_chain',
          count: 1,
        ); // Using word_chain key for definition challenge
        if (content.isNotEmpty) {
          final item = content[0];
          word = (item['word'] ?? word).toString();
          def = (item['definition'] ?? def).toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'word_chain',
      'action': 'start_round',
      'word': word,
      'definition': def,
      'secondsLeft': 60,
      'currentPlayerTurn': _currentPlayerTurn,
      'score': 0,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  Future<void> _emitNext(bool correct) async {
    if (!widget.isHost || _isGeneratingAi) return;

    setState(() => _isGeneratingAi = true);

    String nextWord = 'برمجة';
    String nextDef = 'عملية كتابة أكواد للحاسوب';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'word_chain',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          nextWord = (item['word'] ?? nextWord).toString();
          nextDef = (item['definition'] ?? nextDef).toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'word_chain',
      'action': 'next_word',
      'word': nextWord,
      'definition': nextDef,
      'score': _scoreCount + (correct ? 1 : 0),
      'correct': correct,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitGameOver() {
    final moveData = {'gameName': 'word_chain', 'action': 'game_over'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onGameMove(moveData);
  }

  void _emitLobby() {
    int nextIdx = (_currentPlayerTurn + 1) % (widget.roomPlayers?.length ?? 1);
    final moveData = {
      'gameName': 'word_chain',
      'action': 'lobby_ready',
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
    _timer?.cancel();
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'word_chain',
      title: '⏱️ تحدي التعريف (أونلاين)',
      backgroundColor: FunkyColors.lime,
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
            child: !isPlaying ? _buildLobbyUI() : _buildGameUI(),
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
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Text('⏱️', style: TextStyle(fontSize: 70)),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds)
            .scale(duration: 800.ms, curve: Curves.elasticOut),
        const SizedBox(height: 30),
        Text(
          'تحدي التعريف',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,

          ),
        ),
        const SizedBox(height: 10),
        Text(
          'اشرح الكلمة بدون ما تنطقها! 🗣️',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 40),

        if (_scoreCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Text(
                  'النتيجة الأخيرة: $_scoreCount ✅',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.2),

        const SizedBox(height: 40),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            isHisTurn
                ? 'أنت اللي هتشرح الحين! 🎤'
                : 'اللي هيشرح الحين: $pName 👋',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ).animate().fadeIn().slideY(begin: 0.3),

        const SizedBox(height: 50),

        if (widget.isHost)
          _isGeneratingAi
              ? const CircularProgressIndicator(color: Colors.tealAccent)
              : GestureDetector(
                  onTap: _emitStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.tealAccent, Colors.greenAccent],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Text(
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
            'بانتظار المضيف يبدأ الغرفة...',
            style: GoogleFonts.cairo(color: Colors.white30, fontSize: 16),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard(
              'الوقت المتبقي',
              '$_secondsLeft s',
              Colors.orangeAccent,
              Icons.timer_outlined,
            ),
            _buildStatCard(
              'مجموع النقاط',
              '$_scoreCount pt',
              Colors.tealAccent,
              Icons.emoji_events_outlined,
            ),
          ],
        ),
        const SizedBox(height: 40),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            isMyTurn ? 'اشرح هذي الكلمة 🗣️' : 'خمّن الكلمة من شرح: $pName 👂',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
            ),
          ),
        ).animate().fadeIn().slideY(begin: -0.2),

        const SizedBox(height: 30),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(35),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white12, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
              ),
              BoxShadow(
                color: Colors.tealAccent.withValues(alpha: 0.05),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              if (isMyTurn) ...[
                Text(
                  currentWord,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      const Shadow(color: Colors.tealAccent, blurRadius: 20),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 25),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Text(
                  'قـرّب لهم المعنى:',
                  style: GoogleFonts.cairo(
                    color: Colors.white38,
                    fontSize: 13,

                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _currentDefinition,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    color: Colors.tealAccent.withValues(alpha: 0.9),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    size: 80,
                    color: Colors.white10,
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  'اسمع الشرح بتركيز وحاول تحزر الكلمة!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ).animate(key: ValueKey(currentWord)).fadeIn().scale(duration: 400.ms),

        const SizedBox(height: 50),

        if (widget.isHost)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                'تخطي ➡️',
                Colors.white.withValues(alpha: 0.05),
                () => _emitNext(false),
                borderColor: Colors.white10,
              ),
              _buildActionButton(
                'صح ✅',
                Colors.tealAccent,
                () => _emitNext(true),
                textColor: Colors.black,
                glow: true,
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.2),

        if (widget.isHost && _secondsLeft <= 0) ...[
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _emitLobby,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'العودة للمنصة 🏠',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ).animate().fadeIn(),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    Color textColor = Colors.white,
    Color? borderColor,
    bool glow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: [
            if (glow)
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
