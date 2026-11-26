import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../services/audio_service.dart';
import '../../data/heads_up_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// خمّنها — exact clone of the forehead guessing game (Heads Up! /
/// Lammah «خمن الكلمة» / GamesUP «خمّنها»):
/// - The guesser holds the phone to their forehead, screen facing friends.
/// - Friends describe the word without saying it.
/// - Tilt down = correct (+1), tilt up = pass. Buttons work too.
/// - Passed words come back later in the turn.
/// - Turn timer 45/60/90s, players rotate, most words wins.
class HeadsUpGame extends StatefulWidget {
  const HeadsUpGame({super.key});

  @override
  State<HeadsUpGame> createState() => _HeadsUpGameState();
}

class _HeadsUpGameState extends State<HeadsUpGame> {
  bool _showIntro = true;
  bool _setupDone = false;

  final Set<int> _selectedCategories = {0};
  final List<Map<String, dynamic>> _players = [];
  int _turnSeconds = 60;
  int _rounds = 1;

  // Deck state
  List<String> _deck = [];
  int _deckPointer = 0;
  final List<String> _passedQueue = [];

  // Turn state
  int _currentGuesser = 0;
  int _round = 1;
  String? _currentWord;
  int _secondsLeft = 0;
  Timer? _timer;
  int _turnScore = 0;
  final List<Map<String, dynamic>> _turnWords = []; // {word, correct}
  bool _turnActive = false;
  bool _showTurnSummary = false;
  bool _gameOver = false;
  int _countdown = 0; // 3,2,1 then 0
  Timer? _countdownTimer;

  // Tilt
  StreamSubscription? _accelSub;
  DateTime _lastTilt = DateTime.fromMillisecondsSinceEpoch(0);

  void _buildDeck() {
    _deck = [];
    for (final i in _selectedCategories) {
      final words = headsUpCategories[i]['words'] as List;
      _deck.addAll(words.map((w) => w.toString()));
    }
    _deck.shuffle();
    _deckPointer = 0;
  }

  String _nextWord() {
    if (_deckPointer < _deck.length) {
      return _deck[_deckPointer++];
    }
    if (_passedQueue.isNotEmpty) {
      // Passed words come back (reference rule)
      return _passedQueue.removeAt(0);
    }
    // Deck exhausted: reshuffle
    _deck.shuffle();
    _deckPointer = 0;
    return _deck[_deckPointer++];
  }

  void _startTurn() {
    AudioService.playClick();
    setState(() {
      _countdown = 3;
      _turnWords.clear();
      _passedQueue.clear();
      _turnScore = 0;
      _showTurnSummary = false;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      AudioService.playTick();
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _beginGuessing();
      }
    });
  }

  void _beginGuessing() {
    setState(() {
      _turnActive = true;
      _secondsLeft = _turnSeconds;
      _currentWord = _nextWord();
    });
    AudioService.playSuccess();
    _startTiltListener();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 5 && _secondsLeft > 0) AudioService.playTick();
      if (_secondsLeft <= 0) {
        _endTurn();
      }
    });
  }

  void _startTiltListener() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((event) {
      if (!_turnActive || !mounted) return;
      // Phone on forehead: tilting the top edge DOWN (screen toward the
      // ground) reads strongly negative on z; top edge UP reads positive.
      if (event.z < -6.5) {
        _markAnswer(true);
      } else if (event.z > 6.5) {
        _markAnswer(false);
      }
    });
  }

  void _markAnswer(bool correct) {
    if (!_turnActive || _currentWord == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTilt).inMilliseconds < 900) return;
    _lastTilt = now;
    setState(() {
      _turnWords.add({'word': _currentWord, 'correct': correct});
      if (correct) {
        _turnScore++;
        AudioService.playSuccess();
      } else {
        _passedQueue.add(_currentWord!);
        AudioService.playClick();
      }
      _currentWord = _nextWord();
    });
  }

  void _endTurn() {
    _timer?.cancel();
    _accelSub?.cancel();
    AudioService.playFailure();
    setState(() {
      _turnActive = false;
      _showTurnSummary = true;
      if (_players.isNotEmpty) {
        _players[_currentGuesser]['score'] =
            (_players[_currentGuesser]['score'] as int) + _turnScore;
      }
    });
  }

  void _nextTurn() {
    AudioService.playClick();
    setState(() {
      _showTurnSummary = false;
      if (_currentGuesser + 1 < _players.length) {
        _currentGuesser++;
      } else {
        _currentGuesser = 0;
        _round++;
        if (_round > _rounds) {
          _gameOver = true;
          AudioService.playWinVoice();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🤔 خمّنها',
        backgroundColor: FunkyColors.sky,
        body: GameIntroWidget(
          title: '🤔 خمّنها',
          icon: '🤔',
          description:
              'حط الموبايل على جبهتك وشاشتك وشها لأصحابك!\n\nهما يوصفوا الكلمة من غير ما يقولوها، وانت تخمّن بصوت عالي.\n\n✅ عرفتها؟ ميّل الموبايل لتحت (أو دوس صح).\n⏭️ واقفة؟ ميّل لفوق (أو دوس تخطي) — والكلمة هترجعلك تاني.\n\nكل كلمة صح = نقطة، وأكتر واحد يجمع في الوقت يكسب!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (_gameOver) return _buildGameOver();
    if (!_setupDone) return _buildSetup();
    if (_countdown > 0) return _buildCountdown();
    if (_showTurnSummary) return _buildTurnSummary();
    if (_turnActive) return _buildGuessing();
    return _buildPassPhone();
  }

  // ---------- Screens ----------

  Widget _buildSetup() {
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختار الأقسام:',
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(headsUpCategories.length, (i) {
                  final cat = headsUpCategories[i];
                  final sel = _selectedCategories.contains(i);
                  return GestureDetector(
                    onTap: () {
                      AudioService.playClick();
                      setState(() {
                        if (sel && _selectedCategories.length > 1) {
                          _selectedCategories.remove(i);
                        } else {
                          _selectedCategories.add(i);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? FlatColors.detective : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FlatColors.ink, width: 2),
                      ),
                      child: Text(
                        '${cat['icon']} ${cat['name']}',
                        style: flatCairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : FlatColors.ink,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'وقت الدور:',
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Row(
                children: [45, 60, 90].map((s) {
                  final sel = _turnSeconds == s;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AudioService.playClick();
                        setState(() => _turnSeconds = s);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? FlatColors.mintDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FlatColors.ink, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$s ثانية',
                            style: flatCairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : FlatColors.ink,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'عدد الجولات:',
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Row(
                children: [1, 2, 3].map((r) {
                  final sel = _rounds == r;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AudioService.playClick();
                        setState(() => _rounds = r);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? FlatColors.mintDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FlatColors.ink, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$r',
                            style: flatCairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : FlatColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _selectedCategories.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GlobalPlayerSelectionScreen(
                              gameTitle: 'خمّنها',
                              minPlayers: 2,
                              maxPlayers: 8,
                              onStartGame: (ctx, selectedPlayers) {
                                Navigator.pop(ctx);
                                setState(() {
                                  _players.clear();
                                  _players.addAll(
                                    selectedPlayers.map(
                                      (name) => {'name': name, 'score': 0},
                                    ),
                                  );
                                  _currentGuesser = 0;
                                  _round = 1;
                                  _buildDeck();
                                  _setupDone = true;
                                });
                              },
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.people_alt, size: 28),
                label: Text(
                  'اختار شلتك وابدأ!',
                  style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900),
                ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassPhone() {
    final name = _players.isNotEmpty
        ? _players[_currentGuesser]['name'] as String
        : '';
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'الجولة $_round من $_rounds',
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
                      'عدّي الموبايل لـ $name',
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
                      'هيحطه على جبهته والكل هيوصف له الكلمات',
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
                onPressed: _startTurn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'يلا نبدأ!',
                  style: flatCairo(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
      body: Center(
        child:
            Text(
                  '$_countdown',
                  style: flatCairo(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                )
                .animate(key: ValueKey(_countdown))
                .scale(duration: 400.ms, curve: Curves.elasticOut),
      ),
    );
  }

  Widget _buildGuessing() {
    final progress = _secondsLeft / _turnSeconds;
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '⭐ $_turnScore',
                    style: flatCairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation(
                          _secondsLeft > 10
                              ? FlatColors.mintDark
                              : FlatColors.mafia,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_secondsLeft',
                    style: flatCairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _currentWord ?? '',
                    key: ValueKey('${_turnWords.length}_$_currentWord'),
                    textAlign: TextAlign.center,
                    style: flatCairo(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAnswer(false),
                      icon: const Icon(Icons.skip_next, size: 30),
                      label: Text(
                        'تخطي',
                        style: flatCairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.day,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAnswer(true),
                      icon: const Icon(Icons.check_circle, size: 30),
                      label: Text(
                        'صح!',
                        style: flatCairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlatColors.mintDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'أو ميّل الموبايل: لتحت = صح، لفوق = تخطي',
                style: flatCairo(
                  fontSize: 13,
                  color: FlatColors.ink.withValues(alpha: 0.6),
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnSummary() {
    final name = _players.isNotEmpty
        ? _players[_currentGuesser]['name'] as String
        : '';
    final isLast = _currentGuesser + 1 >= _players.length && _round >= _rounds;
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'خلص وقت $name! ⏰',
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 6),
              Text(
                'جاب $_turnScore صح',
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.mintDark,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _turnWords.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, i) {
                      final w = _turnWords[i];
                      final ok = w['correct'] as bool;
                      return Row(
                        children: [
                          Icon(
                            ok ? Icons.check_circle : Icons.skip_next,
                            color: ok ? FlatColors.mintDark : FlatColors.day,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              w['word'] as String,
                              style: flatCairo(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: FlatColors.ink,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  isLast ? 'النتيجة النهائية 🏆' : 'الدور الجاي ⏭️',
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
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final winner = sorted.isNotEmpty ? sorted.first : null;
    return OfflineGameScaffold(
      title: '🤔 خمّنها',
      backgroundColor: FunkyColors.sky,
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
                '${winner?['name']} كسب!',
                style: flatCairo(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
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
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  setState(() {
                    _gameOver = false;
                    _setupDone = false;
                    _showTurnSummary = false;
                    _turnActive = false;
                    _players.clear();
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
