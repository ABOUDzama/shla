import 'package:flutter/material.dart';
import '../../services/results_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/score_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';
import '../../screens/settings_screen.dart';

class TicTacToeGame extends StatefulWidget {
  final bool online;
  final bool isHost;
  final String? roomCode;
  final String? opponentName;

  const TicTacToeGame({
    super.key,
    this.online = false,
    this.isHost = true,
    this.roomCode,
    this.opponentName,
  });

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  static const Color _xColor = Color(0xFFFF8A5C); // coral
  static const Color _oColor = Color(0xFF4D8DFF); // sky

  List<String> board = List.filled(9, '');
  bool isXTurn = true;
  String? winner;
  bool isDraw = false;
  List<int>? winningLine;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    if (widget.online) {
      _showIntro = false;
      SocketService().socket.on('game_move', _onGameMove);
      SocketService().socket.on('reset_game', _onResetGame);
    }
  }

  @override
  void dispose() {
    if (widget.online) {
      SocketService().socket.off('game_move', _onGameMove);
      SocketService().socket.off('reset_game', _onResetGame);
    }
    super.dispose();
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;
    int index = data['index'];
    setState(() {
      board[index] = isXTurn ? 'X' : 'O';
      isXTurn = !isXTurn;
      _checkWinner();
    });
  }

  void _onResetGame(dynamic data) {
    if (!mounted) return;
    _localReset();
  }

  void _handleTap(int index) {
    if (board[index] != '' || winner != null) return;

    if (widget.online) {
      bool myTurn = (widget.isHost && isXTurn) || (!widget.isHost && !isXTurn);
      if (!myTurn) return;
    }

    setState(() {
      board[index] = isXTurn ? 'X' : 'O';
      isXTurn = !isXTurn;
      _checkWinner();
    });

    if (widget.online) {
      SocketService().socket.emit('game_move', {
        'roomCode': widget.roomCode,
        'moveData': {'index': index},
      });
    }
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
        });

        // Award points in ScoreService
        final scoreService = ScoreService();
        if (scoreService.players.isNotEmpty) {
          // If we have global players, player 0 is X, player 1 is O
          final winnerIndex = winner == 'X' ? 0 : 1;
          if (winnerIndex < scoreService.players.length) {
            scoreService.addScore(scoreService.players[winnerIndex].name, 10);
            ResultsService.instance.recordWin(game: 'إكس أو', winner: scoreService.players[winnerIndex].name, players: scoreService.players.map((p) => p.name).toList());
          }
        }
        return;
      }
    }

    if (!board.contains('')) {
      setState(() {
        isDraw = true;
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
    });
  }

  void _resetGame() {
    _localReset();
    if (widget.online) {
      SocketService().socket.emit('reset_game', {'roomCode': widget.roomCode});
    }
  }

  Widget _chromeButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: FlatColors.border, width: 2),
        ),
        child: Icon(icon, size: 20, color: FlatColors.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🎯 إكس أو',
        backgroundColor: FunkyColors.mint,
        showAi: false,
        body: GameIntroWidget(
          title: '🎯 إكس أو',
          icon: '✏️',
          description:
              'اللعبة الكلاسيكية اللي ما بتخلصش! إكس ولا أو؟ فكر في حركتك صح وحاول تعمل خط قبل خصمك!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    // Interior in the approved flat/cream home language (trial: X/O only).
    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _chromeButton(
                    icon: Icons.settings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('إكس أو', style: FlatDecor.title(size: 24)),
                    ),
                  ),
                  _chromeButton(
                    icon: Icons.home_rounded,
                    onTap: () => setState(() => _showIntro = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Turn / result card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: FlatDecor.card(radius: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (winner == null && !isDraw)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isXTurn ? _xColor : _oColor,
                      ),
                    ),
                  Text(
                    winner != null
                        ? 'الفائز: $winner ✨'
                        : isDraw
                        ? 'تعادل! 🤝'
                        : widget.online
                        ? ((widget.isHost && isXTurn) ||
                                  (!widget.isHost && !isXTurn)
                              ? 'دورك'
                              : 'دور ${widget.opponentName ?? 'المنافس'}')
                        : 'دور الـ ${isXTurn ? 'X' : 'O'}',
                    style: FlatDecor.title(
                      size: 20,
                      color: winner != null
                          ? (winner == 'X' ? _xColor : _oColor)
                          : FlatColors.ink,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 24),
            // Board on a flat white card
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: FlatDecor.card(radius: 28),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        const CustomPaint(
                          size: Size.infinite,
                          painter: FlatGridPainter(),
                        ),
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            final value = board[index];
                            return GestureDetector(
                              onTap: () => _handleTap(index),
                              child: Container(
                                color: Colors.transparent,
                                child: Center(
                                  child: value == ''
                                      ? null
                                      : Text(
                                          value,
                                          style: flatCairo(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                            color: value == 'X'
                                                ? _xColor
                                                : _oColor,
                                          ),
                                        ).animate().fadeIn().scale(
                                            begin: const Offset(0.5, 0.5),
                                          ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (winningLine != null)
                          CustomPaint(
                            size: Size.infinite,
                            painter: FlatWinLinePainter(winningLine!),
                          ).animate().fadeIn(duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (winner != null || isDraw)
              Padding(
                padding: const EdgeInsets.only(bottom: 26, top: 8),
                child: GestureDetector(
                  onTap: _resetGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                    decoration: FlatDecor.button(_xColor, radius: 18),
                    child: Text(
                      'العبوا تاني 🎯',
                      style: FlatDecor.title(size: 18, color: Colors.white),
                    ),
                  ),
                ).animate().fadeIn().scale(),
              )
            else
              const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class ChalkGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double thirdW = size.width / 3;
    double thirdH = size.height / 3;

    canvas.drawLine(
      Offset(thirdW, 10),
      Offset(thirdW + 2, size.height - 10),
      paint,
    );
    canvas.drawLine(
      Offset(thirdW * 2, 12),
      Offset(thirdW * 2 - 2, size.height - 8),
      paint,
    );
    canvas.drawLine(
      Offset(10, thirdH),
      Offset(size.width - 10, thirdH - 2),
      paint,
    );
    canvas.drawLine(
      Offset(8, thirdH * 2),
      Offset(size.width - 12, thirdH * 2 + 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WinLinePainter extends CustomPainter {
  final List<int> line;
  WinLinePainter(this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    double cellW = size.width / 3;
    double cellH = size.height / 3;

    Offset getOffset(int index) {
      double x = (index % 3) * cellW + cellW / 2;
      double y = (index ~/ 3) * cellH + cellH / 2;
      return Offset(x, y);
    }

    Offset start = getOffset(line[0]);
    Offset end = getOffset(line[2]);

    // Extend line slightly
    Offset direction = (end - start);
    start = start - direction * 0.1;
    end = end + direction * 0.1;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}




/// Flat grid: soft ink rounded lines on the white card.
class FlatGridPainter extends CustomPainter {
  const FlatGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FlatColors.ink.withValues(alpha: 0.14)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
          Offset(w * i / 3, 8), Offset(w * i / 3, h - 8), paint);
      canvas.drawLine(
          Offset(8, h * i / 3), Offset(w - 8, h * i / 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Flat win line: chunky amber rounded stroke.
class FlatWinLinePainter extends CustomPainter {
  final List<int> line;
  const FlatWinLinePainter(this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC233)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    Offset center(int i) => Offset(
        (i % 3) * size.width / 3 + size.width / 6,
        (i ~/ 3) * size.height / 3 + size.height / 6);
    canvas.drawLine(center(line.first), center(line.last), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
