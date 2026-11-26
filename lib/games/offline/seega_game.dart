import 'package:flutter/material.dart';
import '../../services/results_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../services/score_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

class SeegaGame extends StatefulWidget {
  final bool online;
  final bool isHost;
  final String? roomCode;
  final String? opponentName;

  const SeegaGame({
    super.key,
    this.online = false,
    this.isHost = true,
    this.roomCode,
    this.opponentName,
  });

  @override
  State<SeegaGame> createState() => _SeegaGameState();
}

class _SeegaGameState extends State<SeegaGame> {
  List<int> board = List.filled(9, 0);
  int currentPlayer = 1;
  int piecesPlaced1 = 0;
  int piecesPlaced2 = 0;
  int? selectedIndex;
  String? winner;
  bool isPlacementPhase = true;
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
    _processTap(index, isFromNetwork: true);
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

    if (widget.online && !isFromNetwork) {
      bool myTurn =
          (widget.isHost && currentPlayer == 1) ||
          (!widget.isHost && currentPlayer == 2);
      if (!myTurn) return;
    }

    if (isPlacementPhase) {
      _handlePlacement(index);
    } else {
      _handleMovement(index);
    }

    if (widget.online && !isFromNetwork) {
      SocketService().socket.emit('game_move', {
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

        // Award points
        final scoreService = ScoreService();
        if (scoreService.players.isNotEmpty) {
          final winnerIndex = board[line[0]] == 1 ? 0 : 1;
          if (winnerIndex < scoreService.players.length) {
            scoreService.addScore(scoreService.players[winnerIndex].name, 10);
            ResultsService.instance.recordWin(game: 'سيجا', winner: scoreService.players[winnerIndex].name, players: scoreService.players.map((p) => p.name).toList());
          }
        }
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
    if (widget.online) {
      SocketService().socket.emit('reset_game', {'roomCode': widget.roomCode});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🎮 السيجة',
        backgroundColor: FunkyColors.orange,
        showAi: false,
        body: GameIntroWidget(
          title: '🎮 السيجة',
          icon: '♟️',
          description:
              'اللعبة القديمة الأصيلة اللي محتاجة ذكاء وتخطيط! السجا هي لعبة مصرية عريقة.. وزع حصواتك وفكر إزاي تحاصر خصمك وتكسب!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    return OfflineGameScaffold(
      title: '🎮 السيجة',
      backgroundColor: FlatColors.bg,
      showAi: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: FlatDecor.card(radius: 16),
              child: Column(
                children: [
                  Text(
                    isPlacementPhase ? 'مرحلة التوزيع' : 'مرحلة التحريك',
                    style: flatCairo(
                      color: FlatColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    isPlacementPhase
                        ? 'حط حصواتك الـ 3 في الأماكن الفاضية'
                        : 'حرك حصواتك جنب بعض عشان تكسب',
                    textAlign: TextAlign.center,
                    style: flatCairo(
                      fontSize: 14,
                      color: FlatColors.ink.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 20),
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: FlatDecor.tag().copyWith(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    winner != null
                        ? 'المنتصر: $winner! 🏆'
                        : widget.online
                        ? (((widget.isHost && currentPlayer == 1) ||
                                  (!widget.isHost && currentPlayer == 2))
                              ? 'دور حجر الألماس'
                              : 'دور ${widget.opponentName ?? 'المنافس'}')
                        : 'دور الحجر: ${currentPlayer == 1 ? 'الأحمر' : 'الأزرق'}',
                    style: flatCairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: winner != null
                          ? FlatColors.mintDark
                          : (currentPlayer == 1
                                ? FlatColors.playerRed
                                : FlatColors.playerBlue),
                    ),
                  ),
                )
                .animate(key: ValueKey(winner ?? currentPlayer.toString()))
                .scale()
                .fadeIn(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FlatColors.tileWhite,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: FlatColors.border,
                      width: 12,
                    ),
                  ),
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
                        key: ValueKey('seega_cell_${index}'),
                        onTap: () => _handleTap(index),
                        child: AnimatedContainer(
                          duration: 250.ms,
                          decoration: BoxDecoration(
                            color: FlatColors.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? FlatColors.day : FlatColors.border,
                              width: 2,
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
                                      color: value == 1
                                          ? FlatColors.mafia
                                          : FlatColors.detective,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                  ).animate().scale(
                                    curve: Curves.elasticOut,
                                    duration: 600.ms,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (winner != null)
              FunkyButton(
                onPressed: _resetGame,
                label: 'إعادة التحدي',
                accent: FunkyColors.orange,
                fontSize: 18,
              ).animate().fadeIn().scale(),
          ],
        ),
    );
  }
}


