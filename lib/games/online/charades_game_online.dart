import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../theme/funky_theme.dart';

class CharadesGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const CharadesGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<CharadesGameOnline> createState() => _CharadesGameOnlineState();
}

class _CharadesGameOnlineState extends State<CharadesGameOnline> {
  final Map<String, List<String>> _fallbackWords = {
    '🎬 أفلام ومسلسلات': [
      'تيتانيك',
      'هاري بوتر',
      'الأسد الملك',
      'باتمان',
      'سبايدرمان',
    ],
    '🐾 حيوانات': ['فيل', 'قرد', 'تمساح', 'طاووس', 'بطريق'],
    '⚽ رياضة': ['كرة قدم', 'سباحة', 'تنس', 'كرة سلة', 'جمباز'],
  };

  String? _currentWord;
  String? _currentCategory;
  String? _actorId;
  int _secondsLeft = 60;
  Timer? _timer;
  bool _gameActive = false;
  int _correctCount = 0;
  String _statusText = 'بانتظار المضيف...';
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onCharadesSync);
  }

  void _onCharadesSync(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    final type = move['type'];

    setState(() {
      if (type == 'start_game') {
        _actorId = move['actorId'];
        _currentWord = move['word'];
        _currentCategory = move['category'];
        _correctCount = 0;
        _secondsLeft = 60;
        _gameActive = true;
        _statusText = (_actorId == SocketService().socket.id)
            ? 'أنت الممثل! 🎭'
            : 'خمن التمثيلية! 🤫';
        _startTimer();
        AudioService.playTick();
      } else if (type == 'next_word') {
        _currentWord = move['word'];
        if (move['correct']) _correctCount++;
        _statusText = (_actorId == SocketService().socket.id)
            ? 'الكلمة التالية: $_currentWord'
            : 'خمن التمثيلية! 🕵️';
        if (move['correct']) AudioService.playSuccess();
      } else if (type == 'timer_sync') {
        _secondsLeft = move['seconds'];
      } else if (type == 'game_over') {
        _gameActive = false;
        _timer?.cancel();
        _statusText = 'انتهى الوقت! النتيجة: $_correctCount ✅';
        AudioService.playFailure();
      }
    });
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
        if (widget.isHost) _emitGameOver();
      } else {
        setState(() => _secondsLeft--);
        AudioService.playTick();
      }
    });
  }

  void _emitStart() {
    final cat = _fallbackWords.keys
        .toList()[_rand.nextInt(_fallbackWords.length)];
    final word =
        _fallbackWords[cat]![_rand.nextInt(_fallbackWords[cat]!.length)];

    final moveData = {
      'type': 'start_game',
      'word': word,
      'category': cat,
      'actorId': SocketService().socket.id,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onCharadesSync(moveData);
  }

  void _emitNext(bool correct) {
    if (SocketService().socket.id != _actorId) return;
    final cat = _currentCategory!;
    final word =
        _fallbackWords[cat]![_rand.nextInt(_fallbackWords[cat]!.length)];

    final moveData = {'type': 'next_word', 'word': word, 'correct': correct};

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onCharadesSync(moveData);
  }

  void _emitGameOver() {
    final moveData = {'type': 'game_over'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onCharadesSync(moveData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().socket.off('game_move', _onCharadesSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActor = SocketService().socket.id == _actorId;

    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'charades',
      title: 'بدون كلام (أونلاين)',
      backgroundColor: FunkyColors.violet,
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
            child: Column(
              key: ValueKey(_gameActive),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_gameActive) _buildTimer(),
                const SizedBox(height: 30),
                _buildGameCard(isActor),
                const SizedBox(height: 50),
                if (isActor && _gameActive) _buildActorControls(),
                if (widget.isHost && !_gameActive) _buildStartButton(),
                if (!isActor && !_gameActive)
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
                      'بانتظار المضيف يبدأ الغرفة... 💤',
                      style: GoogleFonts.cairo(
                        color: Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    Color color = _secondsLeft > 10 ? Colors.indigoAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            '$_secondsLeft ثانية',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ).animate(target: _secondsLeft < 10 ? 1 : 0).shake(hz: 5);
  }

  Widget _buildGameCard(bool isActor) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 350, minHeight: 280),
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [
          const BoxShadow(color: Colors.black38, blurRadius: 40),
          BoxShadow(
            color: Colors.indigoAccent.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentCategory?.split(' ').last ?? '---',
              style: GoogleFonts.cairo(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,

              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currentCategory?.split(' ').first ?? '🎭',
            style: const TextStyle(fontSize: 40),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Divider(color: Colors.white10, height: 1),
          ),
          if (isActor && _gameActive)
            Text(
                  _currentWord ?? '---',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      const Shadow(color: Colors.indigoAccent, blurRadius: 20),
                    ],
                  ),
                )
                .animate(key: ValueKey(_currentWord))
                .scale(duration: 400.ms, curve: Curves.easeOutBack)
          else if (_gameActive)
            Text(
              'جاري التمثيل... 🤫',
              style: GoogleFonts.cairo(
                color: Colors.indigoAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds)
          else
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _correctCount > 0
                    ? Colors.greenAccent
                    : Colors.amberAccent,
                height: 1.4,
              ),
            ),
        ],
      ),
    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack);
  }

  Widget _buildActorControls() {
    return Row(
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
          Colors.greenAccent,
          () => _emitNext(true),
          textColor: Colors.black,
          glow: true,
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
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
    return Column(
      children: [
        if (_correctCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Text(
                  'النتيجة: $_correctCount ✅',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 50),
        ],
        GestureDetector(
          onTap: _emitStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.indigoAccent, Colors.blueAccent],
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Text(
              'ابدأ الغرفة 🚀',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ).animate().scale(),
      ],
    );
  }
}
