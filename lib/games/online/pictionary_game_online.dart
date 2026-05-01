import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../widgets/player_avatar.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/haptic_service.dart';

// ─── Drawing models ───────────────────────────────
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
    if (points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].point != null && points[i + 1].point != null) {
        paint
          ..color = points[i].color
          ..strokeWidth = points[i].strokeWidth;

        // Scale points to current canvas size for cross-device consistency
        final p1 = Offset(
          points[i].point!.dx * size.width,
          points[i].point!.dy * size.height,
        );
        final p2 = Offset(
          points[i + 1].point!.dx * size.width,
          points[i + 1].point!.dy * size.height,
        );
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter old) => true;
}

class PictionaryGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const PictionaryGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<PictionaryGameOnline> createState() => _PictionaryGameOnlineState();
}

class _PictionaryGameOnlineState extends State<PictionaryGameOnline> {
  // Game State
  List<DrawPoint> _points = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 6.0;
  String? _currentWord;
  String? _currentCategory;
  String? _drawerId;
  bool _gameStarted = false;
  bool _isGeneratingAi = false;
  int _drawerIndex = 0;
  final TextEditingController _guessCtrl = TextEditingController();

  // Scoring
  final Map<String, int> _scores = {};

  final List<Color> _palette = [
    Colors.black,
    Colors.red,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.yellow,
    Colors.brown,
    Colors.grey,
  ];

  final List<String> _categories = [
    '🐾 حيوانات',
    '🍕 أكل',
    '🚗 مواصلات',
    '🏠 أشياء',
    '🌍 طبيعة',
    '🎭 أفعال',
  ];
  final Set<String> _selectedCategories = {'🐾 حيوانات', '🍕 أكل'};

  @override
  void initState() {
    super.initState();
    _initScores();
    _setupSocket();
  }

  void _initScores() {
    if (widget.roomPlayers != null) {
      for (var p in widget.roomPlayers!) {
        _scores[p['id'].toString()] = 0;
      }
    }
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onPictionarySync);
  }

  void _onPictionarySync(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    final type = move['type'];

    setState(() {
      if (type == 'start_game') {
        _drawerId = move['drawerId'];
        _currentWord = move['word'];
        _currentCategory = move['category'];
        _points = [];
        _gameStarted = true;
        _guessCtrl.clear();
        AudioService.playTick();
        _showTurnNotification();
      } else if (type == 'draw_point') {
        final dx = move['dx']?.toDouble();
        final dy = move['dy']?.toDouble();
        final color = Color(move['color']);
        final width = move['width'].toDouble();
        _points.add(
          DrawPoint(dx == null ? null : Offset(dx, dy!), color, width),
        );
      } else if (type == 'clear') {
        _points = [];
      } else if (type == 'correct_guess') {
        final winnerId = move['playerId'];
        if (_scores.containsKey(winnerId)) {
          _scores[winnerId] = (_scores[winnerId] ?? 0) + 1;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 ${move['playerName']} حزرها! الكلمة كانت: $_currentWord',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        AudioService.playSuccess();
        HapticService.vibrate();

        // Host will trigger next round if applicable
        if (widget.isHost) {
          Future.delayed(const Duration(seconds: 3), _nextTurn);
        }
      }
    });
  }

  void _showTurnNotification() {
    final drawerName = (widget.roomPlayers != null)
        ? widget.roomPlayers!.firstWhere(
            (p) => p['id'] == _drawerId,
            orElse: () => {'name': 'الرسام'},
          )['name']
        : 'الرسام';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMyTurn
              ? 'دورك ترسم الحين! 🎨'
              : 'الرسام الحين هو: $drawerName 🕵️',
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool get _isMyTurn => _drawerId == SocketService().socket.id;

  Future<void> _start() async {
    if (!widget.isHost || _isGeneratingAi) return;

    setState(() => _isGeneratingAi = true);

    String word = 'شجرة';
    String category = '🌍 طبيعة';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'pictionary',
          count: 5,
          history: [],
        );
        if (content.isNotEmpty) {
          final first = content[0];
          word = (first['word'] ?? first['text'] ?? 'شجرة').toString();
          category = (first['category'] ?? first['cat'] ?? 'عام').toString();
        }
      } catch (e) {
        debugPrint('AI failed: $e');
      }
    }

    setState(() => _isGeneratingAi = false);

    _drawerIndex = 0;
    _emitTurn(
      word,
      category,
      widget.roomPlayers?[_drawerIndex]['id'] ?? SocketService().socket.id,
    );
  }

  void _nextTurn() async {
    if (!widget.isHost) return;

    _drawerIndex = (_drawerIndex + 1) % (widget.roomPlayers?.length ?? 1);

    // Fetch new word
    String word = 'تفاحة';
    String category = '🍕 أكل';

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'pictionary',
          count: 1,
        );
        if (content.isNotEmpty) {
          word = content[0]['word'].toString();
          category = content[0]['category'].toString();
        }
      } catch (_) {}
    }

    _emitTurn(
      word,
      category,
      widget.roomPlayers?[_drawerIndex]['id'] ?? SocketService().socket.id,
    );
  }

  void _emitTurn(String word, String cat, String pid) {
    final moveData = {
      'type': 'start_game',
      'word': word,
      'category': cat,
      'drawerId': pid,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onPictionarySync(moveData);
  }

  void _emitPoint(Offset? localPos, Size size) {
    if (!_isMyTurn) return;
    final moveData = {
      'type': 'draw_point',
      'dx': localPos?.dx != null ? localPos!.dx / size.width : null,
      'dy': localPos?.dy != null ? localPos!.dy / size.height : null,
      'color': _selectedColor.value,
      'width': _strokeWidth,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onPictionarySync(moveData);
  }

  void _emitClear() {
    if (!_isMyTurn) return;
    final moveData = {'type': 'clear'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onPictionarySync(moveData);
  }

  void _submitGuess() {
    if (_guessCtrl.text.trim().toLowerCase() == _currentWord?.toLowerCase()) {
      final moveData = {
        'type': 'correct_guess',
        'playerName': widget.playerName ?? 'لاعب',
        'playerId': SocketService().socket.id,
      };

      SocketService().socket.emit('game_move', {
        'roomCode': widget.roomCode,
        'moveData': moveData,
      });

      _onPictionarySync(moveData);
      _guessCtrl.clear();
    } else {
      AudioService.playFailure();
      _guessCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ! حاول تاني ❌'),
          backgroundColor: Colors.redAccent,
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _guessCtrl.dispose();
    SocketService().socket.off('game_move', _onPictionarySync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'pictionary',
      title: 'خمن الرسمة (أونلاين)',
      backgroundColor: const Color(0xFF0F172A),
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Column(
        children: [
          _buildTopPanel(),
          Expanded(child: _buildCanvasArea()),
          if (_gameStarted) ...[
            if (_isMyTurn) _buildDrawerTools() else _buildGuessingInput(),
          ],
          if (widget.isHost && !_gameStarted) _buildStartSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gameStarted
                        ? 'الفئة: $_currentCategory'
                        : 'استعدوا للرسم!',
                    style: GoogleFonts.cairo(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  if (_gameStarted && _isMyTurn)
                    Text(
                      'ارسم: $_currentWord',
                      style: GoogleFonts.cairo(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        shadows: [
                          const Shadow(
                            color: Colors.cyanAccent,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  if (_gameStarted && !_isMyTurn)
                    Text(
                      'خمّن الآن...',
                      style: GoogleFonts.cairo(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        shadows: [
                          const Shadow(
                            color: Colors.pinkAccent,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.brush_rounded,
                  color: Colors.blueAccent,
                  size: 28,
                ),
              ),
            ],
          ),
          if (_gameStarted) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(color: Colors.white10, height: 1),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _scores.entries.map((e) {
                  final isMe = e.key == SocketService().socket.id;
                  final pName =
                      widget.roomPlayers?.firstWhere(
                        (p) => p['id'] == e.key,
                        orElse: () => {'name': 'لاعب'},
                      )['name'] ??
                      'لاعب';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blueAccent.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isMe
                            ? Colors.blueAccent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildPlayerAvatar(pName, e.key),
                        const SizedBox(width: 8),
                        Text(
                          pName,
                          style: GoogleFonts.cairo(
                            color: isMe ? Colors.blueAccent : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(' ⭐', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildCanvasArea() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Subtle grid pattern for drawing
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: CustomPaint(painter: GridPainter()),
                  ),
                ),
                GestureDetector(
                  onPanStart: _isMyTurn
                      ? (d) => _emitPoint(d.localPosition, size)
                      : null,
                  onPanUpdate: _isMyTurn
                      ? (d) => _emitPoint(d.localPosition, size)
                      : null,
                  onPanEnd: _isMyTurn ? (_) => _emitPoint(null, size) : null,
                  child: CustomPaint(
                    painter: DrawingPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildDrawerTools() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._palette.map(
                  (c) => GestureDetector(
                    onTap: () {
                      HapticService.lightImpact();
                      setState(() => _selectedColor = c);
                    },
                    child: AnimatedContainer(
                      duration: 300.ms,
                      curve: Curves.elasticOut,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: _selectedColor == c ? 42 : 32,
                      height: _selectedColor == c ? 42 : 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == c
                              ? Colors.white
                              : Colors.white24,
                          width: 3,
                        ),
                        boxShadow: [
                          if (_selectedColor == c)
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                IconButton(
                  onPressed: () {
                    HapticService.vibrate(duration: 50);
                    _emitClear();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.line_weight, color: Colors.white38, size: 18),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 2,
                  max: 24,
                  onChanged: (v) => setState(() => _strokeWidth = v),
                  activeColor: Colors.cyanAccent,
                  inactiveColor: Colors.white10,
                ),
              ),
              Text(
                '${_strokeWidth.toInt()}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildGuessingInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: TextField(
                controller: _guessCtrl,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'وش تتوقع الرسمة؟...',
                  hintStyle: GoogleFonts.cairo(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(35),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(35),
                    borderSide: const BorderSide(
                      color: Colors.pinkAccent,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submitGuess(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _submitGuess,
            child: Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.pinkAccent, Colors.purpleAccent],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.3),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildStartSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'اختر الفئات المفضلة:',
            style: GoogleFonts.cairo(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _categories.map((cat) {
              final sel = _selectedCategories.contains(cat);
              return GestureDetector(
                onTap: () {
                  HapticService.lightImpact();
                  setState(() {
                    if (sel) {
                      if (_selectedCategories.length > 1) {
                        _selectedCategories.remove(cat);
                      }
                    } else {
                      _selectedCategories.add(cat);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.blueAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? Colors.blueAccent : Colors.white10,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.cairo(
                      color: sel ? Colors.blueAccent : Colors.white60,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 35),
          if (_isGeneratingAi)
            const CircularProgressIndicator(color: Colors.blueAccent)
          else
            GestureDetector(
              onTap: _start,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.cyanAccent],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  'ابدأ الرسم 🚀',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ).animate().scale(),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPlayerAvatar(String playerName, [String? socketId]) {
    final player = SocketService().currentPlayers.firstWhere(
      (p) =>
          (p['playerName'] ?? p['name'])?.toString().trim().toLowerCase() ==
          playerName.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final String? playerId = socketId ?? player['id']?.toString();
    final String? avatar = player['avatar']?.toString();

    return PlayerAvatar(
      name: playerName,
      avatar: avatar,
      playerId: playerId,
      size: 24,
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => false;
}
