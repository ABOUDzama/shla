import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// لو خيروك (Would You Rather): a party conversation game for gatherings.
/// The group sees a question with two options; every player votes secretly
/// (pass-and-play), then the split is revealed and the debate starts.
/// Grounded in the classic "Would you rather?" gathering game (listed as
/// «ماذا تفضّل؟» among no-equipment family gathering games).
class WouldRatherGame extends StatefulWidget {
  const WouldRatherGame({super.key, this.seed = 9});

  /// Deterministic seed for tests.
  final int seed;

  static const List<({String a, String b})> questions = [
    (a: 'تعيش من غير نت سنة', b: 'تعيش من غير موسيقى سنة'),
    (a: 'تعرف تطير', b: 'تعرف تختفي'),
    (a: 'تفضل شابهك بس أطول', b: 'تفضل شابهك بس أقصر'),
    (a: 'تعيش في بلد تانية لوحدك', b: 'تفضل في مصر مع صحابك'),
    (a: 'تاكل كشري كل يوم', b: 'متعرفش طعم الكشري خالص'),
    (a: 'ترجع ٥ سنين لورا', b: 'تروح ٥ سنين قدام'),
    (a: 'تبقى مشهور وتخسر خصوصيتك', b: 'تعيش عادي ومحدش يعرفك'),
    (a: 'تلاقي فلوس في الشارع', b: 'تلاقي صاحب جديد'),
    (a: 'تقعد سنة من غير موبايل', b: 'تقعد سنة من غير خروجات'),
    (a: 'تكسب مليون وتتبرع بنصهم', b: 'تكسب ربع مليون ليك لوحدك'),
    (a: 'تعيش جنب البحر', b: 'تعيش في وسط البلد'),
    (a: 'تتكلم كل اللغات', b: 'تعزف كل الآلات'),
    (a: 'متنامش أبد وماتتعبش', b: 'تنام يوم كامل كل أسبوع'),
    (a: 'تعرف تاريخ وفاتك', b: 'تعرف تاريخ نجاحك'),
    (a: 'تعيد أسعد يوم في حياتك كل سنة', b: 'تنسى أحزن يوم في حياتك'),
    (a: 'تفضل في ثانوي سنة كمان', b: 'تكبر ٥ سنين مرة واحدة'),
    (a: 'صحاب كتير سطحيين', b: 'صاحب واحد بس حقيقي'),
    (a: 'تشتغل حاجة بتحبها بفلوس قليلة', b: 'تشتغل حاجة مملة بفلوس كتير'),
    (a: 'تعيش في التسعينات', b: 'تعيش في المستقبل'),
    (a: 'محدش ينساك أبد', b: 'متتعصبش أبد'),
    (a: 'تسافر الفضاء', b: 'تغوص أعماق المحيط'),
    (a: 'تلعب أحسن لعبة قديمة', b: 'تجرب لعبة مستقبلية'),
    (a: 'تضحك كل اللي حواليك', b: 'تفهم كل اللي حواليك'),
    (a: 'قهوة مضبوطة كل يوم', b: 'أكل بيتي كل يوم'),
  ];

  /// Vote tally: who picked option A vs option B.
  static (List<String>, List<String>) tally(Map<String, int> votes) {
    final a = <String>[];
    final b = <String>[];
    votes.forEach((name, pick) => (pick == 0 ? a : b).add(name));
    return (a, b);
  }

  @override
  State<WouldRatherGame> createState() => _WouldRatherGameState();
}

class _WouldRatherGameState extends State<WouldRatherGame> {
  late final Random _rng = Random(widget.seed);
  bool _showIntro = true;
  bool _started = false;

  List<String> _names = [];
  late List<int> _order;
  int _round = 0;

  // Voting phase.
  bool _voteStarted = false;
  int _voterIndex = 0;
  bool _gateOpen = false;
  final Map<String, int> _votes = {};
  bool _revealed = false;

  ({String a, String b}) get _current =>
      WouldRatherGame.questions[_order[_round]];

  void _start(List<String> names) {
    setState(() {
      _names = names;
      _order = List.generate(
          WouldRatherGame.questions.length, (i) => i)
        ..shuffle(_rng);
      _round = 0;
      _resetRound();
      _started = true;
    });
  }

  void _resetRound() {
    _voteStarted = false;
    _voterIndex = 0;
    _gateOpen = false;
    _votes.clear();
    _revealed = false;
  }

  void _castVote(int pick) {
    _votes[_names[_voterIndex]] = pick;
    setState(() {
      _gateOpen = false;
      if (_voterIndex + 1 < _names.length) {
        _voterIndex++;
      } else {
        _revealed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🤔 لو خيروك',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: GameIntroWidget(
          title: '🤔 لو خيروك',
          icon: '🤔',
          description:
              'سؤال واحد واختيارين.. كل واحد يصوّت في السر بالتناوب، وبعدها نشوف مين مع مين ويبقى الخناق مفتوح! لعبة جلسات قديمة معروفة، بصياغة مصرية على ذوقنا.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🤔 لو خيروك',
        minPlayers: 2,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_round >= _order.length || (_round > 0 && _round >= _names.length * 3)) {
      return _buildEnd();
    }

    return OfflineGameScaffold(
      title: '🤔 لو خيروك',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: !_voteStarted
            ? _buildQuestion()
            : _revealed
                ? _buildReveal()
                : _buildVote(),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _roundLabel(),
        const SizedBox(height: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'لو خيروك..',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  color: FlatColors.ink.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              _optionCard(q.a, FunkyColors.coral),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'ولا',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                ),
              ),
              _optionCard(q.b, FunkyColors.sky),
            ],
          ),
        ),
        FunkyButton(
          label: 'ابدأ التصويت ⚖️',
          accent: FlatColors.tilePastels[4],
          icon: Icons.how_to_vote_rounded,
          onPressed: () => setState(() {
            _voteStarted = true;
            _gateOpen = false;
          }),
        ),
      ],
    );
  }

  Widget _buildVote() {
    final voter = _names[_voterIndex];
    if (!_gateOpen) {
      // Concealment gate between voters.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _roundLabel(),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: FlatDecor.card(radius: 26),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🤫', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      child: FunkyButton(
                        label: 'صوّت يا $voter',
                        accent: FlatColors.tilePastels[4],
                        icon: Icons.visibility_rounded,
                        onPressed: () =>
                            setState(() => _gateOpen = true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'بس $voter اللي يشوف اختياره!',
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
      );
    }

    final q = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'يا $voter، تختار إيه؟',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: FlatColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _voteButton(q.a, FunkyColors.coral, 0),
              const SizedBox(height: 16),
              _voteButton(q.b, FunkyColors.sky, 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReveal() {
    final q = _current;
    final (teamA, teamB) = WouldRatherGame.tally(_votes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _roundLabel(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              _teamCard(q.a, FunkyColors.coral, teamA),
              const SizedBox(height: 14),
              _teamCard(q.b, FunkyColors.sky, teamB),
              const SizedBox(height: 16),
              Text(
                teamA.length == teamB.length
                    ? 'تعادل! حلوها بينكم 😂'
                    : teamA.length > teamB.length
                        ? 'الأغلبية مع الاختيار الأول 🔥'
                        : 'الأغلبية مع الاختيار التاني 🔥',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ).copyWith(
                    fontFamilyFallback: const ['Noto Color Emoji']),
              ),
            ],
          ),
        ),
        FunkyButton(
          label: 'السؤال اللي بعده ⏭',
          accent: FlatColors.tilePastels[4],
          icon: Icons.arrow_forward_rounded,
          onPressed: () => setState(() {
            _round++;
            _resetRound();
          }),
        ),
      ],
    );
  }

  Widget _buildEnd() {
    return OfflineGameScaffold(
      title: '🤔 لو خيروك',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'خلصت الأسئلة! 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 12),
            Text(
              'عرفتوا بعض أكتر شوية؟ 😄',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.cairo(fontSize: 15, color: FlatColors.ink.withValues(alpha: 0.75))
                      .copyWith(
                          fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 24),
            FunkyButton(
              label: 'العب تاني',
              accent: FlatColors.tilePastels[2],
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() {
                _started = false;
                _showIntro = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Neon identity colors -> flat pastels (coral/sky keep their A/B identity).
  static Color _flatOptionColor(Color accent) =>
      accent == FunkyColors.coral ? FlatColors.tilePastels[3] : FlatColors.tilePastels[1];

  /// Darkened option color for text on white cards (pastels alone fail 3:1).
  static Color _flatOptionTextColor(Color accent) {
    final hsl = HSLColor.fromColor(_flatOptionColor(accent));
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  Widget _roundLabel() {
    return Text(
      'السؤال ${_round + 1}',
      textAlign: TextAlign.center,
      style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7)),
    );
  }

  Widget _optionCard(String text, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: FlatDecor.tile(_flatOptionColor(accent), radius: 22),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: FlatDecor.textOn(_flatOptionColor(accent)),
        ),
      ),
    ).animate().scale(duration: 300.ms);
  }

  Widget _voteButton(String text, Color accent, int pick) {
    return GestureDetector(
      onTap: () => _castVote(pick),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: FlatDecor.tile(_flatOptionColor(accent), radius: 22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: FlatDecor.textOn(_flatOptionColor(accent)),
          ),
        ),
      ),
    );
  }

  Widget _teamCard(String option, Color accent, List<String> team) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: FlatDecor.card(radius: 22),
      child: Column(
        children: [
          Text(
            option,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _flatOptionTextColor(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            team.isEmpty ? 'محدش اختارها 😶' : team.join('، '),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15,
              color: FlatColors.ink.withValues(alpha: 0.75),
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 4),
          Text(
            '${team.length} صوت',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: FlatColors.ink.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
