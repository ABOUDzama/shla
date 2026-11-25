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

class TruthOrDareGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const TruthOrDareGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<TruthOrDareGameOnline> createState() => _TruthOrDareGameOnlineState();
}

class _TruthOrDareGameOnlineState extends State<TruthOrDareGameOnline>
    with TickerProviderStateMixin {
  // Game State
  bool _started = false;
  bool _typeChosen = false;
  String? _currentCard;
  bool _isTruth = true;
  int _currentPlayerIdx = 0;
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

    if (move['gameName'] != 'truth_or_dare') return;

    final type = move['type'];
    setState(() {
      if (type == 'start_game') {
        _started = true;
        _currentPlayerIdx = move['currentPlayerIdx'] ?? 0;
        _typeChosen = false;
        _currentCard = null;
        AudioService.playTick();
        _vibrate(intensity: 100);
      } else if (type == 'card_picked') {
        _typeChosen = true;
        _isTruth = move['isTruth'] ?? true;
        _currentCard = move['card'];
        AudioService.playSuccess();
        _vibrate(intensity: 80);
      } else if (type == 'next_ready') {
        _currentPlayerIdx = move['currentPlayerIdx'];
        _typeChosen = false;
        _currentCard = null;
        _vibrate(intensity: 50);
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

  Future<void> _emitPick(bool isTruth) async {
    final curPlayer =
        (widget.roomPlayers != null &&
            _currentPlayerIdx < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerIdx]
        : null;
    if (curPlayer?['id'] != SocketService().socket.id || _isGeneratingAi) {
      return;
    }

    setState(() => _isGeneratingAi = true);

    String card = isTruth
        ? 'ما هو أكثر موقف محرج تعرضت له؟'
        : 'قم بتقليد صوت حيوان عشوائي يختاره البقية!';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'truth_or_dare',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          card = (isTruth ? (item['truth'] ?? card) : (item['dare'] ?? card))
              .toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'gameName': 'truth_or_dare',
      'type': 'card_picked',
      'isTruth': isTruth,
      'card': card,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitNext() {
    if (!widget.isHost) return;
    int nextIdx = (_currentPlayerIdx + 1) % (widget.roomPlayers?.length ?? 1);
    final moveData = {
      'gameName': 'truth_or_dare',
      'type': 'next_ready',
      'currentPlayerIdx': nextIdx,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _emitStart() {
    if (!widget.isHost) return;
    final moveData = {
      'gameName': 'truth_or_dare',
      'type': 'start_game',
      'currentPlayerIdx': 0,
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
      gameName: 'truth_or_dare',
      title: '🎲 حقيقة أم جرأة (أونلاين)',
      backgroundColor: FunkyColors.magenta,
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
                child: _started ? _buildGameUI() : _buildWaitingUI(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: const Text('🎲', style: TextStyle(fontSize: 80))
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2.seconds)
              .shake(hz: 3, duration: 1.seconds),
        ),
        const SizedBox(height: 30),
        Text(
          'حقيقة أم جرأة',
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'استعد للمواجهة.. الصراحة أو المغامرة! 💥',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 50),

        if (widget.isHost)
          GestureDetector(
            onTap: _emitStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Color(0xFF991B1B)],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  const BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Text(
                'ابدأ اللعبة 🚀',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ).animate().scale()
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'بانتظار المضيف يبدأ... 💤',
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildGameUI() {
    final currentRoomPlayer =
        (widget.roomPlayers != null &&
            _currentPlayerIdx < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerIdx]
        : null;
    final isMyTurn =
        currentRoomPlayer != null &&
        currentRoomPlayer['id'] == SocketService().socket.id;
    final pName = currentRoomPlayer?['name'] ?? 'لاعب';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            isMyTurn ? 'دورك تختار! 🔥' : 'الدور على: $pName 👋',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ).animate().fadeIn().slideY(begin: -0.2),

        const SizedBox(height: 50),

        if (!_typeChosen) ...[
          if (isMyTurn) ...[
            Text(
              'اختار مصيرك:',
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceCard(
                  'حقيقة 💎',
                  Colors.blueAccent,
                  () => _emitPick(true),
                ),
                const SizedBox(width: 20),
                _buildChoiceCard(
                  'جرأة 🔥',
                  Colors.orangeAccent,
                  () => _emitPick(false),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty,
                color: Colors.white24,
                size: 60,
              ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
            ),
            const SizedBox(height: 20),
            Text(
              'ننتظر اختيار $pName...',
              style: GoogleFonts.cairo(color: Colors.white38),
            ),
          ],
        ] else ...[
          _buildPromptCard(),
          const SizedBox(height: 50),
          if (widget.isHost)
            GestureDetector(
              onTap: _emitNext,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.skip_next_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'اللاعب التالي ➡️',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().scale(),
        ],
      ],
    );
  }

  Widget _buildChoiceCard(String label, Color color, VoidCallback onTap) {
    bool isBeingSelected =
        (label.contains('حقيقة') && _isTruth) ||
        (label.contains('جرأة') && !_isTruth);

    return GestureDetector(
      onTap: _isGeneratingAi ? null : onTap,
      child: Container(
        width: 150,
        height: 200,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGeneratingAi && isBeingSelected)
              CircularProgressIndicator(color: color)
            else ...[
              Text(
                label.split(' ')[0],
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(label.split(' ')[1], style: const TextStyle(fontSize: 45)),
            ],
          ],
        ),
      ),
    ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
  }

  Widget _buildPromptCard() {
    final color = _isTruth ? Colors.blueAccent : Colors.orangeAccent;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isTruth ? Icons.diamond_outlined : Icons.whatshot,
              color: color,
              size: 40,
            ),
          ),
          const SizedBox(height: 25),
          Text(
            _isTruth ? 'الحقيقة' : 'الجرأة',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _currentCard ?? 'جاري التحميل...',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().scale(curve: Curves.easeOutBack).fadeIn();
  }
}
