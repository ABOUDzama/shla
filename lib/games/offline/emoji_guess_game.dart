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
import '../../data/emoji_guess_data.dart';

/// إيموجي إيه؟ — مجموعة إيموجي على الشاشة، والشلة تخمّن الكلمة أو الموقف.
class EmojiGuessGame extends StatefulWidget {
  const EmojiGuessGame({super.key});

  @override
  State<EmojiGuessGame> createState() => _EmojiGuessGameState();
}

class _EmojiGuessGameState extends State<EmojiGuessGame> {
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  List<int> _order = [];
  int _round = 0;
  bool _revealed = false;

  static const int totalRounds = 10;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _order = List.generate(emojiGuessCards.length, (i) => i)..shuffle();
      _round = 0;
      _revealed = false;
      _started = true;
    });
  }

  EmojiGuessCard get _card => emojiGuessCards[_order[_round % _order.length]];

  void _next() {
    setState(() {
      _round++;
      _revealed = false;
    });
    AudioService.playClick();
  }

  void _award(int index) {
    setState(() {
      _players[index]['score'] = (_players[index]['score'] as int) + 1;
      _revealed = true;
    });
    AudioService.playSuccess();
    HapticService.success();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🧩 إيموجي إيه؟',
        backgroundColor: FunkyColors.amber,
        body: GameIntroWidget(
          title: '🧩 إيموجي إيه؟',
          icon: '🤔',
          description:
              'شوية إيموجي يظهروا على الشاشة... مين أول واحد يخمّن الكلمة أو الموقف صح؟ اللي يخمّن ياخد النقطة!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🧩 إيموجي إيه؟',
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
        title: '🧩 إيموجي إيه؟',
        backgroundColor: FunkyColors.amber,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🧠✨', style: TextStyle(fontSize: 70))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                const SizedBox(height: 16),
                Text(
                  'عبقري الإيموجي: ${sorted.first['name']}',
                  style: FunkyText.title(size: 26, color: FlatColors.ink),
                  textAlign: TextAlign.center,
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
                  accent: FlatColors.tilePastels[4],
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

    return OfflineGameScaffold(
      title: '🧩 إيموجي إيه؟',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'الجولة ${_round + 1} من $totalRounds',
                style: FunkyText.body(
                    size: 16, color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: FlatDecor.card(radius: 26),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: FlatDecor.tag(),
                      child: Text(
                        card.category,
                        style: FunkyText.body(size: 15, color: FlatColors.tilePastels[1]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      card.emojis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 64, height: 1.3),
                    ).animate(key: ValueKey(_round)).fadeIn(duration: 400.ms).scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 12),
                    if (_revealed)
                      Text(
                        card.answer,
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.tilePastels[2],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.3),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_revealed) ...[
                Text(
                  'مين خمّن صح؟ اضغط على اسمه 👇',
                  style: FunkyText.title(size: 18, color: FlatColors.ink),
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
                        onTap: () => _award(i),
                        child: Container(
                          decoration: FlatDecor.tile(
                            FlatColors.tilePastels[i % FlatColors.tilePastels.length],
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
                FunkyButton(
          label: 'محدش عرف 😅 اعرض الإجابة',
                  accent: FlatColors.tilePastels[3],
                  onPressed: () {
                    setState(() => _revealed = true);
                    AudioService.playFailure();
                  },
                ),
              ] else
                FunkyButton(
          label: 'الكارت اللي بعده ⏭️',
                  accent: FlatColors.tilePastels[4],
                  onPressed: _next,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
