import 'package:flutter/material.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/funky_theme.dart';

class OddOneOutOnline extends StatefulWidget {
  final bool isHost;
  final String? roomCode;
  final String? opponentName;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const OddOneOutOnline({
    super.key,
    required this.isHost,
    this.roomCode,
    this.opponentName,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<OddOneOutOnline> createState() => _OddOneOutOnlineState();
}

class _OddOneOutOnlineState extends State<OddOneOutOnline> {
  bool answered = false;
  int lives = 3;
  int timeLeft = 10;
  List<String> _items = [];
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onGameMoveHandler);
  }

  void _onGameMoveHandler(dynamic data) {
    if (!mounted) return;
    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    setState(() {
      if (move['type'] == 'start_game' || move['type'] == 'next_question') {
        _started = true;
        answered = false;
        _items = List<String>.from(move['shuffledItems']);
        timeLeft = 10;
        _startTimer();
      } else if (move['type'] == 'pick_answer') {
        answered = true;
        _timer?.cancel();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft <= 0) {
        t.cancel();
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().socket.off('game_move', _onGameMoveHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'odd_one_out',
      title: 'استخرج الغريب (أونلاين)',
      backgroundColor: FunkyColors.coral,
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
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 80,
                color: Colors.orangeAccent,
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2.seconds)
            .scale(duration: 800.ms, curve: Curves.elasticOut),
        const SizedBox(height: 30),
        Text(
          'طلع الغريب',
          style: GoogleFonts.cairo(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'ركز وطلع الصورة المختلفة! 🔍',
          style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16),
        ),

        const SizedBox(height: 50),

        if (widget.isHost)
          GestureDetector(
            onTap: _start,
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
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildGameUI() {
    return Column(
      children: [
        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          decoration: BoxDecoration(
            color: (timeLeft < 4 ? Colors.redAccent : Colors.orangeAccent)
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (timeLeft < 4 ? Colors.redAccent : Colors.orangeAccent)
                  .withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                color: timeLeft < 4 ? Colors.redAccent : Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                '$timeLeft',
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: timeLeft < 4 ? Colors.redAccent : Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ).animate(target: timeLeft < 4 ? 1 : 0).shake(),

        const SizedBox(height: 50),

        // Items Grid
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white10),
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: _items.map((i) => _buildItemButton(i)).toList(),
          ),
        ).animate().fadeIn().scale(duration: 500.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildItemButton(String icon) {
    return GestureDetector(
      onTap: answered ? null : () => _pick(icon),
      child:
          Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    const BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 50)),
                ),
              )
              .animate(target: answered ? 1 : 0)
              .scale(begin: const Offset(1, 1), end: const Offset(0.9, 0.9)),
    );
  }

  void _start() {
    final moveData = {
      'game': 'odd_one_out',
      'type': 'start_game',
      'shuffledItems': ['🍎', '🍌', '🥕'],
      'currentIndex': 0,
      'pointer': 0,
      'timeLeft': 10,
    };
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onGameMoveHandler(moveData);
  }

  void _pick(String i) {
    final moveData = {
      'game': 'odd_one_out',
      'type': 'pick_answer',
      'answer': i,
    };
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onGameMoveHandler(moveData);
  }
}
