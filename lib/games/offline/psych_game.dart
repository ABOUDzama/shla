import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/psych_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// أقنعهم — exact clone of Psych! / Fibbage adapted for one phone:
/// 1. A trivia question is shown. Every player secretly writes a fake
///    answer (the phone passes around, input private).
/// 2. All answers (the truth + the lies) are shown shuffled; the phone
///    passes again and everyone votes for what they believe is the truth
///    (you can't vote for your own lie).
/// 3. Answers are revealed one by one with their authors.
/// Scoring (Fibbage structure, scaled): finding the truth = 2 points,
/// each player your lie fools = 1 point. The round before last doubles,
/// the final round triples. Most points wins.
class PsychGame extends StatefulWidget {
  const PsychGame({super.key});

  /// Pure scoring for one round. [votes] maps voter name to the answer
  /// index they picked. [answers] are the shuffled answers (author =
  /// player name or 'الصح' for the truth).
  static Map<String, int> scoreRound(
    Map<String, int> scores, {
    required Map<String, int> votes,
    required List<Map<String, String>> answers,
    required int multiplier,
  }) {
    final next = Map<String, int>.from(scores);
    votes.forEach((voter, idx) {
      final author = answers[idx]['author']!;
      if (author == 'الصح') {
        next[voter] = (next[voter] ?? 0) + 2 * multiplier;
      } else {
        next[author] = (next[author] ?? 0) + 1 * multiplier;
      }
    });
    return next;
  }

  @override
  State<PsychGame> createState() => _PsychGameState();
}

enum _Phase { liePass, lieInput, votePass, votePick, reveal, roundEnd }

class _PsychGameState extends State<PsychGame> {
  final Random _rng = Random(23);
  final TextEditingController _lieController = TextEditingController();

  bool _showIntro = true;
  bool _started = false;
  List<Map<String, dynamic>> _players = [];
  final List<int> _questionOrder = [];

  int _round = 1;
  int _rounds = 3;

  // Round state
  _Phase _phase = _Phase.liePass;
  int _passIndex = 0; // whose turn to hold the phone
  final Map<String, String> _lies = {}; // player -> lie
  List<Map<String, String>> _answers = []; // {text, author}
  final Map<String, int> _votes = {}; // voter -> answer index
  int _revealIndex = 0;
  String? _entryError;

  Map<String, String> get _question =>
      psychQuestions[_questionOrder[(_round - 1) % _questionOrder.length]];

  int get _multiplier =>
      _round == _rounds ? 3 : (_round == _rounds - 1 ? 2 : 1);

  String _norm(String s) => s
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .toLowerCase();

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _started = true;
      _questionOrder
        ..clear()
        ..addAll(List.generate(psychQuestions.length, (i) => i))
        ..shuffle(_rng);
      _round = 1;
      _resetRound();
    });
  }

  void _resetRound() {
    _phase = _Phase.liePass;
    _passIndex = 0;
    _lies.clear();
    _votes.clear();
    _answers = [];
    _revealIndex = 0;
    _entryError = null;
    _lieController.clear();
  }

  void _submitLie() {
    final name = _players[_passIndex]['name'] as String;
    final lie = _lieController.text.trim();
    if (lie.isEmpty) {
      setState(() => _entryError = 'اكتب إجابة الأول! ✍️');
      return;
    }
    if (_norm(lie) == _norm(_question['a']!)) {
      setState(() => _entryError = 'دي الإجابة الصح! اكتب كدبة مقنعة 😅');
      return;
    }
    if (_lies.values.any((l) => _norm(l) == _norm(lie))) {
      setState(() => _entryError = 'حد كتب نفس الإجابة.. غيّرها شوية 🔁');
      return;
    }
    AudioService.playClick();
    setState(() {
      _lies[name] = lie;
      _entryError = null;
      _lieController.clear();
      if (_passIndex + 1 < _players.length) {
        _passIndex++;
        _phase = _Phase.liePass;
      } else {
        _buildAnswers();
        _passIndex = 0;
        _phase = _Phase.votePass;
      }
    });
  }

  void _buildAnswers() {
    _answers = [
      {'text': _question['a']!, 'author': 'الصح'},
      ..._lies.entries.map((e) => {'text': e.value, 'author': e.key}),
    ]..shuffle(_rng);
  }

  void _submitVote(int answerIdx) {
    final voter = _players[_passIndex]['name'] as String;
    AudioService.playClick();
    setState(() {
      _votes[voter] = answerIdx;
      if (_passIndex + 1 < _players.length) {
        _passIndex++;
        _phase = _Phase.votePass;
      } else {
        _phase = _Phase.reveal;
        _revealIndex = 0;
        _applyScores();
      }
    });
  }

  void _applyScores() {
    final scores = {
      for (final p in _players) p['name'] as String: p['score'] as int,
    };
    final next = PsychGame.scoreRound(
      scores,
      votes: _votes,
      answers: _answers,
      multiplier: _multiplier,
    );
    for (final p in _players) {
      p['score'] = next[p['name']] ?? p['score'];
    }
  }

  void _nextReveal() {
    AudioService.playClick();
    setState(() {
      if (_revealIndex + 1 < _answers.length) {
        _revealIndex++;
      } else {
        _phase = _Phase.roundEnd;
        AudioService.playSuccess();
      }
    });
  }

  void _nextRound() {
    AudioService.playClick();
    setState(() {
      if (_round < _rounds) {
        _round++;
        _resetRound();
      } else {
        _phase = _Phase.roundEnd; // final scoreboard shown by build
      }
    });
  }

  void _playAgain() {
    AudioService.playClick();
    setState(() {
      _started = false;
      _showIntro = false;
      _players = [];
    });
  }

  @override
  void dispose() {
    _lieController.dispose();
    super.dispose();
  }

  bool get _isFinalScoreboard => _round >= _rounds && _phase == _Phase.roundEnd;

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🤥 أقنعهم',
        backgroundColor: FunkyColors.violet,
        body: GameIntroWidget(
          title: '🤥 أقنعهم',
          icon: '🤥',
          description:
              'سؤال معلومة غريبة، والإجابة الصح موجودة.. بس مخلوطة بإجاباتكم الكدب!\n\n✍️ كل واحد يكتب إجابة مزيفة في سرية (الموبايل بيلف عليكم).\n🗳️ بعدين الكل يصوّت على اللي شايفها الإجابة الصح.\n\n⭐ لو لقيت الصح = نقطتين. لو حد صدّق كدبتك = نقطة عن كل واحد.\nوالجولة الأخيرة نقاطها ×3!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🤥 أقنعهم',
        minPlayers: 3,
        maxPlayers: 8,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    switch (_phase) {
      case _Phase.liePass:
        return _buildPassScreen(
          title: '✍️ مرحلة الكدب',
          message: 'عدّي الموبايل لـ ${_players[_passIndex]['name']}',
          sub: 'هيكتب إجابته المزيفة في سرية.. محدش يبص! 🙈',
          button: 'تمام، أنا ${_players[_passIndex]['name']}',
          onTap: () {
            AudioService.playClick();
            setState(() => _phase = _Phase.lieInput);
          },
        );
      case _Phase.lieInput:
        return _buildLieInput();
      case _Phase.votePass:
        return _buildPassScreen(
          title: '🗳️ مرحلة التصويت',
          message: 'عدّي الموبايل لـ ${_players[_passIndex]['name']}',
          sub: 'هيختار اللي شايفه الإجابة الصح.. في سرية!',
          button: 'تمام، أنا ${_players[_passIndex]['name']}',
          onTap: () {
            AudioService.playClick();
            setState(() => _phase = _Phase.votePick);
          },
        );
      case _Phase.votePick:
        return _buildVotePick();
      case _Phase.reveal:
        return _buildReveal();
      case _Phase.roundEnd:
        return _isFinalScoreboard ? _buildFinal() : _buildRoundEnd();
    }
  }

  Widget _header({required String stage}) {
    final multText = _multiplier > 1 ? '  (×$_multiplier 🔥)' : '';
    return Column(
      children: [
        Text(
          'الجولة $_round من $_rounds$multText',
          style: flatCairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FlatColors.ink.withValues(alpha: 0.65),
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 4),
        Text(
          stage,
          style: flatCairo(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: FlatColors.ink,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlatColors.ink, width: 2),
          ),
          child: Text(
            _question['q']!,
            textAlign: TextAlign.center,
            style: flatCairo(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FlatColors.ink,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  Widget _buildPassScreen({
    required String title,
    required String message,
    required String sub,
    required String button,
    required VoidCallback onTap,
  }) {
    return OfflineGameScaffold(
      title: '🤥 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: flatCairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    const Text('📲', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      message,
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
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onTap,
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
                  button,
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

  Widget _buildLieInput() {
    final name = _players[_passIndex]['name'] as String;
    return OfflineGameScaffold(
      title: '🤥 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(stage: '$name، اكتب كدبتك 🤫'),
              const SizedBox(height: 16),
              TextField(
                controller: _lieController,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: flatCairo(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'إجابة مقنعة تضحك بيها عليهم...',
                  hintStyle: flatCairo(
                    fontSize: 16,
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
                onSubmitted: (_) => _submitLie(),
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
                onPressed: _submitLie,
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
                  'ثبّت الكدبة 😈',
                  style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVotePick() {
    final voter = _players[_passIndex]['name'] as String;
    return OfflineGameScaffold(
      title: '🤔 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(stage: '$voter، إيه الإجابة الصح؟ 🗳️'),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: _answers.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = _answers[i];
                    final isMine = a['author'] == voter;
                    return Opacity(
                      opacity: isMine ? 0.45 : 1,
                      child: ElevatedButton(
                        onPressed: isMine ? null : () => _submitVote(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FlatColors.ink,
                          disabledBackgroundColor: Colors.white,
                          disabledForegroundColor: FlatColors.ink,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(
                              color: FlatColors.ink,
                              width: 2,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isMine ? '${a['text']}  (إجابتك)' : a['text']!,
                          textAlign: TextAlign.center,
                          style: flatCairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final a = _answers[_revealIndex];
    final isTruth = a['author'] == 'الصح';
    final pickedBy = _votes.entries
        .where((e) => e.value == _revealIndex)
        .map((e) => e.key)
        .toList();
    return OfflineGameScaffold(
      title: '🤥 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _header(stage: 'الكشف! 👀'),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child:
                      Container(
                        key: ValueKey(_revealIndex),
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isTruth ? FlatColors.mintDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: FlatColors.ink, width: 3),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a['text']!,
                              textAlign: TextAlign.center,
                              style: flatCairo(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isTruth ? Colors.white : FlatColors.ink,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isTruth
                                  ? '✅ دي الإجابة الصح!'
                                  : '🤥 كدبة من ${a['author']}',
                              textAlign: TextAlign.center,
                              style: flatCairo(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: isTruth
                                    ? Colors.white
                                    : FlatColors.mafia,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            if (pickedBy.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                isTruth
                                    ? 'لقوها: ${pickedBy.join('، ')} ⭐'
                                    : 'اتضحك عليهم: ${pickedBy.join('، ')} 😂',
                                textAlign: TextAlign.center,
                                style: flatCairo(
                                  fontSize: 15,
                                  color: isTruth
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : FlatColors.ink.withValues(alpha: 0.75),
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ],
                        ),
                      ).animate().scale(
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                      ),
                ),
              ),
              ElevatedButton(
                onPressed: _nextReveal,
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
                  _revealIndex + 1 < _answers.length
                      ? 'الإجابة الجاية 👉'
                      : 'النقاط 📊',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundEnd() {
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return OfflineGameScaffold(
      title: '🤥 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'خلصت الجولة $_round! 📊',
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              Expanded(child: _scoreboard(sorted)),
              const SizedBox(height: 16),
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
                  _round + 1 == _rounds
                      ? 'الجولة الأخيرة ×3 🔥'
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

  Widget _buildFinal() {
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final winner = sorted.first;
    return OfflineGameScaffold(
      title: '🤥 أقنعهم',
      backgroundColor: FunkyColors.violet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 72),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              Text(
                '${winner['name']} أكدب واحد فيكم! 😈',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Expanded(child: _scoreboard(sorted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _playAgain,
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

  Widget _scoreboard(List<Map<String, dynamic>> sorted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: sorted.length,
        separatorBuilder: (_, i) => const Divider(height: 8),
        itemBuilder: (context, i) {
          final p = sorted[i];
          return Row(
            children: [
              Text(
                '${i + 1}',
                style: flatCairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p['name'] as String,
                  style: flatCairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: FlatColors.ink,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              Text(
                '${p['score']} ⭐',
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.mintDark,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
