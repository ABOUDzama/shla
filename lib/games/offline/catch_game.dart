import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/flat_theme.dart';

/// Pure logic for اقطفها (Grab the Fish-style timing game), kept separate
/// from the widget so it can be unit-tested without pumping frames.
///
/// A marker rotates around a ring split into one colored arc per player.
/// A player taps when the marker is inside their arc to score; tapping
/// while it is outside costs nothing but scores nothing. First to
/// [targetScore] wins.
class CatchMatch {
  CatchMatch({
    required this.playerCount,
    this.targetScore = 5,
    this.startAngle = 0.0,
  })  : scores = List<int>.filled(playerCount, 0),
        _scoredLap = List<int>.filled(playerCount, -1);

  final int playerCount;
  final int targetScore;
  final double startAngle;
  final List<int> scores;

  /// Last revolution each player scored in; a player can score at most
  /// once per pass through their arc, so spam-tapping while the marker
  /// sits inside the arc does not rack up points.
  final List<int> _scoredLap;

  int? matchWinner;

  /// The arc owned by [player], in degrees [0, 360). Player 0 starts at
  /// [startAngle] and arcs proceed clockwise in equal shares.
  ({double from, double to}) zoneOf(int player) {
    final slice = 360.0 / playerCount;
    final from = (startAngle + slice * player) % 360;
    final to = (from + slice) % 360;
    return (from: from, to: to);
  }

  /// True when [angle] (degrees, normalized) lies inside [player]'s arc.
  bool inZone(int player, double angle) {
    final a = angle % 360;
    final z = zoneOf(player);
    if (z.from < z.to) {
      return a >= z.from && a < z.to;
    }
    // Arc wraps past 360.
    return a >= z.from || a < z.to;
  }

  /// Registers a tap for [player] at marker position [angle], which may
  /// exceed 360 to mark later revolutions. Returns true when the tap
  /// scores: the marker must be inside the player's arc and the player
  /// must not have scored yet this revolution.
  bool tap(int player, double angle) {
    if (matchWinner != null) return false;
    final lap = angle ~/ 360;
    if (!inZone(player, angle)) return false;
    if (_scoredLap[player] == lap) return false;
    _scoredLap[player] = lap;
    scores[player]++;
    if (scores[player] >= targetScore) matchWinner = player;
    return true;
  }
}

enum _CatchPhase { picking, playing }

class CatchGame extends StatefulWidget {
  const CatchGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<CatchGame> createState() => _CatchGameState();
}

class _CatchGameState extends State<CatchGame>
    with SingleTickerProviderStateMixin {
  bool _showIntro = true;
  /// Entrance fade runs once; flutter_animate restarts effects on every
  /// rebuild (new effect instances), which made the whole screen re-fade
  /// on every tap during play.
  bool _entranceFaded = false;
  _CatchPhase _phase = _CatchPhase.picking;
  late CatchMatch _match;
  late AnimationController _spin;
  Timer? _roundTimer;
  int _players = 2;
  double _startAngle = 0;
  late final Random _random = widget.randomSeed != null ? Random(widget.randomSeed!) : Random();
  String _banner = '';

  static const List<Color> _zoneColors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  @override
  void dispose() {
    _spin.dispose();
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _roundTimer?.cancel();
    _spin.stop();
    setState(() {
      _players = players;
      _phase = _CatchPhase.playing;
      _startMatchRound();
    });
  }

  void _startMatchRound() {
    _lap = 0;
    _lastSpinValue = 0;
    _match = CatchMatch(playerCount: _players, startAngle: _startAngle);
    _banner = 'اطقطف لما السمكة تعدي على لونك! 🐟';
    _spin.duration = Duration(milliseconds: 2200 + _random.nextInt(1500));
    _spin.repeat();
  }

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        // repeat() wraps the value from ~1 back to ~0 each revolution;
        // count laps from the wrap so spam taps score once per pass
        if (_spin.value < _lastSpinValue - 0.5) _lap++;
        _lastSpinValue = _spin.value;
      });
  }

  int _lap = 0;
  double _lastSpinValue = 0;

  void _onTapZone(int player) {
    if (_match.matchWinner != null || !_spin.isAnimating) return;
    final angle = _spin.value * 360 + _lap * 360;
    final scored = _match.tap(player, angle);
    setState(() {
      _banner = scored
          ? 'لاعب ${player + 1} قطفها! 🎉'
          : 'لاعب ${player + 1} غلط اللون 😬';
      if (_match.matchWinner != null) {
        _spin.stop();
        _banner = 'لاعب ${player + 1} كسب الماتش! 🏆';
      }
    });
  }

  Widget _buildRing() {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) {
            return CustomPaint(
              painter: _RingPainter(
                players: _players,
                startAngle: _startAngle,
                markerAngle: _spin.value * 2 * pi,
                colors: _zoneColors,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var p = 0; p < _players; p++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _zoneColors[p].withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'لاعب ${p + 1}: ${_match.scores[p]}',
                style: flatCairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTapZones() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          for (var p = 0; p < _players; p++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _zoneColors[p],
                    foregroundColor: FlatColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: () => _onTapZone(p),
                  child: Text(
                    'لاعب ${p + 1}',
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'كام لاعب؟',
            style: flatCairo(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: FlatColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'السمكة بتلف، دوس لما تدخل في لونك. أول ٥ نقط تكسب',
            style: flatCairo(fontSize: 15, color: FlatColors.ink.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [2, 3, 4])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _zoneColors[n - 2],
                      foregroundColor: FlatColors.ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                    ),
                    onPressed: () => _startMatch(n),
                    child: Text(
                      '$n',
                      style: flatCairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'اقطفها',
        description:
            'السمكة بتلف حوالين الدواير الملونة! دوس على زرارك بالظبط لما تكون السمكة جوه اللون بتاعك. دوسة غلط مفيهاش نقط. أول واحد يوصل ٥ نقط يكسب الماتش 🐟',
        icon: '🐟',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final scaffold = OfflineGameScaffold(
      title: 'اقطفها',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _CatchPhase.picking
            ? _buildPicker()
            : Column(
                children: [
                  _buildScoreBar(),
                  if (_match.matchWinner != null)
                    VictoryFriends(
                        winnerName: 'لاعب ${_match.matchWinner! + 1}'),
                  Expanded(child: _buildRing()),
                  Text(
                    _banner,
                    style: flatCairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                    ).copyWith(
                        fontFamilyFallback: const ['Noto Color Emoji']),
                  ),
                  const SizedBox(height: 4),
                  if (_match.matchWinner != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton(
                        onPressed: () => setState(() {
                          _startAngle = _random.nextDouble() * 360;
                          _startMatchRound();
                        }),
                        child: Text(
                          'ماتش جديد',
                          style:
                              flatCairo(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  else
                    _buildTapZones(),
                ],
              ),
      ),
    );
    if (_entranceFaded) return scaffold;
    _entranceFaded = true;
    return scaffold.animate().fadeIn(duration: 300.ms);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.players,
    required this.startAngle,
    required this.markerAngle,
    required this.colors,
  });

  final int players;
  final double startAngle;
  final double markerAngle;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final slice = 2 * pi / players;
    final start = startAngle * pi / 180 - pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p = 0; p < players; p++) {
      paint.color = colors[p % colors.length].withValues(alpha: 0.8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + slice * p + 0.03,
        slice - 0.06,
        true,
        paint,
      );
    }

    // Center hole to make it a ring of arcs.
    paint.color = FlatColors.bg;
    canvas.drawCircle(center, radius * 0.55, paint);

    // Marker fish on the ring.
    final mx = center.dx + radius * 0.78 * cos(markerAngle - pi / 2 + start);
    final my = center.dy + radius * 0.78 * sin(markerAngle - pi / 2 + start);
    final tp = TextPainter(
      text: const TextSpan(
        text: '🐟',
        style: TextStyle(fontSize: 34, fontFamily: 'Noto Color Emoji'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(mx - tp.width / 2, my - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.markerAngle != markerAngle ||
      oldDelegate.players != players ||
      oldDelegate.startAngle != startAngle;
}
