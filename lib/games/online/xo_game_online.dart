import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../widgets/player_avatar.dart';
import '../../services/socket_service.dart' as ss;
import '../../services/haptic_service.dart';
import '../../widgets/game_result_overlay.dart';
import '../../theme/funky_theme.dart';

class TicTacToeGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? opponentName;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const TicTacToeGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.opponentName,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<TicTacToeGameOnline> createState() => _TicTacToeGameOnlineState();
}

class _TicTacToeGameOnlineState extends State<TicTacToeGameOnline> {
  List<String> board = List.filled(9, '');
  bool isXTurn = true;
  String? winner;
  bool isDraw = false;
  List<int>? winningLine;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    ss.SocketService().socket.on('game_move', _onGameMove);
    ss.SocketService().socket.on('reset_game', _onResetGame);
  }

  @override
  void dispose() {
    ss.SocketService().socket.off('game_move', _onGameMove);
    ss.SocketService().socket.off('reset_game', _onResetGame);
    super.dispose();
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    if (move['index'] != null) {
      int index = move['index'];
      setState(() {
        board[index] = isXTurn ? 'X' : 'O';
        isXTurn = !isXTurn;
        _checkWinner();
        HapticService.vibrate();
      });
    }
  }

  void _onResetGame(dynamic data) {
    if (!mounted) return;
    _localReset();
  }

  void _handleTap(int index) {
    if (board[index] != '' || winner != null) return;

    bool myTurn = (widget.isHost && isXTurn) || (!widget.isHost && !isXTurn);
    if (!myTurn) return;

    setState(() {
      board[index] = isXTurn ? 'X' : 'O';
      isXTurn = !isXTurn;
      _checkWinner();
    });

    ss.SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {'index': index},
    });
  }

  void _checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Cols
      [0, 4, 8], [2, 4, 6], // Diagonals
    ];

    for (var line in lines) {
      if (board[line[0]] != '' &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        setState(() {
          winner = board[line[0]];
          winningLine = line;
          _showOverlay = true;
        });
        return;
      }
    }

    if (!board.contains('')) {
      setState(() {
        isDraw = true;
        _showOverlay = true;
      });
    }
  }

  void _localReset() {
    setState(() {
      board = List.filled(9, '');
      isXTurn = true;
      winner = null;
      isDraw = false;
      winningLine = null;
      _showOverlay = false;
      HapticService.vibrate();
    });
  }

  void _resetGame() {
    _localReset();
    ss.SocketService().socket.emit('reset_game', {'roomCode': widget.roomCode});
  }

  @override
  Widget build(BuildContext context) {
    bool myTurn = (widget.isHost && isXTurn) || (!widget.isHost && !isXTurn);
    final statusText = winner != null
        ? 'الفائز: $winner ✨'
        : isDraw
        ? 'تعادل! 🤝'
        : (myTurn
              ? 'دورك الحين! 🔥'
              : 'دور ${widget.opponentName ?? "الخصم"} ⏳');

    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'xo',
      title: 'إكس أو أونلاين',
      backgroundColor: FunkyColors.mint,
      roomCode: widget.roomCode,
      myId: ss.SocketService().socket.id,
      playerName: widget.playerName,
      showAi: false,
      actions: [
        if (winner != null || isDraw)
          ...(widget.isHost
              ? [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                    onPressed: _resetGame,
                  ),
                ]
              : []),
      ],
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        const BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: winner != null
                            ? Colors.amberAccent
                            : Colors.white,
                      ),
                    ),
                  ).animate(key: ValueKey(statusText)).scale().fadeIn(),

                  const SizedBox(height: 25),

                  // Player Avatars Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPlayerAvatar(
                        widget.playerName ?? 'أنت',
                        isX: widget.isHost,
                      ),
                      const SizedBox(width: 40),
                      _buildPlayerAvatar(
                        widget.opponentName ?? 'الخصم',
                        isX: !widget.isHost,
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
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
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final value = board[index];
                          final isWinCell =
                              winningLine?.contains(index) ?? false;

                          return GestureDetector(
                            onTap: () => _handleTap(index),
                            child: AnimatedContainer(
                              duration: 300.ms,
                              decoration: BoxDecoration(
                                color: isWinCell
                                    ? (value == 'X'
                                              ? Colors.blueAccent
                                              : Colors.redAccent)
                                          .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isWinCell
                                      ? (value == 'X'
                                            ? Colors.blueAccent
                                            : Colors.redAccent)
                                      : Colors.white10,
                                  width: isWinCell ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: value == ''
                                    ? null
                                    : Text(
                                            value,
                                            style: GoogleFonts.permanentMarker(
                                              fontSize: 50,
                                              fontWeight: FontWeight.bold,
                                              color: value == 'X'
                                                  ? Colors.blueAccent
                                                  : Colors.redAccent,
                                              shadows: [
                                                Shadow(
                                                  color:
                                                      (value == 'X'
                                                              ? Colors
                                                                    .blueAccent
                                                              : Colors
                                                                    .redAccent)
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                  blurRadius: 15,
                                                ),
                                              ],
                                            ),
                                          )
                                          .animate()
                                          .scale(
                                            curve: Curves.easeOutBack,
                                            duration: 400.ms,
                                          )
                                          .fadeIn(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ).animate().fadeIn().scale(delay: 200.ms),

                  const SizedBox(height: 50),

                  if (winner != null || isDraw)
                    GestureDetector(
                      onTap: _resetGame,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'إعادة اللعب',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().scale(),
                ],
              ),
            ),
          ),
          if (_showOverlay)
            GameResultOverlay(
              isWin: winner == (widget.isHost ? 'X' : 'O'),
              title: isDraw
                  ? 'تعادل! 🤝'
                  : (winner == (widget.isHost ? 'X' : 'O')
                        ? 'وحش يا بطل! 🥇'
                        : 'حظ أوفر! 🥀'),
              subtitle: isDraw
                  ? 'محدش غلب التاني المرة دي'
                  : (winner == (widget.isHost ? 'X' : 'O')
                        ? 'أداء أسطوري وتكتيك عالي'
                        : 'المرة الجاية هتجيب حقك!'),
              onDismiss: () => setState(() => _showOverlay = false),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar(String name, {bool isX = true}) {
    // Find player data to get the socket ID
    final player = widget.roomPlayers?.firstWhere(
      (p) =>
          (p['playerName'] ?? p['name'])?.toString().trim().toLowerCase() ==
          name.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    final String? playerId = player?['id']?.toString();
    final String? avatar = player?['avatar']?.toString();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatar(
              name: name,
              avatar: avatar,
              playerId: playerId,
              size: 60,
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isX ? Colors.blueAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  isX ? 'X' : 'O',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
