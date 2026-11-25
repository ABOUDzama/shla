import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';

/// أندر كافر (Undercover): word social-deduction, pass-and-play.
/// Rules grounded in the official Undercover rules (yanstarstudio.com):
/// - Civilians (majority) share one secret word; Undercovers get a slightly
///   different word; Mr. White gets no word at all.
/// - Everyone describes their word aloud in turn, players discuss, then vote
///   to oust one player per round.
/// - An ousted Mr. White gets one chance to guess the Civilians' word; a
///   correct guess wins immediately.
/// - Civilians win by ousting all Undercovers and Mr. Whites; the
///   Infiltrators win when only 1 Civilian remains.
/// - Official scoring: winning Civilians +2, Mr. White +6, Undercover +10.
class UndercoverGame extends StatefulWidget {
  const UndercoverGame({super.key, this.seed = 11});

  /// Deterministic seed for tests.
  final int seed;

  static const String civilian = 'civilian';
  static const String undercover = 'undercover';
  static const String mrWhite = 'mrwhite';

  /// Similar-but-different word pairs (Civilian word, Undercover word).
  /// Original Egyptian-Arabic content.
  static const List<List<String>> wordPairs = [
    ['قهوة', 'شاي'],
    ['كشري', 'فول وطعمية'],
    ['شاطئ', 'حمام سباحة'],
    ['سينما', 'مسرح'],
    ['جيم', 'نادي'],
    ['عربية', 'موتوسيكل'],
    ['موبايل', 'تابلت'],
    ['بيتزا', 'برجر'],
    ['قطة', 'كلب'],
    ['شتاء', 'صيف'],
    ['دكتور', 'مهندس'],
    ['فرح', 'خطوبة'],
    ['مدرسة', 'جامعة'],
    ['طيارة', 'قطار'],
    ['كورة قدم', 'كورة سلة'],
    ['شقة', 'فيلا'],
    ['آيس كريم', 'كنافة'],
    ['فيسبوك', 'انستجرام'],
  ];

  /// Role list for [playerCount] players, shuffled with [rng].
  /// Official setup guidance: at least 1 Undercover or 1 Mr. White; we scale
  /// infiltrators with group size.
  static List<String> rolesFor(int playerCount, Random rng) {
    int uc;
    int mw;
    if (playerCount <= 5) {
      uc = 1;
      mw = 0;
    } else if (playerCount <= 8) {
      uc = 1;
      mw = 1;
    } else {
      uc = 2;
      mw = 1;
    }
    final roles = <String>[
      for (var i = 0; i < uc; i++) undercover,
      for (var i = 0; i < mw; i++) mrWhite,
      for (var i = 0; i < playerCount - uc - mw; i++) civilian,
    ];
    roles.shuffle(rng);
    return roles;
  }

  /// Official win check. Returns 'civilians', 'infiltrators', or null.
  static String? winner(Map<String, String> roles, Set<String> ousted) {
    var civAlive = 0;
    var infilAlive = 0;
    roles.forEach((name, role) {
      if (ousted.contains(name)) return;
      if (role == civilian) {
        civAlive++;
      } else {
        infilAlive++;
      }
    });
    if (infilAlive == 0) return 'civilians';
    if (civAlive <= 1) return 'infiltrators';
    return null;
  }

  /// Official scoring applied on a win. Mr. White word-crack win scores +6
  /// to Mr. White alone.
  static Map<String, int> scoreWin(
    Map<String, int> scores,
    Map<String, String> roles, {
    required String winnerSide,
    String? mrWhiteCracker,
  }) {
    final next = Map<String, int>.from(scores);
    if (mrWhiteCracker != null) {
      next[mrWhiteCracker] = (next[mrWhiteCracker] ?? 0) + 6;
      return next;
    }
    roles.forEach((name, role) {
      if (winnerSide == 'civilians' && role == civilian) {
        next[name] = (next[name] ?? 0) + 2;
      } else if (winnerSide == 'infiltrators') {
        if (role == undercover) next[name] = (next[name] ?? 0) + 10;
        if (role == mrWhite) next[name] = (next[name] ?? 0) + 6;
      }
    });
    return next;
  }

  @override
  State<UndercoverGame> createState() => _UndercoverGameState();
}

class _UndercoverGameState extends State<UndercoverGame> {
  late final Random _rng = Random(widget.seed);
  bool _showIntro = true;
  bool _started = false;

  List<String> _names = [];
  Map<String, int> _scores = {};
  Map<String, String> _roles = {};
  final Set<String> _ousted = {};
  String? _civWord;
  String? _ucWord;
  final Set<int> _usedPairs = {};

  // Deal phase (pass-and-play private reveal).
  int _dealIndex = 0;
  bool _cardRevealed = false;

  // Voting phase (pass-and-play secret ballot).
  int _voteIndex = 0;
  final Map<String, String> _votes = {};

  String? _oustedName;
  bool _mrWhiteGuessing = false;
  List<String> _guessOptions = [];
  String? _winnerSide;
  String? _mrWhiteCracker;

  List<String> get _alive =>
      _names.where((n) => !_ousted.contains(n)).toList(growable: false);

  void _start(List<String> names) {
    final roles = UndercoverGame.rolesFor(names.length, _rng);
    final available = <int>[
      for (var i = 0; i < UndercoverGame.wordPairs.length; i++)
        if (!_usedPairs.contains(i)) i
    ];
    final pairIndex = available[_rng.nextInt(available.length)];
    _usedPairs.add(pairIndex);
    final pair = UndercoverGame.wordPairs[pairIndex];
    setState(() {
      _names = names;
      _scores = {for (final n in names) n: 0};
      _roles = {for (var i = 0; i < names.length; i++) names[i]: roles[i]};
      _civWord = pair[0];
      _ucWord = pair[1];
      _ousted.clear();
      _dealIndex = 0;
      _cardRevealed = false;
      _voteIndex = 0;
      _votes.clear();
      _oustedName = null;
      _mrWhiteGuessing = false;
      _winnerSide = null;
      _mrWhiteCracker = null;
      _started = true;
    });
  }

  void _beginVoting() {
    setState(() {
      _dealIndex = _alive.length; // closes the deal phase
      _voteIndex = 0;
      _votes.clear();
    });
  }

  void _castVote(String votee) {
    _votes[_alive[_voteIndex]] = votee;
    if (_voteIndex + 1 < _alive.length) {
      setState(() => _voteIndex++);
    } else {
      _tally();
    }
  }

  void _tally() {
    final counts = <String, int>{};
    for (final v in _votes.values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final top = counts.values.fold(0, max);
    final tied = counts.keys.where((n) => counts[n] == top).toList();
    final ousted = tied[_rng.nextInt(tied.length)];
    setState(() {
      _ousted.add(ousted);
      _oustedName = ousted;
      _mrWhiteGuessing = _roles[ousted] == UndercoverGame.mrWhite;
      if (_mrWhiteGuessing) {
        // Mr. White's crack attempt: pick from 4 candidates (both pair words
        // plus 2 distractors from other pairs), deterministic via seed.
        final distractors = <String>[];
        for (var i = 0; i < UndercoverGame.wordPairs.length; i++) {
          for (final w in UndercoverGame.wordPairs[i]) {
            if (w != _civWord && w != _ucWord) distractors.add(w);
          }
        }
        distractors.shuffle(_rng);
        _guessOptions = [_civWord!, _ucWord!, ...distractors.take(2)]
          ..shuffle(_rng);
      } else {
        _winnerSide = UndercoverGame.winner(_roles, _ousted);
        if (_winnerSide != null) _applyWin();
      }
    });
  }

  void _mrWhiteGuess(String word) {
    setState(() {
      if (word == _civWord) {
        _winnerSide = 'mrwhite';
        _mrWhiteCracker = _oustedName;
        _applyWin();
      } else {
        _mrWhiteGuessing = false;
        _winnerSide = UndercoverGame.winner(_roles, _ousted);
        if (_winnerSide != null) _applyWin();
      }
    });
  }

  void _applyWin() {
    final next = UndercoverGame.scoreWin(
      _scores,
      _roles,
      winnerSide: _winnerSide!,
      mrWhiteCracker: _mrWhiteCracker,
    );
    _scores = next;
  }

  void _nextRound() {
    // Words and roles stay the same all game (official rules); only the
    // ousted player leaves, so we go straight to the next vote.
    setState(() {
      _oustedName = null;
      _votes.clear();
      _voteIndex = 0;
    });
  }

  String _roleText(String role) {
    switch (role) {
      case UndercoverGame.undercover:
        return 'أندر كافر 🥷';
      case UndercoverGame.mrWhite:
        return 'مستر وايت 👤';
      default:
        return 'من المدنيين 🧑';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🥷 أندر كافر',
        backgroundColor: FunkyColors.violet,
        showAi: false,
        body: GameIntroWidget(
          title: '🥷 أندر كافر',
          icon: '🥷',
          description:
              'المدنيين معاهم كلمة سر واحدة، الأندر كافر معاه كلمة شبهها، ومستر وايت ممعاهوش حاجة! اوصفوا كلمتكم من غير ما تحرقوها، وصوّتوا تطردوا المتسللين. المدنيين يكسبوا لو طردوهم كلهم.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🥷 أندر كافر',
        minPlayers: 4,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_winnerSide != null) return _buildWin();

    if (_mrWhiteGuessing) return _buildMrWhiteGuess();

    if (_oustedName != null) return _buildOusted();

    return OfflineGameScaffold(
      title: '🥷 أندر كافر',
      backgroundColor: FunkyColors.violet,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _dealIndex < _alive.length
            ? _buildDeal()
            : _voteIndex < _alive.length
                ? _buildVote()
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildDeal() {
    final name = _alive[_dealIndex];
    final role = _roles[name]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'توزيع الأدوار 🤫',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: FunkyDecor.glowCard(FunkyColors.violet, radius: 26),
            child: Center(
              child: _cardRevealed
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (role == UndercoverGame.mrWhite)
                            Text(
                              'مفيش كلمة ليك 😶\nإنت مستر وايت.. اتفرج وخمّن!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                            )
                          else
                            Text(
                              role == UndercoverGame.civilian
                                  ? _civWord!
                                  : _ucWord!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ).animate().scale(duration: 300.ms),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🤫', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FunkyButton(
                            label: 'شوف كلمتك يا $name',
                            accent: FunkyColors.violet,
                            icon: Icons.visibility_rounded,
                            onPressed: () =>
                                setState(() => _cardRevealed = true),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'بس $name اللي يشوف!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FunkyButton(
          label: _cardRevealed
              ? (_dealIndex + 1 < _alive.length ? 'اللاعب اللي بعده' : 'ابدأ الوصف')
              : 'استنى.. متبصش 👀',
          accent: _cardRevealed ? FunkyColors.mint : FunkyColors.coral,
          icon: _cardRevealed ? Icons.arrow_forward_rounded : Icons.block,
          onPressed: _cardRevealed
              ? () {
                  if (_dealIndex + 1 < _alive.length) {
                    setState(() {
                      _dealIndex++;
                      _cardRevealed = false;
                    });
                  } else {
                    _beginVoting();
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildVote() {
    final voter = _alive[_voteIndex];
    final others =
        _alive.where((n) => n != voter).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التصويت ⚖️',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: Colors.white60,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 4),
        Text(
          'يا $voter، مين أكتر واحد مشكوك فيه؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final candidate = others[i];
              return GestureDetector(
                onTap: () => _castVote(candidate),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration:
                      FunkyDecor.glowCard(FunkyColors.coral, radius: 20),
                  child: Text(
                    candidate,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOusted() {
    final role = _roles[_oustedName]!;
    return OfflineGameScaffold(
      title: '🥷 أندر كافر',
      backgroundColor: FunkyColors.coral,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اتصوّت عليه! ⚖️',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 12),
            Text(
              _oustedName!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ).animate().scale(duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'كان ${_roleTextWithRole(role)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            FunkyButton(
              label: 'كمّلوا',
              accent: FunkyColors.amber,
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                if (_winnerSide == null) _nextRound();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _roleTextWithRole(String role) => _roleText(role);

  Widget _buildMrWhiteGuess() {
    return OfflineGameScaffold(
      title: '🥷 أندر كافر',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'مستر وايت انكشف! 👤',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 8),
            Text(
              'لو خمّن كلمة المدنيين يكسب فورًا.. اختار:',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            for (final option in _guessOptions) ...[
              FunkyButton(
                label: option,
                accent: FunkyColors.amber,
                onPressed: () => _mrWhiteGuess(option),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWin() {
    final title = _mrWhiteCracker != null
        ? 'مستر وايت خمّن الكلمة! 👤'
        : _winnerSide == 'civilians'
            ? 'المدنيون كسبوا! 🎉'
            : 'المتسللون كسبوا! 🥷';
    final sorted = _scores.keys.toList()
      ..sort((a, b) => _scores[b]!.compareTo(_scores[a]!));
    return OfflineGameScaffold(
      title: '🥷 أندر كافر',
      backgroundColor: FunkyColors.mint,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 8),
            Text(
              'كلمة المدنيين كانت: $_civWord',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            for (final n in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '$n (${_roleText(_roles[n]!)}): ${_scores[n]}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      fontSize: 16, color: Colors.white70),
                ),
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
