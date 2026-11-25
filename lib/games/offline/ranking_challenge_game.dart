import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../data/ranking_challenge_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// تحدي الترتيب: a secret ranking appears shuffled, every player arranges it
/// privately, then scores are given by closeness to the correct order.
class RankingChallengeGame extends StatefulWidget {
  const RankingChallengeGame({super.key});

  /// Shared scoring (used by the online variant too):
  /// 3 pts exact position, 1 pt off-by-one. Deterministic for all clients.
  static int scoreGuess(List<String> guess, List<String> truth) {
    int score = 0;
    for (int i = 0; i < guess.length && i < truth.length; i++) {
      final trueIdx = truth.indexOf(guess[i]);
      if (trueIdx == -1) continue; // unknown item: no points
      if (trueIdx == i) {
        score += 3;
      } else if ((trueIdx - i).abs() == 1) {
        score += 1;
      }
    }
    return score;
  }

  @override
  State<RankingChallengeGame> createState() => _RankingChallengeGameState();
}

enum _Phase { setup, passDevice, guessing, roundResults, gameOver }

class _RankingChallengeGameState extends State<RankingChallengeGame> {
  _Phase _phase = _Phase.setup;
  final List<String> _players = [];
  final TextEditingController _nameCtrl = TextEditingController();
  int _totalRounds = 3;
  int _round = 0;

  late Map<String, dynamic> _deck;
  late List<String> _shuffled;
  late List<String> _currentGuess;
  int _currentPlayer = 0;
  final Map<String, List<String>> _guesses = {};
  final Map<String, int> _totalScores = {};
  final List<int> _usedDecks = [];
  final Random _rng = Random();

  List<String> get _truth => List<String>.from(_deck['items']);

  void _addPlayer() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _players.contains(name) || _players.length >= 8) return;
    setState(() {
      _players.add(name);
      _totalScores[name] = 0;
      _nameCtrl.clear();
    });
    AudioService.playClick();
  }

  void _startGame() {
    setState(() {
      _round = 1;
      _guesses.clear();
      for (final p in _players) _totalScores[p] = 0;
      _pickDeck();
      _currentPlayer = 0;
      _phase = _Phase.passDevice;
    });
    AudioService.playSuccess();
  }

  void _pickDeck() {
    int idx;
    do {
      idx = _rng.nextInt(rankingChallengeDecks.length);
    } while (_usedDecks.contains(idx) && _usedDecks.length < rankingChallengeDecks.length);
    _usedDecks.add(idx);
    _deck = rankingChallengeDecks[idx];
    _shuffled = List<String>.from(_deck['items'])..shuffle(_rng);
    // Avoid accidentally showing the correct order.
    while (_isSameOrder(_shuffled, _truth)) {
      _shuffled.shuffle(_rng);
    }
    _currentGuess = List<String>.from(_shuffled);
  }

  bool _isSameOrder(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _confirmGuess() {
    _guesses[_players[_currentPlayer]] = List<String>.from(_currentGuess);
    AudioService.playClick();
    if (_currentPlayer < _players.length - 1) {
      setState(() {
        _currentPlayer++;
        _currentGuess = List<String>.from(_shuffled);
        _phase = _Phase.passDevice;
      });
    } else {
      for (final p in _players) {
        _totalScores[p] = (_totalScores[p] ?? 0) + RankingChallengeGame.scoreGuess(_guesses[p]!, _truth);
      }
      AudioService.playSuccess();
      HapticService.success();
      setState(() => _phase = _Phase.roundResults);
    }
  }

  void _nextRound() {
    if (_round >= _totalRounds) {
      AudioService.playWinVoice();
      setState(() => _phase = _Phase.gameOver);
    } else {
      setState(() {
        _round++;
        _guesses.clear();
        _pickDeck();
        _currentPlayer = 0;
        _phase = _Phase.passDevice;
      });
    }
    AudioService.playClick();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineGameScaffold(
      title: 'تحدي الترتيب 🔢',
      backgroundColor: FunkyColors.coral,
      body: switch (_phase) {
        _Phase.setup => _buildSetup(),
        _Phase.passDevice => _buildPassDevice(),
        _Phase.guessing => _buildGuessing(),
        _Phase.roundResults => _buildRoundResults(),
        _Phase.gameOver => _buildGameOver(),
      },
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('🧠', style: const TextStyle(fontSize: 60))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 900.ms),
          const SizedBox(height: 8),
          Text(
            'مين أدق واحد في الشلة؟\nرتّب العناصر صح واكسب!',
            textAlign: TextAlign.center,
            style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.right,
                  style: flatCairo(color: FlatColors.ink),
                  decoration: InputDecoration(
                    hintText: 'اسم اللاعب',
                    hintStyle: flatCairo(color: FlatColors.ink.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addPlayer(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _addPlayer,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: FunkyColors.coral),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _players.length; i++)
                Chip(
                  label: Text('${_players[i]} ${i == 0 ? "👑" : ""}', style: flatCairo(color: FlatColors.ink)),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 18, color: FlatColors.ink),
                  onDeleted: () => setState(() {
                    _totalScores.remove(_players[i]);
                    _players.removeAt(i);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('عدد الجولات', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 15)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 3, label: Text('3', style: flatCairo(fontWeight: FontWeight.bold))),
              ButtonSegment(value: 5, label: Text('5', style: flatCairo(fontWeight: FontWeight.bold))),
              ButtonSegment(value: 7, label: Text('7', style: flatCairo(fontWeight: FontWeight.bold))),
            ],
            selected: {_totalRounds},
            onSelectionChanged: (s) => setState(() => _totalRounds = s.first),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _players.length >= 2 ? _startGame : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                _players.length < 2 ? 'ضيف ${_players.isEmpty ? "لاعبين" : "لاعب"} كمان' : 'يلا بينا! 🚀',
                style: flatCairo(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassDevice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الجولة $_round / $_totalRounds',
                style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.7), fontSize: 15)),
            const SizedBox(height: 16),
            Text('📱', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              'عدّي الموبايل لـ',
              style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 18),
            ),
            Text(
              _players[_currentPlayer],
              style: flatCairo(
                color: FunkyColors.coral,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'باقي الشلة يبصوا في التانية 😄',
              style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                AudioService.playClick();
                setState(() => _phase = _Phase.guessing);
              },
              child: Text('أنا ${_players[_currentPlayer]}، ابدأ',
                  style: flatCairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  Widget _buildGuessing() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FunkyColors.coral.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FunkyColors.coral.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Text(_deck['icon'] ?? '🔢', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _deck['topic'],
                  style: flatCairo(color: FlatColors.ink, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Text(
          'اسحب ورتّب من الأول للأخير',
          style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.7), fontSize: 13),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _currentGuess.length,
            onReorder: (oldIdx, newIdx) {
              HapticService.lightImpact();
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _currentGuess.removeAt(oldIdx);
                _currentGuess.insert(newIdx, item);
              });
            },
            itemBuilder: (context, i) {
              return Container(
                key: ValueKey(_currentGuess[i]),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: FunkyColors.coral,
                    child: Text('${i + 1}', style: flatCairo(color: FlatColors.ink, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(_currentGuess[i], style: flatCairo(color: FlatColors.ink, fontSize: 16)),
                  trailing: const Icon(Icons.drag_indicator, color: FlatColors.ink),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmGuess,
              icon: const Icon(Icons.check),
              label: Text('ثبت الترتيب ✅', style: flatCairo(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundResults() {
    final truth = _truth;
    final roundScores = {
      for (final p in _players) p: RankingChallengeGame.scoreGuess(_guesses[p]!, truth)
    };
    final sorted = _players.toList()
      ..sort((a, b) => roundScores[b]!.compareTo(roundScores[a]!));
    final maxScore = truth.length * 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('الترتيب الصح ✅',
              style: flatCairo(color: FlatColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlatColors.tilePastels[2],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FlatColors.mintDark),
            ),
            child: Column(
              children: [
                for (int i = 0; i < truth.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text('${i + 1}',
                              style: flatCairo(color: FlatColors.mintDark, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Text(truth[i], style: flatCairo(color: FlatColors.ink, fontSize: 15))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('نتايج الجولة',
              style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final p in sorted)
            _scoreTile(
              name: p,
              roundScore: roundScores[p]!,
              maxScore: maxScore,
              total: _totalScores[p] ?? 0,
              guess: _guesses[p]!,
              truth: truth,
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nextRound,
              icon: Icon(_round >= _totalRounds ? Icons.emoji_events : Icons.skip_next),
              label: Text(
                _round >= _totalRounds ? 'النتيجة النهائية 🏆' : 'الجولة الجاية ▶️',
                style: flatCairo(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreTile({
    required String name,
    required int roundScore,
    required int maxScore,
    required int total,
    required List<String> guess,
    required List<String> truth,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: flatCairo(color: FlatColors.ink, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text('+$roundScore',
                  style: flatCairo(color: FlatColors.mintDark, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              Text('المجموع: $total', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.7), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < guess.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: truth[i] == guess[i]
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}. ${guess[i]}',
                    style: flatCairo(
                      color: truth[i] == guess[i] ? FlatColors.mintDark : FlatColors.mafia,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final sorted = _players.toList()
      ..sort((a, b) => (_totalScores[b] ?? 0).compareTo(_totalScores[a] ?? 0));
    final medals = ['🥇', '🥈', '🥉'];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 80))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms),
            const SizedBox(height: 12),
            Text(
              'أدق واحد في الشلة: ${sorted.first}!',
              textAlign: TextAlign.center,
              style: flatCairo(color: const Color(0xFF8A5A00), fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < sorted.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i == 0 ? FlatColors.tilePastels[4] : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: i == 0 ? Border.all(color: const Color(0xFF8A5A00)) : null,
                ),
                child: Row(
                  children: [
                    Text(i < 3 ? medals[i] : '${i + 1}', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(sorted[i],
                          style: flatCairo(color: FlatColors.ink, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    Text('${_totalScores[sorted[i]]} نقطة',
                        style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 15)),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 120).ms).slideX(begin: 0.2),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.replay),
                    label: Text('العبوا تاني 🔁', style: flatCairo(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.home_outlined, color: FlatColors.ink),
                    label: Text('الرئيسية', style: flatCairo(color: FlatColors.ink)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: FlatColors.ink.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
