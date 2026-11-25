import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

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

  static const int pairCount = 8; // 4x4 board

  void _start(List<String> names) {
    final emojis = ([..._emojiPool]..shuffle()).take(pairCount).toList();
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
      Timer(const Duration(milliseconds: 900), () {
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
              'افتح كارتين... لو شبه بعض يبقوا ليك وتلعب تاني! اللي يجمع أزواج أكتر يكسب. ذاكرتك قد التحدي؟',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🧠 ذاكرة الشلة',
        minPlayers: 1,
        onStartGame: (ctx, selected) {
          Navigator.pop(ctx);
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
                      style: FunkyText.body(size: 18, color: Colors.white),
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
                  (i) => Text(
                    '${_players[i]['name']}: ${_players[i]['score']}',
                    style: FunkyText.body(
                      size: 14,
                      color: i == _turn
                          ? currentAccent
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(_board.length, (i) {
                    final shown = _revealed[i] || _matched[i];
                    return GestureDetector(
                      onTap: () => _flip(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: shown
                            ? FunkyDecor.glowCard(
                                _matched[i] ? FunkyColors.mint : currentAccent,
                                radius: 14,
                              )
                            : BoxDecoration(
                                color: FunkyColors.cardLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: FunkyColors.violet.withOpacity(0.5),
                                  width: 1.2,
                                ),
                              ),
                        child: Center(
                          child: Text(
                            shown ? _board[i] : '❓',
                            style: TextStyle(fontSize: shown ? 34 : 22),
                          ),
                        ),
                      ).animate(key: ValueKey('$i-$shown')).scale(
                            begin: const Offset(0.85, 0.85),
                            duration: 200.ms,
                          ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
