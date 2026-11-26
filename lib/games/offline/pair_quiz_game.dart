import 'dart:math';

import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/pair_quiz_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// مين يعرف مين؟ — clone of the classic "Who Knows Me Best?" party game:
/// each player in turn becomes the SUBJECT. The subject answers a
/// question about himself secretly; everyone else secretly guesses his
/// answer; all answers are revealed together and every matching guess
/// scores 1 point (official scoring of the reference game). After every
/// player was the subject once, the highest score wins — and the app
/// names the strongest duo (the pair with the most matched answers).
class PairQuizGame extends StatefulWidget {
  const PairQuizGame({super.key});

  @override
  State<PairQuizGame> createState() => _PairQuizGameState();
}

enum _PPhase {
  intro,
  players,
  subjectPass,
  subjectAnswer,
  guesserPass,
  guesserPick,
  reveal,
  scoreboard,
  finalResults,
}

class _PairQuizGameState extends State<PairQuizGame> {
  _PPhase _phase = _PPhase.intro;
  final Random _rng = Random();

  List<String> _players = [];
  final Map<int, int> _scores = {};
  final Map<String, int> _pairMatches = {};
  List<int> _subjectOrder = [];
  int _subjectRound = 0;

  List<Map<String, dynamic>> _questions = [];
  int _subjectAnswer = -1;
  final Map<int, int> _guesses = {};
  List<int> _guesserOrder = [];
  int _guesserTurn = 0;

  int get _subject => _subjectOrder[_subjectRound];

  Map<String, dynamic> get _question => _questions[_subjectRound];

  String get _questionText =>
      (_question['q'] as String).replaceAll('{n}', _players[_subject]);

  List<String> get _options => (_question['options'] as List).cast<String>();

  // ---------------------------------------------------------------- flow

  void _start(List<String> names) {
    _players = List<String>.from(names);
    _scores
      ..clear()
      ..addAll({for (var i = 0; i < _players.length; i++) i: 0});
    _pairMatches.clear();
    _subjectOrder = List.generate(_players.length, (i) => i)..shuffle(_rng);
    _questions = List<Map<String, dynamic>>.from(pairQuizQuestions)
      ..shuffle(_rng);
    _subjectRound = 0;
    _setupSubject();
  }

  void _setupSubject() {
    _subjectAnswer = -1;
    _guesses.clear();
    _guesserOrder = [
      for (var i = 0; i < _players.length; i++)
        if (i != _subject) i,
    ];
    _guesserTurn = 0;
    AudioService.playClick();
    setState(() => _phase = _PPhase.subjectPass);
  }

  String _pairKey(int a, int b) => a < b ? '$a|$b' : '$b|$a';

  void _reveal() {
    // 1 point per correct guess; track duo chemistry.
    for (final e in _guesses.entries) {
      if (e.value == _subjectAnswer) {
        _scores[e.key] = (_scores[e.key] ?? 0) + 1;
        final k = _pairKey(e.key, _subject);
        _pairMatches[k] = (_pairMatches[k] ?? 0) + 1;
      }
    }
    AudioService.playSuccess();
    setState(() => _phase = _PPhase.reveal);
  }

  void _nextSubject() {
    if (_subjectRound < _players.length - 1) {
      _subjectRound++;
      _setupSubject();
    } else {
      AudioService.playWinVoice();
      setState(() => _phase = _PPhase.finalResults);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _PPhase.intro:
        return OfflineGameScaffold(
          title: '🤝 مين يعرف مين؟',
          backgroundColor: FunkyColors.amber,
          body: GameIntroWidget(
            title: 'مين يعرف مين؟ 🤝',
            icon: '🤝',
            description:
                'لعبة "من يعرفني أكثر؟" الأصلية!\n\n'
                '🎯 كل واحد فيكم هياخد دوره ويبقى "المحور".\n'
                '🤫 المحور يجاوب سؤال عن نفسه في سرية..\n'
                '💭 والباقي يخمّنوا إجابته في سرية برضه!\n'
                '✅ كل تخمينة صح = نقطة.\n\n'
                'في الآخر هنعرف مين اللي عارف الشلة أكتر.. وأقرب ثنائي لبعض!',
            onStart: () {
              AudioService.playClick();
              setState(() => _phase = _PPhase.players);
            },
          ),
        );
      case _PPhase.players:
        return GlobalPlayerSelectionScreen(
          gameTitle: '🤝 مين يعرف مين؟',
          minPlayers: 3,
          maxPlayers: 8,
          onStartGame: (ctx, selected) => _start(selected),
        );
      case _PPhase.subjectPass:
        return _buildSubjectPass();
      case _PPhase.subjectAnswer:
        return _buildSubjectAnswer();
      case _PPhase.guesserPass:
        return _buildGuesserPass();
      case _PPhase.guesserPick:
        return _buildGuesserPick();
      case _PPhase.reveal:
        return _buildReveal();
      case _PPhase.scoreboard:
        return _buildScoreboard();
      case _PPhase.finalResults:
        return _buildFinal();
    }
  }

  Widget _scaffold(Widget body) => OfflineGameScaffold(
    title: '🤝 مين يعرف مين؟',
    backgroundColor: FunkyColors.amber,
    body: body,
  );

  Widget _buildSubjectPass() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'الجولة ${_subjectRound + 1} من ${_players.length}',
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                'عدّي الموبايل لـ\n${_players[_subject]} 🎯',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'انت المحور الجولة دي!',
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا ${_players[_subject]} 👀', () {
                AudioService.playClick();
                setState(() => _phase = _PPhase.subjectAnswer);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectAnswer() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'يا ${_players[_subject]}..\nجاوب بصراحة وفي سرية 🤫',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            _questionCard(),
            const SizedBox(height: 12),
            Expanded(
              child: _optionsList((i) {
                _subjectAnswer = i;
                AudioService.playClick();
                setState(() => _phase = _PPhase.guesserPass);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuesserPass() {
    final g = _guesserOrder[_guesserTurn];
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'عدّي الموبايل لـ\n${_players[g]} 💭',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا ${_players[g]} 🤫', () {
                AudioService.playClick();
                setState(() => _phase = _PPhase.guesserPick);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuesserPick() {
    final g = _guesserOrder[_guesserTurn];
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'يا ${_players[g]}..\nإجابة ${_players[_subject]} كانت إيه؟ 🤔',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            _questionCard(),
            const SizedBox(height: 12),
            Expanded(
              child: _optionsList((i) {
                _guesses[g] = i;
                AudioService.playClick();
                if (_guesserTurn < _guesserOrder.length - 1) {
                  _guesserTurn++;
                  setState(() => _phase = _PPhase.guesserPass);
                } else {
                  _reveal();
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReveal() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _questionCard(),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlatColors.mintDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FlatColors.ink, width: 2.5),
              ),
              child: Text(
                'إجابة ${_players[_subject]}:\n${_options[_subjectAnswer]} ✅',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final g in _guesserOrder)
                    _resultRow(
                      _players[g],
                      _options[_guesses[g]!],
                      _guesses[g] == _subjectAnswer,
                    ),
                ],
              ),
            ),
            _bigButton(
              _subjectRound < _players.length - 1
                  ? 'المحور اللي بعده ⏭️'
                  : 'النتيجة النهائية! 🏆',
              () {
                AudioService.playClick();
                if (_subjectRound < _players.length - 1) {
                  setState(() => _phase = _PPhase.scoreboard);
                } else {
                  _nextSubject();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboard() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'النقط لحد دلوقتي 📊',
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              _scoreBoard(),
              const SizedBox(height: 24),
              _bigButton('يلا نكمل! 🎯', () {
                AudioService.playClick();
                _nextSubject();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinal() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first;
    final tie = sorted.length > 1 && sorted[1].value == winner.value;

    String duoText = '';
    if (_pairMatches.isNotEmpty) {
      final best = _pairMatches.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final parts = best.first.key.split('|').map(int.parse).toList();
      duoText =
          '❤ أقرب ثنائي: ${_players[parts[0]]} و ${_players[parts[1]]} (${best.first.value} تطابق)';
    }

    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tie
                    ? '🤝 تعادل في القمة!'
                    : '🏆 ${_players[winner.key]} عارف الشلة أكتر واحد!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              if (duoText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  duoText,
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FlatColors.mintDark,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 14),
              _scoreBoard(),
              const SizedBox(height: 24),
              _bigButton('العبوا تاني 🔄', () {
                AudioService.playClick();
                setState(() => _phase = _PPhase.intro);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _questionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlatColors.ink, width: 2.5),
      ),
      child: Text(
        _questionText,
        textAlign: TextAlign.center,
        style: flatCairo(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: FlatColors.ink,
          height: 1.5,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _optionsList(void Function(int) onPick) {
    return ListView(
      children: [
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _bigButton(
              _options[i],
              () => onPick(i),
              color: Colors.white,
              textColor: FlatColors.ink,
            ),
          ),
      ],
    );
  }

  Widget _resultRow(String name, String answer, bool correct) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: correct
            ? FunkyColors.mint.withValues(alpha: 0.25)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: correct ? FlatColors.mintDark : FlatColors.border,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            correct ? '+1 ✅' : '❌',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: FlatColors.ink,
            ),
          ),
          Expanded(
            child: Text(
              '$name: $answer',
              textAlign: TextAlign.right,
              style: flatCairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBoard() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Column(
        children: [
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${e.value} ⭐',
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                  Text(
                    _players[e.key],
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bigButton(
    String label,
    VoidCallback onTap, {
    Color? color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? FlatColors.mintDark,
          foregroundColor: textColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: color == Colors.white
                ? const BorderSide(color: FlatColors.ink, width: 2)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: flatCairo(fontSize: 17, fontWeight: FontWeight.w900),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
