import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'obstacle_logic.dart';

/// سباق العوائق: turn-based obstacle runner for 1-4 seats on one phone.
/// Same seeded course for everyone; fastest finish wins, else furthest.
class ObstacleGameScreen extends StatefulWidget {
  const ObstacleGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<ObstacleGameScreen> createState() => _ObstacleGameScreenState();
}

enum _ObPhase { pickPlayers, pickBots, banner, running, over }

class _ObstacleGameScreenState extends State<ObstacleGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _sky = Color(0xFFFFF3D6);
  static const _track = Color(0xFFE8C98F);
  static const _block = Color(0xFFB08968);

  bool _showIntro = true;
  _ObPhase _phase = _ObPhase.pickPlayers;
  late ObstacleRun _run;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  int _seat = 0;
  double _botError = 0;
  // Result per seat: (finished, timeSeconds, distance).
  late List<(bool, double, double)> _results;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  bool get debugIsRunning => _phase == _ObPhase.running;
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

  ObstacleRun _newRun() => ObstacleRun(
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null);

  void _startMatch(int humans, bool withBots) {
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seatCount = _practice ? 1 : (withBots ? 4 : humans);
    _bots = {
      for (var i = humans; i < _seatCount && (withBots || _practice); i++) i,
    };
    _results = List.filled(_seatCount, (false, 0.0, 0.0));
    _seat = 0;
    setState(() => _phase = _ObPhase.banner);
    if (_bots.contains(_seat)) _autoBegin();
  }

  void _autoBegin() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), _beginRun);
  }

  void _beginRun() {
    if (!mounted || _phase != _ObPhase.banner) return;
    setState(() {
      _run = _newRun();
      if (_bots.contains(_seat)) {
        final r = widget.randomSeed != null
            ? Random(widget.randomSeed! + 55 + _seat)
            : Random();
        _botError = r.nextDouble() * 24 - 12;
      }
      _phase = _ObPhase.running;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _ObPhase.running) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_bots.contains(_seat) && !_run.done) {
      if (_run.botShouldJump(error: _botError)) _run.jump();
    }
    setState(() => _run.step(dt.clamp(0, 1 / 20)));
    if (_run.done) _onDone();
  }

  void _onDone() {
    _ticker.stop();
    _results[_seat] = (_run.finished, _run.time, _run.distance);
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        if (_seat + 1 < _seatCount) {
          _seat++;
          _phase = _ObPhase.banner;
        } else {
          _phase = _ObPhase.over;
        }
      });
      if (_phase == _ObPhase.banner && _bots.contains(_seat)) _autoBegin();
    });
  }

  void _tap() {
    if (_showIntro) return;
    if (_phase == _ObPhase.banner && !_bots.contains(_seat)) {
      _beginRun();
      return;
    }
    if (_phase == _ObPhase.running && !_bots.contains(_seat) && !_run.done) {
      _run.jump();
    }
  }

  TextStyle _t(double size,
          {Color? color, FontWeight w = FontWeight.w800, double? h}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback, height: h);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'سباق العوائق',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🏃',
          title: 'سباق العوائق',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'اجري واقفز فوق الحواجز! كل واحد يجري نفس المضمار بالتناوب. اللي يخلّص أسرع يكسب.. ولو محدش خلّص، اللي وصل أبعد يكسب 🏃',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'سباق العوائق',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _ObPhase.pickPlayers => _pickPlayers(),
        _ObPhase.pickBots => _pickBots(),
        _ObPhase.banner => _banner(),
        _ObPhase.running => _arena(),
        _ObPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🏃', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('نفس المضمار للكل.. الأسرع يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _ObPhase.pickBots;
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
            _humans == 1 ? 'لوحدك: تمرين على المضمار' : 'البوتات تدخل المنافسة',
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
      onTap: _tap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏃',
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
              isBot ? 'البوت بيجري…' : 'دوس للبدء.. ودوس للقفز! 👆',
              style: _t(16, w: FontWeight.w900),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _arena() {
    return GestureDetector(
      onTap: _tap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ObstaclePainter(
              run: _run,
              sky: _sky,
              track: _track,
              block: _block,
              seatColor: _colors[_seat],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_seatLabel(_seat)}: ${_run.time.toStringAsFixed(1)} ث',
                            style: _t(16,
                                w: FontWeight.w900, color: _colors[_seat]),
                            textDirection: TextDirection.rtl,
                          ),
                          Text(
                            '${(_run.distance / _run.courseLength * 100).clamp(0, 100).toStringAsFixed(0)}٪',
                            style: _t(14,
                                color: FlatColors.ink.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value:
                              (_run.distance / _run.courseLength).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: FlatColors.ink.withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_colors[_seat]),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_run.crashed)
                  Center(
                    child: Text('خبطت! 💥',
                        style: _t(30, w: FontWeight.w900),
                        textDirection: TextDirection.rtl),
                  )
                else if (_run.finished)
                  Center(
                    child: Text('خلّص! 🏁',
                        style: _t(30, w: FontWeight.w900),
                        textDirection: TextDirection.rtl),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _over() {
    String fmt((bool, double, double) r) =>
        r.$1 ? 'خلّص في ${r.$2.toStringAsFixed(1)} ث' : 'وصل ${(r.$3 / 10).round()} متر';
    if (_practice) {
      final r = _results[0];
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(r.$1 ? 'خلّصت المضمار! 🏁' : 'تمرين خلص! 💪',
                style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text(fmt(r),
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _ObPhase.pickPlayers)),
          ],
        ),
      );
    }
    // Rank: finished first (by time), then by distance.
    final order = List.generate(_seatCount, (i) => i)
      ..sort((a, b) {
        final ra = _results[a], rb = _results[b];
        if (ra.$1 && rb.$1) return ra.$2.compareTo(rb.$2);
        if (ra.$1 != rb.$1) return ra.$1 ? -1 : 1;
        return rb.$3.compareTo(ra.$3);
      });
    final best = _results[order.first];
    final winners = [
      for (final i in order)
        if (_results[i] == best) i,
    ];
    final humanWinners = winners.where((w) => !_bots.contains(w)).toList();
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (humanWinners.isNotEmpty)
              VictoryFriends(
                gameTitle: 'سباق العوائق',
                winnerName: humanWinners.map(_seatLabel).join(' و '),
                winnerSeats: humanWinners,
              )
            else ...[
              Text('البوتات كسبوا 🤖', style: _t(24, w: FontWeight.w900),
                  textDirection: TextDirection.rtl),
              const SizedBox(height: 8),
              Text('بوت ${winners.first + 1} ${fmt(best)}',
                  style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                  textDirection: TextDirection.rtl),
            ],
            const SizedBox(height: 12),
            for (final i in order)
              Text('${_seatLabel(i)}: ${fmt(_results[i])}',
                  style: _t(15,
                      w: FontWeight.w900,
                      color: winners.contains(i)
                          ? _colors[i]
                          : FlatColors.ink.withValues(alpha: 0.55)),
                  textDirection: TextDirection.rtl),
            const SizedBox(height: 16),
            _bigChoice('العبوا تاني 🔁',
                () => setState(() => _phase = _ObPhase.pickPlayers)),
          ],
        ),
      ),
    );
  }
}

class _ObstaclePainter extends CustomPainter {
  _ObstaclePainter({
    required this.run,
    required this.sky,
    required this.track,
    required this.block,
    required this.seatColor,
  });

  final ObstacleRun run;
  final Color sky, track, block, seatColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Width-based scale: always show ~420 logical px ahead of the runner.
    final scale = size.width / 420;
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);

    // Track sits in the lower middle of the arena.
    final trackTop = size.height * 0.55;
    final yOff = trackTop - (ObstacleRun.groundY + ObstacleRun.runnerSize / 2) * scale;
    canvas.drawRect(Rect.fromLTWH(0, trackTop, size.width, size.height - trackTop),
        Paint()..color = track);

    // Obstacles in view (worldX → screenX).
    final camX = run.distance;
    for (final (ox, oh) in run.obstacles) {
      // obstacle worldX is absolute on the course; screen pos:
      final screenX = (ox - camX + ObstacleRun.runnerX) * scale;
      if (screenX < -40 || screenX > size.width + 40) continue;
      final rect = Rect.fromLTWH(
          screenX - 14 * scale, trackTop - oh * scale, 28 * scale, oh * scale);
      // (trackTop is the ground line after vertical repositioning)
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()..color = block);
      // spikes on top
      final spikes = Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.left + rect.width / 2, rect.top - 8 * scale)
        ..lineTo(rect.right, rect.top)
        ..close();
      canvas.drawPath(spikes, Paint()..color = const Color(0xFF8C6A4F));
    }

    // Finish flag when near.
    final finishScreenX =
        (run.courseLength - camX + ObstacleRun.runnerX) * scale;
    if (finishScreenX < size.width + 60) {
      final fy = trackTop;
      canvas.drawRect(
          Rect.fromLTWH(finishScreenX, fy - 90 * scale, 3, 90 * scale),
          Paint()..color = const Color(0xFF333333));
      final flag = Path()
        ..moveTo(finishScreenX + 3, fy - 90 * scale)
        ..lineTo(finishScreenX + 30 * scale, fy - 80 * scale)
        ..lineTo(finishScreenX + 3, fy - 70 * scale)
        ..close();
      canvas.drawPath(flag, Paint()..color = seatColor);
    }

    // Runner (emoji, bounces while running).
    final bounce = run.onGround && !run.done
        ? sin(run.time * 18) * 3
        : 0.0;
    final ry = run.playerY * scale + yOff + bounce;
    final rx = ObstacleRun.runnerX * scale;
    final tp = TextPainter(
      text: TextSpan(
          text: run.crashed ? '💥' : '🏃',
          style: TextStyle(
              fontSize: ObstacleRun.runnerSize * 1.5 * scale,
              fontFamilyFallback: const ['Noto Color Emoji'])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rx - tp.width / 2, ry - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ObstaclePainter old) => true;
}
