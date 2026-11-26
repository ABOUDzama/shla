import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/justone_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// كلمة واحدة — exact clone of Just One (Spiel des Jahres 2019), adapted
/// for one phone:
/// - Cooperative: 13 mystery words per game, the group scores together.
/// - The guesser looks away; everyone else secretly writes a ONE-WORD clue
///   (3 players: two clues each, official variant).
/// - Identical clues (and clues from the same word family / the word
///   itself) are CANCELLED before the guesser sees them.
/// - The guesser sees the remaining clues and gets ONE guess:
///   correct = card won; wrong = this card AND the next one lost;
///   skip = only this card lost.
/// - Final score rated by the official table (13 perfect ... 0-3 try again).
class JustOneGame extends StatefulWidget {
  const JustOneGame({super.key});

  /// Normalizes Arabic for clue comparison (official rule: spelling
  /// variants, plurals and family variants count as identical).
  static String norm(String s) {
    var t = s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    t = t.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    t = t.replaceAll('ة', 'ه').replaceAll('ى', 'ي');
    t = t.replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    t = t.replaceAll(RegExp(r'[^ء-غف-ي٠-٩a-z0-9 ]'), '');
    // Light stemming: drop common suffixes so plurals/feminine cancel.
    if (t.endsWith('ات') && t.length > 3) t = t.substring(0, t.length - 2);
    if (t.endsWith('ين') && t.length > 3) t = t.substring(0, t.length - 2);
    if (t.endsWith('ون') && t.length > 3) t = t.substring(0, t.length - 2);
    if (t.endsWith('ه') && t.length > 3) t = t.substring(0, t.length - 1);
    return t;
  }

  /// True when a clue is invalid or identical to another clue / the word.
  static bool clashes(String clue, String mystery, List<String> others) {
    final c = norm(clue);
    final m = norm(mystery);
    if (c.isEmpty) return true;
    if (c == m ||
        (c.length > 2 && m.contains(c)) ||
        (m.length > 2 && c.contains(m))) {
      return true;
    }
    return others.any((o) => norm(o) == c);
  }

  /// Official rating message for the score table.
  static String rating(int won) {
    if (won >= 13) return 'نتيجة مثالية! تقدروا تكرروها؟ 🏆';
    if (won == 12) return 'خرافيين! أصحابكم أكيد مبسوطين 🤩';
    if (won == 11) return 'نتيجة تتعملها احتفالية! 🎉';
    if (won >= 9) return 'واو، مش وحش خالص! 💪';
    if (won >= 7) return 'في المتوسط.. تقدروا أحسن! 🙂';
    if (won >= 4) return 'بداية كويسة، جربوا تاني! 🌱';
    return 'جربوا تاني.. وتاني! 😅';
  }

  @override
  State<JustOneGame> createState() => _JustOneGameState();
}

enum _JPhase { reveal, cluePass, clueInput, compare, guess, turnEnd }

class _JustOneGameState extends State<JustOneGame> {
  final Random _rng = Random(31);
  final TextEditingController _clueController = TextEditingController();
  final TextEditingController _guessController = TextEditingController();

  bool _showIntro = true;
  bool _started = false;
  bool _gameOver = false;

  List<String> _players = [];
  List<String> _deck = [];
  int _guesserIndex = 0;
  int _won = 0;
  final Map<String, int> _personalWins = {};

  // Turn state
  _JPhase _phase = _JPhase.reveal;
  String? _mystery;
  int _cluePassIndex = 0; // index into clue-givers list
  int _clueSlot = 0; // for the 3-player two-clue variant
  final List<Map<String, String>> _clues = []; // {by, text}
  List<Map<String, String>> _kept = [];
  List<Map<String, String>> _cancelled = [];
  String? _entryError;
  String? _lastResult; // 'correct' | 'wrong' | 'skip'

  int get _cluesPerWriter => _players.length == 3 ? 2 : 1;

  List<String> get _clueGivers => [
    for (var i = 0; i < _players.length; i++)
      if (i != _guesserIndex) _players[i],
  ];

  void _start(List<String> names) {
    setState(() {
      _players = names;
      _started = true;
      _deck = List.of(justOneWords)..shuffle(_rng);
      _deck = _deck.take(13).toList();
      _guesserIndex = 0;
      _won = 0;
      _personalWins.clear();
      _gameOver = false;
      _resetTurn();
    });
  }

  void _resetTurn() {
    _phase = _JPhase.reveal;
    _mystery = _deck.isNotEmpty ? _deck.first : null;
    _cluePassIndex = 0;
    _clueSlot = 0;
    _clues.clear();
    _kept = [];
    _cancelled = [];
    _entryError = null;
    _lastResult = null;
    _clueController.clear();
    _guessController.clear();
  }

  void _submitClue() {
    final clue = _clueController.text.trim();
    if (clue.isEmpty) {
      setState(() => _entryError = 'اكتب التلميح الأول! ✍️');
      return;
    }
    if (clue.contains(' ')) {
      setState(() => _entryError = 'كلمة واحدة بس! 1️⃣');
      return;
    }
    final currentTexts = _clues.map((c) => c['text']!).toList();
    if (JustOneGame.clashes(clue, _mystery!, currentTexts)) {
      // Allowed to submit; it will be cancelled in comparison (official).
    }
    AudioService.playClick();
    setState(() {
      _clues.add({'by': _clueGivers[_cluePassIndex], 'text': clue});
      _entryError = null;
      _clueController.clear();
      _clueSlot++;
      if (_clueSlot >= _cluesPerWriter) {
        _clueSlot = 0;
        _cluePassIndex++;
      }
      if (_cluePassIndex >= _clueGivers.length) {
        _compareClues();
      } else {
        _phase = _JPhase.cluePass;
      }
    });
  }

  void _compareClues() {
    final kept = <Map<String, String>>[];
    final cancelled = <Map<String, String>>[];
    final keptTexts = <String>[];
    for (final c in _clues) {
      final bad = JustOneGame.clashes(c['text']!, _mystery!, keptTexts);
      if (bad) {
        cancelled.add(c);
      } else {
        kept.add(c);
        keptTexts.add(c['text']!);
      }
    }
    // Official: identical pairs BOTH cancel, not just the second one.
    final counts = <String, int>{};
    for (final c in _clues) {
      final n = JustOneGame.norm(c['text']!);
      counts[n] = (counts[n] ?? 0) + 1;
    }
    final finalKept = <Map<String, String>>[];
    final finalCancelled = <Map<String, String>>[...cancelled];
    for (final c in kept) {
      if ((counts[JustOneGame.norm(c['text']!)] ?? 0) > 1) {
        finalCancelled.add(c);
      } else {
        finalKept.add(c);
      }
    }
    _kept = finalKept;
    _cancelled = finalCancelled;
    _phase = _JPhase.compare;
  }

  void _answer({required bool skipped}) {
    final guess = _guessController.text.trim();
    if (!skipped && guess.isEmpty) {
      setState(() => _entryError = 'اكتب تخمينك أو اضغط تخطي');
      return;
    }
    final correct =
        !skipped && JustOneGame.norm(guess) == JustOneGame.norm(_mystery!);
    setState(() {
      if (correct) {
        _won++;
        _personalWins[_players[_guesserIndex]] =
            (_personalWins[_players[_guesserIndex]] ?? 0) + 1;
        _lastResult = 'correct';
        _deck.removeAt(0);
        AudioService.playSuccess();
      } else if (skipped) {
        _lastResult = 'skip';
        _deck.removeAt(0);
        AudioService.playClick();
      } else {
        // Wrong: lose this card AND the next one (official).
        _lastResult = 'wrong';
        _deck.removeAt(0);
        if (_deck.isNotEmpty) _deck.removeAt(0);
        AudioService.playFailure();
      }
      _phase = _JPhase.turnEnd;
    });
  }

  void _nextTurn() {
    AudioService.playClick();
    setState(() {
      if (_deck.isEmpty) {
        _gameOver = true;
        AudioService.playWinVoice();
        return;
      }
      _guesserIndex = (_guesserIndex + 1) % _players.length;
      _resetTurn();
    });
  }

  @override
  void dispose() {
    _clueController.dispose();
    _guessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '1️⃣ كلمة واحدة',
        backgroundColor: FunkyColors.amber,
        body: GameIntroWidget(
          title: '1️⃣ كلمة واحدة',
          icon: '1️⃣',
          description:
              'لعبة تعاونية: كلكم فريق واحد ضد 13 كلمة سرية!\n\n🙈 واحد يغمّض، والباقي يشوفوا الكلمة ويكتبوا تلميح من كلمة واحدة بس.. في سرية!\n⚠️ أي تلميحين متشابهين بيتلغوا الاتنين!\n👀 المغمّض يفتح، يشوف التلميحات الباقية، وعنده تخمين واحد بس.\n\n✅ صح = كارت كسبتوه. ❌ غلط = الكارت واللي بعده ضاعوا. تخطي = الكارت بس.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '1️⃣ كلمة واحدة',
        minPlayers: 3,
        maxPlayers: 7,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    if (_gameOver) return _buildGameOver();

    switch (_phase) {
      case _JPhase.reveal:
        return _buildReveal();
      case _JPhase.cluePass:
        return _buildCluePass();
      case _JPhase.clueInput:
        return _buildClueInput();
      case _JPhase.compare:
        return _buildCompare();
      case _JPhase.guess:
        return _buildGuess();
      case _JPhase.turnEnd:
        return _buildTurnEnd();
    }
  }

  String get _guesser => _players[_guesserIndex];

  Widget _progressHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'فاض ${_deck.length} كارت',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FlatColors.ink.withValues(alpha: 0.65),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 16),
          Text(
            'كسبتوا $_won ⭐',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FlatColors.mintDark,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildReveal() {
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _progressHeader(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    const Text('🙈', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      '$_guesser يغمّض!',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الباقي بس هم اللي يشوفوا الكلمة السرية',
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: FlatColors.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: FlatColors.ink, width: 3),
                      ),
                      title: Text(
                        'الكلمة السرية 🤫',
                        textAlign: TextAlign.center,
                        style: flatCairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      content: Text(
                        _mystery!,
                        textAlign: TextAlign.center,
                        style: flatCairo(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.mintDark,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            setState(() => _phase = _JPhase.cluePass);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlatColors.mintDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'شفناها، يلا نكتب التلميحات',
                            style: flatCairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'إظهار الكلمة للكل (ما عدا $_guesser)',
                  textAlign: TextAlign.center,
                  style: flatCairo(fontSize: 18, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCluePass() {
    final name = _clueGivers[_cluePassIndex];
    final slotText = _cluesPerWriter == 2
        ? ' (تلميح رقم ${_clueSlot + 1} من 2)'
        : '';
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _progressHeader(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    const Text('📲', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      'عدّي الموبايل لـ $name',
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
                      'هيكتب تلميحه$slotText في سرية',
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
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  setState(() => _phase = _JPhase.clueInput);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'تمام، أنا $name',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClueInput() {
    final name = _clueGivers[_cluePassIndex];
    final slotText = _cluesPerWriter == 2 ? ' (${_clueSlot + 1}/2)' : '';
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _progressHeader(),
              Text(
                '$name، اكتب تلميحك$slotText 🤫',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FlatColors.ink, width: 2),
                ),
                child: Text(
                  'الكلمة السرية: $_mystery',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mintDark,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كلمة واحدة بس.. وخليه أصلي عشان لو حد كتب زيك هيتلغوا!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 14,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _clueController,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'التلميح...',
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
                onSubmitted: (_) => _submitClue(),
              ),
              if (_entryError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _entryError!,
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mafia,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _submitClue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'ثبّت التلميح 🔒',
                  style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompare() {
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _progressHeader(),
              Text(
                'المقارنة! ⚖️',
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                '$_guesser لسه مغمّض.. دي التلميحات بعد الإلغاء',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 14,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    ..._kept.map((c) => _clueTile(c, cancelled: false)),
                    ..._cancelled.map((c) => _clueTile(c, cancelled: true)),
                    if (_kept.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: FlatColors.mafia, width: 2),
                        ),
                        child: Text(
                          'كل التلميحات اتلغت! 😱 الكارت ضاع',
                          textAlign: TextAlign.center,
                          style: flatCairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: FlatColors.mafia,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  if (_kept.isEmpty) {
                    // Official: all cancelled = card back in the box.
                    setState(() {
                      _lastResult = 'skip';
                      _deck.removeAt(0);
                      _phase = _JPhase.turnEnd;
                    });
                  } else {
                    setState(() => _phase = _JPhase.guess);
                  }
                },
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
                  _kept.isEmpty
                      ? 'يا خسارة.. اللي بعده ⏭️'
                      : 'عدّي الموبايل لـ $_guesser 👀',
                  style: flatCairo(fontSize: 19, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clueTile(Map<String, String> c, {required bool cancelled}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cancelled
            ? FlatColors.mafia.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cancelled ? FlatColors.mafia : FlatColors.ink,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? Icons.cancel : Icons.check_circle,
            size: 20,
            color: cancelled ? FlatColors.mafia : FlatColors.mintDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c['text']!,
              style: flatCairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                decoration: cancelled ? TextDecoration.lineThrough : null,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Text(
            c['by']!,
            style: flatCairo(
              fontSize: 13,
              color: FlatColors.ink.withValues(alpha: 0.6),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildGuess() {
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _progressHeader(),
              Text(
                '$_guesser، عينك على التلميحات! 👀',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _kept
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FlatColors.ink, width: 2),
                        ),
                        child: Text(
                          c['text']!,
                          style: flatCairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: FlatColors.ink,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _guessController,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'تخمينك الوحيد...',
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
                onSubmitted: (_) => _answer(skipped: false),
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
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _answer(skipped: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlatColors.ink,
                        side: const BorderSide(color: FlatColors.ink, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'تخطي ⏭️',
                        style: flatCairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _answer(skipped: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mintDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'خمّن! 🎯',
                        style: flatCairo(
                          fontSize: 20,
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

  Widget _buildTurnEnd() {
    final (emoji, title, sub) = switch (_lastResult) {
      'correct' => ('🎉', 'صح!', 'كارت في الجيب.. كملوا!'),
      'wrong' => ('💔', 'غلط.. كانت "$_mystery"', 'الكارت ده واللي بعده راحوا'),
      _ => ('⏭️', 'اتخطّت.. كانت "$_mystery"', 'الكارت ده بس اللي راح'),
    };
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _progressHeader(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 64))
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _lastResult == 'correct'
                            ? FlatColors.mintDark
                            : FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
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
              ElevatedButton(
                onPressed: _nextTurn,
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
                  _deck.isEmpty ? 'النتيجة النهائية 🏁' : 'الدور الجاي ⏭️',
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
    return OfflineGameScaffold(
      title: '1️⃣ كلمة واحدة',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '$_won / 13',
                style: flatCairo(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.mintDark,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              Text(
                JustOneGame.rating(_won),
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        'تخمين كل واحد:',
                        style: flatCairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.ink,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      ..._players.map((p) {
                        final w = _personalWins[p] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p,
                                  style: flatCairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: FlatColors.ink,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                              Text(
                                '$w صح ⭐',
                                style: flatCairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: FlatColors.mintDark,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  setState(() {
                    _started = false;
                    _gameOver = false;
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
