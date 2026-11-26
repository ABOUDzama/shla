import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'koala_logic.dart';

/// كوالا الفضاء: turn-based laser survival for 1-4 seats on one phone.
/// The ship patrols on its own; tap to fire. Most meteors destroyed wins.
class KoalaGameScreen extends StatefulWidget {
  const KoalaGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<KoalaGameScreen> createState() => _KoalaGameScreenState();
}

enum _KoalaPhase { pickPlayers, pickBots, banner, running, over }

class _KoalaGameScreenState extends State<KoalaGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _space = Color(0xFFEAF2FF);

  bool _showIntro = true;
  _KoalaPhase _phase = _KoalaPhase.pickPlayers;
  late KoalaRun _run;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  int _seat = 0;
  late List<int> _scores;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  bool get debugIsRunning => _phase == _KoalaPhase.running;
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

  KoalaRun _newRun() => KoalaRun(
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null);

  void _startMatch(int humans, bool withBots) {
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seatCount = _practice ? 1 : (withBots ? 4 : humans);
    _bots = {
      for (var i = humans; i < _seatCount && (withBots || _practice); i++) i,
    };
    _scores = List.filled(_seatCount, 0);
    _seat = 0;
    setState(() => _phase = _KoalaPhase.banner);
    if (_bots.contains(_seat)) _autoBegin();
  }

  void _autoBegin() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), _beginRun);
  }

  void _beginRun() {
    if (!mounted || _phase != _KoalaPhase.banner) return;
    setState(() {
      _run = _newRun();
      _phase = _KoalaPhase.running;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _KoalaPhase.running) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final step = dt.clamp(0, 1 / 20).toDouble();
    if (_bots.contains(_seat) && !_run.crashed) {
      if (_run.botShouldFire()) _run.fire();
    }
    setState(() => _run.step(step));
    if (_run.crashed) _onCrash();
  }

  void _onCrash() {
    _ticker.stop();
    _scores[_seat] = _run.hits;
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        if (_seat + 1 < _seatCount) {
          _seat++;
          _phase = _KoalaPhase.banner;
        } else {
          _phase = _KoalaPhase.over;
        }
      });
      if (_phase == _KoalaPhase.banner && _bots.contains(_seat)) _autoBegin();
    });
  }

  void _tap() {
    if (_showIntro) return;
    if (_phase == _KoalaPhase.banner && !_bots.contains(_seat)) {
      _beginRun();
      return;
    }
    if (_phase == _KoalaPhase.running && !_bots.contains(_seat) && !_run.crashed) {
      _run.fire();
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
        title: 'كوالا الفضاء',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🐨',
          title: 'كوالا الفضاء',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'الكوالا في سفينته والنيازك نازلة! السفينة بتلف لوحدها وانت تدوس تضرب ليزر.. اللي يدمّر أكتر يكسب 🐨',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'كوالا الفضاء',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _KoalaPhase.pickPlayers => _pickPlayers(),
        _KoalaPhase.pickBots => _pickBots(),
        _KoalaPhase.banner => _banner(),
        _KoalaPhase.running => _arena(),
        _KoalaPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🐨', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل واحد جولة ليزر.. الأكثر تدميرًا يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _KoalaPhase.pickBots;
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
            _humans == 1 ? 'لوحدك: تمرين ليزر' : 'البوتات تدخل المنافسة',
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
            Text('🐨',
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
              isBot ? 'البوت بيضرب…' : 'دوس للبدء.. ودوس تضرب ليزر! 🔫',
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
            painter: _KoalaPainter(
              run: _run,
              space: _space,
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
                        '${_seatLabel(_seat)}: ${_run.hits} 💥',
                        style: _t(18, w: FontWeight.w900, color: _colors[_seat]),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                ),
                if (_run.crashed)
                  Center(
                    child: Text('السفينة ولعت! 💥',
                        style: _t(28, w: FontWeight.w900),
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
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('تمرين خلص! 💪', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('دمّرت ${_scores[0]} نيزك',
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _KoalaPhase.pickPlayers)),
          ],
        ),
      );
    }
    final best = _scores.fold(0, (a, b) => a > b ? a : b);
    final winners = [
      for (var i = 0; i < _seatCount; i++)
        if (_scores[i] == best) i,
    ];
    final humanWinners = winners.where((w) => !_bots.contains(w)).toList();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (humanWinners.isNotEmpty)
            VictoryFriends(
              gameTitle: 'كوالا الفضاء',
              winnerName: humanWinners.map(_seatLabel).join(' و '),
              winnerSeats: humanWinners,
            )
          else ...[
            Text('البوتات كسبوا 🤖', style: _t(24, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('بوت ${winners.first + 1} دمّر $best نيزك',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < _seatCount; i++)
            Text('${_seatLabel(i)}: ${_scores[i]}',
                style: _t(15,
                    w: FontWeight.w900,
                    color: winners.contains(i)
                        ? _colors[i]
                        : FlatColors.ink.withValues(alpha: 0.55)),
                textDirection: TextDirection.rtl),
          const SizedBox(height: 16),
          _bigChoice('العبوا تاني 🔁',
              () => setState(() => _phase = _KoalaPhase.pickPlayers)),
        ],
      ),
    );
  }
}

class _KoalaPainter extends CustomPainter {
  _KoalaPainter({
    required this.run,
    required this.space,
    required this.seatColor,
    required this.ink,
  });

  final KoalaRun run;
  final Color space, seatColor, ink;

  void _emoji(Canvas canvas, String ch, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: ch,
          style: TextStyle(
              fontSize: size,
              fontFamilyFallback: const ['Noto Color Emoji'])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / KoalaRun.worldWidth;
    final sy = size.height / KoalaRun.worldHeight;
    final s = min(sx, sy);
    canvas.drawRect(Offset.zero & size, Paint()..color = space);

    // Stars.
    final starPaint = Paint()..color = ink.withValues(alpha: 0.12);
    for (var i = 0; i < 26; i++) {
      final x = (i * 97.3) % size.width;
      final y = (i * 61.7) % size.height;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 2.2 : 1.3, starPaint);
    }

    // Meteors.
    for (final (mx, my, _) in run.meteors) {
      _emoji(canvas, '☄️', Offset(mx * s, my * s), 30 * s);
    }

    // Lasers.
    final laserPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;
    for (final (lx, ly) in run.lasers) {
      canvas.drawLine(
          Offset(lx * s, ly * s), Offset(lx * s, ly * s - 18 * s), laserPaint);
    }

    // Ship: koala in a saucer.
    final ship = Offset(run.shipX * s, KoalaRun.shipY * s);
    if (run.crashed) {
      _emoji(canvas, '💥', ship, 46 * s);
    } else {
      canvas.drawOval(
          Rect.fromCenter(center: ship, width: 56 * s, height: 18 * s),
          Paint()..color = seatColor);
      _emoji(canvas, '🐨', ship - Offset(0, 12 * s), 30 * s);
    }
  }

  @override
  bool shouldRepaint(covariant _KoalaPainter old) => true;
}
