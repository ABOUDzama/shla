import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'blocade_logic.dart';

/// بلوكيد: Quoridor-style wall race on one phone. Move one step or place a
/// wall each turn; reach the opposite side first. 2 players or 4 players,
/// with optional bots. Original flat art.
class BlocadeGameScreen extends StatefulWidget {
  const BlocadeGameScreen({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<BlocadeGameScreen> createState() => _BlocadeGameScreenState();
}

enum _Phase { pick, playing, over }

class _BlocadeGameScreenState extends State<BlocadeGameScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _title = 'بلوكيد';

  bool _showIntro = true;
  _Phase _phase = _Phase.pick;
  late BlocadeGame _game;
  Set<int> _bots = {};
  Timer? _botTimer;

  bool _wallMode = false;
  bool _horizontal = true;
  Wall? _preview;
  String? _hint;
  Cell? _lastFrom;
  Cell? _lastTo;

  static const _colors4 = [
    Color(0xFFE5484D), // bottom: red
    Color(0xFF3E7BFA), // left: blue
    Color(0xFF2FB36B), // top: green
    Color(0xFFF2B01E), // right: yellow
  ];

  Color _color(int seat) {
    if (_game.playerCount == 2) {
      return seat == 0 ? _colors4[0] : _colors4[2];
    }
    return _colors4[seat];
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  String _name(int seat) =>
      _bots.contains(seat) ? 'بوت ${seat + 1}' : PlayerNames.name(seat);

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

  // Debug accessors for widget tests.
  BlocadeGame get debugGame => _game;
  bool get debugWallMode => _wallMode;

  void _start(int players, int humans) {
    ArcadeJuice.tap();
    _botTimer?.cancel();
    setState(() {
      _game = BlocadeGame(
        playerCount: players,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _bots = {for (var i = humans; i < players; i++) i};
      _wallMode = false;
      _preview = null;
      _hint = null;
      _lastFrom = _lastTo = null;
      _phase = _Phase.playing;
    });
    _maybeBot();
  }

  void _maybeBot() {
    _botTimer?.cancel();
    if (!mounted || _phase != _Phase.playing || _game.winner != null) return;
    if (!_bots.contains(_game.current)) return;
    _botTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted || _phase != _Phase.playing) return;
      final seat = _game.current;
      final before = _game.pawns[seat];
      final did = _game.botTurn();
      if (did == 'move') {
        _lastFrom = before;
        _lastTo = _game.pawns[seat];
      }
      did == 'wall' ? ArcadeJuice.hit() : ArcadeJuice.tap();
      setState(() {
        _hint = did == 'wall' ? '${_name(seat)} حط حيطة' : null;
      });
      _afterAction();
    });
  }

  void _afterAction() {
    if (_game.winner != null) {
      final w = _game.winner!;
      _bots.contains(w) ? ArcadeJuice.lose() : ArcadeJuice.win();
      setState(() => _phase = _Phase.over);
      return;
    }
    _maybeBot();
  }


  void _onBoardTap(Offset local, double boardPx) {
    if (_phase != _Phase.playing || _bots.contains(_game.current)) return;
    final s = boardPx / BlocadeGame.size;
    if (_wallMode) {
      _setPreviewFromPoint(local, s);
      return;
    }
    final cell = Cell((local.dy / s).floor().clamp(0, 8),
        (local.dx / s).floor().clamp(0, 8));
    final seat = _game.current;
    if (_game.legalMoves(seat).contains(cell)) {
      final from = _game.pawns[seat];
      if (_game.move(seat, cell)) {
        ArcadeJuice.score();
        setState(() {
          _lastFrom = from;
          _lastTo = cell;
          _hint = null;
          _preview = null;
        });
        _afterAction();
      }
    } else {
      setState(() => _hint = 'اضغط على نقطة من النقط الملونة عشان تتحرك');
    }
  }

  void _setPreviewFromPoint(Offset p, double s) {
    // Nearest grid intersection (1..8), orientation by offset unless the
    // player forced it with the rotate button.
    final gx = (p.dx / s).clamp(0.5, 8.5);
    final gy = (p.dy / s).clamp(0.5, 8.5);
    final ix = gx.round().clamp(1, 8);
    final iy = gy.round().clamp(1, 8);
    final dx = gx - ix, dy = gy - iy;
    final horizontal = (dx.abs() - dy.abs()).abs() < 0.08
        ? _horizontal
        : dx.abs() > dy.abs();
    final w = Wall(iy - 1, ix - 1, horizontal);
    _horizontal = horizontal;
    setState(() {
      _preview = w;
      _hint = _game.wallProblem(w);
    });
  }

  void _confirmWall() {
    final w = _preview;
    if (w == null) return;
    if (_game.wallProblem(w) != null) return;
    if (_game.placeWall(w)) {
      ArcadeJuice.hit();
      setState(() {
        _preview = null;
        _hint = null;
        _wallMode = false;
      });
      _afterAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: _title,
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🧱',
          title: _title,
          playersLabel: '٢ أو ٤ لاعبين',
          showBotsChip: true,
          description:
              'كل واحد عنده بيدق في نص ضلع. في دورك يا تحرك البيدق خطوة، يا تحط حيطة عشان تعطّل اللي قدامك. أول واحد يوصل للضلع المقابل يكسب. مينفعش تقفل الطريق بالكامل! 🧱',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: _title,
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _Phase.pick => _pick(),
        _Phase.playing => _play(),
        _Phase.over => _over(),
      },
    );
  }

  Widget _choice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 250,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(17, color: Colors.white))),
        ),
      );

  Widget _pick() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('إزاي هتلعبوا؟ 🧱', style: _t(22, w: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('٢ لاعبين: ١٠ حيطان لكل واحد. ٤ لاعبين: ٥ حيطان',
                style: _t(12, color: FlatColors.ink.withValues(alpha: 0.6))),
            const SizedBox(height: 18),
            _choice('لاعبين ٢', () => _start(2, 2)),
            _choice('أنا ضد بوت 🤖', () => _start(2, 1)),
            _choice('٤ لاعبين', () => _start(4, 4)),
            _choice('لاعبين ومعاهم ٢ بوت 🤖', () => _start(4, 2)),
            _choice('أنا و٣ بوتات 🤖', () => _start(4, 1)),
          ],
        ),
      ),
    );
  }

  Widget _statusBar() {
    final seat = _game.current;
    final isBot = _bots.contains(seat);
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _color(seat).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _color(seat), width: 2),
        ),
        child: Text('دور ${_name(seat)}${isBot ? ' 🤖' : ''}',
            key: const ValueKey('blocade_turn'),
            style: _t(18, w: FontWeight.w900, color: _color(seat)),
            textDirection: TextDirection.rtl),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _game.playerCount; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: i == seat ? _color(i) : FlatColors.ink.withValues(alpha: 0.15),
                  width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: _color(i), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('🧱${_game.wallsLeft[i]}',
                  key: ValueKey('walls_$i'), style: _t(13)),
            ]),
          ),
      ]),
    ]);
  }

  Widget _play() {
    final isBot = _bots.contains(_game.current);
    final canWall = !isBot && _game.wallsLeft[_game.current] > 0;
    final wallOk = _preview != null && _game.wallProblem(_preview!) == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(children: [
        _statusBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, c) {
              final px = min(c.maxWidth, c.maxHeight);
              return SizedBox(
                width: px,
                height: px,
                child: GestureDetector(
                  key: const ValueKey('blocade_board'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _onBoardTap(d.localPosition, px),
                  onPanUpdate: _wallMode && !isBot
                      ? (d) => _setPreviewFromPoint(d.localPosition, px / 9)
                      : null,
                  child: CustomPaint(
                    painter: _BoardPainter(
                      game: _game,
                      colorOf: _color,
                      legal: !_wallMode && !isBot
                          ? _game.legalMoves(_game.current)
                          : const [],
                      preview: _wallMode ? _preview : null,
                      previewOk: wallOk,
                      previewColor: _color(_game.current),
                      lastFrom: _lastFrom,
                      lastTo: _lastTo,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 22,
          child: Text(
            _hint ??
                (isBot
                    ? 'البوت بيفكر...'
                    : _wallMode
                        ? 'اضغط أو اسحب على الملعب عشان تحدد الحيطة'
                        : 'اضغط على نقطة ملونة عشان تتحرك'),
            key: const ValueKey('blocade_hint'),
            style: _t(12,
                color: (_hint != null && _wallMode && !wallOk)
                    ? const Color(0xFFD93025)
                    : FlatColors.ink.withValues(alpha: 0.65)),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _modeButton('تحرك', !_wallMode, isBot ? null : () {
              setState(() {
                _wallMode = false;
                _preview = null;
                _hint = null;
              });
            }, key: 'mode_move'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _modeButton('حيطة 🧱', _wallMode, canWall ? () {
              setState(() {
                _wallMode = true;
                _hint = null;
              });
            } : null, key: 'mode_wall'),
          ),
        ]),
        ...[
          const SizedBox(height: 8),
          Opacity(opacity: _wallMode ? 1 : 0, child: IgnorePointer(ignoring: !_wallMode, child: Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('wall_rotate'),
                onPressed: () {
                  setState(() {
                    _horizontal = !_horizontal;
                    final p = _preview;
                    if (p != null) {
                      final w = Wall(p.r, p.c, _horizontal);
                      _preview = w;
                      _hint = _game.wallProblem(w);
                    }
                  });
                },
                child: Text('لف ↻', style: _t(15)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const ValueKey('wall_confirm'),
                onPressed: wallOk ? _confirmWall : null,
                child: Text('ثبّت الحيطة', style: _t(15, color: Colors.white)),
              ),
            ),
          ]))),
        ],
      ]),
    );
  }

  Widget _modeButton(String label, bool on, VoidCallback? onTap,
      {required String key}) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        key: ValueKey(key),
        style: FilledButton.styleFrom(
          backgroundColor: on ? FlatColors.ink : Colors.white,
          foregroundColor: on ? Colors.white : FlatColors.ink,
          side: BorderSide(color: FlatColors.ink, width: 2),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
        ),
        onPressed: onTap,
        child: Text(label,
            style: _t(16, color: on ? Colors.white : FlatColors.ink)),
      ),
    );
  }

  Widget _over() {
    final w = _game.winner!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_bots.contains(w))
            VictoryFriends(
              gameTitle: _title,
              winnerName: PlayerNames.name(w),
              winnerSeats: [w],
            )
          else ...[
            BotsWinLabel(gameTitle: _title, style: _t(24, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${_name(w)} وصل الأول',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 20),
          _choice('العبوا تاني 🔁', () => setState(() => _phase = _Phase.pick)),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.colorOf,
    required this.legal,
    required this.preview,
    required this.previewOk,
    required this.previewColor,
    required this.lastFrom,
    required this.lastTo,
  });

  final BlocadeGame game;
  final Color Function(int) colorOf;
  final List<Cell> legal;
  final Wall? preview;
  final bool previewOk;
  final Color previewColor;
  final Cell? lastFrom, lastTo;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BlocadeGame.size;
    final gap = s * 0.10;
    final r = Radius.circular(s * 0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.2)),
        Paint()..color = const Color(0xFFE9DFCB));
    Rect cellRect(int row, int col) => Rect.fromLTWH(
        col * s + gap / 2, row * s + gap / 2, s - gap, s - gap);

    // Goal tint per seat
    Color? goalTint(int row, int col) {
      for (var i = 0; i < game.playerCount; i++) {
        final side = game.sideOf(i);
        // goal side of seat i is the OPPOSITE of its start side
        final bool inGoal = switch (side) {
          'bottom' => row == 0,
          'top' => row == 8,
          'left' => col == 8,
          _ => col == 0,
        };
        if (inGoal) return colorOf(i).withValues(alpha: 0.22);
      }
      return null;
    }

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        canvas.drawRRect(RRect.fromRectAndRadius(cellRect(row, col), r),
            Paint()..color = goalTint(row, col) ?? const Color(0xFFFFFBF2));
      }
    }
    // Last move trail
    if (lastFrom != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect(lastFrom!.r, lastFrom!.c), r),
          Paint()
            ..color = FlatColors.ink.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    // Legal moves
    for (final m in legal) {
      final c = cellRect(m.r, m.c).center;
      canvas.drawCircle(c, s * 0.2, Paint()..color = previewColor.withValues(alpha: 0.85));
      canvas.drawCircle(
          c,
          s * 0.34,
          Paint()
            ..color = previewColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    // Walls
    void drawWall(Wall w, Color col, {double alpha = 1}) {
      final t = s * 0.14;
      final Rect rect;
      if (w.horizontal) {
        rect = Rect.fromLTWH(w.c * s + gap / 2, (w.r + 1) * s - t / 2,
            2 * s - gap, t);
      } else {
        rect = Rect.fromLTWH((w.c + 1) * s - t / 2, w.r * s + gap / 2, t,
            2 * s - gap);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(t / 2)),
          Paint()..color = col.withValues(alpha: alpha));
    }

    for (final w in game.placed) {
      drawWall(w, w.owner >= 0 ? colorOf(w.owner) : FlatColors.ink);
    }
    if (preview != null) {
      drawWall(preview!, previewOk ? const Color(0xFF2FB36B) : const Color(0xFFD93025),
          alpha: 0.85);
    }
    // Pawns
    for (var i = 0; i < game.playerCount; i++) {
      final p = game.pawns[i];
      final c = cellRect(p.r, p.c).center;
      canvas.drawCircle(c + Offset(0, s * 0.03), s * 0.33,
          Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(c, s * 0.33, Paint()..color = colorOf(i));
      canvas.drawCircle(
          c,
          s * 0.33,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      if (i == game.current) {
        canvas.drawCircle(
            c,
            s * 0.43,
            Paint()
              ..color = colorOf(i)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
