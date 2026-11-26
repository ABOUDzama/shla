import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'ballshoot_logic.dart';

/// تصويب الشلة: turn-based balloon shooting for 1-4 seats on one phone.
/// Same seeded stream for everyone; most hits in 12 balls wins.
class BallShootGameScreen extends StatefulWidget {
  const BallShootGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<BallShootGameScreen> createState() => _BallShootGameScreenState();
}

enum _ShootPhase { pickPlayers, pickBots, banner, running, over }

class _BallShootGameScreenState extends State<BallShootGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _sky = Color(0xFFD8F1FF);

  bool _showIntro = true;
  _ShootPhase _phase = _ShootPhase.pickPlayers;
  late BallShootRound _round;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  int _seat = 0;
  double _botError = 0;
  double _botVisible = 0;
  late List<(int, int)> _results; // (hits, taps) per seat
  double _popFlash = 0; // seconds left of the pop effect

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  bool get debugIsRunning => _phase == _ShootPhase.running;
  int get debugSeatCount => _seatCount;
  Set<int> get debugBots => _bots;

  String _seatLabel(int seat) =>
      _bots.contains(seat) ? 'بوت ${seat + 1}' : PlayerNames.name(seat);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nextTimer?.cancel();
    super.dispose();
  }

  BallShootRound _newRound() => BallShootRound(
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null);

    void _juiceEnd() {
    final best = _results.fold(0, (a, b) => a > b.$1 ? a : b.$1);
    final humanWin = [
      for (var i = 0; i < _seatCount; i++)
        if (_results[i].$1 == best && !_bots.contains(i)) i,
    ].isNotEmpty;
    humanWin ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

void _startMatch(int humans, bool withBots) {
    ArcadeJuice.tap();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seatCount = _practice ? 1 : (withBots ? 4 : humans);
    _bots = {
      for (var i = humans; i < _seatCount && (withBots || _practice); i++) i,
    };
    _results = List.filled(_seatCount, (0, 0));
    _seat = 0;
    setState(() => _phase = _ShootPhase.banner);
    if (_bots.contains(_seat)) _autoBegin();
  }

  void _autoBegin() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), _beginRound);
  }

  void _beginRound() {
    if (!mounted || _phase != _ShootPhase.banner) return;
    setState(() {
      _round = _newRound();
      _botVisible = 0;
      _popFlash = 0;
      if (_bots.contains(_seat)) {
        final r = widget.randomSeed != null
            ? Random(widget.randomSeed! + 77 + _seat)
            : Random();
        _botError = r.nextDouble() * 36 - 18;
      }
      _phase = _ShootPhase.running;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _ShootPhase.running) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final step = dt.clamp(0, 1 / 20).toDouble();
    _botVisible = _round.ball == null ? 0 : _botVisible + step;
    _round.step(step);
    if (_popFlash > 0) _popFlash -= step;
    if (_bots.contains(_seat) && !_round.over) {
      final tap = _round.botTap(error: _botError, sinceVisible: _botVisible);
      if (tap != null) {
        if (_round.tapAt(tap.$1, tap.$2)) _popFlash = 0.25;
      }
    }
    setState(() {});
    if (_round.over) _onDone();
  }

  void _onDone() {
    _ticker.stop();
    _results[_seat] = (_round.hits, _round.taps);
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        if (_seat + 1 < _seatCount) {
          _seat++;
          _phase = _ShootPhase.banner;
        } else {
          _phase = _ShootPhase.over;
          _juiceEnd();
        }
      });
      if (_phase == _ShootPhase.banner && _bots.contains(_seat)) _autoBegin();
    });
  }

  void _tapAt(TapDownDetails d, double scale, Offset origin) {
    if (_showIntro || _phase != _ShootPhase.running) return;
    if (_bots.contains(_seat) || _round.over) return;
    final wx = (d.localPosition.dx - origin.dx) / scale;
    final wy = (d.localPosition.dy - origin.dy) / scale;
    if (_round.tapAt(wx, wy)) _popFlash = 0.25;
    setState(() {});
  }

  TextStyle _t(double size,
          {Color? color, FontWeight w = FontWeight.w800, double? h}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback, height: h);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'تصويب الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🎈',
          title: 'تصويب الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'بلالين بتطير وانت تفرقعها! ١٢ بالونة لكل واحد بالتناوب.. اللي يفرقع أكتر يكسب 🎈',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'تصويب الشلة',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _ShootPhase.pickPlayers => _pickPlayers(),
        _ShootPhase.pickBots => _pickBots(),
        _ShootPhase.banner => _banner(),
        _ShootPhase.running => _arena(),
        _ShootPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🎈', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('١٢ بالونة لكل لاعب.. الأكثر فرقعة يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _ShootPhase.pickBots;
                });
              }
            }),
        ],
      ),
    );
  }

  Widget _pickBots() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('البوتات تلعب كمان؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _humans == 1 ? 'لوحدك: تمرين تصويب' : 'البوتات تدخل المنافسة',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ],
      ),
    );
  }

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _banner() {
    final isBot = _bots.contains(_seat);
    return GestureDetector(
      onTap: isBot ? null : _beginRound,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎈',
                style: const TextStyle(
                    fontSize: 64, fontFamilyFallback: _emojiFallback)),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _colors[_seat].withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _colors[_seat], width: 2),
              ),
              child: Text(
                'دور ${_seatLabel(_seat)}${isBot ? ' 🤖' : ''}',
                style: _t(22, w: FontWeight.w900, color: _colors[_seat]),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isBot ? 'البوت بيصوّب…' : 'دوس للبدء.. ودوس على البلالين! 👆',
              style: _t(16, w: FontWeight.w900),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _arena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = min(constraints.maxWidth / BallShootRound.worldWidth,
            constraints.maxHeight / BallShootRound.worldHeight);
        final origin = Offset(
            (constraints.maxWidth - BallShootRound.worldWidth * scale) / 2,
            (constraints.maxHeight - BallShootRound.worldHeight * scale) / 2);
        return GestureDetector(
          onTapDown: (d) => _tapAt(d, scale, origin),
          child: Container(
            color: _sky,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ShootPainter(
                round: _round,
                scale: scale,
                origin: origin,
                seatColor: _colors[_seat],
                ink: FlatColors.ink,
                popFlash: _popFlash,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_seatLabel(_seat)}: ${_round.hits} 🎈',
                          style: _t(16,
                              w: FontWeight.w900, color: _colors[_seat]),
                          textDirection: TextDirection.rtl,
                        ),
                        Text(
                          '${_round.launched}/${_round.ballCount}',
                          style: _t(14,
                              color: FlatColors.ink.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _over() {
    String fmt((int, int) r) => 'فرقع ${r.$1} من ${_roundStaticCount()}';
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('تمرين خلص! 💪', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text(fmt(_results[0]),
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _ShootPhase.pickPlayers)),
          ],
        ),
      );
    }
    final best = _results.fold(0, (a, b) => a > b.$1 ? a : b.$1);
    final winners = [
      for (var i = 0; i < _seatCount; i++)
        if (_results[i].$1 == best) i,
    ];
    final humanWinners = winners.where((w) => !_bots.contains(w)).toList();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (humanWinners.isNotEmpty)
            VictoryFriends(
              gameTitle: 'تصويب الشلة',
              winnerName: humanWinners.map(_seatLabel).join(' و '),
              winnerSeats: humanWinners,
            )
          else ...[
            Text('البوتات كسبوا 🤖', style: _t(24, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('بوت ${winners.first + 1} ${fmt(_results[winners.first])}',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < _seatCount; i++)
            Text('${_seatLabel(i)}: ${fmt(_results[i])}',
                style: _t(15,
                    w: FontWeight.w900,
                    color: winners.contains(i)
                        ? _colors[i]
                        : FlatColors.ink.withValues(alpha: 0.55)),
                textDirection: TextDirection.rtl),
          const SizedBox(height: 16),
          _bigChoice('العبوا تاني 🔁',
              () => setState(() => _phase = _ShootPhase.pickPlayers)),
        ],
      ),
    );
  }

  int _roundStaticCount() => _results.isEmpty ? 12 : _round.ballCount;
}

class _ShootPainter extends CustomPainter {
  _ShootPainter({
    required this.round,
    required this.scale,
    required this.origin,
    required this.seatColor,
    required this.ink,
    required this.popFlash,
  });

  final BallShootRound round;
  final double scale;
  final Offset origin;
  final Color seatColor, ink;
  final double popFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final b = round.ball;
    if (b != null) {
      final c = origin + Offset(b.$1 * scale, b.$2 * scale);
      final tp = TextPainter(
        text: TextSpan(
            text: '🎈',
            style: TextStyle(
                fontSize: BallShootRound.ballRadius * 2.2 * scale,
                fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    if (popFlash > 0) {
      final tp = TextPainter(
        text: TextSpan(
            text: '💥',
            style: TextStyle(
                fontSize: 60 * scale,
                fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          origin +
              Offset(BallShootRound.worldWidth / 2 * scale - tp.width / 2,
                  BallShootRound.worldHeight / 2 * scale - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ShootPainter old) => true;
}
