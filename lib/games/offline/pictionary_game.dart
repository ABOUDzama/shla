import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/raw_data_manager.dart';
import '../../widgets/premium_loading_indicator.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

// ─── Drawing model ───────────────────────────────
class DrawPoint {
  final Offset? point;
  final Color color;
  final double strokeWidth;
  DrawPoint(this.point, this.color, this.strokeWidth);
}

class DrawingPainter extends CustomPainter {
  final List<DrawPoint> points;
  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].point != null && points[i + 1].point != null) {
        paint
          ..color = points[i].color
          ..strokeWidth = points[i].strokeWidth;
        canvas.drawLine(points[i].point!, points[i + 1].point!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter old) => old.points.length != points.length;
}

// ─── Game ──────────────────────────────────────────────────────────
class PictionaryGame extends StatefulWidget {
  const PictionaryGame({super.key});

  @override
  State<PictionaryGame> createState() => _PictionaryGameState();
}

class _PictionaryGameState extends State<PictionaryGame> {
  List<Map<String, String>> wordCategories = [];
  bool isLoadingData = true;
  bool _showIntro = true;
  bool _isGeneratingAi = false;
  final List<String> _aiHistory = [];

  void _generateAiContent() async {
    if (!SettingsService.isAiEnabled) return;

    setState(() => _isGeneratingAi = true);
    try {
      final content = await AIService.fetchGameContent(
        'pictionary',
        count: 20,
        history: _aiHistory,
      );
      if (content.isNotEmpty) {
        for (var item in content) {
          final word = item['word']?.toString() ?? '';
          if (word.isNotEmpty) {
            _aiHistory.add(word);
          }
        }
        if (_aiHistory.length > 50) {
          _aiHistory.removeRange(0, _aiHistory.length - 50);
        }
      }
      List<Map<String, String>> aiWords = [];
      for (var item in content) {
        aiWords.add({
          'word': item['word']?.toString() ?? '',
          'category': item['category']?.toString() ?? 'عام',
        });
      }

      if (aiWords.isNotEmpty) {
        setState(() {
          wordCategories.addAll(aiWords);
        });
        if (!_started && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم توليد مفردات جديدة بالذكاء الاصطناعي! ✨'),
              backgroundColor: FlatColors.mintDark,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد محتوى AI: $e'),
            backgroundColor: FlatColors.mafia,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingAi = false);
    }
  }

  final List<Map<String, String>> _fallbackWordCategories = [
    {'word': 'قطة', 'category': '🐾 حيوانات'},
    {'word': 'كلب', 'category': '🐾 حيوانات'},
    {'word': 'أسد', 'category': '🐾 حيوانات'},
    {'word': 'ديناصور', 'category': '🐾 حيوانات'},
    {'word': 'بطة', 'category': '🐾 حيوانات'},
    {'word': 'فيل', 'category': '🐾 حيوانات'},
    {'word': 'زرافة', 'category': '🐾 حيوانات'},
    {'word': 'أرنب', 'category': '🐾 حيوانات'},
    {'word': 'نمر', 'category': '🐾 حيوانات'},
    {'word': 'قرد', 'category': '🐾 حيوانات'},
    {'word': 'دلفين', 'category': '🐾 حيوانات'},
    {'word': 'سلحفاة', 'category': '🐾 حيوانات'},
    {'word': 'تمساح', 'category': '🐾 حيوانات'},
    {'word': 'سمكة', 'category': '🐾 حيوانات'},
    {'word': 'عصفور', 'category': '🐾 حيوانات'},
    {'word': 'بيتزا', 'category': '🍕 أكل'},
    {'word': 'كيكة', 'category': '🍕 أكل'},
    {'word': 'برغر', 'category': '🍕 أكل'},
    {'word': 'عنب', 'category': '🍕 أكل'},
    {'word': 'شاورما', 'category': '🍕 أكل'},
    {'word': 'كنافة', 'category': '🍕 أكل'},
    {'word': 'سوشي', 'category': '🍕 أكل'},
    {'word': 'موز', 'category': '🍕 أكل'},
    {'word': 'كشري', 'category': '🍕 أكل'},
    {'word': 'فلافل', 'category': '🍕 أكل'},
    {'word': 'تفاحة', 'category': '🍕 أكل'},
    {'word': 'بطيخ', 'category': '🍕 أكل'},
    {'word': 'موبايل', 'category': '📱 تكنولوجيا'},
    {'word': 'حاسوب', 'category': '📱 تكنولوجيا'},
    {'word': 'روبوت', 'category': '📱 تكنولوجيا'},
    {'word': 'كاميرا', 'category': '📱 تكنولوجيا'},
    {'word': 'تلفاز', 'category': '📱 تكنولوجيا'},
    {'word': 'سماعة', 'category': '📱 تكنولوجيا'},
    {'word': 'طيارة', 'category': '🚗 مواصلات'},
    {'word': 'عربية', 'category': '🚗 مواصلات'},
    {'word': 'دراجة', 'category': '🚗 مواصلات'},
    {'word': 'قطار', 'category': '🚗 مواصلات'},
    {'word': 'مركب', 'category': '🚗 مواصلات'},
    {'word': 'حافلة', 'category': '🚗 مواصلات'},
    {'word': 'صاروخ', 'category': '🚗 مواصلات'},
    {'word': 'ساعة', 'category': '🏠 أشياء'},
    {'word': 'مظلة', 'category': '🏠 أشياء'},
    {'word': 'مفتاح', 'category': '🏠 أشياء'},
    {'word': 'كرسي', 'category': '🏠 أشياء'},
    {'word': 'مرآة', 'category': '🏠 أشياء'},
    {'word': 'منزل', 'category': '🏠 أشياء'},
    {'word': 'حقيبة', 'category': '🏠 أشياء'},
    {'word': 'مصباح', 'category': '🏠 أشياء'},
    {'word': 'قلم', 'category': '🏠 أشياء'},
    {'word': 'شمس', 'category': '🌍 طبيعة'},
    {'word': 'قمر', 'category': '🌍 طبيعة'},
    {'word': 'نجمة', 'category': '🌍 طبيعة'},
    {'word': 'جبل', 'category': '🌍 طبيعة'},
    {'word': 'بحر', 'category': '🌍 طبيعة'},
    {'word': 'نخلة', 'category': '🌍 طبيعة'},
    {'word': 'شجرة', 'category': '🌍 طبيعة'},
    {'word': 'مطر', 'category': '🌍 طبيعة'},
    {'word': 'برق', 'category': '🌍 طبيعة'},
    {'word': 'وردة', 'category': '🌍 طبيعة'},
    {'word': 'كرة', 'category': '⚽ رياضة'},
    {'word': 'سباحة', 'category': '⚽ رياضة'},
    {'word': 'ملاكمة', 'category': '⚽ رياضة'},
    {'word': 'تنس', 'category': '⚽ رياضة'},
    {'word': 'ركض', 'category': '⚽ رياضة'},
    {'word': 'غوص', 'category': '⚽ رياضة'},
    {'word': 'بتمان', 'category': '🎭 شخصيات'},
    {'word': 'فأر', 'category': '🎭 شخصيات'},
    {'word': 'ملك', 'category': '🎭 شخصيات'},
    {'word': 'شرطي', 'category': '🎭 شخصيات'},
    {'word': 'غناء', 'category': '🎭 أفعال'},
    {'word': 'نوم', 'category': '🎭 أفعال'},
    {'word': 'طيران', 'category': '🎭 أفعال'},
    {'word': 'بكاء', 'category': '🎭 أفعال'},
    {'word': 'رقص', 'category': '🎭 أفعال'},
    {'word': 'سباحة', 'category': '🎭 أفعال'},
    {'word': 'أكل', 'category': '🎭 أفعال'},
    {'word': 'قفز', 'category': '🎭 أفعال'},
  ];

  List<DrawPoint> _points = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 5.0;
  Map<String, String>? _currentWord;
  bool _drawing = false;
  bool _guessing = false; // Phase where guesser types answer
  bool _showResult = false;
  String _guessText = '';
  bool? _guessCorrect;
  final List<Map<String, dynamic>> _players = [];
  int _drawerIndex = 0;
  final _rand = Random();
  final _playerCtrl = TextEditingController();
  final _guessCtrl = TextEditingController();
  bool _started = false;
  final Set<int> _usedWordIndices = {};

  final List<Color> _palette = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.yellow,
    Colors.brown,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    final rawData = await RawDataManager.getGameData('pictionary_game', {});

    if (rawData.containsKey('items') && rawData['items'] is List) {
      List<Map<String, String>> parsedWords = [];
      for (var item in rawData['items']) {
        if (item is Map) {
          parsedWords.add({
            'word': item['word']?.toString() ?? '',
            'category': item['category']?.toString() ?? '',
          });
        }
      }

      if (parsedWords.isNotEmpty) {
        if (mounted) {
          setState(() {
            wordCategories = parsedWords;
            isLoadingData = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        wordCategories = _fallbackWordCategories;
        isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _playerCtrl.dispose();
    _guessCtrl.dispose();
    super.dispose();
  }

  void _pickWord() {
    if (SettingsService.isAiEnabled &&
        _started &&
        !_isGeneratingAi &&
        _usedWordIndices.length >= wordCategories.length - 2) {
      _generateAiContent(); // Auto-fetch in background
    }

    if (_usedWordIndices.length >= wordCategories.length) {
      _usedWordIndices.clear();
    }
    int idx;
    do {
      idx = _rand.nextInt(wordCategories.length);
    } while (_usedWordIndices.contains(idx));
    _usedWordIndices.add(idx);
    setState(() {
      _currentWord = wordCategories[idx];
      _points = [];
      _drawing = true;
      _guessing = false;
      _showResult = false;
      _guessText = '';
      _guessCorrect = null;
    });
    _guessCtrl.clear();
  }

  void _doneDrawing() {
    // Drawer finishes and passes phone to guesser
    setState(() {
      _drawing = false;
      _guessing = true;
    });
    AudioService.playClick();
  }

  void _submitGuess() {
    final guess = _guessCtrl.text.trim();
    if (guess.isEmpty) return;
    // Pass phone back to drawer to decide: we just show what was guessed
    setState(() {
      _guessText = guess;
      _guessCorrect = null; // Drawer decides
      _showResult = true;
      _guessing = false;
    });
    AudioService.playClick();
  }

  void _drawerDecide(bool correct) {
    setState(() {
      _guessCorrect = correct;
      if (correct && _players.isNotEmpty) {
        // Guesser gets 1 point
        final guessIdx = (_drawerIndex + 1) % _players.length;
        _players[guessIdx]['score'] = (_players[guessIdx]['score'] as int) + 1;
      }
      if (correct) {
        AudioService.playSuccess();
      } else {
        AudioService.playFailure();
      }
    });
  }

  void _nextRound() {
    if (_players.isNotEmpty) {
      setState(() {
        _drawerIndex = (_drawerIndex + 1) % _players.length;
      });
    }
    _pickWord();
  }

  String get _drawerName => _players.isNotEmpty
      ? _players[_drawerIndex % _players.length]['name']
      : 'الرسام';

  String get _guesserName => _players.length > 1
      ? _players[(_drawerIndex + 1) % _players.length]['name']
      : 'المخمن';


  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: FunkyColors.sky,
        body: GameIntroWidget(
          title: '🎨 ارسم وخمّن',
          icon: '🎨',
          description:
              'واحد يرسم والكل يخمّن! اللعبة اللي هتكشف مواهبك المدفونة في الرسم (أو الكارثية!)... مين هيقدر يوصّل المعلومة بالرسم؟',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (isLoadingData || wordCategories.isEmpty) {
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: FunkyColors.sky,
        body: const PremiumLoadingIndicator(message: 'جاري تجهيز الألوان...'),
      );
    }

    if (!_started) {
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: FlatColors.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  '🎨',
                  style: TextStyle(fontSize: 90),
                ).animate().scale(),
                const SizedBox(height: 12),
                Text(
                  'ارسم وخمّن!',
                  style: flatCairo(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                Text(
                  'واحد يرسم والباقي يخمّن!\nمين أسرع واحد هيعرف الكلمة؟ 🎨',
                  textAlign: TextAlign.center,
                  style: flatCairo(fontSize: 15, color: FlatColors.ink.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 50),
                FunkyButton(
                      accent: FunkyColors.sky,
                      icon: Icons.people_alt,
                      label: 'اختار شلتك وابدأ!',
                      fontSize: 22,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GlobalPlayerSelectionScreen(
                              gameTitle: 'ارسم وخمّن',
                              minPlayers: 2,
                              onStartGame: (ctx, selectedPlayers) {
                                Navigator.pop(ctx);
                                setState(() {
                                  _players.clear();
                                  _players.addAll(
                                    selectedPlayers.map(
                                      (name) => {'name': name, 'score': 0},
                                    ),
                                  );
                                  _drawerIndex = 0;
                                  _started = true;
                                  _pickWord();
                                });
                              },
                            ),
                          ),
                        );
                      },
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 1.seconds,
                    ),
              ],
            ),
          ),
        ),
      );
    }

    // ─── DRAWING PHASE ───────────────────────────────────────
    if (_drawing && _currentWord != null) {
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: FlatColors.bg,
        onAiRefresh: _generateAiContent,
        body: SafeArea(
          child: Column(
            children: [
              // Who is drawing
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: FlatDecor.card(radius: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🎨 $_drawerName يرسم',
                        style: flatCairo(
                          color: FlatColors.mintDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'الكلمة: ${_currentWord!['word']} (الرسام بس)',
                        style: flatCairo(
                          color: FlatColors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category only
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'الفئة: ${_currentWord!['category']}',
                  style: flatCairo(color: FlatColors.ink.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),

              // Drawing canvas
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: FlatDecor.card(radius: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GestureDetector(
                      onPanStart: (d) => setState(
                        () => _points.add(
                          DrawPoint(
                            d.localPosition,
                            _selectedColor,
                            _strokeWidth,
                          ),
                        ),
                      ),
                      onPanUpdate: (d) => setState(
                        () => _points.add(
                          DrawPoint(
                            d.localPosition,
                            _selectedColor,
                            _strokeWidth,
                          ),
                        ),
                      ),
                      onPanEnd: (_) => setState(
                        () => _points.add(
                          DrawPoint(null, _selectedColor, _strokeWidth),
                        ),
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: DrawingPainter(_points),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Color palette
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ..._palette.map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _selectedColor == color ? 38 : 28,
                          height: _selectedColor == color ? 38 : 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color
                                  ? FlatColors.ink
                                  : FlatColors.border,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _points.clear()),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FlatColors.mafia, width: 2),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: FlatColors.mafia,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.line_weight,
                      color: FlatColors.ink,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 2,
                        max: 25,
                        onChanged: (v) => setState(() => _strokeWidth = v),
                        activeColor: FlatColors.detective,
                      ),
                    ),
                  ],
                ),
              ),

              // Done drawing button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: _doneDrawing,
                  icon: const Icon(Icons.send_rounded, size: 22),
                  label: Text(
                    'خلصت الرسم! دي التلفون للمخمن 📱',
                    style: flatCairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(elevation: 0,
                    backgroundColor: FlatColors.mintDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─── GUESSING PHASE ──────────────────────────────────────
    if (_guessing) {
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: FlatColors.bg,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: FlatDecor.tile(FlatColors.day, radius: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    'دور المخمّن: $_guesserName',
                    style: flatCairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: FlatDecor.card(radius: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) => RepaintBoundary(
                      child: CustomPaint(
                        painter: DrawingPainter(_points),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _guessCtrl,
                autofocus: false,
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب تخمينك هنا...',
                  hintStyle: flatCairo(color: FlatColors.ink.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: FlatColors.border, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: FlatColors.border, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _submitGuess(),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _submitGuess,
                icon: const Icon(Icons.check_circle, size: 24),
                label: Text(
                  'تأكيد الإجابة ✅',
                  style: flatCairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(elevation: 0,
                  backgroundColor: FlatColors.day,
                  foregroundColor: FlatColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_showResult) {
      final isCorrect = _guessCorrect == true;
      final drawerName = _drawerName;
      const Color bgColor = FlatColors.bg; // flat: cream everywhere
      return OfflineGameScaffold(
        title: '🎨 ارسم وخمّن',
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─── Drawer decides ───
                  if (_guessCorrect == null) ...[
                    const Text(
                      '🎨',
                      style: TextStyle(fontSize: 80),
                    ).animate().scale(),
                    const SizedBox(height: 16),
                    Text(
                      'دي للراسم ($drawerName)',
                      style: flatCairo(
                        fontSize: 20,
                        color: FlatColors.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الفئة: ${_currentWord!['category']}',
                      style: flatCairo(
                        fontSize: 14,
                        color: FlatColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الكلمة الصحيحة:',
                      style: flatCairo(
                        fontSize: 15,
                        color: FlatColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: FlatDecor.tile(FlatColors.day, radius: 16),
                      child: Text(
                        _currentWord!['word']!,
                        style: flatCairo(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: FlatColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إجابة $_guesserName:',
                      style: flatCairo(
                        fontSize: 15,
                        color: FlatColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: FlatDecor.card(radius: 16),
                      child: Text(
                        _guessText,
                        style: flatCairo(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: FlatColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'هل إجابته صح؟',
                      style: flatCairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _drawerDecide(true),
                            icon: const Icon(Icons.check_circle, size: 30),
                            label: Text(
                              'صح ✅\n+1 نقطة',
                              textAlign: TextAlign.center,
                              style: flatCairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(elevation: 0,
                              backgroundColor: FlatColors.mintDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _drawerDecide(false),
                            icon: const Icon(Icons.cancel, size: 30),
                            label: Text(
                              'غلط ❌\nلا نقطة',
                              textAlign: TextAlign.center,
                              style: flatCairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(elevation: 0,
                              backgroundColor: FlatColors.mafia,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ─── Final result ───
                    Text(
                      isCorrect ? '🎉' : '😅',
                      style: const TextStyle(fontSize: 100),
                    ).animate().scale(),
                    const SizedBox(height: 20),
                    Text(
                      isCorrect ? 'صح! 🏆 نقطة لـ $_guesserName!' : 'مش صح 😅',
                      style: flatCairo(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: isCorrect ? FlatColors.mintDark : FlatColors.mafia,
                      ),
                    ).animate().fadeIn(),
                    const SizedBox(height: 12),
                    Text(
                      'الكلمة: ${_currentWord!['word']}',
                      style: flatCairo(
                        fontSize: 20,
                        color: FlatColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                    if (_players.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: FlatDecor.card(radius: 16),
                        child: Wrap(
                          spacing: 20,
                          alignment: WrapAlignment.center,
                          children: _players
                              .map(
                                (p) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p['name'],
                                      style: flatCairo(
                                        color: FlatColors.ink,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${p['score']} نقطة',
                                      style: flatCairo(
                                        color: FlatColors.ink.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    FunkyButton(
                      onPressed: _nextRound,
                      icon: Icons.play_arrow,
                      label: 'دور جديد 🎨',
                      accent: FunkyColors.violet,
                      fontSize: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return OfflineGameScaffold(
      title: '🎨 ارسم وخمّن',
      backgroundColor: FlatColors.bg,
      body: Center(
        child: FunkyButton(
          onPressed: _pickWord,
          label: 'ابدأ',
          accent: FunkyColors.sky,
        ),
      ),
    );
  }
}


