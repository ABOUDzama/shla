import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// الشيفرة: a two-team word-association grid game in the Codenames genre.
/// Mechanics verified against the publisher rulebook (Czech Games Edition):
/// https://filemanager.czechgames.com/storage/files/codenames-2015/rules/codenames-rules-en.pdf
/// 25 words in a 5x5 grid; starting team has 9 agents, the other 8, seven
/// innocent bystanders, one assassin; clue = one word + a number; a correct
/// guess earns another (up to number+1); any wrong guess ends the turn;
/// contacting the assassin loses instantly; first team to contact all its
/// agents wins. Original Arabic name, original word pool, original art -
/// no branded assets.
///
/// House adaptations (labeled): an invalid clue (empty, multi-word, or a
/// word already on the board) is blocked at entry with an error message
/// instead of ending the turn with a penalty; the end-turn button is always
/// available, while the publisher rules require at least one guess. Both
/// fit single-device pass-and-play.
class CodeNamesGame extends StatefulWidget {
  const CodeNamesGame({super.key, this.seed = 21});

  /// Deterministic seed for tests.
  final int seed;

  /// Original Egyptian-Arabic-friendly word pool (written for Shla).
  static const List<String> wordPool = [
    'قهوة', 'كشري', 'ميكروباص', 'كوبري', 'بلكونة', 'عجل', 'كورنيش',
    'مول', 'كشك', 'ترابيزة', 'مروحة', 'تلاجة', 'غسالة', 'موبايل',
    'شاحن', 'ريموت', 'كنبة', 'سجادة', 'لمبة', 'مفتاح', 'باب',
    'شباك', 'سلم', 'أسانسير', 'جرس', 'طرشي', 'فول', 'طعمية',
    'عيش', 'جبنة', 'بطيخ', 'مانجو', 'بلح', 'قصب', 'ذرة',
    'سمك', 'فراخ', 'رز', 'مكرونة', 'شاي', 'عصير', 'مياه',
    'شمس', 'بحر', 'رملة', 'مركب', 'شاطئ', 'مظلة', 'نضارة',
    'كابينة', 'موجة', 'قمر', 'نجمة', 'سحابة', 'مطر', 'رعد',
    'مدرسة', 'دفتر', 'قلم', 'شنطة', 'مدرس', 'امتحان', 'طابور',
  ];

  /// One deal: 25 grid words + the secret key (25 cells: starting team has
  /// 9 agents, the other 8, seven neutrals, one assassin).
  static (List<String>, List<String>) deal(Random rng, String startTeam) {
    final pool = List<String>.from(wordPool)..shuffle(rng);
    final words = pool.take(25).toList();
    final other = startTeam == 'red' ? 'blue' : 'red';
    final key = <String>[
      ...List.filled(9, startTeam),
      ...List.filled(8, other),
      ...List.filled(7, 'neutral'),
      'assassin',
    ]..shuffle(rng);
    return (words, key);
  }

  /// Clue validation: single word, non-empty, not already on the board.
  /// Returns an Arabic error message, or null when valid.
  static String? validateClue(String raw, List<String> boardWords) {
    final clue = raw.trim();
    if (clue.isEmpty) return 'اكتب تلميح الأول';
    if (clue.contains(RegExp(r'\s'))) return 'التلميح كلمة واحدة بس';
    if (boardWords.contains(clue)) return 'التلميح ميبقاش كلمة من اللوحة';
    return null;
  }

  /// Official rule: at most (clue number + 1) guesses per turn.
  static int guessesAllowed(int clueCount) => clueCount + 1;

  /// A team wins the moment all its agents are revealed, even mid-turn of
  /// the other team. Assassin handled in-game (instant loss).
  static String? winner(List<String> key, Set<int> revealed) {
    for (final team in ['red', 'blue']) {
      var all = true;
      for (var i = 0; i < key.length; i++) {
        if (key[i] == team && !revealed.contains(i)) {
          all = false;
          break;
        }
      }
      if (all) return team;
    }
    return null;
  }

  @override
  State<CodeNamesGame> createState() => _CodeNamesGameState();
}

class _CodeNamesGameState extends State<CodeNamesGame> {
  bool _showIntro = true;
  bool _started = false;

  late List<String> _red;
  late List<String> _blue;
  late List<String> _words;
  late List<String> _key;
  final Set<int> _revealed = {};

  String _turn = 'red'; // red starts (9 agents)
  bool _gateOpen = false;
  bool _cluePhase = false; // spymaster entering the clue (no colors shown)
  String? _clue;
  int _clueCount = 2;
  int _guessesLeft = 0;
  String? _winner;
  String? _clueError;

  final TextEditingController _clueController = TextEditingController();

  String get _spyName =>
      (_turn == 'red' ? _red : _blue).first;

  void _start(List<String> names) {
    final rng = Random(widget.seed);
    final (words, key) = CodeNamesGame.deal(rng, 'red');
    setState(() {
      // Alternating split; first member of each team is the spymaster.
      _red = [for (var i = 0; i < names.length; i += 2) names[i]];
      _blue = [for (var i = 1; i < names.length; i += 2) names[i]];
      _words = words;
      _key = key;
      _revealed.clear();
      _turn = 'red';
      _gateOpen = false;
      _cluePhase = false;
      _clue = null;
      _clueCount = 2;
      _guessesLeft = 0;
      _winner = null;
      _clueError = null;
      _clueController.clear();
      _started = true;
    });
  }

  void _submitClue() {
    final err = CodeNamesGame.validateClue(_clueController.text, _words);
    if (err != null) {
      setState(() => _clueError = err);
      return;
    }
    setState(() {
      _clue = _clueController.text.trim();
      _guessesLeft = CodeNamesGame.guessesAllowed(_clueCount);
      _cluePhase = false;
      _gateOpen = false; // concealment: key closed before public guessing
      _clueError = null;
    });
  }

  void _swapTurn() {
    _turn = _turn == 'red' ? 'blue' : 'red';
    _clue = null;
    _guessesLeft = 0;
    _gateOpen = false;
    _cluePhase = false;
    _clueController.clear();
  }

  void _endTurn() {
    setState(_swapTurn);
  }

  void _guess(int index) {
    if (_winner != null || _revealed.contains(index) || _clue == null) {
      return;
    }
    final cell = _key[index];
    setState(() {
      _revealed.add(index);
      if (cell == 'assassin') {
        // Instant loss for the guessing team.
        _winner = _turn == 'red' ? 'blue' : 'red';
        return;
      }
      final w = CodeNamesGame.winner(_key, _revealed);
      if (w != null) {
        _winner = w;
        return;
      }
      if (cell != _turn) {
        _swapTurn();
      } else {
        _guessesLeft--;
        if (_guessesLeft <= 0) _swapTurn();
      }
    });
  }

  @override
  void dispose() {
    _clueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🕵 الشيفرة',
        backgroundColor: FunkyColors.violet,
        showAi: false,
        body: GameIntroWidget(
          title: '🕵 الشيفرة',
          icon: '🕵',
          description:
              'فريقين وشبكة كلمات! قائد كل فريق هو بس اللي يشوف الخريطة السرية، ويدي تلميح من كلمة واحدة + عدد. خمّنوا كلماتكم وابعدوا عن كلمات الفريق التاني.. وبالذات القاتل! محتاجين ٤ لاعيبة أو أكتر.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🕵 الشيفرة',
        minPlayers: 4,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_winner != null) return _buildWin();

    return OfflineGameScaffold(
      title: '🕵 الشيفرة',
      backgroundColor: FunkyColors.violet,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_gateOpen && _clue == null && !_cluePhase
            ? _buildGate()
            : _cluePhase
                ? _buildClueEntry()
                : _gateOpen
                    ? _buildKeyMap()
                    : _buildGuessing(),
      ),
    );
  }

  Color _teamColor(String team) =>
      team == 'red' ? const Color(0xFFC63730) : const Color(0xFF2B5CD6);

  Widget _buildGate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الدور على الفريق ${_turn == 'red' ? 'الأحمر' : 'الأزرق'}',
          textAlign: TextAlign.center,
          style: flatCairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _teamColor(_turn),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            decoration: FunkyDecor.glowCard(FunkyColors.violet, radius: 26),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🤫', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FunkyButton(
                      label: 'افتح الخريطة يا $_spyName',
                      accent: _teamColor(_turn),
                      icon: Icons.map_rounded,
                      onPressed: () => setState(() => _gateOpen = true),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'بس $_spyName اللي يشوف الخريطة!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: flatCairo(
                        fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMap() {
    // Spymaster-only: colored key. Closed again before any public phase.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الخريطة السرية - $_spyName بس! 🤫',
          textAlign: TextAlign.center,
          style: flatCairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: FlatColors.ink.withValues(alpha: 0.75),
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _grid(reveal: (i) => true),
        ),
        const SizedBox(height: 10),
        FunkyButton(
          label: 'اكتب التلميح ✍',
          accent: _teamColor(_turn),
          icon: Icons.edit_rounded,
          onPressed: () => setState(() {
            _gateOpen = false; // conceal the key before clue entry
            _cluePhase = true;
          }),
        ),
      ],
    );
  }

  Widget _buildClueEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'يا $_spyName، اكتب تلميح من كلمة واحدة وعدد الكلمات:',
          textAlign: TextAlign.center,
          style: flatCairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _clueController,
          textAlign: TextAlign.center,
          style: flatCairo(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'التلميح..',
            hintStyle: flatCairo(color: FlatColors.ink.withValues(alpha: 0.5), fontSize: 15),
            errorText: _clueError,
            errorStyle: flatCairo(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 4; n++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _clueCount = n),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _clueCount == n
                          ? _teamColor(_turn)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: flatCairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _clueCount == n ? Colors.white : FlatColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        FunkyButton(
          label: 'اعرض التلميح للفريق',
          accent: _teamColor(_turn),
          icon: Icons.check_rounded,
          onPressed: _submitClue,
        ),
      ],
    );
  }

  Widget _buildGuessing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التلميح: $_clue ($_clueCount) - فاضل $_guessesLeft تخمينة',
          textAlign: TextAlign.center,
          style: flatCairo(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _teamColor(_turn),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _grid(reveal: (i) => _revealed.contains(i))),
        const SizedBox(height: 10),
        FunkyButton(
          label: 'خلصنا تخمين ⏭',
          accent: FunkyColors.violet,
          icon: Icons.skip_next_rounded,
          onPressed: _endTurn,
        ),
      ],
    );
  }

  Widget _grid({required bool Function(int) reveal}) {
    return GridView.count(
      crossAxisCount: 5,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 1.35,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 25; i++)
          GestureDetector(
            onTap: () {
              // Taps only count on the public guessing grid.
              if (!_gateOpen && !_cluePhase && _clue != null) _guess(i);
            },
            child: Container(
              decoration: BoxDecoration(
                color: reveal(i)
                    ? _key[i] == 'neutral'
                        ? const Color(0xFFB8A88A)
                        : _key[i] == 'assassin'
                            ? const Color(0xFF22242E)
                            : _teamColor(_key[i])
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _words[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: flatCairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: reveal(i)
                        ? (_key[i] == 'neutral'
                            ? FlatColors.ink
                            : Colors.white)
                        : FlatColors.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWin() {
    final winners = _winner == 'red' ? _red : _blue;
    return OfflineGameScaffold(
      title: '🕵 الشيفرة',
      backgroundColor: FunkyColors.violet,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الفريق ${_winner == 'red' ? 'الأحمر' : 'الأزرق'} كسب! 🎉',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _teamColor(_winner!),
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 12),
            Text(
              winners.join('، '),
              textAlign: TextAlign.center,
              style:
                  flatCairo(fontSize: 16, color: FlatColors.ink.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 24),
            FunkyButton(
              label: 'العب تاني',
              accent: FunkyColors.mint,
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
