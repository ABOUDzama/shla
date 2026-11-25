import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// الجاسوس (Spy): everyone secretly sees the same location except one spy,
/// who sees only "you are the spy". Players question each other aloud, then
/// vote. Caught spy: everyone else +2. Spy survives the vote: spy +3.
class SpyGame extends StatefulWidget {
  const SpyGame({super.key});

  /// Pure scoring for a finished round.
  static Map<String, int> scoreRound(
    Map<String, int> scores, {
    required String spy,
    required bool spyCaught,
  }) {
    final next = Map<String, int>.from(scores);
    if (spyCaught) {
      for (final name in next.keys) {
        if (name != spy) next[name] = (next[name] ?? 0) + 2;
      }
    } else {
      next[spy] = (next[spy] ?? 0) + 3;
    }
    return next;
  }

  @override
  State<SpyGame> createState() => _SpyGameState();
}

class _SpyGameState extends State<SpyGame> {
  static const List<String> _locations = [
    'الجيم', 'المستشفى', 'الفرح', 'الشاطئ', 'الجامعة', 'المول',
    'مطعم كشري', 'السينما', 'الملعب', 'المطار', 'البنك', 'الصيدلية',
    'محطة المترو', 'القهوة البلدي', 'سوق الخضار', 'الكوافير',
    'محل الموبايلات', 'المدرسة', 'المكتبة', 'الحديقة', 'النادي الرياضي',
    'عيادة الدكتور', 'محطة البنزين', 'الميكروباص',
  ];

  final Random _rng = Random(11);
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  int _spyIndex = 0;
  String? _location;
  final Set<String> _usedLocations = {};
  int _roundsPlayed = 0;

  // Deal phase: pass the phone around; each player taps to peek their card.
  int _dealIndex = 0;
  bool _cardRevealed = false;
  bool _discussionStarted = false;

  int get _totalRounds => _players.length;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _started = true;
      _roundsPlayed = 0;
      _dealRound();
    });
  }

  void _dealRound() {
    final available = _locations
        .where((l) => !_usedLocations.contains(l))
        .toList(growable: false);
    _location = available[_rng.nextInt(available.length)];
    _usedLocations.add(_location!);
    _spyIndex = _rng.nextInt(_players.length);
    _dealIndex = 0;
    _cardRevealed = false;
    _discussionStarted = false;
  }

  void _finishRound({required bool spyCaught}) {
    final scores = {
      for (final p in _players) p['name'] as String: p['score'] as int
    };
    final next = SpyGame.scoreRound(scores,
        spy: _players[_spyIndex]['name'] as String, spyCaught: spyCaught);
    setState(() {
      for (final p in _players) {
        p['score'] = next[p['name']] ?? p['score'];
      }
      _roundsPlayed++;
      if (_roundsPlayed < _totalRounds) _dealRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🕵️ الجاسوس',
        backgroundColor: FunkyColors.violet,
        showAi: false,
        body: GameIntroWidget(
          title: '🕵️ الجاسوس',
          icon: '🕵️',
          description:
              'الكل يشوف نفس المكان في سرية.. إلا جاسوس واحد ميعرفش! سألوا بعض أسئلة وخمنوا مين الجاسوس قبل ما يعرف المكان.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🕵️ الجاسوس',
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
        title: '🕵️ الجاسوس',
        backgroundColor: FunkyColors.violet,
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
                  accent: FlatColors.tilePastels[0],
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() {
                    _started = false;
                    _showIntro = true;
                    _players = [];
                    _usedLocations.clear();
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Deal phase: pass the phone, each player peeks at their role.
    if (!_discussionStarted) {
      final player = _players[_dealIndex];
      final isSpy = _dealIndex == _spyIndex;
      return OfflineGameScaffold(
        title: '🕵️ الجاسوس',
        backgroundColor: FunkyColors.violet,
        showAi: false,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الجولة ${_roundsPlayed + 1} من $_totalRounds',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 8),
              Text(
                'ادّي الموبايل لـ ${player['name']}',
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
                    child: _cardRevealed
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isSpy ? '🕵️' : '📍',
                                style: const TextStyle(fontSize: 56),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isSpy ? 'أنت الجاسوس!' : _location!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: isSpy
                                      ? FlatColors.mafia
                                      : FlatColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isSpy
                                    ? 'خمّن المكان من أسئلة الشلة من غير ما حد يشك فيك'
                                    : 'احفظ المكان كويس.. وفيه جاسوس بينكم ميعرفوش',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                    fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7)),
                              ),
                            ],
                          ).animate().scale(duration: 300.ms)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🤐', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                child: FunkyButton(
                                  label: 'شوف كارتك',
                                  accent: FlatColors.tilePastels[0],
                                  icon: Icons.visibility_rounded,
                                  onPressed: () =>
                                      setState(() => _cardRevealed = true),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'بس ${player['name']} اللي يشوف!',
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
              const SizedBox(height: 20),
              if (_cardRevealed)
                FunkyButton(
                  label: _dealIndex == _players.length - 1
                      ? 'ابدأوا الأسئلة'
                      : 'خبّي وادّي للي بعده',
                  accent: FlatColors.tilePastels[2],
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => setState(() {
                    if (_dealIndex == _players.length - 1) {
                      _discussionStarted = true;
                    } else {
                      _dealIndex++;
                      _cardRevealed = false;
                    }
                  }),
                ),
            ],
          ),
        ),
      );
    }

    // Discussion + vote phase.
    return OfflineGameScaffold(
      title: '🕵️ الجاسوس',
      backgroundColor: FunkyColors.violet,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سألوا بعض عن المكان.. ولما تتفقوا، صوّتوا على الجاسوس!',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 15, color: FlatColors.ink.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 20),
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
                        icon: Icons.person_search_rounded,
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
    final spyName = _players[_spyIndex]['name'] as String;
    final caught = accusedName == spyName;
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
                caught ? 'اتمسك! 🎯' : 'هرب منكم! 🏃',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                caught
                    ? '$accusedName كان الجاسوس فعلاً! المكان كان: $_location'
                    : 'الجاسوس الحقيقي هو $spyName.. والمكان كان: $_location',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 16, color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 20),
              FunkyButton(
                label: _roundsPlayed + 1 < _totalRounds
                    ? 'الجولة اللي بعدها'
                    : 'النتيجة النهائية',
                accent: FlatColors.tilePastels[0],
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _finishRound(spyCaught: caught);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
