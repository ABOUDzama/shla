import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/flat_theme.dart';

/// كورة اللمسة: 1-4 players (+ optional bots); bots tap their own balls
/// after a short human-like delay. Solo without bots is target practice.
///
/// Pure logic for كورة اللمسة (Shla-original same-phone moving target).
///
/// Rules: 2-4 players share one phone. Each round a colored ball appears and
/// drifts around the arena while shrinking; its color names ONE owner. Only
/// the owner may tap the ball before it vanishes: a correct tap scores a
/// point. If any other player taps it, that player loses a point (never
/// below zero) and the round ends. If the ball vanishes untouched, nobody
/// scores. First to [targetScore] points wins the match.
class TouchBallMatch {
  TouchBallMatch({required this.players, this.targetScore = 5, Random? random})
      : assert(players >= 1 && players <= 4),
        assert(targetScore >= 1),
        _random = random ?? Random();

  final int players;
  final int targetScore;
  final Random _random;

  /// How long the ball stays tappable, in milliseconds.
  static const int ballLifetimeMs = 2600;

  final List<int> _scores = <int>[];
  int? _owner;
  bool _ballLive = false;

  void start() {
    _scores
      ..clear()
      ..addAll(List<int>.filled(players, 0));
    _owner = null;
    _ballLive = false;
  }

  List<int> get scores => List<int>.unmodifiable(_scores);
  int? get owner => _owner;
  bool get ballLive => _ballLive;

  /// Spawns the ball for a random owner. Returns that owner's index.
  int spawnBall() {
    _owner = _random.nextInt(players);
    _ballLive = true;
    return _owner!;
  }

  /// Registers a tap on the ball by [player]. Returns true when the tap was
  /// the owner's (a point), false when it was someone else's (a penalty).
  /// Either way the ball dies. Ignored when no ball is live.
  bool tapBall(int player) {
    if (!_ballLive || _owner == null) return true;
    _ballLive = false;
    if (player == _owner) {
      _scores[player]++;
      return true;
    }
    if (_scores[player] > 0) _scores[player]--;
    return false;
  }

  /// The ball vanished untouched: round ends with no score change.
  void ballExpired() {
    _ballLive = false;
    _owner = null;
  }

  /// Clears the owner between rounds once the ball is dead.
  void nextRound() {
    if (!_ballLive) _owner = null;
  }

  /// Match winner index, or null.
  int? get matchWinner {
    for (int i = 0; i < players; i++) {
      if (_scores.length == players && _scores[i] >= targetScore) return i;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

enum _BallPhase { pickPlayers, pickBots, playing, matchOver }

class TouchBallGame extends StatefulWidget {
  const TouchBallGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<TouchBallGame> createState() => _TouchBallGameState();
}

class _TouchBallGameState extends State<TouchBallGame> {
  bool _showIntro = true;
  _BallPhase _phase = _BallPhase.pickPlayers;
  late TouchBallMatch _match;
  late final Random _random = widget.randomSeed != null ? Random(widget.randomSeed!) : Random();
  Timer? _ticker;
  Timer? _nextTimer;
  Timer? _botTapTimer;
  int _humans = 2;
  bool _practice = false;
  final Set<int> _botSeats = {};

  @visibleForTesting
  TouchBallMatch get debugMatch => _match;

  @visibleForTesting
  Set<int> get debugBotSeats => _botSeats;
  double _x = 0, _y = 0, _vx = 0, _vy = 0;
  double _arenaW = 1, _arenaH = 1;
  int _elapsed = 0;
  String _banner = '';

  static const List<Color> _zoneColors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    _nextTimer?.cancel();
    _botTapTimer?.cancel();
    super.dispose();
  }

  void _startMatch(int humans, bool withBots) {
    _ticker?.cancel();
    _nextTimer?.cancel();
    _botTapTimer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    _botSeats.clear();
    for (var i = humans; i < seats && withBots; i++) {
      _botSeats.add(i);
    }
    setState(() {
      _match = TouchBallMatch(players: seats, random: _random);
      _match.start();
      _phase = _BallPhase.playing;
    });
    _spawn();
  }

  /// The screen rect owned by [player]: balls stay inside their owner's
  /// zone so the owner can always reach their own ball (the core "only
  /// the owner may tap" rule stays exactly the same).
  Rect _zoneRect(int player) {
    final w = _arenaW, h = _arenaH;
    if (_match.players == 1) return Rect.fromLTWH(0, 0, w, h);
    if (_match.players == 2) {
      return player == 0 ? Rect.fromLTWH(0, 0, w, h / 2) : Rect.fromLTWH(0, h / 2, w, h / 2);
    }
    // RTL: seat 0 sits on the visual right, so raw x starts at w/2.
    if (_match.players == 3) {
      if (player == 0) return Rect.fromLTWH(w / 2, 0, w / 2, h / 2);
      if (player == 1) return Rect.fromLTWH(0, 0, w / 2, h / 2);
      return Rect.fromLTWH(0, h / 2, w, h / 2);
    }
    if (player == 0) return Rect.fromLTWH(w / 2, 0, w / 2, h / 2);
    if (player == 1) return Rect.fromLTWH(0, 0, w / 2, h / 2);
    if (player == 2) return Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2);
    return Rect.fromLTWH(0, h / 2, w / 2, h / 2);
  }

  void _spawn() {
    _ticker?.cancel();
    _botTapTimer?.cancel();
    final owner = _match.spawnBall();
    if (_botSeats.contains(owner)) {
      // bot owners tap their own ball after a short human-like delay
      _botTapTimer = Timer(
        Duration(milliseconds: 400 + _random.nextInt(600)),
        () {
          if (mounted && _match.ballLive && _phase == _BallPhase.playing) {
            _tapAs(owner);
          }
        },
      );
    }
    setState(() {
      _elapsed = 0;
      final zr = _zoneRect(owner);
      _x = zr.left + 20 + _random.nextDouble() * (zr.width - 180).clamp(1, 10000);
      _y = zr.top + 20 + _random.nextDouble() * (zr.height - 180).clamp(1, 10000);
      final angle = _random.nextDouble() * 2 * pi;
      const speed = 9.0;
      _vx = cos(angle) * speed;
      _vy = sin(angle) * speed;
      _banner = 'كورة ${_botSeats.contains(owner) ? 'بوت' : 'لاعب'} ${owner + 1}! هو بس اللي يلمسها ⚽';
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  void _tick() {
    // Skip while the arena has never been laid out (first frame after the
    // picker): with a 1x1 arena the clamps would wedge the ball at x=0.5.
    if (!mounted || !_match.ballLive || _arenaW <= 1) return;
    setState(() {
      _elapsed += 50;
      _x += _vx;
      _y += _vy;
      final zr = _zoneRect(_match.owner ?? 0);
      final minX = zr.left, minY = zr.top;
      final maxX = (zr.right - 80).clamp(minX, 10000).toDouble();
      final maxY = (zr.bottom - 80).clamp(minY, 10000).toDouble();
      if (_x < minX) {
        _x = minX;
        _vx = -_vx;
      }
      if (_y < minY) {
        _y = minY;
        _vy = -_vy;
      }
      if (_x > maxX) {
        _x = maxX;
        _vx = -_vx;
      }
      if (_y > maxY) {
        _y = maxY;
        _vy = -_vy;
      }
      if (_elapsed >= TouchBallMatch.ballLifetimeMs) {
        _match.ballExpired();
        _banner = 'الكورة طارت! محدش لمسها';
        _scheduleNext();
      }
    });
  }

  int _zoneAt(double x, double y) {
    if (_match.players == 1) return 0;
    final top = y < _arenaH / 2;
    // The zone grid renders RTL: seat 0 is the visual RIGHT half.
    final right = x > _arenaW / 2;
    if (_match.players == 2) return top ? 0 : 1;
    if (_match.players == 3) return top ? (right ? 0 : 1) : 2;
    return top ? (right ? 0 : 1) : (right ? 2 : 3);
  }

  void _onBallTap() {
    if (!_match.ballLive || _phase != _BallPhase.playing) return;
    final zone = _zoneAt(_x + 40, _y + 40);
    if (_botSeats.contains(zone)) return; // bot zones tap themselves
    _tapAs(zone);
  }

  void _tapAs(int player) {
    if (!_match.ballLive || _phase != _BallPhase.playing) return;
    final good = _match.tapBall(player);
    _ticker?.cancel();
    _botTapTimer?.cancel();
    setState(() {
      if (_match.matchWinner != null) {
        _phase = _BallPhase.matchOver;
        _banner = _practice
            ? 'خلصت التدريب! ⚽'
            : '${_botSeats.contains(_match.matchWinner) ? 'بوت' : 'لاعب'} ${_match.matchWinner! + 1} كسب الماتش! 🏆';
      } else {
        _banner = good
            ? '${_botSeats.contains(player) ? 'بوت' : 'لاعب'} ${player + 1} لمسها في وقتها! ⚽'
            : 'لاعب ${player + 1} لمس كورة مش بتاعته! نقطة تتخصم 😬';
      }
    });
    if (_match.matchWinner == null) _scheduleNext();
  }

  void _scheduleNext() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _phase == _BallPhase.playing) {
        _match.nextRound();
        _spawn();
      }
    });
  }

  double get _ballScale {
    final t = (_elapsed / TouchBallMatch.ballLifetimeMs).clamp(0.0, 1.0);
    return 1.0 - t * 0.7;
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
              setState(() => _phase = _BallPhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startMatch(4, false);
                } else {
                  setState(() => _phase = _BallPhase.pickBots);
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
                ? 'من غير بوتات هتتدرب: كل الكور بتاعتك، جمّع ٥ نقط'
                : 'البوتات بتكمّل لحد ٤ لاعبين وبتلعب لوحدها',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  Widget _buildZoneBackground() {
    Widget cell(int p) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _zoneColors[p].withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _zoneColors[p], width: 1.4),
            ),
            child: Center(
              child: Text(
                '${p + 1}',
                style: flatCairo(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
            ),
          ),
        );
    if (_match.players == 1) {
      return Column(children: [cell(0)]);
    }
    if (_match.players == 2) {
      return Column(children: [cell(0), cell(1)]);
    }
    return Column(
      children: [
        Expanded(child: Row(children: [cell(0), cell(1)])),
        Expanded(
          child: _match.players == 4
              ? Row(children: [cell(2), cell(3)])
              : Row(children: [cell(2)]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'كورة اللمسة',
        description:
            '١-٤ لاعبين على نفس الموبايل، وتقدر تضيف بوتات. كورة ملونة بتلف على الشاشة وبتصغّر.. اللون بيحدد صاحبها، وهو بس اللي يلمسها قبل ما تطير! لو حد تاني لمسها يتخصم منه نقطة. أول واحد يوصل ٥ نقط يكسب ⚽',
        icon: '⚽',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'كورة اللمسة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _BallPhase.pickPlayers
            ? _buildPicker()
            : _phase == _BallPhase.pickBots
                ? _buildBots()
                : Column(
                children: [
                  if (_phase == _BallPhase.matchOver)
                    _practice
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'جبت ${_match.scores[0]} نقط! تدريب كامل ⚽',
                              style: _t(20),
                            ),
                          )
                        : _botSeats.contains(_match.matchWinner)
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('البوتات كسبوا 🤖', style: _t(22)),
                              )
                            : VictoryFriends(gameTitle: 'كورة اللمسة',
                                winnerName: 'لاعب ${_match.matchWinner! + 1}'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 0; i < _match.players; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _zoneColors[i].withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _zoneColors[i]),
                            ),
                            child: Text(
                              '${_botSeats.contains(i) ? '🤖 ' : ''}${i + 1}: ${_match.scores[i]}',
                              style: flatCairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: FlatColors.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _arenaW = constraints.maxWidth;
                        _arenaH = constraints.maxHeight;
                        return Stack(
                          children: [
                            Positioned.fill(child: _buildZoneBackground()),
                            if (_match.ballLive)
                              Positioned(
                                left: _x,
                                top: _y,
                                child: GestureDetector(
                                  key: const Key('touch_ball'),
                                  onTap: _onBallTap,
                                  child: Transform.scale(
                                    scale: _ballScale,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            _zoneColors[_match.owner ?? 0],
                                        border: Border.all(
                                            color: FlatColors.ink, width: 3),
                                        
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${(_match.owner ?? 0) + 1}',
                                          style: flatCairo(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: FlatColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: FlatColors.tileWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FlatColors.border, width: 2),
                    ),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FlatColors.ink,
                      ).copyWith(
                          fontFamilyFallback: const ['Noto Color Emoji']),
                    ),
                  ),
                  if (_phase == _BallPhase.matchOver)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton(
                        onPressed: () => setState(() => _phase = _BallPhase.pickPlayers),
                        child: Text(
                          'العبوا تاني ⚽',
                          style:
                              flatCairo(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
