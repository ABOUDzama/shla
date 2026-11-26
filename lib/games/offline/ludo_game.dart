import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'ludo_logic.dart';

/// لودو الشلة: classic Ludo for 2-4 seats on one phone. Original flat board
/// drawn in the app's cream/bright style; bots fill the empty seats.
class LudoGameScreen extends StatefulWidget {
  const LudoGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

enum _LudoPhase { pickPlayers, pickBots, playing, over }

class _LudoGameScreenState extends State<LudoGameScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _LudoPhase _phase = _LudoPhase.pickPlayers;
  late LudoGame _game;
  Timer? _botTimer;
  int _humans = 2;
  bool _practice = false;

  /// One-shot notice for the current roll ('رمى 6 ويلعب تاني!' وغيرها).
  String _notice = '';

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  String _seatLabel(int seat) =>
      _game.isBot(seat) ? 'بوت ${seat + 1}' : PlayerNames.name(seat);

  /// The 52 main-track squares as (row, col) on the 15x15 board grid.
  static const List<(int, int)> _path = [
    (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
    (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
    (0, 7),
    (0, 8), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
    (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
    (7, 14),
    (8, 14), (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
    (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8),
    (14, 7),
    (14, 6), (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
    (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
    (7, 0),
    (6, 0),
  ];

  /// Home-column cells per player (steps 51..55; step 56 lands on [homeEnd]).
  static const List<List<(int, int)>> _homeCol = [
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
  ];

  /// The cell a token sits on when it has finished (step 57 shows here).
  static const List<(int, int)> _homeEnd = [(7, 6), (6, 7), (7, 8), (8, 7)];

  /// Yard spots (the four token pads) per player, absolute (row, col).
  static const List<List<(int, int)>> _yardSpots = [
    [(1, 1), (1, 4), (4, 1), (4, 4)],
    [(1, 10), (1, 13), (4, 10), (4, 13)],
    [(10, 10), (10, 13), (13, 10), (13, 13)],
    [(10, 1), (10, 4), (13, 1), (13, 4)],
  ];

  @visibleForTesting
  LudoGame get debugGame => _game;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _startGame(int humans, bool withBots) {
    _botTimer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 2 : (withBots ? 4 : humans);
    final bots = <int>{
      for (var i = humans; i < seats && (withBots || _practice); i++) i,
    };
    setState(() {
      _game = LudoGame(
        playerCount: seats,
        botSeats: bots,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _notice = '';
      _phase = _LudoPhase.playing;
    });
    _maybeBotTurn();
  }

  bool get _currentIsBot =>
      _phase == _LudoPhase.playing && _game.isBot(_game.currentPlayer);

  void _maybeBotTurn() {
    _botTimer?.cancel();
    if (_phase != _LudoPhase.playing || !_currentIsBot || _game.isOver) return;
    _botTimer = Timer(const Duration(milliseconds: 650), _botStep);
  }

  void _botStep() {
    if (!mounted || _phase != _LudoPhase.playing) return;
    setState(() {
      if (_game.dice == null) {
        final value = _game.rollDice();
        _notice = _rollNotice(value);
        if (_game.dice == null) {
          // No move (or a third six): hand over after a beat.
          _botTimer =
              Timer(const Duration(milliseconds: 650), _maybeBotTurn);
          return;
        }
      } else {
        final move = _game.chooseBotMove();
        _game.moveToken(move);
        _notice = '';
      }
      _afterTurnStep();
    });
  }

  String _rollNotice(int value) {
    if (value == 6 && _game.dice == null) return 'ثلاث ستات! الدور راح 😅';
    if (_game.dice == null) return 'مفيش حركة — الدور للي بعده';
    return value == 6 ? '٦! رمية كمان 🎲' : '';
  }

  void _afterTurnStep() {
    if (_game.isOver) {
      _botTimer?.cancel();
      _phase = _LudoPhase.over;
      return;
    }
    _maybeBotTurn();
  }

  void _humanRoll() {
    if (_currentIsBot || _game.dice != null || _game.isOver) return;
    setState(() {
      final value = _game.rollDice();
      _notice = _rollNotice(value);
      if (_game.dice == null) _afterTurnStep();
    });
  }

  void _humanMove(int tokenIndex) {
    if (_currentIsBot || _game.dice == null || _game.isOver) return;
    if (!_game.legalMoves().contains(tokenIndex)) return;
    setState(() {
      _game.moveToken(tokenIndex);
      _notice = '';
      _afterTurnStep();
    });
  }

  TextStyle _t(double size,
          {Color? color, FontWeight w = FontWeight.w800, double? h}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback, height: h);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'لودو الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🎲',
          title: 'لودو الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'لودو كلاسيك: رمي ٦ عشان تطلع من البيت، كُل اللي يقابلك يرجعه، وأول واحد يدخل أحجاره الأربعة البيت يكسب!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    switch (_phase) {
      case _LudoPhase.pickPlayers:
        return OfflineGameScaffold(
        title: 'لودو الشلة',
        backgroundColor: FlatColors.bg,
        body: _pickPlayers());
      case _LudoPhase.pickBots:
        return OfflineGameScaffold(
        title: 'لودو الشلة',
        backgroundColor: FlatColors.bg,
        body: _pickBots());
      case _LudoPhase.playing:
        return OfflineGameScaffold(
        title: 'لودو الشلة',
        backgroundColor: FlatColors.bg,
        body: _playing());
      case _LudoPhase.over:
        return OfflineGameScaffold(
        title: 'لودو الشلة',
        backgroundColor: FlatColors.bg,
        body: _over());
    }
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🎲', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل واحد ليه 4 أحجار — الأول يوصّلهم البيت',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startGame(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _LudoPhase.pickBots;
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
          Text('البوتات تكمل المقاعد؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'لوحدك: تمرين ضد بوت واحد، من غير نتيجة'
                : 'الأماكن الفاضية تتملى بوتات',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startGame(_humans, true)),
          _bigChoice('لا', () => _startGame(_humans, false)),
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

  // ---------------------------------------------------------------- game ---

  Widget _playing() {
    final current = _game.currentPlayer;
    final legal = _game.legalMoves();
    return Column(
      children: [
        _turnBar(current),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Board centered with the dice OUTSIDE the square, one die at
              // each seat's corner (Ludo King reference layout).
              final side = min(constraints.maxWidth, constraints.maxHeight);
              final dieSize = side * 0.13;
              final boardSide = side - dieSize * 2.0;
              final boardLeft = (constraints.maxWidth - boardSide) / 2;
              final boardTop = (constraints.maxHeight - boardSide) / 2;
              return Stack(
                children: [
                  Positioned(
                    left: boardLeft,
                    top: boardTop,
                    width: boardSide,
                    height: boardSide,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: FlatColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: FlatColors.ink.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LayoutBuilder(
                          builder: (context, bc) {
                            final cell = bc.maxWidth / 15;
                            return Stack(
                              children: [
                                ..._boardCells(cell),
                                ..._tokens(cell, legal),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  ..._cornerDice(constraints.maxWidth, constraints.maxHeight,
                      boardLeft, boardTop, boardSide, dieSize),
                ],
              );
            },
          ),
        ),
        if (_notice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_notice,
                style: _t(13, w: FontWeight.w900, color: _colors[current]),
                textDirection: TextDirection.rtl),
          ),
        if (!_currentIsBot && _game.dice != null && legal.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('دوس على حجر يتحرك 🎯',
                style: _t(13, w: FontWeight.w900, color: _colors[current]),
                textDirection: TextDirection.rtl),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// One die per seat, OUTSIDE the board square at that seat's corner
  /// (reference Ludo layout). The active seat's die is full-size and
  /// colored; tapping it rolls (humans only). Bots' dice show their rolled
  /// pips while they play.
  List<Widget> _cornerDice(double maxW, double maxH, double boardLeft,
      double boardTop, double boardSide, double dieSize) {
    // Corner anchors: p0 top-left, p1 top-right, p2 bottom-right, p3
    // bottom-left; pushed diagonally outward from the board corners.
    final anchors = [
      (boardLeft - dieSize * 0.48, boardTop - dieSize * 0.48),
      (boardLeft + boardSide + dieSize * 0.48, boardTop - dieSize * 0.48),
      (boardLeft + boardSide + dieSize * 0.48,
          boardTop + boardSide + dieSize * 0.48),
      (boardLeft - dieSize * 0.48, boardTop + boardSide + dieSize * 0.48),
    ];
    final widgets = <Widget>[];
    for (var p = 0; p < _game.playerCount; p++) {
      final active = p == _game.currentPlayer && !_game.isOver;
      final rolled = active ? _game.dice : null;
      final isBot = _game.isBot(p);
      final size = dieSize;
      final cx = anchors[p].$1.clamp(4.0 + size / 2, maxW - 4.0 - size / 2);
      final cy = anchors[p].$2.clamp(4.0 + size / 2, maxH - 4.0 - size / 2);
      widgets.add(Positioned(
        left: cx - size / 2,
        top: cy - size / 2,
        width: size,
        height: size,
        child: GestureDetector(
          key: ValueKey('die_$p'),
          onTap: (active && !isBot && _game.dice == null) ? _humanRoll : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: active ? 1.0 : 0.85,
            child: Opacity(
              opacity: active ? 1 : 0.55,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.22),
                  border: Border.all(
                      color: active ? _colors[p] : FlatColors.border,
                      width: active ? 3 : 2),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: _colors[p].withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Center(
                  child: rolled != null
                      ? _DiceFace(value: rolled, color: _colors[p])
                      : isBot
                          ? Text('🤖',
                              style: TextStyle(
                                  fontSize: size * 0.34,
                                  fontFamilyFallback: _emojiFallback))
                          : Icon(Icons.casino_rounded,
                              color: active ? _colors[p] : FlatColors.border,
                              size: size * 0.5),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  Widget _turnBar(int current) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _colors[current].withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors[current], width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _colors[current], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'دور ${_seatLabel(current)}${_game.isBot(current) ? ' 🤖' : ''}',
              style: _t(14, w: FontWeight.w900, color: _colors[current]),
              textDirection: TextDirection.rtl,
            ),
          ),
          for (var p = 0; p < _game.playerCount; p++) ...[
            if (p > 0)
              Text('·',
                  style: _t(12,
                      w: FontWeight.w900,
                      color: FlatColors.ink.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_game.tokens[p].where((t) => t == LudoGame.finished).length}/4',
                textDirection: TextDirection.ltr,
                style: _t(12,
                    w: FontWeight.w900,
                    color: p < _humans ? _colors[p] : FlatColors.ink.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- board -----

  Color _cellColor(int row, int col) {
    // Yards
    const yardRows = [(0, 5), (0, 5), (9, 14), (9, 14)];
    const yardCols = [(0, 5), (9, 14), (9, 14), (0, 5)];
    for (var p = 0; p < 4; p++) {
      if (row >= yardRows[p].$1 &&
          row <= yardRows[p].$2 &&
          col >= yardCols[p].$1 &&
          col <= yardCols[p].$2) {
        return _colors[p].withValues(alpha: 0.30);
      }
    }
    // Home columns and ends
    for (var p = 0; p < 4; p++) {
      if (_homeCol[p].contains((row, col))) {
        return _colors[p].withValues(alpha: 0.45);
      }
      if (_homeEnd[p] == (row, col)) return _colors[p];
    }
    // Player start squares
    for (var p = 0; p < 4; p++) {
      if (_path[(p * 13) % 52] == (row, col)) {
        return _colors[p].withValues(alpha: 0.45);
      }
    }
    return Colors.white;
  }

  bool _isCenter(int row, int col) =>
      row >= 6 && row <= 8 && col >= 6 && col <= 8;

  List<Widget> _boardCells(double cell) {
    final cells = <Widget>[];
    for (var row = 0; row < 15; row++) {
      for (var col = 0; col < 15; col++) {
        final inYard = (row <= 5 || row >= 9) && (col <= 5 || col >= 9);
        final onTrack = _path.contains((row, col));
        final isHomeCol =
            _homeCol.any((c) => c.contains((row, col)));
        final isHomeEnd = _homeEnd.contains((row, col));
        if (!inYard && !onTrack && !isHomeCol && !isHomeEnd && !_isCenter(row, col)) {
          continue; // empty cross-arm gaps
        }
        final safe = onTrack && LudoGame.isSafeSquare(_path.indexOf((row, col)));
        cells.add(Positioned(
          left: col * cell,
          top: row * cell,
          width: cell,
          height: cell,
          child: Container(
            decoration: BoxDecoration(
              color: _cellColor(row, col),
              border: inYard
                  ? null
                  : Border.all(color: FlatColors.border, width: 0.6),
            ),
            child: safe
                ? Center(
                    child: Text('⭐', style: TextStyle(fontSize: cell * 0.42, fontFamilyFallback: _emojiFallback)))
                : _isCenter(row, col) && (row, col) == (7, 7)
                    ? Center(
                        child:
                            Text('🏆', style: TextStyle(fontSize: cell * 0.5, fontFamilyFallback: _emojiFallback)))
                    : null,
          ),
        ));
      }
    }
    return cells;
  }

  List<Widget> _tokens(double cell, List<int> legal) {
    final widgets = <Widget>[];
    // Group tokens occupying the same board cell so they fan out.
    final placed = <(int, int), int>{};
    for (var p = 0; p < _game.playerCount; p++) {
      for (var t = 0; t < 4; t++) {
        final steps = _game.tokens[p][t];
        final (int, int) spot;
        if (steps == LudoGame.yard) {
          spot = _yardSpots[p][t];
        } else if (steps >= 51) {
          spot = steps == LudoGame.finished
              ? _homeEnd[p]
              : _homeCol[p][steps - 51];
        } else {
          spot = _path[LudoGame.absoluteSquare(p, steps)!];
        }
        final index = placed[spot] ?? 0;
        placed[spot] = index + 1;
        final isMovable =
            p == _game.currentPlayer && legal.contains(t) && !_currentIsBot;
        widgets.add(_tokenWidget(cell, spot, index, _colors[p], isMovable,
            () => _humanMove(t)));
      }
    }
    return widgets;
  }

  Widget _tokenWidget(double cell, (int, int) spot, int stackIndex, Color color,
      bool isMovable, VoidCallback onTap) {
    // Fan stacked tokens into the cell's corners.
    final offsets = [
      const Offset(0.28, 0.28),
      const Offset(0.72, 0.28),
      const Offset(0.28, 0.72),
      const Offset(0.72, 0.72),
    ];
    final o = offsets[stackIndex % 4];
    final size = cell * 0.66;
    return Positioned(
      left: (spot.$2 + o.dx) * cell - size / 2,
      top: (spot.$1 + o.dy) * cell - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: isMovable ? onTap : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isMovable ? 1.18 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isMovable ? FlatColors.ink : Colors.white,
                  width: isMovable ? 3 : 2),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- over -----

  Widget _over() {
    final w = _game.winner!;
    final humanWin = w < _humans;
    if (!_practice && humanWin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VictoryFriends(
                gameTitle: 'لودو الشلة', winnerName: '${PlayerNames.name(w)}'),
            const SizedBox(height: 20),
            _bigChoice('العبوا تاني 🔁', () => setState(() {
                  _phase = _LudoPhase.pickPlayers;
                  _showIntro = false;
                })),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_practice ? 'تمرين خلص! 💪' : 'البوتات كسبوا 🤖',
              style: _t(24, w: FontWeight.w900),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 8),
          Text(
            _practice
                ? 'وصّلت ${_game.tokens[w].length} أحجار البيت — جاهز للشلة؟'
                : 'بوت ${w + 1} دخل أحجاره الأول',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 20),
          _bigChoice('العبوا تاني 🔁', () => setState(() {
                _phase = _LudoPhase.pickPlayers;
              })),
        ],
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value, required this.color});

  final int value;
  final Color color;

  static const Map<int, List<int>> _pips = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final lit = _pips[value]!;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var r = 0; r < 3; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lit.contains(r * 3 + c)
                                ? color
                                : Colors.transparent,
                          ),
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
}
