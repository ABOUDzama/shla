import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// أكمل المثل: the first half of an Egyptian proverb shows with 4 possible
/// endings (the right one plus endings borrowed from other proverbs). A wrong
/// pick passes the same proverb to the next player for a steal.
class ProverbGame extends StatefulWidget {
  const ProverbGame({super.key});

  /// Builds the 4 options for a round: the correct ending plus 3 endings
  /// sampled from other proverbs, shuffled with [seed].
  static List<String> buildOptions(
      List<({String start, String end})> proverbs, int index, int seed) {
    final correct = proverbs[index].end;
    final others = [
      for (var i = 0; i < proverbs.length; i++)
        if (i != index) proverbs[i].end
    ]..shuffle(Random(seed));
    return [correct, ...others.take(3)]..shuffle(Random(seed + 1));
  }

  static const List<({String start, String end})> proverbs = [
    (start: 'اللي يتلسع من الشوربة...', end: 'ينفخ في الزبادي'),
    (start: 'الجار قبل...', end: 'الدار'),
    (start: 'عصفور في الإيد...', end: 'أحسن من عشرة على الشجرة'),
    (start: 'الطيور على...', end: 'أشكالها تقع'),
    (start: 'اللي حابب الورد...', end: 'يصبر على الشوك'),
    (start: 'اسأل مجرب...', end: 'وماتسألش طبيب'),
    (start: 'اللي على راسه بطحة...', end: 'يحسس عليها'),
    (start: 'القناعة...', end: 'كنز لا يفنى'),
    (start: 'درهم وقاية...', end: 'خير من قنطار علاج'),
    (start: 'في التأني...', end: 'السلامة'),
    (start: 'في العجلة...', end: 'الندامة'),
    (start: 'العلم في الصغر...', end: 'كالنقش على الحجر'),
    (start: 'خير الكلام...', end: 'ما قل ودل'),
    (start: 'اللي بيته من إزاز...', end: 'ميحدفش الناس بالطوب'),
    (start: 'الصديق وقت...', end: 'الضيق'),
    (start: 'اليد الواحدة...', end: 'ماتصفقش'),
    (start: 'أول الغيث...', end: 'قطرة'),
    (start: 'اللي يزرع حنطة...', end: 'يحصد حنطة'),
    (start: 'خير الأمور...', end: 'أوسطها'),
    (start: 'الوقت...', end: 'كالسيف'),
    (start: 'الباب اللي يجيلك منه الريح...', end: 'سده واستريح'),
    (start: 'عين الحب...', end: 'عميا'),
    (start: 'الكتاب بيبان...', end: 'من عنوانه'),
    (start: 'الصاحب...', end: 'ساتر'),
  ];

  @override
  State<ProverbGame> createState() => _ProverbGameState();
}

class _ProverbGameState extends State<ProverbGame> {


  final Random _rng = Random(13);
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  final List<int> _order = [];
  int _roundsPlayed = 0;
  int _turn = 0;
  int _attemptsLeft = 0;
  String? _lastPick;
  bool? _lastWasCorrect;

  int get _totalRounds => _players.length;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _started = true;
      _order
        ..clear()
        ..addAll(List.generate(ProverbGame.proverbs.length, (i) => i))
        ..shuffle(_rng);
      _roundsPlayed = 0;
      _turn = 0;
      _attemptsLeft = _players.length;
      _lastPick = null;
      _lastWasCorrect = null;
    });
  }

  int get _proverbIndex => _order[_roundsPlayed % _order.length];

  void _pick(String option) {
    final correct = ProverbGame.proverbs[_proverbIndex].end;
    setState(() {
      _lastPick = option;
      if (option == correct) {
        _players[_turn]['score'] = (_players[_turn]['score'] as int) + 1;
        _lastWasCorrect = true;
      } else {
        _lastWasCorrect = false;
        _attemptsLeft--;
        _turn = (_turn + 1) % _players.length;
      }
    });
  }

  void _nextRound() {
    setState(() {
      _roundsPlayed++;
      _attemptsLeft = _players.length;
      _lastPick = null;
      _lastWasCorrect = null;
      _turn = _roundsPlayed % _players.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '📜 أكمل المثل',
        backgroundColor: FunkyColors.pink,
        showAi: false,
        body: GameIntroWidget(
          title: '📜 أكمل المثل',
          icon: '📜',
          description:
              'النص الأولاني من مثل شعبي قدامك و4 نهايات.. اختار الصح! غلطت؟ المثل يروح للي بعدك ويسرق النقطة.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '📜 أكمل المثل',
        minPlayers: 2,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_roundsPlayed >= _totalRounds) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      final top = sorted.first['score'] as int;
      final winners = sorted.where((p) => p['score'] == top).toList();
      return OfflineGameScaffold(
        title: '📜 أكمل المثل',
        backgroundColor: FunkyColors.pink,
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
                  accent: FlatColors.tilePastels[5],
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

    final proverb = ProverbGame.proverbs[_proverbIndex];
    final options =
        ProverbGame.buildOptions(ProverbGame.proverbs, _proverbIndex, _roundsPlayed + 5);
    final roundOver = _lastWasCorrect == true || _attemptsLeft <= 0;

    return OfflineGameScaffold(
      title: '📜 أكمل المثل',
      backgroundColor: FunkyColors.pink,
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
              'دور: ${_players[_turn]['name']}',
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FlatDecor.card(radius: 24),
              child: Text(
                proverb.start,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
            ).animate().fadeIn(duration: 250.ms),
            if (_lastWasCorrect == false)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'غلط! $_lastPick مش هي.. الفرصة لـ ${_players[_turn]['name']}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FlatColors.mafia,
                  ),
                ),
              ),
            if (roundOver)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'الإجابة: ${proverb.end}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FlatColors.mintDark,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FunkyButton(
                        label: option,
                        accent: roundOver && option == proverb.end
                            ? FlatColors.tilePastels[2]
                            : FlatColors.tilePastels[1],
                        onPressed: roundOver ? () {} : () => _pick(option),
                      ),
                    ),
                ],
              ),
            ),
            if (roundOver)
              FunkyButton(
                label: _roundsPlayed + 1 < _totalRounds
                    ? 'المثل اللي بعده'
                    : 'النتيجة النهائية',
                accent: FlatColors.tilePastels[5],
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextRound,
              ),
          ],
        ),
      ),
    );
  }
}
