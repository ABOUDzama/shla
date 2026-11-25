import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';

/// Pure logic for سباق الدوس (Shla-original same-phone tap race).
///
/// Rules: 2-4 players share one phone, each with a colored lane. After a
/// countdown a 5-second sprint starts; everyone taps their lane as fast as
/// possible. Most taps wins the round and scores a point. A tie means a
/// replay round (no points). First to [roundsToWin] points wins the match.
class TapRaceMatch {
  TapRaceMatch({required this.players, this.roundsToWin = 3, Random? random})
      : assert(players >= 2 && players <= 4),
        assert(roundsToWin >= 1),
        _random = random ?? Random();

  final int players;
  final int roundsToWin;
  final Random _random;

  static const int roundDurationSeconds = 5;

  final List<int> _scores = <int>[];
  final List<int> _taps = <int>[];
  int _round = 0;
  bool _sprintLive = false;

  void start() {
    _scores
      ..clear()
      ..addAll(List<int>.filled(players, 0));
    _round = 0;
    _startRound();
  }

  void _startRound() {
    _round++;
    _taps
      ..clear()
      ..addAll(List<int>.filled(players, 0));
    _sprintLive = true;
  }

  int get round => _round;
  List<int> get scores => List<int>.unmodifiable(_scores);
  List<int> get taps => List<int>.unmodifiable(_taps);
  bool get sprintLive => _sprintLive;

  /// Records a tap for [player] (0-based). Ignored when the sprint is not
  /// live (before GO or after time).
  void tap(int player) {
    if (!_sprintLive) return;
    if (player < 0 || player >= players) return;
    _taps[player]++;
  }

  /// Called when the 5 seconds elapse. Returns the round winner index, or
  /// null on a tie (round replays, no points).
  int? endSprint() {
    if (!_sprintLive) return null;
    _sprintLive = false;
    int best = 0;
    for (final t in _taps) {
      if (t > best) best = t;
    }
    if (best == 0) return null; // nobody tapped: replay
    final winners = <int>[
      for (int i = 0; i < players; i++)
        if (_taps[i] == best) i,
    ];
    if (winners.length > 1) return null; // tie: replay
    final winner = winners.single;
    _scores[winner]++;
    return winner;
  }

  /// True when the last sprint ended in a tie and the round replays.
  bool get roundWasTie => _lastRoundTie;

  bool _lastRoundTie = false;

  /// Marks the outcome of the just-ended sprint and prepares the next round.
  /// [winner] must come from [endSprint]; null means tie replay.
  void advance(int? winner) {
    _lastRoundTie = winner == null;
    if (matchWinner != null) return;
    _startRound();
  }

  /// Match winner index (first to [roundsToWin] points), or null.
  int? get matchWinner {
    for (int i = 0; i < players; i++) {
      if (_scores.length == players && _scores[i] >= roundsToWin) return i;
    }
    return null;
  }

  /// Random lane highlight used by the UI for the ready phase.
  int randomLane() => _random.nextInt(players);
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

enum _RacePhase { pickPlayers, countdown, sprint, roundResult, matchOver }

class TapRaceGame extends StatefulWidget {
  const TapRaceGame({super.key});

  @override
  State<TapRaceGame> createState() => _TapRaceGameState();
}

class _TapRaceGameState extends State<TapRaceGame> {
  bool _showIntro = true;
  _RacePhase _phase = _RacePhase.pickPlayers;
  late TapRaceMatch _match;
  Timer? _timer;
  int _countdown = 3;
  int _secondsLeft = TapRaceMatch.roundDurationSeconds;
  int? _lastWinner;

  static const List<Color> _laneColors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _timer?.cancel();
    setState(() {
      _match = TapRaceMatch(players: players);
      _match.start();
      _phase = _RacePhase.countdown;
      _countdown = 3;
    });
    _tickCountdown();
  }

  void _tickCountdown() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _phase != _RacePhase.countdown) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
        _tickCountdown();
      } else {
        setState(() {
          _phase = _RacePhase.sprint;
          _secondsLeft = TapRaceMatch.roundDurationSeconds;
        });
        _tickSprint();
      }
    });
  }

  void _tickSprint() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _phase != _RacePhase.sprint) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        _tickSprint();
      } else {
        final winner = _match.endSprint();
        setState(() {
          _secondsLeft = 0;
          _lastWinner = winner;
          _phase = _match.matchWinner != null
              ? _RacePhase.matchOver
              : _RacePhase.roundResult;
        });
      }
    });
  }

  void _nextRound() {
    if (!mounted) return;
    setState(() {
      _match.advance(_lastWinner);
      _phase = _RacePhase.countdown;
      _countdown = 3;
    });
    _tickCountdown();
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'كام لاعب؟',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          for (final n in [2, 3, 4])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () => _startMatch(n),
                  child: Text(
                    '$n لاعبين',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLane(int player) {
    final isTop = (_match.players == 2 && player == 0) ||
        (_match.players > 2 && player < 2);
    final sprinting = _phase == _RacePhase.sprint;
    final taps = _match.taps[player];
    final score = _match.scores[player];
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'لاعب ${player + 1}',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            '$taps',
            style: GoogleFonts.cairo(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$score / ${_match.roundsToWin}',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!sprinting) return;
          setState(() => _match.tap(player));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _laneColors[player].withValues(alpha: sprinting ? 0.9 : 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _laneColors[player], width: 2),
          ),
          child: isTop ? Transform.rotate(angle: pi, child: content) : content,
        ),
      ),
    );
  }

  String get _banner {
    switch (_phase) {
      case _RacePhase.countdown:
        return '$_countdown...';
      case _RacePhase.sprint:
        return 'دوسوا! $_secondsLeft';
      case _RacePhase.roundResult:
        return _lastWinner == null
            ? 'تعادل! الجولة تتعاد 😬'
            : 'لاعب ${_lastWinner! + 1} كسب الجولة! 🏁';
      case _RacePhase.matchOver:
        return 'لاعب ${_match.matchWinner! + 1} كسب الماتش! 🏆';
      case _RacePhase.pickPlayers:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'سباق الدوس',
        description:
            '٢-٤ لاعبين على نفس الموبايل. لما العد يخلص، دوس على حارتك أسرع ما تقدر لمدة ٥ ثواني! الأكثر دوسات ياخد الجولة، وأول واحد يوصل ٣ جولات يكسب الماتش. تعادل؟ الجولة تتعاد.',
        icon: '👟',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'سباق الدوس',
      backgroundColor: FunkyColors.orange,
      body: SafeArea(
        child: _phase == _RacePhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  if (_phase == _RacePhase.matchOver)
                    VictoryFriends(
                        winnerName: 'لاعب ${_match.matchWinner! + 1}'),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: FunkyColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: FunkyColors.amber, width: 1.6),
                      ),
                      child: Text(
                        _banner,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ).copyWith(
                            fontFamilyFallback: const ['Noto Color Emoji']),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: List.generate(_match.players, _buildLane),
                    ),
                  ),
                  if (_phase == _RacePhase.roundResult ||
                      _phase == _RacePhase.matchOver)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton(
                        onPressed: _phase == _RacePhase.matchOver
                            ? () => _startMatch(_match.players)
                            : _nextRound,
                        child: Text(
                          _phase == _RacePhase.matchOver
                              ? 'ماتش جديد'
                              : 'الجولة الجاية',
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
