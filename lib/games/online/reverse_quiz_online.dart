import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../theme/funky_theme.dart';

class ReverseQuizOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const ReverseQuizOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<ReverseQuizOnline> createState() => _ReverseQuizOnlineState();
}

class _ReverseQuizOnlineState extends State<ReverseQuizOnline> {
  List<Map<String, String>> questions = [
    {
      'answer': 'أرجنتيني وبيلعب في إنتر ميامي',
      'question': 'مين هو ليونيل ميسي؟',
      'icon': '⚽',
    },
    {
      'answer': 'عاصمة مصر وأكبر مدنها',
      'question': 'إيه هي القاهرة؟',
      'icon': '🏙️',
    },
    {
      'answer': 'كوكب أحمر ورابع كوكب من الشمس',
      'question': 'إيه هو المريخ؟',
      'icon': '🔴',
    },
    {
      'answer': 'فاكهة صفراء طويلة بتحبها القرود',
      'question': 'إيه هي الموزة؟',
      'icon': '🍌',
    },
    {
      'answer': 'لعبة بـ 11 لاعب وفيها مرمى',
      'question': 'إيه هي كرة القدم؟',
      'icon': '⚽',
    },
    {
      'answer': 'شركة تفاحة مقضومة شعارها',
      'question': 'إيه هي شركة أبل؟',
      'icon': '🍏',
    },
    {
      'answer': 'أكبر حيوان في العالم بيعيش في البحر',
      'question': 'إيه هو الحوت الأزرق؟',
      'icon': '🐋',
    },
  ];

  int currentIndex = 0;
  bool _isFlipped = false;
  bool _hintUsed = false;
  int _secondsLeft = 15;
  Timer? _timer;
  bool _gameActive = false;
  bool _isLoadingAi = false;
  String _statusText = 'بانتظار المضيف للبدء...';

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onQuizSync);
  }

  void _onQuizSync(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    final type = move['type'];

    setState(() {
      if (type == 'start_game' || type == 'next_question') {
        if (move['questions'] != null) {
          questions = List<Map<String, String>>.from(
            (move['questions'] as List).map((e) => Map<String, String>.from(e)),
          );
        }
        currentIndex = move['index'] ?? currentIndex;
        _secondsLeft = 15;
        _isFlipped = false;
        _hintUsed = false;
        _gameActive = true;
        _statusText = 'خمن السؤال!';
        _startTimer();
        AudioService.playTick();
      } else if (type == 'flip_card') {
        _timer?.cancel();
        _isFlipped = true;
        _statusText = (move['timeout'] == true)
            ? 'انتهى الوقت! ✨'
            : 'تم الكشف! 👀';
        if (move['timeout'] == true) AudioService.playFailure();
      } else if (type == 'hint') {
        _hintUsed = true;
        AudioService.playClick();
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
        if (widget.isHost && !_isFlipped) {
          _emitFlip(timeout: true);
        }
      } else {
        setState(() => _secondsLeft--);
        AudioService.playTick();
      }
    });
  }

  Future<void> _emitStart() async {
    if (!widget.isHost || _isLoadingAi) return;

    if (!_gameActive && SettingsService.isAiEnabled) {
      setState(() => _isLoadingAi = true);
      try {
        final content = await AIService.fetchGameContent(
          'reverse_quiz',
          count: 10,
        );
        if (content.isNotEmpty) {
          questions = content
              .map(
                (item) => {
                  'answer': (item['answer'] ?? item['text'] ?? 'إجابة مجهولة')
                      .toString(),
                  'question':
                      (item['question'] ?? item['query'] ?? 'ما هو السؤال؟')
                          .toString(),
                  'icon': (item['icon'] ?? '❓').toString(),
                },
              )
              .toList();
        }
      } catch (e) {
        debugPrint('AI Error: $e');
      }
      setState(() => _isLoadingAi = false);
    }

    int nextIdx = _gameActive ? (currentIndex + 1) % questions.length : 0;

    final moveData = {
      'type': _gameActive ? 'next_question' : 'start_game',
      'index': nextIdx,
      'questions': !_gameActive ? questions : null,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onQuizSync(moveData);
  }

  void _emitFlip({bool timeout = false}) {
    final moveData = {'type': 'flip_card', 'timeout': timeout};

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onQuizSync(moveData);
  }

  void _emitHint() {
    if (_hintUsed || _isFlipped) return;
    final moveData = {'type': 'hint'};

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onQuizSync(moveData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().socket.off('game_move', _onQuizSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentIndex];
    String hintText = "💡 التلميح: الكلمات الأولى";
    if (_hintUsed) {
      List<String> words = currentQuestion['question']!.split(' ');
      hintText =
          "💡 التلميح: ${words[0]} ${words.length > 1 ? words[1] : ''}...";
    }

    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'reverse_quiz',
      title: 'تحدي الإجابة المقلوبة (أونلاين)',
      backgroundColor: FunkyColors.mint,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 30),
              // Status & Timer
              Hero(
                tag: 'quiz_status',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 15,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _statusText,
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_gameActive && !_isFlipped)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _secondsLeft < 5
                                ? Colors.redAccent.withValues(alpha: 0.1)
                                : Colors.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_secondsLeft',
                            style: GoogleFonts.cairo(
                              color: _secondsLeft < 5
                                  ? Colors.redAccent
                                  : Colors.cyanAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ).animate(target: _secondsLeft < 5 ? 1 : 0).shake(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Main Card
              Expanded(
                child: _isLoadingAi
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.cyanAccent,
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: GestureDetector(
                            onTap: widget.isHost && !_isFlipped && _gameActive
                                ? () => _emitFlip()
                                : null,
                            child: AspectRatio(
                              aspectRatio: 0.8,
                              child: AnimatedSwitcher(
                                duration: 600.ms,
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
                                      final rotate = Tween(
                                        begin: 1.5,
                                        end: 0.0,
                                      ).animate(animation);
                                      return AnimatedBuilder(
                                        animation: rotate,
                                        child: child,
                                        builder: (context, child) {
                                          return Transform(
                                            transform: Matrix4.rotationY(
                                              rotate.value,
                                            ),
                                            alignment: Alignment.center,
                                            child: child,
                                          );
                                        },
                                      );
                                    },
                                child: Container(
                                  key: ValueKey(_isFlipped),
                                  decoration: BoxDecoration(
                                    color: _isFlipped
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(45),
                                    border: Border.all(
                                      color: _isFlipped
                                          ? Colors.transparent
                                          : Colors.white12,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isFlipped
                                                    ? Colors.white
                                                    : Colors.cyanAccent)
                                                .withValues(alpha: 0.05),
                                        blurRadius: 40,
                                        spreadRadius: 2,
                                      ),
                                      const BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(25.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color:
                                                (_isFlipped
                                                        ? const Color(
                                                            0xFF0F172A,
                                                          )
                                                        : Colors.white)
                                                    .withValues(alpha: 0.05),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            currentQuestion['icon']!,
                                            style: const TextStyle(
                                              fontSize: 70,
                                            ),
                                          ),
                                        ).animate().scale(
                                          duration: 400.ms,
                                          curve: Curves.easeOutBack,
                                        ),
                                        const SizedBox(height: 40),
                                        Text(
                                          _isFlipped
                                              ? currentQuestion['question']!
                                              : currentQuestion['answer']!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.cairo(
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: _isFlipped
                                                ? const Color(0xFF0F172A)
                                                : Colors.white,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (!_isFlipped && _gameActive)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 30,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 15,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Text(
                                                hintText,
                                                style: GoogleFonts.cairo(
                                                  color: Colors.cyanAccent
                                                      .withValues(alpha: 0.7),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ).animate().fadeIn().slideY(
                                            begin: 0.2,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 30),

              // Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isHost)
                      GestureDetector(
                        onTap: _emitStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.cyanAccent, Colors.blueAccent],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 10),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.cyan[900],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _gameActive
                                    ? 'السؤال التالي'
                                    : 'ابدأ المسابقة 🚀',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan[900],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(),
                    if (!widget.isHost && !_gameActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'بانتظار المضيف يبدأ الجولة... 💤',
                          style: GoogleFonts.cairo(color: Colors.white38),
                        ),
                      ),
                    if (_gameActive && !_isFlipped && !_hintUsed)
                      const SizedBox(width: 20),
                    if (_gameActive && !_isFlipped && !_hintUsed)
                      GestureDetector(
                            onTap: _emitHint,
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amberAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.amberAccent,
                                size: 30,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.15, 1.15),
                            duration: 800.ms,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
