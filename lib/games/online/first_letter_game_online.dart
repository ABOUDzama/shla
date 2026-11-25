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

class FirstLetterGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const FirstLetterGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<FirstLetterGameOnline> createState() => _FirstLetterGameOnlineState();
}

class _FirstLetterGameOnlineState extends State<FirstLetterGameOnline>
    with TickerProviderStateMixin {
  // Game State
  bool _gameActive = false;
  String? _currentCategory;
  String? _currentLetter;
  String? _currentPlayerId;
  int _secondsLeft = 10;
  int _currentPlayerTurn = 0;
  String _statusText = 'بانتظار المضيف...';
  bool _isGeneratingAi = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onSync);
  }

  void _onSync(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['gameName'] != 'first_letter') return;

    final type = move['type'];

    setState(() {
      if (type == 'start_turn') {
        _currentPlayerId = move['playerId'];
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        _currentCategory = move['category'];
        _currentLetter = move['letter'];
        _secondsLeft = 10;
        _gameActive = true;

        final isMe = _currentPlayerId == SocketService().socket.id;
        _statusText = isMe
            ? 'دورك تقول كلمة! 🗣️'
            : 'اسمع من ${_getPlayerName(_currentPlayerId!)} 👂';

        _startTimer();
        AudioService.playTick();
        _vibrate(intensity: 100);
      } else if (type == 'result') {
        _gameActive = false;
        _timer?.cancel();
        if (move['success']) {
          _statusText = 'صح! 🎉';
          AudioService.playSuccess();
          _vibrate(intensity: 100);
        } else {
          _statusText = 'انتهى الوقت! 💥';
          AudioService.playFailure();
          _vibrate(pattern: [0, 200, 100, 200]);
        }
      } else if (type == 'next_ready') {
        _currentPlayerTurn = move['currentPlayerTurn'];
        _gameActive = false;
        _statusText = 'استعد للجولة التالية...';
      }
    });
  }

  String _getPlayerName(String id) {
    final player = widget.roomPlayers?.firstWhere(
      (p) => p['id'] == id,
      orElse: () => null,
    );
    return player?['name'] ?? 'لاعب';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 0) {
        t.cancel();
        if (widget.isHost && _gameActive) _emitResult(false);
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

    String cat = '🍎 فواكه';
    String letter = 'أ';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'first_letter',
          count: 1,
        );
        if (content.isNotEmpty) {
          final item = content[0];
          cat = (item['category'] ?? cat).toString();
          letter = (item['letter'] ?? letter).toString();
        }
      } catch (_) {}
    }

    setState(() => _isGeneratingAi = false);

    final players =
        widget.roomPlayers ??
        [
          {'id': SocketService().socket.id, 'name': widget.playerName},
        ];
    final targetPlayer = players[_currentPlayerTurn];

    final moveData = {
      'gameName': 'first_letter',
      'type': 'start_turn',
      'category': cat,
      'letter': letter,
      'playerId': targetPlayer['id'],
      'currentPlayerTurn': _currentPlayerTurn,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onSync(moveData);
  }

  void _emitResult(bool success) {
    final moveData = {
      'gameName': 'first_letter',
      'type': 'result',
      'success': success,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onSync(moveData);
  }

  void _emitNext() {
    int nextIdx = (_currentPlayerTurn + 1) % (widget.roomPlayers?.length ?? 1);
    final moveData = {
      'gameName': 'first_letter',
      'type': 'next_ready',
      'currentPlayerTurn': nextIdx,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onSync(moveData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().socket.off('game_move');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'first_letter',
      title: '🔤 أول حرف (أونلاين)',
      backgroundColor: FunkyColors.orange,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            _buildTimer(),
            const Spacer(),
            _buildLetterCard(),
            const Spacer(),
            if (widget.isHost && _gameActive) _buildHostControls(),
            if (widget.isHost && !_gameActive) _buildStartButton(),
            if (!widget.isHost && !_gameActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'بانتظار المضيف يبدأ... 💤',
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 18),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    Color color = _secondsLeft > 3 ? Colors.white70 : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          if (_secondsLeft <= 3)
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
        ],
      ),
      child: Text(
        '$_secondsLeft',
        style: GoogleFonts.cairo(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: color,
          shadows: [
            if (_secondsLeft <= 3)
              const Shadow(color: Colors.redAccent, blurRadius: 10),
          ],
        ),
      ),
    ).animate(target: _secondsLeft < 3 ? 1 : 0).shake(hz: 8);
  }

  Widget _buildLetterCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.deepOrangeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentCategory ?? 'استعد للجولة!',
              style: GoogleFonts.cairo(
                fontSize: 20,
                color: Colors.deepOrangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _currentLetter ?? '؟',
                  style: GoogleFonts.cairo(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      const Shadow(
                        color: Colors.deepOrangeAccent,
                        blurRadius: 30,
                      ),
                    ],
                  ),
                ),
              )
              .animate(key: ValueKey(_currentLetter))
              .scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildHostControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'خطأ ❌',
          Colors.white.withValues(alpha: 0.05),
          () => _emitResult(false),
          borderColor: Colors.white10,
        ),
        _buildActionButton(
          'صح ✅',
          Colors.greenAccent,
          () => _emitResult(true),
          textColor: Colors.black,
          glow: true,
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback onTap, {
    Color textColor = Colors.white,
    Color? borderColor,
    bool glow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
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

  Widget _buildStartButton() {
    return _isGeneratingAi
        ? const CircularProgressIndicator(color: Colors.deepOrangeAccent)
        : GestureDetector(
            onTap: _currentLetter == null || !_gameActive
                ? _emitStart
                : _emitNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepOrangeAccent, Colors.orangeAccent],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentLetter == null || !_gameActive
                        ? Icons.play_arrow_rounded
                        : Icons.skip_next_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentLetter == null || !_gameActive
                        ? 'ابدأ كرت جديد 🚀'
                        : 'الجولة التالية ➡️',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().scale();
  }
}
