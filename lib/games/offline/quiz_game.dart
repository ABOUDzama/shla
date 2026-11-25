import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';

import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/raw_data_manager.dart';
import '../../services/ai_service.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../services/ai_cache_service.dart';
import '../../services/played_history_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

class QuizGame extends StatefulWidget {
  const QuizGame({super.key});
  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  Map<String, List<Map<String, String>>> questions = {};
  bool isLoadingData = true;
  bool isGeneratingAi = false;
  List<Map<String, String>> gameQuestions = [];
  int currentQuestionIndex = 0;
  bool showAnswer = false;
  List<String> selectedCategories = [];
  bool gameStarted = false;
  bool _offlineNoticeShown = false;
  bool _showIntro = true;

  // Multiplayer
  List<String> _players = [];
  Map<String, int> _playerScores = {};

  final Map<String, List<Map<String, String>>> _fallbackQuestions = {
    'ثقافة عامة': [
      {
        'question': 'ما هو أطول نهر في العالم؟',
        'answer': 'نهر النيل',
        'icon': '🌊',
      },
      {
        'question': 'ما هو أصل كلمة "أطلس" التي تطلق على كتاب الخرائط؟',
        'answer': 'يوناني',
        'icon': '🗺️',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    final rawData = await RawDataManager.loadLocalGameData('quiz_game') ?? {};

    if (rawData.containsKey('categories') && rawData['categories'] is Map) {
      Map<String, List<Map<String, String>>> parsedQuestions = {};
      final cats = rawData['categories'] as Map;
      cats.forEach((key, value) {
        if (value is List) {
          parsedQuestions[key.toString()] = List<Map<String, String>>.from(
            value.map(
              (e) => Map<String, String>.from(
                e.map((k, v) => MapEntry(k.toString(), v.toString())),
              ),
            ),
          );
        }
      });

      if (parsedQuestions.isNotEmpty) {
        if (mounted) {
          setState(() {
            questions = parsedQuestions;
            isLoadingData = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        questions = _fallbackQuestions;
        isLoadingData = false;
      });
    }
  }

  void _openPlayerSelection() {
    if (selectedCategories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalPlayerSelectionScreen(
          gameTitle: 'سؤال وجواب',
          minPlayers: 2,
          onStartGame: (ctx, selectedPlayers) {
            Navigator.pop(ctx);
            setState(() {
              _players = selectedPlayers;
              _playerScores = {for (var player in selectedPlayers) player: 0};
            });
            _startGame();
          },
        ),
      ),
    );
  }

  void _startGame() async {
    setState(() {
      isLoadingData = true;
      gameStarted = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline =
          !(connectivityResult.contains(ConnectivityResult.none) &&
              connectivityResult.length == 1);

      gameQuestions = [];

      // Always load the offline library which includes both JSON and previously cached AI questions
      await _loadOfflineQuestions();

      if (isOnline) {
        for (var cat in selectedCategories) {
          final newQuestions = await AIService.fetchAiQuestions(cat, count: 10);
          for (var item in newQuestions) {
            gameQuestions.add({
              'question': item['question']?.toString() ?? '',
              'answer': item['answer']?.toString() ?? '',
              'icon': '✨',
            });
          }
        }
      }

      // Deduplicate questions by question text to ensure a clean library pool
      final uniqueQ = <String, Map<String, String>>{};
      for (var q in gameQuestions) {
        uniqueQ[q['question'] ?? ''] = q;
      }
      gameQuestions = uniqueQ.values.toList();

      // Filter out previously played questions
      final unplayed = await PlayedHistoryService.filterUnplayed(gameQuestions);
      if (unplayed.isNotEmpty) {
        gameQuestions = unplayed.map((e) {
          final m = Map<String, dynamic>.from(e);
          return m.map((k, v) => MapEntry(k.toString(), v.toString()));
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching AI questions, falling back to local data: $e');
      if (gameQuestions.isEmpty) {
        await _loadOfflineQuestions();
      }
      if (mounted && !_offlineNoticeShown) {
        _offlineNoticeShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'أنت في وضع الأوفلاين أو حدث خطأ، تم تشغيل بنك الأسئلة المحلي',
            ),
          ),
        );
      }
    }

    gameQuestions.shuffle();

    // Mark the first question as played immediately
    if (gameQuestions.isNotEmpty) {
      PlayedHistoryService.markAsPlayed(gameQuestions[0]['question'] ?? '');
    }

    setState(() {
      currentQuestionIndex = 0;
      showAnswer = false;
      isLoadingData = false;
    });
  }

  Future<void> _loadOfflineQuestions() async {
    for (var cat in selectedCategories) {
      // 1. Load from default JSON
      if (questions.containsKey(cat)) {
        gameQuestions.addAll(questions[cat]!);
      }
      // 2. Load from internal DB cache
      try {
        final cached = await AICacheService.loadQuizQuestions(cat);
        if (cached.isNotEmpty) {
          gameQuestions.addAll(cached);
        }
      } catch (_) {}
    }
  }

  void _changeScore(String playerName, int delta) {
    setState(() {
      _playerScores[playerName] = (_playerScores[playerName] ?? 0) + delta;
    });
    if (delta > 0) {
      AudioService.playSuccess();
    } else {
      AudioService.playClick();
    }
  }

  void _nextQuestion() {
    setState(() {
      if (currentQuestionIndex + 1 < gameQuestions.length) {
        currentQuestionIndex++;
        showAnswer = false;
        // Mark as played when shown
        PlayedHistoryService.markAsPlayed(
          gameQuestions[currentQuestionIndex]['question'] ?? '',
        );
      } else {
        gameQuestions.shuffle();
        currentQuestionIndex = 0;
        showAnswer = false;
        if (gameQuestions.isNotEmpty) {
          PlayedHistoryService.markAsPlayed(gameQuestions[0]['question'] ?? '');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return OfflineGameScaffold(
        title: 'تحدي المعرفة',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: const Center(
          child: CircularProgressIndicator(color: FlatColors.ink),
        ),
      );
    }

    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'تحدي المعرفة',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: GameIntroWidget(
          title: 'تحدي الأسئلة الكبرى',
          icon: '❓',
          description:
              'اختبر معلوماتك في مجالات مختلفة! جاوب على الأسئلة ونافس أصحابك في أكتر واحد عارف معلومات عامة.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!gameStarted) {
      return OfflineGameScaffold(
        title: 'تحدي المعرفة',
        backgroundColor: FunkyColors.amber,
        showAi: false,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'تحدي الأسئلة الكبرى',
                  style: GoogleFonts.cairo(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: questions.keys.map((cat) {
                    final isSelected = selectedCategories.contains(cat);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedCategories.remove(cat);
                          } else {
                            selectedCategories.add(cat);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FlatColors.tilePastels[1].withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected
                                ? FlatColors.tilePastels[1]
                                : FlatColors.border,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.cairo(
                            color: isSelected
                                ? FlatColors.tilePastels[1]
                                : FlatColors.ink,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 60),
                AnimatedOpacity(
                  opacity: selectedCategories.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: selectedCategories.isNotEmpty
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openPlayerSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FlatColors.tilePastels[3],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'اختار الشلة وابدأ >',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = gameQuestions[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / gameQuestions.length;

    return OfflineGameScaffold(
      title: 'تحدي المعرفة',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: FlatColors.ink),
          onPressed: () {
            setState(() {
              gameStarted = false;
              _players.clear();
            });
          },
        ),
      ],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress Section
              Text(
                'سؤال ${currentQuestionIndex + 1} من ${gameQuestions.length}',
                style: GoogleFonts.cairo(
                  color: FlatColors.ink.withValues(alpha: 0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: FlatColors.border,
                  color: FunkyColors.amber,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 24),

              // Question Card
              GestureDetector(
                onTap: () {
                  if (!showAnswer) setState(() => showAnswer = true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  decoration: FlatDecor.card(radius: 30),
                  child: Column(
                    children: [
                      Text(
                        currentQuestion['question'] ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.ink,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (!showAnswer)
                        Text(
                              'انقر لرؤية الإجابة 💡',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                color: FlatColors.ink.withValues(alpha: 0.75),
                                fontWeight: FontWeight.bold,
                              ).copyWith(
                                  fontFamilyFallback:
                                      FunkyText.emojiFallback),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fade(duration: 1.5.seconds)
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: FlatColors.tilePastels[2],
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'الإجابة الصحيحة:',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: FlatColors.mintDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentQuestion['answer'] ?? '',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: FlatColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().scale(),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1, end: 0, duration: 400.ms),

              const SizedBox(height: 24),

              // Scoreboard Section
              if (_players.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: FlatDecor.card(radius: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.stars,
                            color: Colors.amberAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'لوحة النقاط',
                            style: GoogleFonts.cairo(
                              color: FlatColors.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'لاعبين ${_players.length}',
                            style: GoogleFonts.cairo(
                              color: FlatColors.ink.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: FlatColors.border, height: 1),
                      ),
                      ..._players.map((pName) {
                        final score = _playerScores[pName] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pName,
                                  style: GoogleFonts.cairo(
                                    color: FlatColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$score',
                                style: GoogleFonts.cairo(
                                  color: FlatColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () => _changeScore(pName, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: FlatColors.tilePastels[2],
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.add,
                                    color: FlatColors.ink,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _changeScore(pName, -1),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: FlatColors.mafia,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Bottom Area
              showAnswer
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlatColors.tilePastels[3],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'السؤال التالي',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      ).animate().fadeIn().scale(),
                    )
                  : const SizedBox(
                      height: 50,
                    ), // Spacer spacing instead of button
            ],
          ),
        ),
      ),
    );
  }
}
