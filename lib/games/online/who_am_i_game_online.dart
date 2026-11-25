import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/haptic_service.dart';
import '../../data/who_am_i_data.dart';
import '../../widgets/game_result_overlay.dart';
import '../../theme/funky_theme.dart';


class WhoAmIGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const WhoAmIGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<WhoAmIGameOnline> createState() => _WhoAmIGameOnlineState();
}

class _WhoAmIGameOnlineState extends State<WhoAmIGameOnline> {
  // Game State
  bool _gameStarted = false;
  int _hintsRevealed = 0;
  bool _answered = false;
  List<bool> _revealedHints = [];
  int _currentIndex = 0;
  int _currentPlayerTurn = 0;
  List<Map<String, dynamic>> _shuffled = [];
  bool _isGeneratingAi = false;
  bool _showOverlay = false;
  String? _winnerName;


  // Categories for the host
  final List<String> _categories = [
    '🎭 شخصيات عامة',
    '⚽ رياضيون',
    '🎬 ممثلون',
    '🦒 حيوانات',
    '💡 مخترعون',
    '🌍 تاريخي',
  ];
  final Set<String> _selectedCategories = {'🎭 شخصيات عامة'};

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onGameMove);
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['game'] != 'who_am_i') return;

    setState(() {
      final type = move['type'];
      if (type == 'start_game') {
        _gameStarted = true;
        _currentPlayerTurn = move['currentPlayerTurn'] ?? 0;
        _currentIndex = move['currentIndex'] ?? 0;
        _shuffled = List<Map<String, dynamic>>.from(move['shuffled']);
        _hintsRevealed = 0;
        _answered = false;
        _revealedHints = List<bool>.filled((_shuffled[_currentIndex]['hints'] as List).length, false);
        AudioService.playTick();
        _showStartSnackBar();
      } else if (type == 'next_card') {
        _currentPlayerTurn = move['currentPlayerTurn'];
        _currentIndex = move['currentIndex'];
        _hintsRevealed = 0;
        _answered = false;
        _revealedHints = List<bool>.filled((_shuffled[_currentIndex]['hints'] as List).length, false);
        AudioService.playTick();
        HapticService.vibrate();
        _showTurnNotification();
      } else if (type == 'show_hint') {
        int index = move['index'];
        _hintsRevealed = move['hintsRevealed'];
        _revealedHints[index] = true;
        AudioService.playTick();
        HapticService.vibrate();
      } else if (type == 'correct_guess') {
        _answered = true;
        _winnerName = move['winnerName'];
        _showOverlay = true;
        AudioService.playSuccess();
      } else if (type == 'show_answer') {

        _answered = true;
        _revealedHints = List<bool>.filled((_shuffled[_currentIndex]['hints'] as List).length, true);
        AudioService.playFailure();
      }
    });
  }

  void _showStartSnackBar() {
    final subjectName = (widget.roomPlayers != null && _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn]['name'] : 'اللاعب';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('بدأنا! الدور على: $subjectName 👤'),
        backgroundColor: Colors.indigo,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _start() async {
    if (!widget.isHost || _isGeneratingAi) return;

    setState(() => _isGeneratingAi = true);

    List<Map<String, dynamic>> gameData = [];

    if (SettingsService.isAiEnabled) {
      try {
        final content = await AIService.fetchGameContent(
          'who_am_i',
          count: 10,
          history: [], // Could track history if needed
        );
        if (content.isNotEmpty) {
          gameData = content.map((item) => {
            'name': (item['name'] ?? item['character'] ?? 'مجهول').toString(),
            'hints': item['hints'] is List
                ? List<String>.from(item['hints'].map((e) => e.toString()))
                : ['لا يوجد معلومات إضافية'],
            'icon': item['icon']?.toString() ?? '👤',
          }).toList();
        }
      } catch (e) {
        debugPrint('AI generation failed: $e');
      }
    }

    // Fallback to local data if AI fails or is disabled
    if (gameData.isEmpty) {
      gameData = List.from(whoAmIData)..shuffle();
      if (gameData.length > 15) gameData = gameData.sublist(0, 15);
    }

    setState(() => _isGeneratingAi = false);

    final moveData = {
      'game': 'who_am_i',
      'type': 'start_game',
      'shuffled': gameData,
      'currentIndex': 0,
      'currentPlayerTurn': 0,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _reveal() {
    final hints = _shuffled[_currentIndex]['hints'] as List;
    if (_hintsRevealed >= hints.length) return;

    final moveData = {
      'game': 'who_am_i',
      'type': 'show_hint',
      'index': _hintsRevealed,
      'hintsRevealed': _hintsRevealed + 1,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  void _showAnswer() {
    final moveData = {'game': 'who_am_i', 'type': 'show_answer'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData
    });
    _onGameMove(moveData);
  }

  void _next() {
    int nextTurn = (_currentPlayerTurn + 1) % (widget.roomPlayers?.length ?? 1);
    int nextIndex = (_currentIndex + 1) % _shuffled.length;

    final moveData = {
      'game': 'who_am_i',
      'type': 'next_card',
      'currentPlayerTurn': nextTurn,
      'currentIndex': nextIndex,
    };

    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });

    _onGameMove(moveData);
  }

  @override
  void dispose() {
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }



  String _getPlayerName(String id) {
    if (widget.roomPlayers == null) return 'لاعب';
    final player = widget.roomPlayers!.firstWhere((p) => p['id'] == id, orElse: () => null);
    return player?['name'] ?? 'لاعب';
  }

  void _showTurnNotification() {
    if (!mounted) return;
    final isMe = _currentPlayerTurn < (widget.roomPlayers?.length ?? 0) &&
        widget.roomPlayers![_currentPlayerTurn]['id'] == SocketService().socket.id;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isMe ? 'بدأ دورك! 🕵️' : 'بدأ دور ${_getPlayerName(widget.roomPlayers![_currentPlayerTurn]['id'])}'),
        backgroundColor: isMe ? Colors.greenAccent[700] : Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'who_am_i',
      title: 'من أنا؟ (أونلاين)',
      backgroundColor: FunkyColors.sky,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Stack(
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _gameStarted ? _buildGameUI() : _buildSetupUI(),
            ),
          ),
          if (_showOverlay)
            GameResultOverlay(
              isWin: true, // In this game, a correct guess is a win for the team/subject
              title: 'توقع صحيح! 🎯',
              subtitle: '$_winnerName عرف الإجابة بذكاء!',
              onDismiss: () => setState(() => _showOverlay = false),
            ),
        ],
      ),

    );
  }


  Widget _buildSetupUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text('🎭', style: TextStyle(fontSize: 60)),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 25),
          Text(
            'مين أنا؟',
            style: GoogleFonts.cairo(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,

            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.isHost 
              ? 'جهز اللعبة لشلتك بذكاء!' 
              : 'بانتظار المضيف يضبط الشخصيات...',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 16, color: Colors.white54),
          ),
          const SizedBox(height: 40),
          if (widget.isHost) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategories.contains(cat);
                  return GestureDetector(
                    onTap: () {
                      HapticService.lightImpact();
                      setState(() {
                        if (isSelected) {
                          if (_selectedCategories.length > 1) _selectedCategories.remove(cat);
                        } else {
                          _selectedCategories.add(cat);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amberAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.01),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white10),
                      ),
                      child: Text(cat, style: GoogleFonts.cairo(color: isSelected ? Colors.amberAccent : Colors.white38, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 50),
            _isGeneratingAi 
              ? const CircularProgressIndicator(color: Colors.amberAccent)
              : GestureDetector(
                  onTap: _start,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent]),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: Text('ابدأ التحدي 🕵️', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ).animate().scale(),
          ],
        ],
      ),
    );
  }

  Widget _buildGameUI() {
    final currentCard = _shuffled[_currentIndex];
    final hints = List<String>.from(currentCard['hints']);
    final currentSubject = (widget.roomPlayers != null && _currentPlayerTurn < widget.roomPlayers!.length)
        ? widget.roomPlayers![_currentPlayerTurn] : null;
    
    final isMyTurn = currentSubject != null && currentSubject['id'] == SocketService().socket.id;
    final subjectName = currentSubject?['name'] ?? 'لاعب';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          // Turn Display
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isMyTurn ? Icons.visibility_off : Icons.person_search_rounded, 
                  color: isMyTurn ? Colors.greenAccent : Colors.amberAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  isMyTurn ? 'أنت الشخصية المجهولة! 🤐' : 'خمن الشخصية: $subjectName',
                  style: GoogleFonts.cairo(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: isMyTurn ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),
          
          const SizedBox(height: 30),

          // Main Reveal Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(currentCard['icon'] ?? '👤', style: const TextStyle(fontSize: 60)),
                ),
                const SizedBox(height: 25),
                if (_answered)
                  Text(
                    currentCard['name'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                      shadows: [const Shadow(color: Colors.amberAccent, blurRadius: 15)],
                    ),
                  ).animate().scale(curve: Curves.easeOutBack)
                else
                  Text(
                    isMyTurn ? '؟؟؟' : currentCard['name'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: isMyTurn ? 54 : 30,
                      fontWeight: FontWeight.bold,
                      color: isMyTurn ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    ),
                  ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 25),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // Hints Section
                ...List.generate(
                  _answered ? hints.length : _hintsRevealed,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            hints[i],
                            style: GoogleFonts.cairo(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideX(begin: 0.1),
                ),
                
                if (!_answered && _hintsRevealed == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('المضيف سيكشف التلميحات تدريجياً...', style: GoogleFonts.cairo(color: Colors.white24, fontSize: 13)),
                  ).animate(onPlay: (c)=>c.repeat()).shimmer(duration: 2.seconds),
              ],
            ),
          ).animate(key: ValueKey('$_currentIndex-$_answered')).fadeIn().scale(curve: Curves.easeOut),

          const SizedBox(height: 40),

          // Controls
          if (widget.isHost) ...[
            if (!_answered) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      onPressed: _hintsRevealed < hints.length ? _reveal : null,
                      icon: Icons.lightbulb_rounded,
                      label: 'تلميح 💡',
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildActionBtn(
                      onPressed: _showAnswer,
                      icon: Icons.check_circle_rounded,
                      label: 'كشف ✅',
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ] else
              _buildActionBtn(
                onPressed: _next,
                icon: Icons.skip_next_rounded,
                label: 'الشخصية التالية ➡️',
                color: Colors.blueAccent,
                fullWidth: true,
              ),
          ] else if (!isMyTurn)
            Container(
              padding: const EdgeInsets.all(15),
              child: Text('المضيف يقود اللعبة الآن، انتظر التلميحات!', style: GoogleFonts.cairo(color: Colors.white24, fontSize: 12)),
            ),
          
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        boxShadow: [
          if (onPressed != null) BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 20),
        label: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
      ),
    ).animate().fadeIn();
  }
}
