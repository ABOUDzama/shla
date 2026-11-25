import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';

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
      : assert(players >= 2 && players <= 4),
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

enum _BallPhase { pickPlayers, playing, matchOver }

class TouchBallGame extends StatefulWidget {
  const TouchBallGame({super.key});

  @override
  State<TouchBallGame> createState() => _TouchBallGameState();
}

class _TouchBallGameState extends State<TouchBallGame> {
  bool _showIntro = true;
  _BallPhase _phase = _BallPhase.pickPlayers;
  late TouchBallMatch _match;
  final Random _random = Random();
  Timer? _ticker;
  Timer? _nextTimer;
  double _x = 0, _y = 0, _vx = 0, _vy = 0;
  double _arenaW = 1, _arenaH = 1;
  int _elapsed = 0;
  String _banner = '';

  static const List<Color> _zoneColors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _ticker?.cancel();
    _nextTimer?.cancel();
    setState(() {
      _match = TouchBallMatch(players: players);
      _match.start();
      _phase = _BallPhase.playing;
    });
    _spawn();
  }

  void _spawn() {
    _ticker?.cancel();
    final owner = _match.spawnBall();
    setState(() {
      _elapsed = 0;
      _x = 60 + _random.nextDouble() * (_arenaW - 160).clamp(1, 10000);
      _y = 60 + _random.nextDouble() * (_arenaH - 160).clamp(1, 10000);
      final angle = _random.nextDouble() * 2 * pi;
      const speed = 9.0;
      _vx = cos(angle) * speed;
      _vy = sin(angle) * speed;
      _banner = 'كورة لاعب ${owner + 1}! هو بس اللي يلمسها ⚽';
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_match.ballLive) return;
    setState(() {
      _elapsed += 50;
      _x += _vx;
      _y += _vy;
      if (_x < 0) {
        _x = 0;
        _vx = -_vx;
      }
      if (_y < 0) {
        _y = 0;
        _vy = -_vy;
      }
      final maxX = (_arenaW - 80).clamp(0, 10000).toDouble();
      final maxY = (_arenaH - 80).clamp(0, 10000).toDouble();
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
    final top = y < _arenaH / 2;
    final left = x < _arenaW / 2;
    if (_match.players == 2) return top ? 0 : 1;
    if (_match.players == 3) return top ? (left ? 0 : 1) : 2;
    return top ? (left ? 0 : 1) : (left ? 2 : 3);
  }

  void _onBallTap() {
    if (!_match.ballLive || _phase != _BallPhase.playing) return;
    final zone = _zoneAt(_x + 40, _y + 40);
    final good = _match.tapBall(zone);
    _ticker?.cancel();
    setState(() {
      if (_match.matchWinner != null) {
        _phase = _BallPhase.matchOver;
        _banner = 'لاعب ${_match.matchWinner! + 1} كسب الماتش! 🏆';
      } else {
        _banner = good
            ? 'لاعب ${zone + 1} لمسها في وقتها! ⚽'
            : 'لاعب ${zone + 1} لمس كورة مش بتاعته! نقطة تتخصم 😬';
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
                style: GoogleFonts.cairo(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: _zoneColors[p].withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
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
            '٢-٤ لاعبين على نفس الموبايل. كورة ملونة بتلف على الشاشة وبتصغّر.. اللون بيحدد صاحبها، وهو بس اللي يلمسها قبل ما تطير! لو حد تاني لمسها يتخصم منه نقطة. أول واحد يوصل ٥ نقط يكسب ⚽',
        icon: '⚽',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'كورة اللمسة',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: _phase == _BallPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  if (_phase == _BallPhase.matchOver)
                    VictoryFriends(
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
                              '${i + 1}: ${_match.scores[i]}',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
                                            color: Colors.white, width: 3),
                                        boxShadow: const [
                                          BoxShadow(
                                              blurRadius: 12,
                                              color: Colors.black38),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${(_match.owner ?? 0) + 1}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
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
                      color: FunkyColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FunkyColors.amber, width: 1.6),
                    ),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FunkyColors.amber,
                      ).copyWith(
                          fontFamilyFallback: const ['Noto Color Emoji']),
                    ),
                  ),
                  if (_phase == _BallPhase.matchOver)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton(
                        onPressed: () => _startMatch(_match.players),
                        child: Text(
                          'ماتش جديد',
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
