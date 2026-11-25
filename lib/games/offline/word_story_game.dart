import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// قصة كلمة بكلمة (one-word story): the classic gathering game where the
/// group builds a story one word per turn. Grounded in the no-equipment
/// gathering games listed at familygameideas.com/ar/party-games/no-equipment/
/// («قصة كلمة بكلمة»). Distinct from سلسلة الكلمات, which is last-letter
/// word chaining with categories, not collaborative storytelling.
class WordStoryGame extends StatefulWidget {
  const WordStoryGame({super.key});

  /// Every player adds this many words before the story closes.
  static const int wordsPerPlayer = 5;

  /// Classic story openers the group can start from (rotated per session).
  static const List<String> openers = [
    'كان يا ما كان في قديم الزمان',
    'في يوم من الأيام',
    'مرة واحد صاحبنا',
    'في قعدة من قعداتنا',
  ];

  /// Normalizes a typed entry into a single story word: trims, collapses
  /// inner whitespace, and rejects empty or multi-word input (returns null).
  static String? normalizeWord(String raw) {
    final w = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (w.isEmpty || w.contains(' ')) return null;
    if (w.length > 20) return null;
    return w;
  }

  /// Session end: every player contributed [wordsPerPlayer] words.
  static bool isEnd(int wordsAdded, int playerCount) =>
      playerCount > 0 && wordsAdded >= playerCount * wordsPerPlayer;

  @override
  State<WordStoryGame> createState() => _WordStoryGameState();
}

class _WordStoryGameState extends State<WordStoryGame> {
  bool _showIntro = true;
  bool _started = false;

  List<String> _names = [];
  String _opener = WordStoryGame.openers.first;
  final List<String> _words = [];
  int _openerIndex = 0;
  final TextEditingController _controller = TextEditingController();
  String? _entryError;

  int get _turn => _words.length;
  String get _currentPlayer => _names[_turn % _names.length];

  void _start(List<String> names) {
    setState(() {
      _names = names;
      _openerIndex = (_openerIndex + 1) % WordStoryGame.openers.length;
      _opener = WordStoryGame.openers[_openerIndex];
      _words.clear();
      _controller.clear();
      _entryError = null;
      _started = true;
    });
  }

  void _addWord() {
    final w = WordStoryGame.normalizeWord(_controller.text);
    if (w == null) {
      setState(() => _entryError = 'كلمة واحدة بس، من غير مسافات!');
      return;
    }
    setState(() {
      _words.add(w);
      _controller.clear();
      _entryError = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '📖 قصة كلمة بكلمة',
        backgroundColor: FunkyColors.mint,
        showAi: false,
        body: GameIntroWidget(
          title: '📖 قصة كلمة بكلمة',
          icon: '📖',
          description:
              'لعبة القعدات الأصلية: القصة بتبدأ، وكل واحد فيكم يضيف كلمة واحدة بس في دوره. هيطلع منكم إيه؟ أغرب قصة بتتكتب لما محدش يعرف اللي جاي!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '📖 قصة كلمة بكلمة',
        minPlayers: 2,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (WordStoryGame.isEnd(_words.length, _names.length)) {
      return _buildEnd();
    }

    return OfflineGameScaffold(
      title: '📖 قصة كلمة بكلمة',
      backgroundColor: FunkyColors.mint,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الدور على: $_currentPlayer ✍',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: flatCairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: FlatColors.ink.withValues(alpha: 0.75),
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration:
                    FlatDecor.card(radius: 26),
                child: SingleChildScrollView(
                  child: Text(
                    '$_opener ${_words.join(' ')}',
                    style: flatCairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FlatColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب كلمة واحدة بس..',
                hintStyle:
                    flatCairo(color: FlatColors.ink.withValues(alpha: 0.5), fontSize: 15),
                errorText: _entryError,
                errorStyle: flatCairo(fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _addWord(),
            ),
            const SizedBox(height: 12),
            FunkyButton(
              label: 'ضيف الكلمة ✍',
              accent: FunkyColors.mint,
              icon: Icons.add_rounded,
              onPressed: _addWord,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnd() {
    final story = '$_opener ${_words.join(' ')}';
    return OfflineGameScaffold(
      title: '📖 قصة كلمة بكلمة',
      backgroundColor: FunkyColors.mint,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'قصتكم جاهزة! 🎉',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration:
                    FlatDecor.card(radius: 26),
                child: SingleChildScrollView(
                  child: Text(
                    story,
                    style: flatCairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                      height: 1.9,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FunkyButton(
              label: 'قصة جديدة',
              accent: FunkyColors.amber,
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() {
                _started = false;
                _showIntro = true;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
