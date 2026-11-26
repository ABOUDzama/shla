import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'orbit_logic.dart';

/// وحش المدار: turn-based orbit-dodge survival for 1-4 seats on one phone.
/// Tap to hop between orbits and dodge the meteor rain; longest survives.
class OrbitGameScreen extends StatefulWidget {
  const OrbitGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<OrbitGameScreen> createState() => _OrbitGameScreenState();
}

enum _OrbitPhase { pickPlayers, pickBots, banner, running, over }

class _OrbitGameScreenState extends State<OrbitGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _space = Color(0xFFFFF7E8);
  static const _planet = Color(0xFF35C99E);

  bool _showIntro = true;
  _OrbitPhase _phase = _OrbitPhase.pickPlayers;
  late OrbitRun _run;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  int _seat = 0;
  late List<double> _times;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  bool get debugIsRunning => _phase == _OrbitPhase.running;
  int get debugSeatCount => _seatCount;
  Set<int> get debugBots => _bots;
  void debugHopIfNeeded() {
    if (_phase == _OrbitPhase.running && !_run.crashed && _run.botShouldHop()) {
      _run.hop();
    }
  }

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

  OrbitRun _newRun() =>
      OrbitRun(random: widget.randomSeed != null ? Random(widget.randomSeed!) : null);

  void _startMatch(int humans, bool withBots) {
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seatCount = _practice ? 1 : (withBots ? 4 : humans);
    _bots = {
      for (var i = humans; i < _seatCount && (withBots || _practice); i++) i,
    };
    _times = List.filled(_seatCount, 0);
    _seat = 0;
    setState(() => _phase = _OrbitPhase.banner);
    if (_bots.contains(_seat)) _autoBegin();
  }

  void _autoBegin() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), _beginRun);
  }

  void _beginRun() {
    if (!mounted || _phase != _OrbitPhase.banner) return;
    setState(() {
      _run = _newRun();
      _phase = _OrbitPhase.running;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _OrbitPhase.running) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final step = dt.clamp(0, 1 / 20).toDouble();
    if (_bots.contains(_seat) && !_run.crashed) {
      if (_run.botShouldHop()) _run.hop();
    }
    setState(() => _run.step(step));
    if (_run.crashed) _onCrash();
  }

  void _onCrash() {
    _ticker.stop();
    _times[_seat] = _run.time;
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        if (_seat + 1 < _seatCount) {
          _seat++;
          _phase = _OrbitPhase.banner;
        } else {
          _phase = _OrbitPhase.over;
        }
      });
      if (_phase == _OrbitPhase.banner && _bots.contains(_seat)) _autoBegin();
    });
  }

  void _tap() {
    if (_showIntro) return;
    if (_phase == _OrbitPhase.banner && !_bots.contains(_seat)) {
      _beginRun();
      return;
    }
    if (_phase == _OrbitPhase.running && !_bots.contains(_seat) && !_run.crashed) {
      _run.hop();
      setState(() {});
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
        title: 'وحش المدار',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '👾',
          title: 'وحش المدار',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'الوحش بيلف حوالين كوكبه والنيازك بتنزل! دوس عشان تنط بين المدارين وتنجو.. اللي يعيش أطول يكسب 👾',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'وحش المدار',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _OrbitPhase.pickPlayers => _pickPlayers(),
        _OrbitPhase.pickBots => _pickBots(),
        _OrbitPhase.banner => _banner(),
        _OrbitPhase.running => _arena(),
        _OrbitPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 👾', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل واحد جولة نجاة.. الأطول عمرًا يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _OrbitPhase.pickBots;
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
            _humans == 1 ? 'لوحدك: تمرين نجاة' : 'البوتات تدخل المنافسة',
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
            Text('👾',
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
              isBot ? 'البوت بيلف…' : 'دوس للبدء.. ودوس للنط! 👆',
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
            painter: _OrbitPainter(
              run: _run,
              space: _space,
              planet: _planet,
              seatColor: _colors[_seat],
              ink: FlatColors.ink,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _colors[_seat], width: 2),
                      ),
                      child: Text(
                        '${_seatLabel(_seat)}: ${_run.time.toStringAsFixed(1)} ث',
                        style: _t(18, w: FontWeight.w900, color: _colors[_seat]),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                ),
                if (_run.crashed)
                  Center(
                    child: Text('نيزك! 💥',
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
    String fmt(double t) => '${t.toStringAsFixed(1)} ثانية';
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('تمرين خلص! 💪', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('عشت ${fmt(_times[0])}',
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _OrbitPhase.pickPlayers)),
          ],
        ),
      );
    }
    final best = _times.fold(0.0, (a, b) => a > b ? a : b);
    final winners = [
      for (var i = 0; i < _seatCount; i++)
        if (_times[i] == best) i,
    ];
    final humanWinners = winners.where((w) => !_bots.contains(w)).toList();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (humanWinners.isNotEmpty)
            VictoryFriends(
              gameTitle: 'وحش المدار',
              winnerName: humanWinners.map(_seatLabel).join(' و '),
              winnerSeats: humanWinners,
            )
          else ...[
            Text('البوتات كسبوا 🤖', style: _t(24, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('بوت ${winners.first + 1} عاش ${fmt(best)}',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < _seatCount; i++)
            Text('${_seatLabel(i)}: ${fmt(_times[i])}',
                style: _t(15,
                    w: FontWeight.w900,
                    color: winners.contains(i)
                        ? _colors[i]
                        : FlatColors.ink.withValues(alpha: 0.55)),
                textDirection: TextDirection.rtl),
          const SizedBox(height: 16),
          _bigChoice('العبوا تاني 🔁',
              () => setState(() => _phase = _OrbitPhase.pickPlayers)),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.run,
    required this.space,
    required this.planet,
    required this.seatColor,
    required this.ink,
  });

  final OrbitRun run;
  final Color space, planet, seatColor, ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = space);
    final center = Offset(size.width / 2, size.height / 2);
    final s = min(size.width, size.height) / 320;

    // Orbit rings.
    final ringPaint = Paint()
      ..color = ink.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, OrbitRun.innerR * s, ringPaint);
    canvas.drawCircle(center, OrbitRun.outerR * s, ringPaint);

    // Planet.
    canvas.drawCircle(center, 30 * s, Paint()..color = planet);
    canvas.drawCircle(center - Offset(8 * s, 8 * s), 8 * s,
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // Meteors.
    for (final (ma, mr) in run.meteors) {
      final p = center + Offset(cos(ma) * mr * s, sin(ma) * mr * s);
      final tp = TextPainter(
        text: TextSpan(
            text: '☄️',
            style: TextStyle(
                fontSize: 22 * s, fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // Monster.
    final mp = center +
        Offset(cos(run.angle) * run.ringRadius * s,
            sin(run.angle) * run.ringRadius * s);
    if (run.crashed) {
      final tp = TextPainter(
        text: TextSpan(
            text: '💥',
            style: TextStyle(
                fontSize: 34 * s, fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mp - Offset(tp.width / 2, tp.height / 2));
    } else {
      canvas.drawCircle(mp, 15 * s, Paint()..color = seatColor);
      final tp = TextPainter(
        text: TextSpan(
            text: '👾',
            style: TextStyle(
                fontSize: 26 * s, fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}
