import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';
import '../../data/taboo_data.dart';

/// كلمات ممنوعة — وصّف الكلمة من غير ما تقول الكلمات الممنوعة.
class TabooGame extends StatefulWidget {
  const TabooGame({super.key});

  @override
  State<TabooGame> createState() => _TabooGameState();
}

class _TabooGameState extends State<TabooGame> {
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  List<int> _order = [];
  int _cardIndex = 0;
  int _describerTurn = 0;
  int _turnsPlayed = 0;
  int _secondsLeft = 60;
  Timer? _timer;
  bool _timerRunning = false;

  static const int secondsPerTurn = 60;
  static const int turnsPerPlayer = 2;

  int get _totalTurns => _players.isEmpty ? 0 : _players.length * turnsPerPlayer;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _order = List.generate(tabooCards.length, (i) => i)..shuffle();
      _cardIndex = 0;
      _describerTurn = 0;
      _turnsPlayed = 0;
      _started = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = secondsPerTurn;
    _timerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 5 && _secondsLeft > 0) {
          AudioService.playTick();
        }
        if (_secondsLeft <= 0) {
          _endTurn();
        }
      });
    });
  }

  void _guessed() {
    setState(() {
      _players[_describerTurn]['score'] =
          (_players[_describerTurn]['score'] as int) + 1;
      _cardIndex = (_cardIndex + 1) % _order.length;
    });
    AudioService.playSuccess();
    HapticService.success();
  }

  void _skip() {
    setState(() {
      _cardIndex = (_cardIndex + 1) % _order.length;
    });
    AudioService.playClick();
    HapticService.lightImpact();
  }

  void _endTurn() {
    _timer?.cancel();
    _timerRunning = false;
    AudioService.playFailure();
    setState(() {
      _turnsPlayed++;
      _describerTurn = (_describerTurn + 1) % _players.length;
    });
    // Restart the clock for the next describer; without this every turn
    // after the first ran with a dead timer stuck at 0.
    if (_turnsPlayed < _totalTurns) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  TabooCard get _card => tabooCards[_order[_cardIndex % _order.length]];

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🚫 كلمات ممنوعة',
        backgroundColor: FunkyColors.coral,
        body: GameIntroWidget(
          title: '🚫 كلمات ممنوعة',
          icon: '🙊',
          description:
              'وصّف الكلمة اللي فوق لصحابك من غير ما تقول أي كلمة من الكلمات الممنوعة تحتها! كل كلمة صح = نقطة. عندك 60 ثانية في الدور!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🚫 كلمات ممنوعة',
        minPlayers: 2,
        onStartGame: (ctx, selected) {
          _start(selected);
        },
      );
    }

    if (_turnsPlayed >= _totalTurns) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      return OfflineGameScaffold(
        title: '🚫 كلمات ممنوعة',
        backgroundColor: FunkyColors.coral,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 80))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .rotate(duration: 700.ms, begin: -0.05, end: 0.05),
                const SizedBox(height: 16),
                Text(
                  'أحسن واصف: ${sorted.first['name']}',
                  style: FunkyText.title(size: 26, color: FunkyColors.coral),
                ),
                const SizedBox(height: 24),
                ...sorted.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${p['name']} — ${p['score']} نقطة',
                      style: FunkyText.body(size: 18, color: FlatColors.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FunkyButton(
          label: 'العب تاني 🔄',
                  accent: FunkyColors.coral,
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

    final card = _card;
    final describer = _players[_describerTurn]['name'];

    return OfflineGameScaffold(
      title: '🚫 كلمات ممنوعة',
      backgroundColor: FunkyColors.coral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: FlatDecor.tag(),
                    child: Text(
                      'الواصف: $describer',
                      style: FunkyText.title(size: 16, color: FlatColors.ink),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _secondsLeft <= 10 ? FlatColors.mafia : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _secondsLeft <= 10 ? FlatColors.mafia : FlatColors.border, width: 2),
                    ),
                    child: Text(
                      '⏱ $_secondsLeft',
                      style: FunkyText.title(size: 18, color: _secondsLeft <= 10 ? Colors.white : FlatColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: FlatDecor.card(),
                child: Column(
                  children: [
                    Text(
                      card.word,
                      style: GoogleFonts.cairo(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                    ).animate(key: ValueKey(_cardIndex)).fadeIn().slideY(begin: -0.2),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlatColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FlatColors.border, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '🙊 ممنوع تقول:',
                            style: FunkyText.title(size: 16, color: FlatColors.tilePastels[3]),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: card.forbidden
                                .map(
                                  (w) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: FunkyDecor.pill(FlatColors.tilePastels[5]),
                                    child: Text(
                                      w,
                                      style: FunkyText.body(size: 15, color: Colors.white),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FunkyButton(
          label: 'تخطي ⏭️',
                      accent: FlatColors.tilePastels[4],
                      onPressed: _skip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FunkyButton(
          label: 'خمّنوها! +1 ✅',
                      accent: FlatColors.tilePastels[2],
                      onPressed: _guessed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
