import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// Pure round/match logic for the reaction game, kept separate from the
/// widget so it can be unit-tested without pumping timers.
enum ReactionOutcome { roundWin, falseStart, ignored }

class ReactionMatch {
  ReactionMatch({required this.playerCount, this.targetScore = 5})
      : scores = List<int>.filled(playerCount, 0);

  final int playerCount;
  final int targetScore;
  final List<int> scores;

  /// True while a round accepts taps (either waiting for green or green).
  bool roundActive = true;
  int? matchWinner;

  /// Registers a tap for [player]. [green] says whether the signal was
  /// already showing. A tap before green is a false start: the player loses
  /// a point (never below zero) and the round ends. The first tap after
  /// green wins the round; reaching [targetScore] wins the match.
  ReactionOutcome tap(int player, {required bool green}) {
    if (!roundActive || matchWinner != null) {
      return ReactionOutcome.ignored;
    }
    roundActive = false;
    if (!green) {
      if (scores[player] > 0) scores[player]--;
      return ReactionOutcome.falseStart;
    }
    scores[player]++;
    if (scores[player] >= targetScore) {
      matchWinner = player;
    }
    return ReactionOutcome.roundWin;
  }

  /// Arms the next round. No-op once the match has a winner.
  void nextRound() {
    if (matchWinner == null) roundActive = true;
  }
}

/// Monotonic clock (Stopwatch) used to time reactions; tests replace it with
/// the fake test clock so a controlled delay reports that delay.
final Stopwatch _mono = Stopwatch()..start();
Duration Function() reactionNow = () => _mono.elapsed;

class ReactionGame extends StatefulWidget {
  const ReactionGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<ReactionGame> createState() => _ReactionGameState();
}

enum _Phase { pickPlayers, pickBots, waiting, green, resolved, matchOver }

class _ReactionGameState extends State<ReactionGame> {
  bool _showIntro = true;
  /// Entrance fade runs once; flutter_animate restarts effects on every
  /// rebuild (new effect instances), which made the whole screen re-fade
  /// on every tap during play.
  bool _entranceFaded = false;
  _Phase _phase = _Phase.pickPlayers;
  late ReactionMatch _match;
  Timer? _greenTimer;
  Timer? _nextTimer;
  late final Random _random =
      widget.randomSeed != null ? Random(widget.randomSeed!) : Random();
  final List<Timer> _botTimers = [];
  int _humans = 2;
  bool _practice = false;
  final Set<int> _botSeats = {};
  Duration? _greenAt;
  int? _lastWinner;
  bool _lastFalse = false;
  int? _lastMs;

  @visibleForTesting
  ReactionMatch get debugMatch => _match;
  @visibleForTesting
  Set<int> get debugBots => _botSeats;
  @visibleForTesting
  bool get debugGreen => _phase == _Phase.green;

  static const List<Color> _zoneColors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _greenTimer?.cancel();
    _nextTimer?.cancel();
    for (final t in _botTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _startMatch(int humans, bool withBots) {
    _greenTimer?.cancel();
    _nextTimer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    _botSeats
      ..clear()
      ..addAll([for (var i = humans; i < seats && withBots; i++) i]);
    setState(() {
      _match = ReactionMatch(playerCount: seats);
      _lastWinner = null;
    });
    _armRound();
  }

  void _armRound() {
    _greenTimer?.cancel();
    setState(() {
      _match.nextRound();
      _phase = _Phase.waiting;
      _lastWinner = null;
      _lastMs = null;
    });
    final delay = Duration(milliseconds: 1500 + _random.nextInt(3000));
    _greenTimer = Timer(delay, () {
      if (!mounted || _phase != _Phase.waiting) return;
      setState(() {
        _phase = _Phase.green;
        _greenAt = reactionNow();
      });
      for (final b in _botSeats) {
        if (_random.nextDouble() < 0.85) {
          _botTimers.add(Timer(Duration(milliseconds: 300 + _random.nextInt(350)), () {
            if (mounted && _phase == _Phase.green) _onZoneTap(b);
          }));
        }
      }
    });
  }

  void _onZoneTap(int player) {
    if (_phase != _Phase.waiting && _phase != _Phase.green) return;
    final outcome = _match.tap(player, green: _phase == _Phase.green);
    if (outcome == ReactionOutcome.ignored) return;
    for (final t in _botTimers) {
      t.cancel();
    }
    _botTimers.clear();
    setState(() {
      _lastWinner = player;
      _lastFalse = outcome == ReactionOutcome.falseStart;
      _lastMs = _greenAt == null || _lastFalse
          ? null
          : (reactionNow() - _greenAt!).inMilliseconds;
      _phase = _match.matchWinner != null ? _Phase.matchOver : _Phase.resolved;
    });
    if (_match.matchWinner == null) {
      _nextTimer?.cancel();
      _nextTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _phase == _Phase.resolved) _armRound();
      });
    }
  }

  Widget _buildZone(int player) {
    // the zone drawn at the top of the screen faces the player sitting
    // there, so its text is rotated; in a 2-player match that is player 2
    final isTop = _match.playerCount == 2
        ? player == 1
        : _match.playerCount > 2 && player < 2;
    final waiting = _phase == _Phase.waiting;
    final green = _phase == _Phase.green;
    final color = green
        ? FunkyColors.lime
        : waiting
            ? FlatColors.tileWhite
            : _zoneColors[player];
    // max-contrast text on whatever the zone fill is (ink wins on every
    // flat pastel; white would fail on lime/cyan)
    final onZone = FlatDecor.textOn(color);
    final label = _botSeats.contains(player) ? 'بوت ${player + 1}' : 'لاعب ${player + 1}';
    final msg = green
        ? 'دوس!'
        : waiting
            ? 'استنى الأخضر'
            : _lastWinner == player
                ? (_lastFalse
                    ? 'بدري! -١'
                    : (_lastMs != null ? 'الأسرع  $_lastMs ms' : 'الأسرع'))
                : '';
    final score = _match.scores[player];
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: flatCairo(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: onZone,
            ),
          ),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(msg,
                  style: flatCairo(fontSize: 26, fontWeight: FontWeight.w900, color: onZone)),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$score / ${_match.targetScore}',
              textDirection: TextDirection.ltr,
              style: flatCairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: FlatColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Expanded(
      child: GestureDetector(
        key: ValueKey('zone_$player'),
        onTap: _botSeats.contains(player) ? null : () => _onZoneTap(player),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: waiting ? 0.55 : 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _zoneColors[player], width: 2),
          ),
          child:
              isTop ? Transform.rotate(angle: pi, child: content) : content,
        ),
      ),
    );
  }

  Widget _buildArena() {
    final players = _match.playerCount;
    final zones = List.generate(players, _buildZone);
    return Column(
      children: [
        Expanded(
          child: players == 1
              ? Column(children: [zones[0]])
              : players == 2
              ? Column(children: [zones[1], zones[0]])
              : Column(
                  children: [
                    Expanded(
                      child: Row(children: [zones[1], zones[0]]),
                    ),
                    Expanded(
                      child: Row(
                        children: players == 4
                            ? [zones[3], zones[2]]
                            : [Expanded(child: const SizedBox()), zones[2]],
                      ),
                    ),
                  ],
                ),
        ),
        if (_phase == _Phase.matchOver)
          Builder(builder: (context) {
            final w = _match.matchWinner!;
            if (_practice) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('خلصت ٥ جولات', style: _t(22)),
              );
            }
            return w >= _humans
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('البوتات كسبوا 🤖',
                        style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900, color: FlatColors.ink)
                            .copyWith(fontFamilyFallback: const ['Noto Color Emoji'])))
                : VictoryFriends(
                    gameTitle: _practice ? null : 'أسرع رد فعل',
                    winnerName: 'لاعب ${w + 1}');
          }),
        if (_phase == _Phase.matchOver)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton(
              onPressed: () => setState(() => _phase = _Phase.pickPlayers),
              child: Text(
                'العب تاني',
                style: flatCairo(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: const ['Noto Color Emoji']);

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(onPressed: onTap, child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _buildPicker() => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('كام لاعب؟', style: _t(26)),
            const SizedBox(height: 20),
            _bigChoice('لاعب واحد', () {
              _humans = 1;
              setState(() => _phase = _Phase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startMatch(4, false);
                } else {
                  setState(() => _phase = _Phase.pickBots);
                }
              }),
          ]),
        ),
      );

  Widget _buildBots() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('نضيف بوتات؟', style: _t(26)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'من غير بوتات هتتدرب لوحدك وتشوف سرعة ردّك'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'أسرع رد فعل',
        description:
            'الشاشة هتستنى شوية وبعدين تقلب خضرا.. أول واحد يدوس يكسب الجولة! اللي يدوس قبل الأخضر تتخصم منه نقطة. أول واحد يوصل ٥ نقط يكسب الماتش ⚡',
        icon: '⚡',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final scaffold = OfflineGameScaffold(
      title: 'أسرع رد فعل',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _buildPicker(),
          _Phase.pickBots => _buildBots(),
          _ => _buildArena(),
        },
      ),
    );
    if (_entranceFaded) return scaffold;
    _entranceFaded = true;
    return scaffold.animate().fadeIn(duration: 300.ms);
  }
}
