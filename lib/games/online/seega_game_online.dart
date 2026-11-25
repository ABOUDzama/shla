import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/audio_service.dart';
import '../../services/socket_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

class SeegaGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? opponentName;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const SeegaGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.opponentName,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<SeegaGameOnline> createState() => _SeegaGameOnlineState();
}

class _SeegaGameOnlineState extends State<SeegaGameOnline> {
  List<int> board = List.filled(9, 0);
  int currentPlayer = 1;
  int piecesPlaced1 = 0;
  int piecesPlaced2 = 0;
  int? selectedIndex;
  String? winner;
  bool isPlacementPhase = true;

  @override
  void initState() {
    super.initState();
    SocketService().socket.on('seega_state_updated', _onGameMove);
    SocketService().socket.on('game_move', _onGameMove);
    SocketService().socket.on('reset_game', _onResetGame);
  }

  @override
  void dispose() {
    SocketService().socket.off('seega_state_updated', _onGameMove);
    SocketService().socket.off('game_move', _onGameMove);
    SocketService().socket.off('reset_game', _onResetGame);
    super.dispose();
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['index'] != null) {
      _processTap(move['index'], isFromNetwork: true);
    }
  }

  void _onResetGame(dynamic data) {
    if (!mounted) return;
    _localReset();
  }

  void _handleTap(int index) {
    _processTap(index, isFromNetwork: false);
  }

  void _processTap(int index, {required bool isFromNetwork}) {
    if (winner != null) return;

    if (!isFromNetwork) {
      bool myTurn = false;
      if (widget.isHost && currentPlayer == 1) myTurn = true;
      if (!widget.isHost && currentPlayer == 2) myTurn = true;
      if (!myTurn) return;
    }

    if (isPlacementPhase) {
      _handlePlacement(index);
    } else {
      _handleMovement(index);
    }

    if (!isFromNetwork) {
      SocketService().socket.emit('seega_state_updated', {
        'roomCode': widget.roomCode,
        'moveData': {'index': index},
      });
    }
  }

  void _handlePlacement(int index) {
    if (board[index] != 0) return;
    setState(() {
      board[index] = currentPlayer;
      if (currentPlayer == 1) {
        piecesPlaced1++;
      } else {
        piecesPlaced2++;
      }
      if (piecesPlaced1 == 3 && piecesPlaced2 == 3) isPlacementPhase = false;
      currentPlayer = currentPlayer == 1 ? 2 : 1;
    });
  }

  void _handleMovement(int index) {
    if (selectedIndex == null) {
      if (board[index] == currentPlayer) setState(() => selectedIndex = index);
    } else {
      if (_isAdjacent(selectedIndex!, index) && board[index] == 0) {
        setState(() {
          board[index] = currentPlayer;
          board[selectedIndex!] = 0;
          selectedIndex = null;
          _checkWinner();
          currentPlayer = currentPlayer == 1 ? 2 : 1;
          HapticService.vibrate();
          AudioService.playTick();
        });
      } else if (board[index] == currentPlayer) {
        setState(() => selectedIndex = index);
      }
    }
  }

  bool _isAdjacent(int from, int to) {
    int rowFrom = from ~/ 3, colFrom = from % 3;
    int rowTo = to ~/ 3, colTo = to % 3;
    return (rowFrom == rowTo && (colFrom - colTo).abs() == 1) ||
        (colFrom == colTo && (rowFrom - rowTo).abs() == 1);
  }

  void _checkWinner() {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (var line in lines) {
      if (board[line[0]] != 0 &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        setState(() => winner = board[line[0]] == 1 ? 'الأحمر' : 'الأزرق');
        return;
      }
    }
  }

  void _localReset() {
    setState(() {
      board = List.filled(9, 0);
      currentPlayer = 1;
      piecesPlaced1 = 0;
      piecesPlaced2 = 0;
      selectedIndex = null;
      winner = null;
      isPlacementPhase = true;
    });
  }

  void _resetGame() {
    _localReset();
    SocketService().socket.emit('reset_game', {'roomCode': widget.roomCode});
  }

  @override
  Widget build(BuildContext context) {
    bool myTurn =
        (widget.isHost && currentPlayer == 1) ||
        (!widget.isHost && currentPlayer == 2);
    final statusText = winner != null
        ? 'المنتصر: $winner! 🏆'
        : (myTurn
              ? 'دورك الحين! 🔥'
              : 'دور ${widget.opponentName ?? "الخصم"} ⏳');

    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'seega',
      title: 'لعبة السيجة (أونلاين)',
      backgroundColor: FunkyColors.orange,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      showAi: false,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        const BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          isPlacementPhase ? 'مرحلة التوزيع' : 'مرحلة التحريك',
                          style: GoogleFonts.cairo(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isPlacementPhase
                              ? 'حط حصواتك الـ 3 في الأماكن الفاضية'
                              : 'حرك حصواتك جنب بعض عشان تكسب',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),

                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (currentPlayer == 1
                                  ? Colors.redAccent
                                  : Colors.blueAccent)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            (currentPlayer == 1
                                    ? Colors.redAccent
                                    : Colors.blueAccent)
                                .withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: winner != null
                            ? Colors.amberAccent
                            : Colors.white,
                      ),
                    ),
                  ).animate(key: ValueKey(statusText)).scale().fadeIn(),

                  const SizedBox(height: 40),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white12, width: 2),
                      boxShadow: [
                        const BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final value = board[index];
                          final isSelected = selectedIndex == index;

                          return GestureDetector(
                            onTap: () => _handleTap(index),
                            child: AnimatedContainer(
                              duration: 300.ms,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.amberAccent.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.amberAccent
                                      : Colors.white10,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: value == 0
                                    ? null
                                    : Container(
                                        width: 55,
                                        height: 55,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            center: const Alignment(-0.3, -0.3),
                                            radius: 0.8,
                                            colors: value == 1
                                                ? [
                                                    const Color(0xFFF87171),
                                                    const Color(0xFFB91C1C),
                                                  ]
                                                : [
                                                    const Color(0xFF60A5FA),
                                                    const Color(0xFF1D4ED8),
                                                  ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (value == 1
                                                          ? Colors.redAccent
                                                          : Colors.blueAccent)
                                                      .withValues(alpha: 0.5),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.white24,
                                            width: 2,
                                          ),
                                        ),
                                      ).animate().scale(
                                        curve: Curves.easeOutBack,
                                        duration: 500.ms,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ).animate().fadeIn().scale(delay: 300.ms),

                  const SizedBox(height: 50),

                  if (winner != null)
                    GestureDetector(
                      onTap: _resetGame,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          'إعادة التحدي 🔄',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ).animate().fadeIn().scale(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
