import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/flat_theme.dart';

/// Pure logic for سباق الدوس (Shla-original same-phone tap race).
///
/// Rules: 2-4 players share one phone, each with a colored lane. After a
/// countdown a 5-second sprint starts; everyone taps their lane as fast as
/// possible. Most taps wins the round and scores a point. A tie means a
/// replay round (no points). First to [roundsToWin] points wins the match.
class TapRaceMatch {
  TapRaceMatch({required this.players, this.roundsToWin = 3, Random? random})
    : assert(players >= 1 && players <= 4),
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

enum _RacePhase {
  pickPlayers,
  pickBots,
  countdown,
  sprint,
  roundResult,
  matchOver,
}

class TapRaceGame extends StatefulWidget {
  const TapRaceGame({super.key, this.randomSeed});
  final int? randomSeed;

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
  int _humans = 2;
  bool _practice = false;
  final Set<int> _botSeats = {};
  Timer? _botTimer;
  late final Random _random = widget.randomSeed != null
      ? Random(widget.randomSeed!)
      : Random();

  @visibleForTesting
  TapRaceMatch get debugMatch => _match;
  @visibleForTesting
  Set<int> get debugBots => _botSeats;

  static const List<Color> _laneColors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  void _startMatch(int humans, bool withBots) {
    ArcadeJuice.tap();
    _timer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    _botSeats
      ..clear()
      ..addAll([for (var i = humans; i < seats && withBots; i++) i]);
    setState(() {
      _match = TapRaceMatch(
        players: seats,
        roundsToWin: _practice ? 1 : 3,
        random: _random,
      );
      _match.start();
      _phase = _RacePhase.countdown;
      _countdown = 3;
    });
    _tickCountdown();
  }

  void _runBots() {
    _botTimer?.cancel();
    if (_botSeats.isEmpty) return;
    _botTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _phase != _RacePhase.sprint) return;
      setState(() {
        for (final b in _botSeats) {
          // about 4-6 taps a second, a bit different per seat
          if (_random.nextDouble() < 0.4 + 0.06 * (b - _humans)) _match.tap(b);
        }
      });
    });
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
        _runBots();
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
        _botTimer?.cancel();
        final winner = _match.endSprint();
        setState(() {
          _secondsLeft = 0;
          _lastWinner = winner;
          _phase = _match.matchWinner != null
              ? _RacePhase.matchOver
              : _RacePhase.roundResult;
        });
        final mw = _match.matchWinner;
        if (mw != null) {
          _botSeats.contains(mw) ? ArcadeJuice.lose() : ArcadeJuice.win();
        }
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

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(
        fontSize: size,
        fontWeight: w,
        color: color ?? FlatColors.ink,
      ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']);

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      width: 220,
      child: FilledButton(
        onPressed: onTap,
        child: Text(label, style: _t(18, color: Colors.white)),
      ),
    ),
  );

  Widget _buildPicker() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('كام لاعب؟', style: _t(26)),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () {
            _humans = 1;
            setState(() => _phase = _RacePhase.pickBots);
          }),
          for (final n in [2, 3, 4])
            _bigChoice('$n لاعبين', () {
              _humans = n;
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() => _phase = _RacePhase.pickBots);
              }
            }),
        ],
      ),
    ),
  );

  Widget _buildBots() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('نضيف بوتات؟', style: _t(26)),
        const SizedBox(height: 8),
        Text(
          _humans == 1
              ? 'من غير بوتات هتتدرب لوحدك: دوسة كام في ٥ ثواني'
              : 'البوتات بتكمّل لحد ٤ لاعبين',
          style: _t(14, w: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
        _bigChoice('لا', () => _startMatch(_humans, false)),
      ],
    ),
  );

  Widget _buildLane(int player) {
    final isTop =
        _match.players > 1 &&
        ((_match.players == 2 && player == 0) ||
            (_match.players > 2 && player < 2));
    final sprinting = _phase == _RacePhase.sprint;
    final taps = _match.taps[player];
    final score = _match.scores[player];
    final onLane = FlatDecor.textOn(_laneColors[player]);
    final laneMsg = switch (_phase) {
      _RacePhase.countdown => '$_countdown',
      _RacePhase.roundResult =>
        _lastWinner == null
            ? 'تعادل، الجولة تتعاد'
            : (_lastWinner == player ? 'كسبت الجولة' : ''),
      _ => '',
    };
    final content = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _botSeats.contains(player) ? 'بوت ${player + 1}' : PlayerNames.name(player),
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: onLane,
              ),
            ),
            Text(
              '$taps',
              style: flatCairo(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: onLane,
              ),
            ),
            if (laneMsg.isNotEmpty)
              Text(
                laneMsg,
                style: flatCairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: onLane,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$score / ${_match.roundsToWin}',
                textDirection: TextDirection.ltr,
                style: flatCairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!sprinting || _botSeats.contains(player)) return;
          setState(() => _match.tap(player));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: sprinting
                ? _laneColors[player]
                : Color.alphaBlend(
                    _laneColors[player].withValues(alpha: 0.55),
                    Colors.white,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlatColors.ink, width: 2),
          ),
          child: KeyedSubtree(
            key: ValueKey('lane_$player'),
            child: isTop
                ? Transform.rotate(angle: pi, child: content)
                : content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'سباق الدوس',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'سباق الدوس',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            'لما العد يخلص، دوس على حارتك أسرع ما تقدر لمدة ٥ ثواني! الأكثر دوسات ياخد الجولة، وأول واحد يوصل ٣ جولات يكسب الماتش. تعادل؟ الجولة تتعاد.',
        icon: '👟',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    return OfflineGameScaffold(
      title: 'سباق الدوس',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _RacePhase.pickPlayers
            ? _buildPicker()
            : _phase == _RacePhase.pickBots
            ? _buildBots()
            : Column(
                children: [
                  if (_phase == _RacePhase.matchOver)
                    _practice
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'دوست ${_match.taps[0]} دوسة في ٥ ثواني',
                              style: _t(22),
                            ),
                          )
                        : (_match.matchWinner! >= _humans
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: BotsWinLabel(
                                    gameTitle: 'سباق الدوس',
                                    style: _t(22),
                                  ),
                                )
                              : VictoryFriends(
                                  gameTitle: 'سباق الدوس',
                                  winnerName: '${PlayerNames.name(_match.matchWinner!)}',
                                  winnerSeats: [_match.matchWinner!],
                                )),
                  if (_phase == _RacePhase.sprint)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '$_secondsLeft',
                        key: const ValueKey('clock'),
                        style: _t(28),
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
                            ? () => setState(
                                () => _phase = _RacePhase.pickPlayers,
                              )
                            : _nextRound,
                        child: Text(
                          _phase == _RacePhase.matchOver
                              ? 'ماتش جديد'
                              : 'الجولة الجاية',
                          style: flatCairo(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
