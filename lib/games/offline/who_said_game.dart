import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// مين قالها؟: each round one player secretly answers a fun question by
/// picking 1 of 3 options. The group then sees the question and the answer
/// and votes who answered. Identified: everyone else +2. Fooled them: the
/// secret answerer +3.
class WhoSaidGame extends StatefulWidget {
  const WhoSaidGame({super.key});

  /// Pure scoring for a finished round.
  static Map<String, int> scoreRound(
    Map<String, int> scores, {
    required String answerer,
    required bool identified,
  }) {
    final next = Map<String, int>.from(scores);
    if (identified) {
      for (final name in next.keys) {
        if (name != answerer) next[name] = (next[name] ?? 0) + 2;
      }
    } else {
      next[answerer] = (next[answerer] ?? 0) + 3;
    }
    return next;
  }

  static const List<({String question, List<String> options})> questions = [
    (question: 'إيه أكتر أكلة ممكن تاكلها كل يوم؟', options: ['كشري', 'فراخ مشوية', 'ملوخية']),
    (question: 'لو كسبت مليون جنيه، أول حاجة تعملها إيه؟', options: ['أسافر', 'أشتري عربية', 'أفتح مشروع']),
    (question: 'إيه أكتر حاجة بتضايقك؟', options: ['الزحمة', 'الحر', 'الصوت العالي']),
    (question: 'تفضل الصبح ولا بالليل؟', options: ['الصبح بدري', 'بالليل', 'مفيش فرق']),
    (question: 'إيه الأجازة المثالية؟', options: ['بحر', 'سفر بره', 'قعدة في البيت']),
    (question: 'لو ليك قوة خارقة، تختار إيه؟', options: ['تطير', 'تختفي', 'تقرا الأفكار']),
    (question: 'أكتر حاجة بتخوفك؟', options: ['العقارب', 'الظلام', 'الامتحانات']),
    (question: 'لو كنت حيوان، تبقى إيه؟', options: ['أسد', 'قطة', 'عصفور']),
    (question: 'إيه أكتر حاجة بتاكل وقتك؟', options: ['الموبايل', 'الشغل', 'النوم']),
    (question: 'قهوة ولا شاي؟', options: ['قهوة', 'شاي', 'حاجة سقعة']),
    (question: 'أحلى موسم في السنة؟', options: ['الصيف', 'الشتا', 'الربيع']),
    (question: 'يوم فاضي تمامًا، تعمل إيه؟', options: ['أخرج مع الشلة', 'أنام', 'ألعب']),
    (question: 'إيه أكتر موقف بيحرجك؟', options: ['الغنا قدام ناس', 'النسيان', 'الوقعة قدام الكل']),
    (question: 'حلو ولا حادق؟', options: ['حلو', 'حادق', 'الاتنين مع بعض']),
    (question: 'إيه هوايتك السرية؟', options: ['الطبخ', 'الرسم', 'الغنا في الحمام']),
    (question: 'لو تعيش في زمن تاني، تختار إيه؟', options: ['زمن الفراعنة', 'التسعينات', 'المستقبل']),
    (question: 'إيه اللي بيضحكك دايمًا؟', options: ['النكت البايخة', 'مقالب أصحابك', 'المواقف الغبية']),
    (question: 'فنجان قهوتك إزاي؟', options: ['سادة', 'مظبوط', 'سكر زيادة']),
    (question: 'إيه أول حاجة تعملها لو بقيت مشهور؟', options: ['أخبي نفسي', 'أستغلها', 'أعمل خير']),
    (question: 'تفضل قعدة شلة فين؟', options: ['قهوة', 'بيت حد فينا', 'خروجة مفاجئة']),
  ];

  @override
  State<WhoSaidGame> createState() => _WhoSaidGameState();
}

class _WhoSaidGameState extends State<WhoSaidGame> {
  final Random _rng = Random(17);
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  final List<int> _questionOrder = [];
  int _roundsPlayed = 0;

  // Per-round state.
  int get _answererIndex => _roundsPlayed; // each player answers once, in order
  bool _questionRevealed = false;
  String? _chosenAnswer;

  int get _totalRounds => _players.length;

  ({String question, List<String> options}) get _current =>
      WhoSaidGame.questions[_questionOrder[_roundsPlayed % _questionOrder.length]];

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _started = true;
      _questionOrder
        ..clear()
        ..addAll(List.generate(WhoSaidGame.questions.length, (i) => i))
        ..shuffle(_rng);
      _roundsPlayed = 0;
      _questionRevealed = false;
      _chosenAnswer = null;
    });
  }

  void _chooseAnswer(String option) {
    setState(() => _chosenAnswer = option);
  }

  void _finishRound({required bool identified}) {
    final scores = {
      for (final p in _players) p['name'] as String: p['score'] as int
    };
    final next = WhoSaidGame.scoreRound(scores,
        answerer: _players[_answererIndex]['name'] as String,
        identified: identified);
    setState(() {
      for (final p in _players) {
        p['score'] = next[p['name']] ?? p['score'];
      }
      _roundsPlayed++;
      _questionRevealed = false;
      _chosenAnswer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🗣️ مين قالها؟',
        backgroundColor: FunkyColors.mint,
        showAi: false,
        body: GameIntroWidget(
          title: '🗣️ مين قالها؟',
          icon: '🗣️',
          description:
              'واحد يجاوب سؤال في سرية من 3 اختيارات.. والشلة تشوف السؤال والإجابة وتخمن مين اللي جاوبها!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🗣️ مين قالها؟',
        minPlayers: 3,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_roundsPlayed >= _totalRounds) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      final top = sorted.first['score'] as int;
      final winners = sorted.where((p) => p['score'] == top).toList();
      return OfflineGameScaffold(
        title: '🗣️ مين قالها؟',
        backgroundColor: FunkyColors.mint,
        showAi: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  winners.length == 1
                      ? 'الفايز: ${winners.first['name']}'
                      : 'تعادل: ${winners.map((w) => w['name']).join(' و ')}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                for (final p in sorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${p['name']}: ${p['score']}',
                      style: GoogleFonts.cairo(
                          fontSize: 18, color: FlatColors.ink.withValues(alpha: 0.75)),
                    ),
                  ),
                const SizedBox(height: 32),
                FunkyButton(
                  label: 'العب تاني',
                  accent: FlatColors.tilePastels[2],
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() {
                    _started = false;
                    _showIntro = true;
                    _players = [];
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final answerer = _players[_answererIndex];

    // Secret answering phase: pass the phone to the answerer.
    if (_chosenAnswer == null) {
      return OfflineGameScaffold(
        title: '🗣️ مين قالها؟',
        backgroundColor: FunkyColors.mint,
        showAi: false,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الجولة ${_roundsPlayed + 1} من $_totalRounds',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              Text(
                'ادّي الموبايل لـ ${answerer['name']}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: FlatDecor.card(radius: 26),
                  child: Center(
                    child: _questionRevealed
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _current.question,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: FlatColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                for (final option in _current.options)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: FunkyButton(
                                      label: option,
                                      accent: FlatColors.tilePastels[2],
                                      onPressed: () => _chooseAnswer(option),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'إجابتك سرية.. محدش يبص!',
                                  style: GoogleFonts.cairo(
                                      fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🤫', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                child: FunkyButton(
                                  label: 'شوف سؤالك',
                                  accent: FlatColors.tilePastels[2],
                                  icon: Icons.visibility_rounded,
                                  onPressed: () => setState(
                                      () => _questionRevealed = true),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'بس ${answerer['name']} اللي يشوف!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                    fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group vote phase.
    return OfflineGameScaffold(
      title: '🗣️ مين قالها؟',
      backgroundColor: FunkyColors.mint,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FlatDecor.card(radius: 24),
              child: Column(
                children: [
                  Text(
                    _current.question,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الإجابة: $_chosenAnswer',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: FlatColors.mintDark,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: 16),
            Text(
              'مين اللي جاوب كده؟ 👀',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final p in _players)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FunkyButton(
                        label: p['name'] as String,
                        accent: FlatColors.tilePastels[3],
                        icon: Icons.record_voice_over_rounded,
                        onPressed: () =>
                            _showReveal(context, p['name'] as String),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReveal(BuildContext context, String accusedName) {
    final answererName = _players[_answererIndex]['name'] as String;
    final identified = accusedName == answererName;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                identified ? 'عرفتوه! 🎯' : 'ضحك عليكم! 😎',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                identified
                    ? '$answererName هو فعلاً اللي قال: $_chosenAnswer'
                    : 'اللي جاوب كان $answererName مش $accusedName!',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.cairo(fontSize: 16, color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 20),
              FunkyButton(
                label: _roundsPlayed + 1 < _totalRounds
                    ? 'الجولة اللي بعدها'
                    : 'النتيجة النهائية',
                accent: FlatColors.tilePastels[2],
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _finishRound(identified: identified);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
