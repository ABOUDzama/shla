import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// كلمة السر (Password): each round one player is the clue-giver. Only the
/// clue-giver sees the secret word, says one-word clues out loud, and the
/// rest guess. A correct guess scores the guesser +2 and the clue-giver +1.
class PasswordGame extends StatefulWidget {
  const PasswordGame({super.key});

  /// Pure scoring: guesser gets 2, clue-giver gets 1.
  static Map<String, int> scoreRound(
      Map<String, int> scores, String clueGiver, String guesser) {
    final next = Map<String, int>.from(scores);
    next[guesser] = (next[guesser] ?? 0) + 2;
    next[clueGiver] = (next[clueGiver] ?? 0) + 1;
    return next;
  }

  @override
  State<PasswordGame> createState() => _PasswordGameState();
}

class _PasswordGameState extends State<PasswordGame> {
  static const List<String> _words = [
    'كشري', 'أتوبيس', 'موبايل', 'قهوة', 'كوبري', 'بحر', 'عجلة', 'مدرسة',
    'فرح', 'مظلة', 'تكييف', 'ميكروباص', 'فول', 'طعمية', 'ماتش', 'شاطئ',
    'دكان', 'أسانسير', 'بلكونة', 'ميدان', 'مترو', 'تذكرة', 'شنطة', 'بواب',
    'سلم', 'موتوسيكل', 'زحمة', 'إشارة', 'قطة', 'كلب', 'بطارية', 'شاحن',
    'ريموت', 'تليفزيون', 'غسالة', 'تلاجة', 'بوتاجاز', 'سجادة', 'كنبة',
    'مخدة', 'بطانية', 'شباك', 'باب', 'مفتاح', 'عمارة', 'ناصية', 'ترام',
    'سفر', 'خريطة', 'جران', 'سطح', 'صيف', 'شتا', 'رمل', 'نيل', 'أهرامات',
    'عريس', 'مزيكا', 'نادي', 'غردقة',
  ];

  final Random _rng = Random(7);
  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  int _clueGiverIndex = 0;
  int _roundsPlayed = 0;
  String? _word;
  bool _wordRevealed = false;
  // Gates scoring/skip until the clue-giver has seen the word at least once,
  // so a premature tap cannot score or skip the round (parent review).
  bool _wordSeen = false;
  final Set<String> _usedWords = {};

  int get _totalRounds => _players.length;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _started = true;
      _roundsPlayed = 0;
      _clueGiverIndex = 0;
      _nextWord();
    });
  }

  void _nextWord() {
    final available =
        _words.where((w) => !_usedWords.contains(w)).toList(growable: false);
    _word = available[_rng.nextInt(available.length)];
    _usedWords.add(_word!);
    _wordRevealed = false;
    _wordSeen = false;
  }

  void _guessed(String guesserName) {
    final scores = {for (final p in _players) p['name'] as String: p['score'] as int};
    final next = PasswordGame.scoreRound(
        scores, _players[_clueGiverIndex]['name'] as String, guesserName);
    setState(() {
      for (final p in _players) {
        p['score'] = next[p['name']] ?? p['score'];
      }
      _advanceRound();
    });
  }

  void _noGuess() {
    setState(_advanceRound);
  }

  void _advanceRound() {
    _roundsPlayed++;
    _clueGiverIndex = (_clueGiverIndex + 1) % _players.length;
    if (_roundsPlayed < _totalRounds) _nextWord();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🔑 كلمة السر',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: GameIntroWidget(
          title: '🔑 كلمة السر',
          icon: '🔑',
          description:
              'واحد من الشلة بس اللي يشوف كلمة السر! يقول تلميح من كلمة واحدة والباقي يخمنوا. اللي يخمن صح ياخد نقطتين وصاحب الكلمة نقطة.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🔑 كلمة السر',
        minPlayers: 2,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_roundsPlayed >= _totalRounds) {
      final sorted = [..._players]
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      final top = sorted.first['score'] as int;
      final winners = sorted.where((p) => p['score'] == top).toList();
      return OfflineGameScaffold(
        title: '🔑 كلمة السر',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  winners.length == 1
                      ? 'الفايز: ${winners.first['name']}'
                      : 'تعادل: ${winners.map((w) => w['name']).join(' و ')}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                for (final p in sorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${p['name']}: ${p['score']}',
                      style: GoogleFonts.cairo(
                          fontSize: 18, color: FlatColors.ink.withValues(alpha: 0.75)),
                    ),
                  ),
                const SizedBox(height: 32),
                FunkyButton(
                  label: 'العب تاني',
                  accent: FlatColors.tilePastels[4],
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() {
                    _started = false;
                    _showIntro = true;
                    _players = [];
                    _usedWords.clear();
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final clueGiver = _players[_clueGiverIndex];
    return OfflineGameScaffold(
      title: '🔑 كلمة السر',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الجولة ${_roundsPlayed + 1} من $_totalRounds',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 8),
            Text(
              'صاحب كلمة السر: ${clueGiver['name']}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: FlatDecor.card(radius: 26),
                child: Center(
                  child: _wordRevealed
                      ? GestureDetector(
                          onTap: () =>
                              setState(() => _wordRevealed = false),
                          child: Text(
                            _word!,
                            style: GoogleFonts.cairo(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: FlatColors.ink,
                            ),
                          ).animate().scale(duration: 300.ms),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🤫', style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: FunkyButton(
                                label: 'شوف الكلمة',
                                accent: FlatColors.tilePastels[4],
                                icon: Icons.visibility_rounded,
                                onPressed: () => setState(() {
                                  _wordRevealed = true;
                                  _wordSeen = true;
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'بس ${clueGiver['name']} اللي يشوفها!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FunkyButton(
              label: 'خمنوها صح',
              accent: FlatColors.tilePastels[2],
              icon: Icons.check_circle_rounded,
              onPressed:
                  _wordSeen ? () => _showGuesserPicker(context) : null,
            ),
            const SizedBox(height: 12),
            FunkyButton(
              label: 'محصلش تخمين',
              accent: FlatColors.tilePastels[3],
              icon: Icons.skip_next_rounded,
              onPressed: _wordSeen ? _noGuess : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showGuesserPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مين اللي خمن صح؟',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              for (final p in _players)
                if (p['name'] != _players[_clueGiverIndex]['name'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FunkyButton(
                      label: p['name'] as String,
                      accent: FlatColors.tilePastels[1],
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _guessed(p['name'] as String);
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
