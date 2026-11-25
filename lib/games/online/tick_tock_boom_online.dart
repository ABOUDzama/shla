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

class TickTockBoomOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const TickTockBoomOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<TickTockBoomOnline> createState() => _TickTockBoomOnlineState();
}

class _TickTockBoomOnlineState extends State<TickTockBoomOnline>
    with TickerProviderStateMixin {
  // Game State
  bool isPlaying = false;
  bool hasExploded = false;
  String currentLetter = '';
  String currentCategory = '';
  List<String> _currentExamples = [];
  int _currentPlayerTurn = 0;

  // Timer & Animations
  Timer? _localTimer;
  int _tickCount = 0;
  int _explosionTime = 0;
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

    if (move['gameName'] != 'tick_tock_boom') return;

    final action = move['action'];
    setState(() {
      if (action == 'start_round') {
        currentCategory = move['currentCategory'];
        currentLetter = move['currentLetter'];
        _currentExamples = List<String>.from(move['examples'] ?? []);
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        _explosionTime = move['explosionTime'] ?? 15;
        _tickCount = 0;
        isPlaying = true;
        hasExploded = false;
        _startLocalTimer();
        AudioService.playTick();
      } else if (action == 'next_player') {
        _currentPlayerTurn = move['nextPlayerIndex'];
        _tickCount = move['tickCount'] ?? _tickCount;
        AudioService.playTick();
        _vibrate(intensity: 50); // Small vibrate on pass
      } else if (action == 'explode') {
        _stopLocalTimer();
        isPlaying = false;
        hasExploded = true;
        _currentPlayerTurn = move['loserIndex'] ?? _currentPlayerTurn;
        AudioService.playExplosion();
        _vibrate(pattern: [0, 500, 100, 500]); // Strong vibrate on explosion
      }
    });
  }

  void _startLocalTimer() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(milliseconds: 1000), (t) {
      if (!isPlaying) {
        t.cancel();
        return;
      }
      setState(() {
        _tickCount++;
      });
      AudioService.playTick();

      // Host manages the explosion
      if (widget.isHost && _tickCount >= _explosionTime) {
        _emitExplosion();
      }
    });
  }

  void _stopLocalTimer() {
    _localTimer?.cancel();
    _localTimer = null;
  }

  void _vibrate({int? duration, int? intensity, List<int>? pattern}) {
    HapticService.vibrate(
      duration: duration ?? 50,
      amplitude: intensity,
      pattern: pattern,
    );
  }

  Future<void> _start() async {
    if (!widget.isHost || _isGeneratingAi) return;

    setState(() => _isGeneratingAi = true);

    String cat = 'منوعات';
    String letter = 'أ';
    List<String> examples = ['أسد', 'أرنب'];

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'letter_bomb',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          cat = (item['category'] ?? 'عام').toString();
          letter = (item['letter'] ?? 'ب').toString();
          examples = List<String>.from(item['examples'] ?? []);
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'tick_tock_boom',
      'action': 'start_round',
      'currentCategory': cat,
      'currentLetter': letter,
      'examples': examples,
      'explosionTime': Random().nextInt(15) + 10, // 10 to 25 seconds
      'currentPlayerTurn': Random().nextInt(widget.roomPlayers?.length ?? 1),
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _passBomb() {
    if (!isPlaying) return;
    int nextIdx = (_currentPlayerTurn + 1) % (widget.roomPlayers?.length ?? 1);
    final moveData = {
      'gameName': 'tick_tock_boom',
      'action': 'next_player',
      'nextPlayerIndex': nextIdx,
      'tickCount': _tickCount,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitExplosion() {
    final moveData = {
      'gameName': 'tick_tock_boom',
      'action': 'explode',
      'loserIndex': _currentPlayerTurn,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  @override
  void dispose() {
    _stopLocalTimer();
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'tick_tock_boom',
      title: 'تيك توك بوم (أونلاين)',
      backgroundColor: FunkyColors.coral,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isPlaying && !hasExploded) _buildLobbyUI(),
              if (isPlaying) _buildGameUI(),
              if (hasExploded) _buildExplosionUI(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: const Text('💣', style: TextStyle(fontSize: 80)),
        ).animate(onPlay: (c) => c.repeat()).shake(hz: 2, duration: 1.seconds),
        const SizedBox(height: 30),
        Text(
          'قنبلة الحروف',
          style: GoogleFonts.cairo(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'مرر القنبلة قبل ما تنفجر في وجهك! 🔥',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 50),

        if (widget.isHost)
          _isGeneratingAi
              ? const CircularProgressIndicator(color: Colors.amberAccent)
              : GestureDetector(
                  onTap: _start,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amberAccent, Colors.orangeAccent],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Text(
                      'ابدأ الغرفة 🚀',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ).animate().scale()
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              'بانتظار المضيف يجهّز القنبلة...',
              style: GoogleFonts.cairo(color: Colors.white30, fontSize: 16),
            ),
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

    final remaining = max(0, _explosionTime - _tickCount);
    final pulseDuration = (remaining <= 5)
        ? 300.ms
        : (remaining <= 10)
        ? 500.ms
        : 800.ms;

    return Column(
      children: [
        Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMyTurn ? Colors.redAccent : Colors.amberAccent,
                  width: 2,
                ),
              ),
              child: Text(
                isMyTurn
                    ? 'القنبلة معك! صرّفها بسرعة! 🧨'
                    : 'القنبلة عند: $pName 🕵️',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isMyTurn ? Colors.redAccent : Colors.amberAccent,
                ),
              ),
            )
            .animate(key: ValueKey(isMyTurn))
            .fadeIn()
            .slideX(begin: isMyTurn ? 0.1 : -0.1),

        const SizedBox(height: 40),

        Text(
          currentCategory,
          style: GoogleFonts.cairo(
            fontSize: 22,
            color: Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 25),

        Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMyTurn
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : Colors.white10,
                  width: 4,
                ),
                boxShadow: [
                  if (isMyTurn)
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  currentLetter,
                  style: GoogleFonts.cairo(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      if (isMyTurn)
                        const Shadow(color: Colors.redAccent, blurRadius: 20),
                    ],
                  ),
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              duration: pulseDuration,
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
            ),

        const SizedBox(height: 60),

        if (isMyTurn)
          GestureDetector(
                onTap: _passBomb,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.orangeAccent],
                    ),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'مرر القنبلة! 🏃',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.bolt_rounded, color: Colors.black),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1.seconds)
              .shake(hz: 3),
      ],
    );
  }

  Widget _buildExplosionUI() {
    final loser =
        (widget.roomPlayers != null &&
            _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn]
        : null;
    final pName = loser?['name'] ?? 'لاعب';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: const Text('💥', style: TextStyle(fontSize: 100)),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 30),
        Text(
          'صارت رماد! 🔥',
          style: GoogleFonts.cairo(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
            shadows: [const Shadow(color: Colors.redAccent, blurRadius: 20)],
          ),
        ).animate().fadeIn().slideY(begin: 0.2),
        const SizedBox(height: 15),
        Text(
          'الخاسر في هذه الجولة: $pName 💀',
          style: GoogleFonts.cairo(
            fontSize: 18,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),

        if (_currentExamples.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  '💡 بعض الكلمات المناسبة:',
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _currentExamples
                      .map(
                        (ex) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            ex,
                            style: GoogleFonts.cairo(
                              color: Colors.amberAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 50),
        ],

        if (widget.isHost)
          GestureDetector(
            onTap: () => setState(() {
              hasExploded = false;
              isPlaying = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
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
    );
  }
}
