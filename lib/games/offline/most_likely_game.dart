import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../data/most_likely_data.dart';

/// مين فينا؟ — سؤال مضحك، الشلة تشاور على شخص، والمختار ياخد نقطة.
class MostLikelyGame extends StatefulWidget {
  const MostLikelyGame({super.key});

  @override
  State<MostLikelyGame> createState() => _MostLikelyGameState();
}

class _MostLikelyGameState extends State<MostLikelyGame> {
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  List<int> _order = [];
  int _round = 0;
  bool _counted = false;

  static const int totalRounds = 12;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _order = List.generate(mostLikelyPrompts.length, (i) => i)..shuffle();
      _round = 0;
      _counted = false;
      _started = true;
    });
  }

  void _pick(int index) {
    setState(() {
      _players[index]['score'] = (_players[index]['score'] as int) + 1;
      _round++;
      _counted = false;
    });
    AudioService.playSuccess();
    HapticService.success();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '👉 مين فينا؟',
        backgroundColor: FunkyColors.lime,
        body: GameIntroWidget(
          title: '👉 مين فينا؟',
          icon: '👉',
          description:
              'سؤال يطلع، الكل يعد 3-2-1 ويشاور على شخص في الشلة! اللي عليه أصوات أكتر ياخد النقطة... واللي نقطه أكتر في الآخر هو "المتهم الأول" في الشلة 😂',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '👉 مين فينا؟',
        minPlayers: 2,
        onStartGame: (ctx, selected) {
          _start(selected);
        },
      );
    }

    if (_round >= totalRounds) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      return OfflineGameScaffold(
        title: '👉 مين فينا؟',
        backgroundColor: FunkyColors.lime,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 80))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.15, 1.15)),
                const SizedBox(height: 16),
                Text(
                  'المتهم الأول في الشلة:',
                  style: FunkyText.title(size: 24, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  sorted.first['name'] as String,
                  style: FunkyText.headline(size: 40, color: FunkyColors.lime),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
                const SizedBox(height: 24),
                ...sorted.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${p['name']} — ${p['score']} نقطة',
                      style: FunkyText.body(size: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FunkyButton(
          label: 'العب تاني 🔄',
                  accent: FunkyColors.lime,
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

    final prompt = mostLikelyPrompts[_order[_round % _order.length]];

    return OfflineGameScaffold(
      title: '👉 مين فينا؟',
      backgroundColor: FunkyColors.lime,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'الجولة ${_round + 1} من $totalRounds',
                style: FunkyText.body(size: 16, color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: FunkyDecor.glowCard(FunkyColors.lime),
                child: Column(
                  children: [
                    const Text('👉', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate(key: ValueKey(_round)).fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.9, 0.9),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 16),
              if (!_counted)
                FunkyButton(
          label: 'عدّوا 3-2-1 وأشيروا! 👉',
                  accent: FunkyColors.magenta,
                  onPressed: () {
                    setState(() => _counted = true);
                    AudioService.playClick();
                    HapticService.heavyImpact();
                  },
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'مين اختاروه؟ 👀',
                        style: FunkyText.title(size: 20, color: FunkyColors.lime),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                          children: List.generate(_players.length, (i) {
                            return GestureDetector(
                              onTap: () => _pick(i),
                              child: Container(
                                decoration: FunkyDecor.glowCard(
                                  FunkyColors.accents[i % FunkyColors.accents.length],
                                ),
                                child: Center(
                                  child: Text(
                                    '${_players[i]['name']} (${_players[i]['score']})',
                                    style: FunkyText.title(size: 16, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
