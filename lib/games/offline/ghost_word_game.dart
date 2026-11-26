import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/heads_up_data.dart';
import '../../data/justone_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// كلمة عالحبل — clone of the classic word game Ghost:
/// players take turns adding ONE letter to a shared fragment that must
/// stay the beginning of a real word. Whoever completes a word (3+
/// letters) loses the round. Instead of adding a letter you may CHALLENGE
/// the previous player: they must name a real word starting with the
/// fragment — if they can, the challenger loses; if not, they lose.
/// Round losers collect the letters of "الشبح" one by one; completing the
/// word eliminates you. Last player standing wins.
class GhostWordGame extends StatefulWidget {
  const GhostWordGame({super.key});

  static const List<String> letters = [
    'ا',
    'أ',
    'إ',
    'آ',
    'ب',
    'ت',
    'ث',
    'ج',
    'ح',
    'خ',
    'د',
    'ذ',
    'ر',
    'ز',
    'س',
    'ش',
    'ص',
    'ض',
    'ط',
    'ظ',
    'ع',
    'غ',
    'ف',
    'ق',
    'ك',
    'ل',
    'م',
    'ن',
    'ه',
    'و',
    'ؤ',
    'ي',
    'ئ',
    'ى',
    'ة',
  ];

  static const List<String> ghostLetters = ['ا', 'ل', 'ش', 'ب', 'ح'];

  /// Common words for auto-detection of a completed word (group may still
  /// flag words outside this list, as in the spoken game).
  static Set<String> knownWords() {
    final all = <String>{...justOneWords};
    for (final cat in headsUpCategories) {
      for (final w in (cat['words'] as List)) {
        all.add(w.toString());
      }
    }
    return all;
  }

  static String norm(String s) {
    var t = s.trim().toLowerCase();
    t = t.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    t = t.replaceAll('ة', 'ه').replaceAll('ى', 'ي');
    t = t.replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    return t;
  }

  static bool isCompleteWord(String fragment, Set<String> words) {
    if (fragment.length < 3) return false;
    final n = norm(fragment);
    return words.any((w) => norm(w) == n);
  }

  static bool startsWithFragment(String word, String fragment) {
    final w = norm(word);
    final f = norm(fragment);
    return w.length >= 3 && w.startsWith(f) && w != f;
  }

  @override
  State<GhostWordGame> createState() => _GhostWordGameState();
}

enum _GPhase { play, challengeAnswer, challengeVote, roundEnd, gameOver }

class _GhostWordGameState extends State<GhostWordGame> {
  final TextEditingController _wordController = TextEditingController();

  bool _showIntro = true;
  bool _started = false;

  List<Map<String, dynamic>> _players = []; // {name, letters:int, out}
  int _starter = 0;
  int _current = 0;
  String _fragment = '';
  int _lastLetterPlayer = -1;
  _GPhase _phase = _GPhase.play;
  int? _roundLoser;
  String? _loserReason;
  String? _entryError;

  final Set<String> _words = GhostWordGame.knownWords();

  List<Map<String, dynamic>> get _alive =>
      _players.where((p) => p['out'] != true).toList();

  void _start(List<String> names) {
    setState(() {
      _players = names
          .map((n) => {'name': n, 'letters': 0, 'out': false})
          .toList();
      _starter = 0;
      _started = true;
      _newRound();
    });
  }

  void _newRound() {
    _fragment = '';
    _roundLoser = null;
    _loserReason = null;
    _entryError = null;
    _wordController.clear();
    _current = _starter;
    while (_players[_current]['out'] == true) {
      _current = (_current + 1) % _players.length;
    }
    _lastLetterPlayer = _current;
    _phase = _GPhase.play;
  }

  void _addLetter(String letter) {
    AudioService.playClick();
    setState(() {
      _lastLetterPlayer = _current;
      _fragment += letter;
      if (GhostWordGame.isCompleteWord(_fragment, _words)) {
        _roundLoser = _current;
        _loserReason = 'كمّل كلمة "$_fragment" 📕';
        _endRound();
      } else {
        _nextAlive();
      }
    });
  }

  void _nextAlive() {
    do {
      _current = (_current + 1) % _players.length;
    } while (_players[_current]['out'] == true);
  }

  void _claimCompleteWord() {
    // Group flags that the fragment is already a word (outside the list).
    setState(() {
      _roundLoser = _lastLetterPlayer;
      _loserReason = '"$_fragment" كلمة كاملة! 📕';
      _endRound();
    });
  }

  void _openChallenge() {
    AudioService.playClick();
    setState(() => _phase = _GPhase.challengeAnswer);
  }

  void _submitChallengeWord() {
    final word = _wordController.text.trim();
    if (!GhostWordGame.startsWithFragment(word, _fragment)) {
      setState(
        () => _entryError = 'لازم كلمة تبدأ بـ"$_fragment" ومابتكونش هي نفسها!',
      );
      return;
    }
    setState(() {
      _entryError = null;
      _phase = _GPhase.challengeVote;
    });
  }

  void _challengeVote({required bool realWord}) {
    // Challenger = current; challenged = _lastLetterPlayer.
    setState(() {
      if (realWord) {
        _roundLoser = _current;
        _loserReason = 'تحدّى وغلط.. الكلمة موجودة فعلًا 😅';
      } else {
        _roundLoser = _lastLetterPlayer;
        _loserReason = 'كان بيهيّص! مفيش كلمة كده 🏴';
      }
      _endRound();
    });
  }

  void _endRound() {
    final p = _players[_roundLoser!];
    p['letters'] = (p['letters'] as int) + 1;
    if ((p['letters'] as int) >= GhostWordGame.ghostLetters.length) {
      p['out'] = true;
    }
    _phase = _GPhase.roundEnd;
    AudioService.playFailure();
  }

  void _nextRound() {
    AudioService.playClick();
    setState(() {
      if (_alive.length <= 1) {
        _phase = _GPhase.gameOver;
        AudioService.playWinVoice();
        return;
      }
      do {
        _starter = (_starter + 1) % _players.length;
      } while (_players[_starter]['out'] == true);
      _newRound();
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '👻 كلمة عالحبل',
        backgroundColor: FunkyColors.violet,
        body: GameIntroWidget(
          title: '👻 كلمة عالحبل',
          icon: '👻',
          description:
              'لعبة الحروف الشهيرة!\n\n🔤 كل واحد يضيف حرف واحد على الكلمة اللي بتتكون.. بس خليها دايمًا بداية كلمة حقيقية!\n\n📕 اللي يكمّل كلمة (3 حروف أو أكتر) يخسر الجولة.\n🚩 شاكك إن اللي قبلك بيهيّص؟ تحدّاه! لو ماعندوش كلمة يخسر، ولو عنده إنت اللي تخسر.\n\n👻 الخسران بيجمع حروف "الشبح".. اللي يكملها يطير، وآخر واحد واقف يكسب!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '👻 كلمة عالحبل',
        minPlayers: 2,
        maxPlayers: 8,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    switch (_phase) {
      case _GPhase.play:
        return _buildPlay();
      case _GPhase.challengeAnswer:
        return _buildChallengeAnswer();
      case _GPhase.challengeVote:
        return _buildChallengeVote();
      case _GPhase.roundEnd:
        return _buildRoundEnd();
      case _GPhase.gameOver:
        return _buildGameOver();
    }
  }

  Widget _ghostRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _players.map((p) {
        final n = p['letters'] as int;
        final out = p['out'] == true;
        final active = _players.indexOf(p) == _current;
        final collected = GhostWordGame.ghostLetters.take(n).join();
        return Opacity(
          opacity: out ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? FlatColors.mintDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlatColors.ink, width: 2),
            ),
            child: Text(
              '${p['name']} ${collected.isEmpty ? '·' : collected}${out ? ' 💀' : ''}',
              style: flatCairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlay() {
    final name = _players[_current]['name'] as String;
    return OfflineGameScaffold(
      title: '👻 كلمة عالحبل',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ghostRow(),
              const SizedBox(height: 10),
              Text(
                'دور $name',
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Text(
                  _fragment.isEmpty ? '...' : _fragment,
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.mintDark,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _fragment.length >= 3
                          ? _claimCompleteWord
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlatColors.mafia,
                        side: const BorderSide(
                          color: FlatColors.mafia,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'دي كلمة! 📕',
                        style: flatCairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _fragment.isNotEmpty ? _openChallenge : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlatColors.detective,
                        side: const BorderSide(
                          color: FlatColors.detective,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'تحدي 🚩',
                        style: flatCairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: GridView.count(
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.1,
                    children: GhostWordGame.letters.map((l) {
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _addLetter(l),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FlatColors.ink,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                l,
                                style: flatCairo(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: FlatColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeAnswer() {
    final challenged = _players[_lastLetterPlayer]['name'] as String;
    return OfflineGameScaffold(
      title: '👻 كلمة عالحبل',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🚩 تحدي!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Text(
                  '$challenged، قول كلمة حقيقية تبدأ بـ"$_fragment" وإلا بتخسر!',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.ink,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _wordController,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'الكلمة...',
                  hintStyle: flatCairo(
                    fontSize: 18,
                    color: FlatColors.ink.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: FlatColors.ink,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: FlatColors.ink,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submitChallengeWord(),
              ),
              if (_entryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _entryError!,
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mafia,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitChallengeWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'دي كلمتي! 💪',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeVote() {
    final word = _wordController.text.trim();
    final challenged = _players[_lastLetterPlayer]['name'] as String;
    return OfflineGameScaffold(
      title: '👻 كلمة عالحبل',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      '$challenged قال: "$word"',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يا شلة: دي كلمة حقيقية؟',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 16,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _challengeVote(realWord: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mafia,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'مش كلمة ❌',
                        style: flatCairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _challengeVote(realWord: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mintDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'كلمة حقيقية ✅',
                        style: flatCairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundEnd() {
    final p = _players[_roundLoser!];
    final collected = GhostWordGame.ghostLetters
        .take(p['letters'] as int)
        .join();
    final out = p['out'] == true;
    return OfflineGameScaffold(
      title: '👻 كلمة عالحبل',
      backgroundColor: FunkyColors.violet,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      out ? '💀' : '👻',
                      style: const TextStyle(fontSize: 56),
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${p['name']} خسر الجولة!',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loserReason ?? '',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 16,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      out ? 'جمع "الشبح" كاملة وطار! 💀' : 'جمع: $collected',
                      style: flatCairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: out ? FlatColors.mafia : FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _nextRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _alive.length <= 1
                      ? 'النتيجة النهائية 🏆'
                      : 'الجولة الجاية ⏭️',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final winner = _alive.isNotEmpty ? _alive.first : null;
    return OfflineGameScaffold(
      title: '👻 كلمة عالحبل',
      backgroundColor: FunkyColors.violet,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 72),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 10),
              Text(
                winner != null
                    ? '${winner['name']} نجا من الشبح!'
                    : 'الشبح كسبكم كلكم! 👻',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  setState(() {
                    _started = false;
                    _players = [];
                  });
                },
                icon: const Icon(Icons.replay),
                label: Text(
                  'العبوا تاني!',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
