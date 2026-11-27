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
import 'flappy_logic.dart';

/// فلابي الشلة: turn-based flappy runs for 1-4 seats on one phone. Each
/// seat flies one run; the furthest score wins. Original flat art.
class FlappyGameScreen extends StatefulWidget {
  const FlappyGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<FlappyGameScreen> createState() => _FlappyGameScreenState();
}

enum _FlappyPhase { pickPlayers, pickBots, banner, running, over }

class _FlappyGameScreenState extends State<FlappyGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _sky = Color(0xFFB9E4FF);
  static const _pipe = Color(0xFF35C99E);
  static const _pipeDark = Color(0xFF17795A);
  static const _ground = Color(0xFFE8C98F);

  bool _showIntro = true;
  _FlappyPhase _phase = _FlappyPhase.pickPlayers;
  late FlappyRun _run;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  List<int> _scores = [];
  int _seat = 0;
  double _botError = 0;
  DateTime _lastBotFlap = DateTime.fromMillisecondsSinceEpoch(0);
  bool _crashedBeat = false;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  bool get debugIsRunning => _phase == _FlappyPhase.running;
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

  FlappyRun _newRun() => FlappyRun(
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null);

    void _juiceEnd() {
    final best = _scores.fold(0, (a, b) => a > b ? a : b);
    final humanWin = [
      for (var i = 0; i < _seatCount; i++)
        if (_scores[i] == best && !_bots.contains(i)) i,
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
    _scores = List.filled(_seatCount, 0);
    _seat = 0;
    setState(() => _phase = _FlappyPhase.banner);
    if (_bots.contains(_seat)) _autoBegin();
  }

  void _autoBegin() {
    // Bot seats start their run after a short beat.
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), _beginRun);
  }

  void _beginRun() {
    if (!mounted || _phase != _FlappyPhase.banner) return;
    setState(() {
      _run = _newRun();
      _crashedBeat = false;
      if (_bots.contains(_seat)) {
        final r = widget.randomSeed != null
            ? Random(widget.randomSeed! + 100 + _seat)
            : Random();
        _botError = r.nextDouble() * 36 - 18;
      }
      _phase = _FlappyPhase.running;
    });
    _run.flap();
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _FlappyPhase.running) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_bots.contains(_seat) && !_run.crashed) {
      final now = DateTime.now();
      if (now.difference(_lastBotFlap).inMilliseconds > 170 &&
          _run.botShouldFlap(error: _botError)) {
        _lastBotFlap = now;
        _run.flap();
      }
    }
    setState(() => _run.step(dt.clamp(0, 1 / 20)));
    if (_run.crashed) _onCrash();
  }

  void _onCrash() {
    _ticker.stop();
    _scores[_seat] = _run.score;
    setState(() => _crashedBeat = true);
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        if (_seat + 1 < _seatCount) {
          _seat++;
          _phase = _FlappyPhase.banner;
        } else {
          _phase = _FlappyPhase.over;
          _juiceEnd();
        }
      });
      if (_phase == _FlappyPhase.banner && _bots.contains(_seat)) {
        _autoBegin();
      }
    });
  }

  void _tap() {
    if (_showIntro) return;
    if (_phase == _FlappyPhase.banner && !_bots.contains(_seat)) {
      _beginRun();
      return;
    }
    if (_phase == _FlappyPhase.running &&
        !_bots.contains(_seat) &&
        !_crashedBeat) {
      _run.flap();
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
        title: 'فلابي الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🐤',
          title: 'فلابي الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'كل واحد ياخد رايح جاي.. قصدي رحلة طيران! دوس عشان الفرخة ترفع وتعدي من فتحات المواسير. اللي يعدي أكتر مواسير يكسب. بالتناوب على نفس الموبايل 🐤',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'فلابي الشلة',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _FlappyPhase.pickPlayers => _pickPlayers(),
        _FlappyPhase.pickBots => _pickBots(),
        _FlappyPhase.banner => _banner(),
        _FlappyPhase.running => _arena(),
        _FlappyPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🐤', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل لاعب رحلة واحدة.. الأعلى سكور يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _FlappyPhase.pickBots;
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
            _humans == 1 ? 'لوحدك: تمرين وأعلى سكور' : 'البوتات تدخل المنافسة',
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
            Text('🐤', style: const TextStyle(fontSize: 64, fontFamilyFallback: _emojiFallback)),
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
            if (_seat > 0)
              Text(
                'أعلى سكور لحد دلوقتي: ${_scores.take(_seat).fold(0, (a, b) => a > b ? a : b)}',
                style: _t(14, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl,
              ),
            const SizedBox(height: 14),
            Text(
              isBot ? 'البوت بيطير…' : 'دوس في أي حتة للبدء 👆',
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
            painter: _FlappyPainter(
              run: _run,
              sky: _sky,
              pipe: _pipe,
              pipeDark: _pipeDark,
              ground: _ground,
              ink: FlatColors.ink,
              crashed: _run.crashed,
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
                        border:
                            Border.all(color: _colors[_seat], width: 2),
                      ),
                      child: Text(
                        '${_seatLabel(_seat)}: ${_run.score}',
                        style: _t(18,
                            w: FontWeight.w900, color: _colors[_seat]),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                ),
                if (_run.crashed)
                  Center(
                    child: Text('وقعت! 💥',
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
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('تمرين خلص! 💪', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('عديت ${_scores[0]} ${_scores[0] == 1 ? 'ماسورة' : 'مواسير'}',
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _FlappyPhase.pickPlayers)),
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
              gameTitle: 'فلابي الشلة',
              winnerName:
                  humanWinners.map(_seatLabel).join(' و '),
              winnerSeats: humanWinners,
            )
          else ...[
            BotsWinLabel(gameTitle: 'فلابي الشلة', style: _t(24, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('بوت ${winners.first + 1} طار أبعد مسافة ($best)',
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
              () => setState(() => _phase = _FlappyPhase.pickPlayers)),
        ],
      ),
    );
  }
}

class _FlappyPainter extends CustomPainter {
  _FlappyPainter({
    required this.run,
    required this.sky,
    required this.pipe,
    required this.pipeDark,
    required this.ground,
    required this.ink,
    required this.crashed,
  });

  final FlappyRun run;
  final Color sky, pipe, pipeDark, ground, ink;
  final bool crashed;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / run.worldHeight;
    final worldW = size.width / scale;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = sky);

    // Ground
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - 18, size.width, 18),
        Paint()..color = ground);

    // Pipes
    for (final (px, gapY) in run.pipes) {
      final left = (px - FlappyRun.pipeWidth / 2) * scale;
      final w = FlappyRun.pipeWidth * scale;
      final gapTop = (gapY - run.gapHeight / 2) * scale;
      final gapBottom = (gapY + run.gapHeight / 2) * scale;
      final topRect = Rect.fromLTWH(left, 0, w, gapTop);
      final bottomRect =
          Rect.fromLTWH(left, gapBottom, w, size.height - 18 - gapBottom);
      final p = Paint()..color = pipe;
      final pd = Paint()..color = pipeDark;
      canvas.drawRRect(
          RRect.fromRectAndRadius(topRect, const Radius.circular(8)), p);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bottomRect, const Radius.circular(8)), p);
      // lips
      canvas.drawRect(
          Rect.fromLTWH(left - 3, gapTop - 10, w + 6, 10), pd);
      canvas.drawRect(
          Rect.fromLTWH(left - 3, gapBottom, w + 6, 10), pd);
    }

    // Bird (emoji, tilted by velocity)
    final bx = run.birdX * scale;
    final by = run.birdY * scale;
    final tilt = (run.velocity / 900).clamp(-0.5, 0.9);
    final tp = TextPainter(
      text: TextSpan(
          text: crashed ? '💥' : '🐤',
          style: TextStyle(
              fontSize: FlappyRun.birdRadius * 2.4 * scale,
              fontFamilyFallback: const ['Noto Color Emoji'])),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(bx, by);
    canvas.rotate(tilt);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    // Distance line marker (subtle)
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = 0.0; x < worldW; x += 100) {
      canvas.drawLine(
          Offset(x * scale, 0), Offset(x * scale, size.height - 18), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter old) => true;
}
