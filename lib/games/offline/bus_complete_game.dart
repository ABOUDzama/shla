import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// أتوبيس كومبليت (لعبة الأتوبيس): letter + categories, fill fast, unique
/// answers score double. Pass-and-play on one device.
class BusCompleteGame extends StatefulWidget {
  const BusCompleteGame({super.key});

  static const List<String> allCategories = [
    'ولد', 'بنت', 'جماد', 'نبات', 'بلاد', 'أكلة',
    'حيوان', 'لون', 'مهنة', 'رياضي', 'فيلم أو مسلسل', 'حاجة في التلاجة',
  ];

  static const List<String> letters = [
    'ا', 'ب', 'ت', 'ج', 'ح', 'د', 'ر', 'ز', 'س', 'ش', 'ص', 'ط',
    'ع', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  ];

  /// Normalizes Arabic words so comparison is fair across alef/taa forms.
  static String normalize(String word) {
    var w = word.trim();
    if (w.isEmpty) return w;
    w = w.replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), ''); // tashkeel + tatweel
    w = w.replaceAll(RegExp(r'[أإآ]'), 'ا');
    w = w.replaceAll('ة', 'ه');
    w = w.replaceAll('ى', 'ي');
    w = w.replaceAll(RegExp(r'\s+'), ' ').trim();
    return w;
  }

  /// Comparison form: normalize + drop a leading definite article "ال"
  /// (plain alef only, so همزة-قطع words like ألعاب/ألم are untouched).
  /// "البحرين" must count for letter ب, and equal "بحرين" when deduplicating.
  static String normalizeForCompare(String word) {
    final raw = word.trim().replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '');
    final stripped = raw.startsWith('ال') && raw.length > 3 ? raw.substring(2) : raw;
    return normalize(stripped);
  }

  static bool startsWithLetter(String word, String letter) {
    final w = normalizeForCompare(word);
    return w.isNotEmpty && w[0] == letter;
  }

  /// Scores one round. answers[player][category] = word.
  /// Unique valid answer = 10, shared valid answer = 5, invalid/empty = 0.
  static Map<String, int> scoreRound(
    List<String> players,
    List<String> categories,
    String letter,
    Map<String, Map<String, String>> answers,
  ) {
    final scores = {for (final p in players) p: 0};
    for (final cat in categories) {
      final counts = <String, int>{};
      final normalizedByPlayer = <String, String>{};
      for (final p in players) {
        final raw = answers[p]?[cat] ?? '';
        final norm = normalizeForCompare(raw).toLowerCase();
        normalizedByPlayer[p] = norm;
        if (norm.isNotEmpty && startsWithLetter(raw, letter)) {
          counts[norm] = (counts[norm] ?? 0) + 1;
        }
      }
      for (final p in players) {
        final norm = normalizedByPlayer[p]!;
        if (norm.isEmpty || !startsWithLetter(answers[p]?[cat] ?? '', letter)) continue;
        scores[p] = scores[p]! + ((counts[norm] ?? 0) > 1 ? 5 : 10);
      }
    }
    return scores;
  }

  @override
  State<BusCompleteGame> createState() => _BusCompleteGameState();
}

enum _Phase { setup, passDevice, playing, roundResults, gameOver }

class _BusCompleteGameState extends State<BusCompleteGame> {
  _Phase _phase = _Phase.setup;
  final List<String> _players = [];
  final TextEditingController _nameCtrl = TextEditingController();
  final Set<String> _categories = {
    'ولد', 'بنت', 'جماد', 'نبات', 'بلاد', 'أكلة',
  };
  int _totalRounds = 3;
  int _round = 0;
  static const int _turnSeconds = 45;

  late String _letter;
  int _currentPlayer = 0;
  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, Map<String, String>> _answers = {};
  final Map<String, int> _totalScores = {};
  final List<String> _usedLetters = [];
  final Random _rng = Random();
  Timer? _timer;
  int _timeLeft = _turnSeconds;

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
      _answers.clear();
      _usedLetters.clear();
      for (final p in _players) _totalScores[p] = 0;
      _pickLetter();
      _currentPlayer = 0;
      _phase = _Phase.passDevice;
    });
    AudioService.playSuccess();
  }

  void _pickLetter() {
    String l;
    do {
      l = BusCompleteGame.letters[_rng.nextInt(BusCompleteGame.letters.length)];
    } while (_usedLetters.contains(l));
    _usedLetters.add(l);
    _letter = l;
  }

  void _startTurn() {
    _fieldCtrls.clear();
    for (final c in _categories) {
      _fieldCtrls[c] = TextEditingController();
    }
    _timeLeft = _turnSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _timeLeft--);
      if (_timeLeft <= 5 && _timeLeft > 0) {
        AudioService.playTick();
        HapticService.lightImpact();
      }
      if (_timeLeft <= 0) {
        t.cancel();
        _finishTurn(timeOut: true);
      }
    });
    setState(() => _phase = _Phase.playing);
  }

  void _finishTurn({bool timeOut = false}) {
    _timer?.cancel();
    final me = _players[_currentPlayer];
    _answers[me] = {
      for (final c in _categories) c: _fieldCtrls[c]?.text.trim() ?? '',
    };
    if (timeOut) {
      AudioService.playFailure();
      HapticService.heavyImpact();
    } else {
      AudioService.playClick();
    }
    if (_currentPlayer < _players.length - 1) {
      setState(() {
        _currentPlayer++;
        _phase = _Phase.passDevice;
      });
    } else {
      final roundScores = BusCompleteGame.scoreRound(
        _players, _categories.toList(), _letter, _answers,
      );
      for (final p in _players) {
        _totalScores[p] = (_totalScores[p] ?? 0) + (roundScores[p] ?? 0);
      }
      AudioService.playSuccess();
      HapticService.success();
      setState(() => _phase = _Phase.roundResults);
    }
  }

  void _nextRound() {
    AudioService.playClick();
    if (_round >= _totalRounds) {
      AudioService.playWinVoice();
      setState(() => _phase = _Phase.gameOver);
    } else {
      setState(() {
        _round++;
        _answers.clear();
        _pickLetter();
        _currentPlayer = 0;
        _phase = _Phase.passDevice;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineGameScaffold(
      title: 'أتوبيس كومبليت 🚌',
      backgroundColor: FunkyColors.amber,
      body: switch (_phase) {
        _Phase.setup => _buildSetup(),
        _Phase.passDevice => _buildPassDevice(),
        _Phase.playing => _buildPlaying(),
        _Phase.roundResults => _buildRoundResults(),
        _Phase.gameOver => _buildGameOver(),
      },
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🚌', style: const TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: -12, end: 12, duration: 1200.ms),
          const SizedBox(height: 6),
          Text(
            'حرف واحد.. وكل واحد يملى الفئات قبل الوقت!\nالإجابة المختلفة عن الكل بـ 10 نقط، والمكررة بـ 5.',
            textAlign: TextAlign.center,
            style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.right,
                  style: flatCairo(color: FlatColors.ink),
                  decoration: InputDecoration(
                    hintText: 'اسم اللاعب',
                    hintStyle: flatCairo(color: FlatColors.ink.withValues(alpha: 0.7)),
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
                style: IconButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _players.length; i++)
                Chip(
                  label: Text(_players[i], style: flatCairo(color: FlatColors.ink)),
                  backgroundColor: Colors.orange.withValues(alpha: 0.25),
                  deleteIcon: Icon(Icons.close, size: 18, color: FlatColors.ink.withValues(alpha: 0.55)),
                  onDeleted: () => setState(() {
                    _totalScores.remove(_players[i]);
                    _players.removeAt(i);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('الفئات (اختار 4 على الأقل)',
              style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in BusCompleteGame.allCategories)
                FilterChip(
                  label: Text(c, style: flatCairo(fontSize: 13)),
                  selected: _categories.contains(c),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _categories.add(c);
                    } else if (_categories.length > 4) {
                      _categories.remove(c);
                    }
                  }),
                  selectedColor: FlatColors.tilePastels[4],
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _categories.contains(c) ? Colors.white : FlatColors.ink.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('عدد الجولات', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 7, label: Text('7')),
            ],
            selected: {_totalRounds},
            onSelectionChanged: (s) => setState(() => _totalRounds = s.first),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _players.length >= 2 ? _startGame : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(
              _players.length < 2 ? 'ضيف لاعبين على الأقل' : 'اركبوا الأتوبيس! 🚌',
              style: flatCairo(fontWeight: FontWeight.bold, fontSize: 17),
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
                style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 15)),
            const SizedBox(height: 20),
            Text('حرف الجولة:', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 18)),
            const SizedBox(height: 8),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.25),
                border: Border.all(color: Colors.orange, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(_letter,
                  style: flatCairo(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.orangeAccent)),
            ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),
            const SizedBox(height: 20),
            Text('عدّي الموبايل لـ', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 17)),
            Text(
              _players[_currentPlayer],
              style: flatCairo(color: FlatColors.ink, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                AudioService.playClick();
                _startTurn();
              },
              child: Text('أنا ${_players[_currentPlayer]}، يلا! ⏱️',
                  style: flatCairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    final urgent = _timeLeft <= 10;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange,
                radius: 26,
                child: Text(_letter, style: flatCairo(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_players[_currentPlayer],
                    style: flatCairo(color: FlatColors.ink, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: urgent ? Colors.red.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: urgent ? Border.all(color: Colors.redAccent) : Border.all(color: FlatColors.border, width: 2),
                ),
                child: Text(
                  '$_timeLeft',
                  style: flatCairo(
                    color: urgent ? Colors.redAccent : FlatColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: _timeLeft / _turnSeconds,
          backgroundColor: FlatColors.border,
          color: urgent ? Colors.redAccent : Colors.orange,
          minHeight: 5,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _fieldCtrls[c],
                    textAlign: TextAlign.right,
                    style: flatCairo(color: FlatColors.ink, fontSize: 17),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: c,
                      labelStyle: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _finishTurn(),
              icon: const Icon(Icons.check_circle),
              label: Text('خلصت! ✅', style: flatCairo(fontWeight: FontWeight.bold, fontSize: 17).copyWith(fontFamilyFallback: FunkyText.emojiFallback)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundResults() {
    final cats = _categories.toList();
    final roundScores = BusCompleteGame.scoreRound(_players, cats, _letter, _answers);
    final sorted = _players.toList()..sort((a, b) => roundScores[b]!.compareTo(roundScores[a]!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('جولة حرف "$_letter"',
              style: flatCairo(color: FlatColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final cat in cats)
            _categoryResult(cat, roundScores.keys.toList()),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (final p in sorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(p, style: flatCairo(color: FlatColors.ink, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Text('+${roundScores[p]}', style: flatCairo(color: FlatColors.mintDark, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Text('المجموع: ${_totalScores[p]}', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.7), fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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

  Widget _categoryResult(String cat, List<String> players) {
    final normalized = <String, String>{};
    final counts = <String, int>{};
    for (final p in players) {
      final raw = _answers[p]?[cat] ?? '';
      final norm = BusCompleteGame.normalize(raw).toLowerCase();
      normalized[p] = norm;
      if (norm.isNotEmpty && BusCompleteGame.startsWithLetter(raw, _letter)) {
        counts[norm] = (counts[norm] ?? 0) + 1;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cat, style: flatCairo(color: FlatColors.ink, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          for (final p in players)
            Builder(builder: (_) {
              final raw = _answers[p]?[cat] ?? '';
              final norm = normalized[p]!;
              final valid = norm.isNotEmpty && BusCompleteGame.startsWithLetter(raw, _letter);
              final dup = valid && (counts[norm] ?? 0) > 1;
              final pts = !valid ? 0 : (dup ? 5 : 10);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(p, style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75), fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: Text(
                        raw.isEmpty ? '—' : raw,
                        style: flatCairo(
                          color: valid ? FlatColors.ink : FlatColors.mafia,
                          fontSize: 14,
                          decoration: valid ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    Text(
                      '+$pts',
                      style: flatCairo(
                        color: pts == 10 ? FlatColors.mintDark : (pts == 5 ? const Color(0xFF8A5A00) : FlatColors.ink.withValues(alpha: 0.7)),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
            const Text('🚌💨', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(
              'الكابتن: ${sorted.first}! 🏆',
              style: flatCairo(color: FlatColors.ink, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < sorted.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i == 0 ? FlatColors.tilePastels[4].withValues(alpha: 0.18) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == 0 ? FlatColors.tilePastels[4] : FlatColors.border, width: 2),
                ),
                child: Row(
                  children: [
                    Text(i < 3 ? medals[i] : '${i + 1}', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(sorted[i],
                          style: flatCairo(color: FlatColors.ink, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    Text('${_totalScores[sorted[i]]} نقطة', style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.75))),
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
                    label: Text('جولة تانية 🔁', style: flatCairo(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.home_outlined, color: Colors.white70),
                    label: Text('الرئيسية', style: flatCairo(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
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
