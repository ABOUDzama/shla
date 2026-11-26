import 'package:flutter/material.dart';
import 'dart:math';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/flat_theme.dart';

/// Pure logic for اقطفها (Grab the Fish-style timing game), kept separate
/// from the widget so it can be unit-tested without pumping frames.
///
/// A marker rotates around a ring split into one colored arc per player.
/// A player taps when the marker is inside their arc to score; tapping
/// while it is outside locks that player out until the next lap. First to
/// [targetScore] wins.
class CatchMatch {
  CatchMatch({
    required this.playerCount,
    this.targetScore = 5,
    this.startAngle = 0.0,
  })  : scores = List<int>.filled(playerCount, 0),
        _scoredLap = List<int>.filled(playerCount, -1),
        _lockedLap = List<int>.filled(playerCount, -1);

  final int playerCount;
  final int targetScore;
  final double startAngle;
  final List<int> scores;

  /// Last revolution each player scored in; a player can score at most
  /// once per pass through their arc, so spam-tapping while the marker
  /// sits inside the arc does not rack up points.
  final List<int> _scoredLap;

  /// Lap in which a player tapped outside their arc. A wrong tap locks that
  /// player out for the rest of the lap, so spamming no longer wins.
  final List<int> _lockedLap;

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
    if (_lockedLap[player] == lap) return false;
    if (!inZone(player, angle)) {
      _lockedLap[player] = lap;
      return false;
    }
    if (_scoredLap[player] == lap) return false;
    _scoredLap[player] = lap;
    scores[player]++;
    if (scores[player] >= targetScore) matchWinner = player;
    return true;
  }
}

enum _CatchPhase { pickPlayers, pickBots, playing }

class CatchGame extends StatefulWidget {
  const CatchGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<CatchGame> createState() => _CatchGameState();
}

class _CatchGameState extends State<CatchGame> with SingleTickerProviderStateMixin {
  bool _showIntro = true;
  _CatchPhase _phase = _CatchPhase.pickPlayers;
  late CatchMatch _match;
  late AnimationController _spin;
  late final Random _random = widget.randomSeed != null ? Random(widget.randomSeed!) : Random();
  int _humans = 2;
  int _seats = 2;
  bool _practice = false;
  int _lap = 0;
  double _lastSpinValue = 0;
  final Set<int> _botSeats = {};

  /// The ring always has 4 quadrants, one per corner, clockwise from the
  /// top: top-right = seat 2, bottom-right = seat 3, bottom-left = seat 1,
  /// top-left = seat 4 (seat index 1, 2, 0, 3). So a player's arc sits in
  /// the same corner as their pad. Quadrants of absent seats are grey.
  static const _zoneOfSeat = [2, 0, 1, 3];
  static const _seatOfZone = [1, 2, 0, 3];
  int _score(int seat) => _match.scores[_zoneOfSeat[seat]];
  // per bot: fraction of its arc where it taps this lap, or null (it misses the lap)
  final Map<int, double?> _botPlan = {};

  static const _emojiFallback = ['Noto Color Emoji'];
  static const List<Color> _zoneColors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  @visibleForTesting
  CatchMatch get debugMatch => _match;
  @visibleForTesting
  double get debugAngle => _spin.value * 360 + _lap * 360;
  @visibleForTesting
  set debugSpin(double v) {
    _spin.value = v;
    _lastSpinValue = v;
    _spin.repeat();
  }
  @visibleForTesting
  Set<int> get debugBots => _botSeats;
  @visibleForTesting
  int debugScore(int seat) => _score(seat);
  @visibleForTesting
  int? get debugWinnerSeat =>
      _match.matchWinner == null ? null : _seatOfZone[_match.matchWinner!];

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addListener(_onFrame);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _planBots() {
    for (final b in _botSeats) {
      _botPlan[b] = _random.nextDouble() < 0.65 ? 0.15 + _random.nextDouble() * 0.7 : null;
    }
  }

  void _onFrame() {
    if (_phase != _CatchPhase.playing) return;
    if (_spin.value < _lastSpinValue - 0.5) {
      _lap++;
      _planBots();
    }
    _lastSpinValue = _spin.value;
    if (_match.matchWinner != null) return;
    final angle = _spin.value * 360 + _lap * 360;
    for (final b in _botSeats) {
      final f = _botPlan[b];
      if (f == null) continue;
      final z = _match.zoneOf(_zoneOfSeat[b]);
      const slice = 90.0;
      var rel = (angle % 360 - z.from) % 360;
      if (rel < 0) rel += 360;
      if (rel < slice && rel >= f * slice) {
        _botPlan[b] = null;
        _tap(b);
      }
    }
  }

  void _start(int humans, bool withBots) {
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seats = _practice ? 1 : (withBots ? 4 : humans);
    _botSeats
      ..clear()
      ..addAll([for (var s = humans; s < _seats && withBots; s++) s]);
    _lap = 0;
    _lastSpinValue = 0;
    _match = CatchMatch(playerCount: 4, startAngle: 0);
    _spin.duration = Duration(milliseconds: 2200 + _random.nextInt(1500));
    _planBots();
    setState(() => _phase = _CatchPhase.playing);
    _spin.repeat();
  }

  void _tap(int seat) {
    if (_phase != _CatchPhase.playing || _match.matchWinner != null || !_spin.isAnimating) return;
    _match.tap(_zoneOfSeat[seat], _spin.value * 360 + _lap * 360);
    if (_match.matchWinner != null) _spin.stop();
    setState(() {});
  }

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

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
              setState(() => _phase = _CatchPhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _start(4, false);
                } else {
                  setState(() => _phase = _CatchPhase.pickBots);
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
                ? 'من غير بوتات هتتدرب لوحدك: ٥ نقط في أقل لفّات'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _start(_humans, true)),
          _bigChoice('لا', () => _start(_humans, false)),
        ]),
      );

  Alignment _corner(int seat) => const [
        Alignment.bottomLeft,
        Alignment.topRight,
        Alignment.bottomRight,
        Alignment.topLeft,
      ][seat];

  Widget _pad(int seat) {
    return Listener(
      key: ValueKey('pad_$seat'),
      onPointerDown: (_) => _tap(seat),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _zoneColors[seat].withValues(alpha: 0.95),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text('${_score(seat)}', style: _t(24, color: Colors.white)),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.matchWinner == null ? null : _seatOfZone[_match.matchWinner!];
    Widget head;
    if (_practice) {
      head = Text('خلصت ٥ نقط في ${_lap + 1} لفّة', style: _t(22));
    } else if (w != null && w >= _humans) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'اقطفها', winnerName: '${PlayerNames.name(w!)}', winnerSeats: [w!]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() {
          _phase = _CatchPhase.pickPlayers;
        }),
        child: Text('ماتش جديد', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'اقطفها',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'اقطفها',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            'السمكة بتلف حوالين الدواير الملونة! دوس على زرارك في ركنك بالظبط لما تكون السمكة جوه اللون بتاعك. لو دست في الوقت الغلط بتتقفل عليك لحد اللفّة الجاية. أول واحد يوصل ٥ نقط يكسب',
        icon: '🐟',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    return OfflineGameScaffold(
      title: 'اقطفها',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _CatchPhase.pickPlayers => _buildPicker(),
          _CatchPhase.pickBots => _buildBots(),
          _CatchPhase.playing => _match.matchWinner != null
              ? Center(child: _buildOver())
              : LayoutBuilder(builder: (context, c) {
                  final side = min(c.maxWidth - 24, c.maxHeight - 24);
                  return Stack(children: [
                    Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: AnimatedBuilder(
                          animation: _spin,
                          builder: (context, _) => CustomPaint(
                            painter: _RingPainter(
                              players: 4,
                              startAngle: 0,
                              markerAngle: _spin.value * 2 * pi,
                              colors: [for (var z = 0; z < 4; z++) _zoneColors[_seatOfZone[z]]],
                              active: {for (var i = 0; i < _seats; i++) _zoneOfSeat[i]},
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (var s = 0; s < _seats; s++)
                      if (!_botSeats.contains(s) && (!_practice || s == 0))
                        Align(
                          alignment: _corner(s),
                          child: Padding(padding: const EdgeInsets.all(8), child: _pad(s)),
                        ),
                    // bot scores (no pad, just a pill in their corner)
                    for (final s in _botSeats)
                      Align(
                        alignment: _corner(s),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _zoneColors[s].withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: FlatColors.ink, width: 2),
                            ),
                            child: Text('🤖 ${_score(s)}', style: _t(16)),
                          ),
                        ),
                      ),
                  ]);
                }),
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.players,
    required this.startAngle,
    required this.markerAngle,
    required this.colors,
    required this.active,
  });

  final int players;
  final double startAngle;
  final double markerAngle;
  final List<Color> colors;
  final Set<int> active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final slice = 2 * pi / players;
    final start = startAngle * pi / 180 - pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p = 0; p < players; p++) {
      paint.color = active.contains(p)
          ? colors[p % colors.length].withValues(alpha: 0.85)
          : FlatColors.border.withValues(alpha: 0.35);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start + slice * p + 0.03, slice - 0.06, true, paint);
    }
    paint.color = FlatColors.bg;
    canvas.drawCircle(center, radius * 0.55, paint);
    // vector fish marker
    final mx = center.dx + radius * 0.78 * cos(markerAngle - pi / 2 + start);
    final my = center.dy + radius * 0.78 * sin(markerAngle - pi / 2 + start);
    canvas.save();
    canvas.translate(mx, my);
    canvas.rotate(markerAngle + start);
    final ink = Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final tail = Path()..moveTo(-8, 0)..lineTo(-22, -9)..lineTo(-22, 9)..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFFFB02E));
    canvas.drawPath(tail, ink);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 24), Paint()..color = const Color(0xFFFFB02E));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 24), ink);
    canvas.drawCircle(const Offset(8, -3), 3, Paint()..color = FlatColors.ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.markerAngle != markerAngle || old.players != players || old.startAngle != startAngle;
}
