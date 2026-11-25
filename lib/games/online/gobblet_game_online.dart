import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/audio_service.dart';
import '../../services/socket_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

class Piece {
  final int player; // 1 for Red, 2 for Blue
  final int size; // 1: Small, 2: Medium, 3: Large
  Piece({required this.player, required this.size});
}

class GobbletGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? opponentName;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const GobbletGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.opponentName,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<GobbletGameOnline> createState() => _GobbletGameOnlineState();
}

class _GobbletGameOnlineState extends State<GobbletGameOnline> {
  late List<List<List<Piece>>> _board;
  late List<List<int>> _inventory;
  int _currentPlayer = 1;
  bool _isGameOver = false;
  int? _selectedRow;
  int? _selectedCol;
  Piece? _selectedPiece;

  @override
  void initState() {
    super.initState();
    _initGame();
    SocketService().socket.on('gobblet_state_updated', _onGameMove);
    SocketService().socket.on('game_move', _onGameMove);
    SocketService().socket.on('reset_game', _onResetGame);
  }

  @override
  void dispose() {
    SocketService().socket.off('gobblet_state_updated', _onGameMove);
    SocketService().socket.off('game_move', _onGameMove);
    SocketService().socket.off('reset_game', _onResetGame);
    super.dispose();
  }

  void _onGameMove(dynamic data) {
    if (!mounted) return;

    final Map<String, dynamic> move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);

    String? type = move['type'];
    if (type == 'tap') {
      _processTap(move['row'], move['col'], isFromNetwork: true);
    } else if (type == 'inventory') {
      _processInventorySelect(move['sizeIndex'], isFromNetwork: true);
    }
  }

  void _onResetGame(dynamic data) {
    if (!mounted) return;
    _initGame();
  }

  void _initGame() {
    setState(() {
      _board = List.generate(3, (_) => List.generate(3, (_) => []));
      _inventory = [
        [3, 3, 3],
        [3, 3, 3],
      ];
      _currentPlayer = 1;
      _isGameOver = false;
      _selectedRow = null;
      _selectedCol = null;
      _selectedPiece = null;
    });
  }

  void _handleTap(int row, int col) {
    _processTap(row, col, isFromNetwork: false);
  }

  void _processTap(int row, int col, {required bool isFromNetwork}) {
    if (_isGameOver) return;

    if (!isFromNetwork) {
      bool myTurn =
          (widget.isHost && _currentPlayer == 1) ||
          (!widget.isHost && _currentPlayer == 2);
      if (!myTurn) return;
    }

    setState(() {
      final targetStack = _board[row][col];
      final topPiece = targetStack.isNotEmpty ? targetStack.last : null;

      if (_selectedPiece == null) {
        return;
      } else {
        bool validMove = false;
        if (topPiece == null || _selectedPiece!.size > topPiece.size) {
          validMove = true;
        }

        if (_selectedRow == row && _selectedCol == col) {
          _selectedRow = null;
          _selectedCol = null;
          _selectedPiece = null;
          return;
        }

        if (validMove) {
          if (_selectedRow == -1) {
            _inventory[_currentPlayer - 1][_selectedCol!]--;
          } else {
            _board[_selectedRow!][_selectedCol!].removeLast();
          }
          _board[row][col].add(_selectedPiece!);
          _checkWin();
          if (!_isGameOver) {
            _currentPlayer = _currentPlayer == 1 ? 2 : 1;
            HapticService.vibrate();
            AudioService.playTick();
            _selectedRow = null;
            _selectedCol = null;
            _selectedPiece = null;
          }
        } else {
          _selectedRow = null;
          _selectedCol = null;
          _selectedPiece = null;
        }

        if (!isFromNetwork) {
          SocketService().socket.emit('gobblet_state_updated', {
            'roomCode': widget.roomCode,
            'moveData': {'type': 'tap', 'row': row, 'col': col},
          });
        }
      }
    });
  }

  void _selectFromInventory(int sizeIndex) {
    _processInventorySelect(sizeIndex, isFromNetwork: false);
  }

  void _processInventorySelect(int sizeIndex, {required bool isFromNetwork}) {
    if (_isGameOver) return;
    if (!isFromNetwork) {
      bool myTurn =
          (widget.isHost && _currentPlayer == 1) ||
          (!widget.isHost && _currentPlayer == 2);
      if (!myTurn) return;
    }

    if (_inventory[_currentPlayer - 1][sizeIndex] > 0) {
      setState(() {
        _selectedRow = -1;
        _selectedCol = sizeIndex;
        _selectedPiece = Piece(player: _currentPlayer, size: sizeIndex + 1);
      });
      if (!isFromNetwork) {
        SocketService().socket.emit('gobblet_state_updated', {
          'roomCode': widget.roomCode,
          'moveData': {'type': 'inventory', 'sizeIndex': sizeIndex},
        });
      }
    }
  }

  void _checkWin() {
    Piece? getTop(int r, int c) =>
        _board[r][c].isNotEmpty ? _board[r][c].last : null;
    bool checkLine(Piece? p1, Piece? p2, Piece? p3) {
      if (p1 == null || p2 == null || p3 == null) return false;
      return p1.player == p2.player && p2.player == p3.player;
    }

    for (int i = 0; i < 3; i++) {
      if (checkLine(getTop(i, 0), getTop(i, 1), getTop(i, 2))) {
        _endGame(getTop(i, 0)!.player);
        return;
      }
      if (checkLine(getTop(0, i), getTop(1, i), getTop(2, i))) {
        _endGame(getTop(0, i)!.player);
        return;
      }
    }
    if (checkLine(getTop(0, 0), getTop(1, 1), getTop(2, 2))) {
      _endGame(getTop(0, 0)!.player);
      return;
    }
    if (checkLine(getTop(0, 2), getTop(1, 1), getTop(2, 0))) {
      _endGame(getTop(0, 2)!.player);
      return;
    }

    if (_inventory.every((p) => p.every((count) => count == 0)) &&
        !_isGameOver) {
      _endGame(null);
    }
  }

  void _endGame(int? winnerPlayer) {
    setState(() => _isGameOver = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          winnerPlayer != null
              ? '🎉 مبروك اللاعب ${winnerPlayer == 1 ? "الأحمر" : "الأزرق"} فاز!'
              : 'تعادل!',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'تحب تلعب دور تاني؟',
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initGame();
              SocketService().socket.emit('reset_game', {
                'roomCode': widget.roomCode,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'العب تاني',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'gobblet',
      title: 'جووبليت (أونلاين)',
      backgroundColor: FunkyColors.pink,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      showAi: false,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildInventoryUI(2), // Blue Player (Top)
            const Spacer(),
            _buildBoardUI(),
            const Spacer(),
            _buildInventoryUI(1), // Red Player (Bottom)
            if (_isGameOver) ...[
              const SizedBox(height: 20),
              _buildResetButton(),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryUI(int player) {
    bool isMe =
        (widget.isHost && player == 1) || (!widget.isHost && player == 2);
    bool isTurn = _currentPlayer == player && !_isGameOver && isMe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isTurn
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isTurn
              ? (player == 1 ? Colors.redAccent : Colors.blueAccent).withValues(
                  alpha: 0.5,
                )
              : Colors.white10,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            isMe
                ? 'إمداداتك (أنت)'
                : 'إمدادات ${widget.opponentName ?? "الخصم"}',
            style: GoogleFonts.cairo(
              color: player == 1 ? Colors.redAccent : Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (sizeIndex) {
              final count = _inventory[player - 1][sizeIndex];
              final isSelected =
                  _selectedRow == -1 &&
                  _selectedCol == sizeIndex &&
                  _currentPlayer == player;

              return GestureDetector(
                    onTap: isTurn
                        ? () => _selectFromInventory(sizeIndex)
                        : null,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildPieceIcon(
                              player,
                              sizeIndex + 1,
                              isSelected: isSelected,
                            ),
                            if (count == 0)
                              Container(
                                width: 40,
                                height: 40,
                                color: Colors.transparent,
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white24,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'x$count',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate(target: isSelected ? 1 : 0)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                  );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardUI() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: List.generate(
            3,
            (row) => Expanded(
              child: Row(
                children: List.generate(
                  3,
                  (col) => Expanded(child: _buildCellUI(row, col)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellUI(int row, int col) {
    final stack = _board[row][col];
    final topPiece = stack.isNotEmpty ? stack.last : null;
    final isSelected = _selectedRow == row && _selectedCol == col;

    return GestureDetector(
      onTap: () => _handleTap(row, col),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amberAccent : Colors.white10,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amberAccent.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: topPiece != null
              ? _buildPieceIcon(
                  topPiece.player,
                  topPiece.size,
                  isSelected: isSelected,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPieceIcon(int player, int size, {bool isSelected = false}) {
    double baseSize = 35.0 + (size - 1) * 20.0;

    return Container(
          width: baseSize,
          height: baseSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.8,
              colors: player == 1
                  ? [const Color(0xFFF87171), const Color(0xFFB91C1C)]
                  : [const Color(0xFF60A5FA), const Color(0xFF1D4ED8)],
            ),
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: (player == 1 ? Colors.redAccent : Colors.blueAccent)
                    .withValues(alpha: isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 20 : 10,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.lens,
              size: baseSize * 0.4,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        )
        .animate(target: isSelected ? 1 : 0)
        .shimmer(duration: const Duration(seconds: 2))
        .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1));
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: () {
        _initGame();
        SocketService().socket.emit('reset_game', {
          'roomCode': widget.roomCode,
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          'العب مرة ثانية 🔄',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
        ),
      ),
    ).animate().fadeIn();
  }
}
