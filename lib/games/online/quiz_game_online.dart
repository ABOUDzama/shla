import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../widgets/player_avatar.dart';
import '../../services/socket_service.dart';
import '../../services/ai_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/premium_loading_indicator.dart';
import '../../theme/funky_theme.dart';

class QuizGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const QuizGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<QuizGameOnline> createState() => _QuizGameOnlineState();
}

class _QuizGameOnlineState extends State<QuizGameOnline> {
  final Set<String> _selectedCategories = {};
  bool _gameStarted = false;
  bool _isLoadingAi = false;
  Map<String, dynamic>? _currentQuestion;
  bool _showAnswer = false;
  Map<String, int> _scores = {};
  List<dynamic> _players = [];

  final List<String> _categories = [
    'ثقافة عامة',
    'رياضة',
    'علوم',
    'تاريخ',
    'أفلام وفن',
    'تكنولوجيا',
    '🔥 أسئلة صعبة',
  ];

  final Map<String, List<Map<String, String>>> _fallbackQuestions = {
    'ثقافة عامة': [
      {
        'question': 'ما هو الطائر الذي يضع أكبر بيضة في العالم؟',
        'answer': 'النعامة',
      },
      {
        'question': 'ما هو أصل كلمة "أطلس" التي تطلق على كتاب الخرائط؟',
        'answer': 'يوناني',
      },
      {'question': 'كم عدد ألوان قوس قزح؟', 'answer': '7 ألوان'},
      {
        'question': 'ما هي أكبر قارة في العالم من حيث المساحة؟',
        'answer': 'آسيا',
      },
    ],
    'رياضة': [
      {
        'question': 'من هو اللاعب الذي فاز بأكبر عدد من كرات ذهبية؟',
        'answer': 'ليونيل ميسي',
      },
      {
        'question': 'كم مدة الشوط الواحد في مباراة كرة القدم؟',
        'answer': '45 دقيقة',
      },
      {
        'question': 'في أي مدينة أقيمت أول دورة ألعاب أولمبية حديثة؟',
        'answer': 'أثينا',
      },
      {
        'question': 'ما هي الدولة التي فازت بكأس العالم 2022؟',
        'answer': 'الأرجنتين',
      },
    ],
    'علوم': [
      {'question': 'ما هو الرمز الكيميائي للماء؟', 'answer': 'H2O'},
      {'question': 'ما هو أقرب كوكب للشمس؟', 'answer': 'عطارد'},
      {'question': 'ما هو الغاز الذي يتنفسه الإنسان؟', 'answer': 'الأكسجين'},
      {
        'question': 'ما هو العضو المسؤول عن ضخ الدم في الجسم؟',
        'answer': 'القلب',
      },
    ],
    'تاريخ': [
      {'question': 'من هو مكتشف أمريكا؟', 'answer': 'كريستوفر كولومبوس'},
      {'question': 'في أي عام انتهت الحرب العالمية الثانية؟', 'answer': '1945'},
      {
        'question': 'ما هي أقدم حضارة في التاريخ؟',
        'answer': 'الحضارة السومرية',
      },
      {
        'question': 'من هو القائد المسلم الذي فتح الأندلس؟',
        'answer': 'طارق بن زياد',
      },
    ],
    'أفلام وفن': [
      {
        'question': 'من هو الرسام الذي رسم لوحة الموناليزا؟',
        'answer': 'ليوناردو دا فينشي',
      },
      {'question': 'ما هي جنسية الفنان العالمي بيكاسو؟', 'answer': 'إسباني'},
      {'question': 'ما هي عاصمة السينما العالمية؟', 'answer': 'هوليوود'},
      {
        'question': 'من هو الممثل الملقب بـ "الزعيم" في السينما المصرية؟',
        'answer': 'عادل إمام',
      },
    ],
    'تكنولوجيا': [
      {'question': 'من هو مؤسس شركة مايكروسوفت؟', 'answer': 'بيل جيتس'},
      {'question': 'ماذا ترمز اختصار WWW؟', 'answer': 'World Wide Web'},
      {
        'question': 'ما هي أول شركة أنتجت الهاتف المحمول؟',
        'answer': 'موتورولا',
      },
      {
        'question': 'ما هو نظام التشغيل الذي طورته شركة جوجل للهواتف؟',
        'answer': 'أندرويد',
      },
    ],
    '🔥 أسئلة صعبة': [
      {'question': 'ما هو الكوكب الذي يلقب بالكوكب الأزرق؟', 'answer': 'الأرض'},
      {'question': 'ما هي لغة النمسا الرسمية؟', 'answer': 'الألمانية'},
      {'question': 'كم عدد صمامات قلب الإنسان؟', 'answer': '4 صمامات'},
      {
        'question': 'ما هي الدولة التي تسمى ببلد المليون شهيد؟',
        'answer': 'الجزائر',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _players = widget.roomPlayers ?? [];

    // Ensure scores map is initialized for all players
    for (var p in _players) {
      final name = (p['playerName'] ?? p['name'] ?? 'لاعب').toString();
      if (name.isNotEmpty) {
        _scores[name] = 0;
      }
    }

    // Safety check: ensure current player (host or guest) is in the scores
    final myName = widget.playerName ?? 'أنا';
    if (!_scores.containsKey(myName)) {
      _scores[myName] = 0;
    }

    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onGameMove);
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;
    final move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    setState(() {
      final type = move['type'];
      if (type == 'start_quiz') {
        _gameStarted = true;
        _currentQuestion = Map<String, dynamic>.from(move['question']);
        _showAnswer = false;
        if (move['scores'] != null) {
          _scores = Map<String, int>.from(move['scores']);
        }
        HapticService.vibrate();
        AudioService.playTick();
      } else if (type == 'reveal_answer') {
        _showAnswer = true;
        HapticService.vibrate();
        AudioService.playSuccess();
      } else if (type == 'update_scores') {
        _scores = Map<String, int>.from(move['scores']);
      } else if (type == 'next_question') {
        _currentQuestion = Map<String, dynamic>.from(move['question']);
        _showAnswer = false;
        AudioService.playTick();
      }
    });
  }

  Future<void> _handleStartGame() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فئة واحدة على الأقل')),
      );
      return;
    }

    setState(() => _isLoadingAi = true);

    Map<String, dynamic>? nextQuestion;

    try {
      // Try AI first
      final questions = await AIService.fetchAiQuestions(
        _selectedCategories.join(' و '),
        count: 1,
      );
      if (questions.isNotEmpty) {
        nextQuestion = questions.first;
      }
    } catch (e) {
      debugPrint('AI Quiz error: $e');
    }

    // Fallback if AI fails or returns empty
    if (nextQuestion == null) {
      final randomCat = (_selectedCategories.toList()..shuffle()).first;
      final pool =
          _fallbackQuestions[randomCat] ?? _fallbackQuestions['ثقافة عامة']!;
      nextQuestion = (pool..shuffle()).first;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('استخدام سؤال احتياطي لصعوبة الاتصال بالـ AI 🔄'),
          ),
        );
      }
    }

    final moveData = {
      'type': 'start_quiz',
      'question': nextQuestion,
      'scores': _scores,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);

    setState(() => _isLoadingAi = false);
  }

  void _handleRevealAnswer() {
    final moveData = {'type': 'reveal_answer'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onGameMove(moveData);
  }

  void _handleNextQuestion() async {
    setState(() => _isLoadingAi = true);

    Map<String, dynamic>? nextQuestion;

    try {
      // Try AI first
      final questions = await AIService.fetchAiQuestions(
        _selectedCategories.join(' و '),
        count: 1,
      );
      if (questions.isNotEmpty) {
        nextQuestion = questions.first;
      }
    } catch (e) {
      debugPrint('AI Next Question error: $e');
    }

    // Fallback if AI fails
    if (nextQuestion == null) {
      final randomCat = (_selectedCategories.toList()..shuffle()).first;
      final pool =
          _fallbackQuestions[randomCat] ?? _fallbackQuestions['ثقافة عامة']!;
      nextQuestion = (pool..shuffle()).first;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التحويل للأسئلة الاحتياطية 🔄')),
        );
      }
    }

    final moveData = {'type': 'next_question', 'question': nextQuestion};

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);

    setState(() => _isLoadingAi = false);
  }

  void _updateScore(String player, int delta) {
    _scores[player] = (_scores[player] ?? 0) + delta;
    final moveData = {'type': 'update_scores', 'scores': _scores};

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
      gameName: 'quiz',
      title: 'تحدي المعلومات (أونلاين)',
      backgroundColor: FunkyColors.amber,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: _isLoadingAi
          ? const Center(
              child: PremiumLoadingIndicator(message: 'جاري استدعاء الـ AI...'),
            )
          : AnimatedSwitcher(
              duration: 600.ms,
              child: !_gameStarted ? _buildSetupUI() : _buildGameUI(),
            ),
    );
  }

  Widget _buildSetupUI() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const ValueKey('setup'),
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.psychology,
                size: 80,
                color: Colors.blueAccent,
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
            ),
            const SizedBox(height: 30),
            Text(
              widget.isHost ? 'اختر فئات الأسئلة:' : 'بانتظار المضيف...',
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _categories.map((cat) {
                final isSelected = _selectedCategories.contains(cat);
                return GestureDetector(
                  onTap: widget.isHost
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedCategories.remove(cat);
                            } else {
                              _selectedCategories.add(cat);
                            }
                          });
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: 300.ms,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blueAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.cairo(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 50),
            if (widget.isHost)
              GestureDetector(
                onTap: _handleStartGame,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.indigoAccent],
                    ),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Text(
                    'ابدأ التحدي 🚀',
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
                'بانتظار المضيف يبدأ... 💤',
                style: GoogleFonts.cairo(color: Colors.white38, fontSize: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return Column(
      key: const ValueKey('game'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildQuestionCard(),
                const SizedBox(height: 40),
                _buildScoreboard(),
              ],
            ),
          ),
        ),
        if (widget.isHost) _buildHostControls(),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
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
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Colors.blueAccent,
              size: 30,
            ),
          ),
          const SizedBox(height: 25),
          Text(
            _currentQuestion?['question'] ?? 'السؤال قادم...',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),
          AnimatedSwitcher(
            duration: 500.ms,
            child: _showAnswer
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'الإجابة الصحيحة:',
                          style: GoogleFonts.cairo(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _currentQuestion?['answer'] ?? '',
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ).animate().flipV()
                : Container(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'الإجابة مخفية ✨',
                      style: GoogleFonts.cairo(
                        color: Colors.white24,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(curve: Curves.easeOutBack);
  }

  Widget _buildScoreboard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.leaderboard_rounded,
                color: Colors.amberAccent,
                size: 24,
              ),
              const SizedBox(width: 15),
              Text(
                'لوحة الصدارة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10, height: 1),
          ),
          ..._scores.entries.map((e) {
            final isMe = e.key == widget.playerName;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.blueAccent.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isMe
                      ? Colors.blueAccent.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  _buildPlayerAvatar(e.key),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      e.key,
                      style: GoogleFonts.cairo(
                        color: isMe ? Colors.blueAccent : Colors.white,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isHost) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                      onPressed: () => _updateScore(e.key, -1),
                    ),
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          '${e.value}',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                      onPressed: () => _updateScore(e.key, 1),
                    ),
                  ] else
                    Text(
                      '${e.value}',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHostControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showAnswer ? null : _handleRevealAnswer,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _showAnswer
                      ? Colors.white10
                      : Colors.orangeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _showAnswer
                        ? Colors.white10
                        : Colors.orangeAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: Text(
                    'اكشف الإجابة ✨',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: _showAnswer ? Colors.white24 : Colors.orangeAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: _handleNextQuestion,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.indigoAccent],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    'السؤال التالي ➡️',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar(String playerName) {
    final player = SocketService().currentPlayers.firstWhere(
      (p) =>
          (p['playerName'] ?? p['name'])?.toString().trim().toLowerCase() ==
          playerName.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final String? playerId = player['id']?.toString();
    final String? avatar = player['avatar']?.toString();

    return PlayerAvatar(
      name: playerName,
      avatar: avatar,
      playerId: playerId,
      size: 35,
    );
  }
}
