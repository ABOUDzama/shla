import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// ذاكرة الشلة — افتح كارتين، لو متشابهين خدهم وجرب تاني.
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  static const List<String> _emojiPool = [
    '🍕', '🚀', '🎸', '🐱', '🌈', '⚽', '🎁', '🍉',
    '🐸', '👑', '🎯', '🚗', '🍩', '🦁', '🎨', '⭐',
    '🦄', '🍔', '🎲', '🐢',
  ];

  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  List<String> _board = [];
  List<bool> _revealed = [];
  List<bool> _matched = [];
  int? _firstPick;
  int _turn = 0;
  bool _busy = false;
  Timer? _flipBackTimer;

  /// Board grows with the squad: 1-2 players 4x4 (8 pairs), 3-4 players
  /// 4x6 (12 pairs), 5-6 players 5x6 (15 pairs), 7+ players 6x6 (18 pairs).
  static int _pairCountFor(int playerCount) {
    if (playerCount <= 2) return 8;
    if (playerCount <= 4) return 12;
    if (playerCount <= 6) return 15;
    return 18;
  }

  int get _pairCount => _pairCountFor(_players.length);

  @visibleForTesting
  List<String> get debugBoard => _board;
  @visibleForTesting
  List<bool> get debugRevealed => _revealed;

  int get _columns => _pairCount <= 12 ? 4 : (_pairCount <= 15 ? 5 : 6);

  void _start(List<String> names) {
    final emojis =
        ([..._emojiPool]..shuffle()).take(_pairCountFor(names.length)).toList();
    final cards = [...emojis, ...emojis]..shuffle();
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _board = cards;
      _revealed = List.filled(cards.length, false);
      _matched = List.filled(cards.length, false);
      _firstPick = null;
      _turn = 0;
      _busy = false;
      _started = true;
    });
  }

  void _flip(int index) {
    if (_busy || _revealed[index] || _matched[index]) return;
    HapticService.lightImpact();
    setState(() => _revealed[index] = true);
    if (_firstPick == null) {
      _firstPick = index;
      return;
    }
    final first = _firstPick!;
    _firstPick = null;
    if (_board[first] == _board[index]) {
      setState(() {
        _matched[first] = true;
        _matched[index] = true;
        _players[_turn]['score'] = (_players[_turn]['score'] as int) + 1;
      });
      AudioService.playSuccess();
      HapticService.success();
    } else {
      _busy = true;
      AudioService.playClick();
      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _revealed[first] = false;
          _revealed[index] = false;
          _turn = (_turn + 1) % _players.length;
          _busy = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    super.dispose();
  }

  bool get _done => _started && _matched.every((m) => m);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🧠 ذاكرة الشلة',
        backgroundColor: FunkyColors.sky,
        body: GameIntroWidget(
          title: '🧠 ذاكرة الشلة',
          icon: '🃏',
          description:
              'افتح كارتين... لو شبه بعض يبقوا ليك وتلعب تاني! اللي يجمع أزواج أكتر يكسب. والبورد بتكبر كل ما الشلة تكبر! ذاكرتك قد التحدي؟',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🧠 ذاكرة الشلة',
        minPlayers: 1,
        onStartGame: (ctx, selected) {
          _start(selected);
        },
      );
    }

    if (_done) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      final topScore = sorted.first['score'] as int;
      final winners =
          sorted.where((p) => p['score'] == topScore).toList();
      return OfflineGameScaffold(
        title: '🧠 ذاكرة الشلة',
        backgroundColor: FunkyColors.sky,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧠🏆', style: TextStyle(fontSize: 70))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                const SizedBox(height: 16),
                Text(
                  winners.length == 1
                      ? 'الذاكرة الحديدية: ${winners.first['name']}'
                      : 'تعادل أذكياء! 🤝',
                  style: FunkyText.title(size: 26, color: FunkyColors.sky),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...sorted.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${p['name']} — ${p['score']} زوج',
                      style: FunkyText.body(size: 18, color: FlatColors.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FunkyButton(
          label: 'العب تاني 🔄',
                  accent: FunkyColors.sky,
                  onPressed: () => setState(() {
                    _started = false;
                    _showIntro = true;
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentAccent =
        FunkyColors.accents[_turn % FunkyColors.accents.length];

    return OfflineGameScaffold(
      title: '🧠 ذاكرة الشلة',
      backgroundColor: FunkyColors.sky,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: FunkyDecor.pill(currentAccent),
                    child: Text(
                      'دور: ${_players[_turn]['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FunkyText.title(size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(
                  _players.length,
                  (i) => ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      '${_players[i]['name']}: ${_players[i]['score']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FunkyText.body(
                        size: 14,
                        color: i == _turn
                            ? currentAccent
                            : FlatColors.ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = _columns;
                    final rows = (_board.length + cols - 1) ~/ cols;
                    final spacing = cols >= 6 ? 6.0 : 8.0;
                    final cellW =
                        (constraints.maxWidth - (cols - 1) * spacing) / cols;
                    final cellH =
                        (constraints.maxHeight - (rows - 1) * spacing) / rows;
                    // Squash cells vertically (ratio > 1 = wider than tall)
                    // when the board is taller than the available area, so
                    // every row stays reachable. Never taller than square.
                    final ratio = (cellW / cellH).clamp(1.0, 3.0);
                    final fittedH = cellW / ratio;
                    final emojiSize = (fittedH * 0.55).clamp(14.0, 34.0);
                    return GridView.count(
                      crossAxisCount: cols,
                      childAspectRatio: ratio,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(_board.length, (i) {
                        final shown = _revealed[i] || _matched[i];
                        return GestureDetector(
                          onTap: () => _flip(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: shown
                                ? FlatDecor.tile(
                                    _matched[i]
                                        ? FlatColors.tilePastels[2]
                                        : FlatColors.tilePastels[
                                            _turn % FlatColors.tilePastels.length],
                                    radius: 14,
                                  )
                                : BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: FlatColors.border,
                                      width: 2,
                                    ),
                                  ),
                            child: Center(
                              child: Text(
                                shown ? _board[i] : '❓',
                                style: TextStyle(
                                  fontSize:
                                      shown ? emojiSize : emojiSize * 0.65,
                                ),
                              ),
                            ),
                          ).animate(key: ValueKey('$i-$shown')).scale(
                                begin: const Offset(0.85, 0.85),
                                duration: 200.ms,
                              ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
