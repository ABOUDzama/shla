import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../services/socket_service.dart';
import '../../widgets/base_game_scaffold.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MultiTouchScreenOnline extends StatefulWidget {
  final bool isHost;
  final String? roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const MultiTouchScreenOnline({
    super.key,
    required this.isHost,
    this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<MultiTouchScreenOnline> createState() => _MultiTouchScreenOnlineState();
}

class _MultiTouchScreenOnlineState extends State<MultiTouchScreenOnline> {
  Map<String, Offset> touches = {};
  bool isSelecting = false;
  bool showResult = false;
  String? selectedId;
  int _countdown = 0;
  final Random _random = Random();

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

    final type = move['type'];
    
    setState(() {
      if (type == 'touch_update') {
        touches[move['id'].toString()] = Offset(move['dx'].toDouble(), move['dy'].toDouble());
      } else if (type == 'touch_remove') {
        touches.remove(move['id'].toString());
      } else if (type == 'start_selection') {
        isSelecting = true;
        showResult = false;
        selectedId = null;
        _countdown = move['countdown'] ?? 3;
      } else if (type == 'countdown_tick') {
        _countdown = move['countdown'];
      } else if (type == 'result_revealed') {
        isSelecting = false;
        showResult = true;
        selectedId = move['winnerId'];
      } else if (type == 'reset_game') {
        isSelecting = false;
        showResult = false;
        selectedId = null;
        touches.clear();
      }
    });
  }

  void _emitStart() {
    if (touches.length < 2) return;
    
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {'type': 'start_selection', 'countdown': 3}
    });

    int count = 3;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      count--;
      if (count <= 0) {
        timer.cancel();
        _emitResult();
      } else {
        SocketService().socket.emit('game_move', {
          'roomCode': widget.roomCode,
          'moveData': {'type': 'countdown_tick', 'countdown': count}
        });
      }
    });
  }

  void _emitResult() {
    if (touches.isEmpty) return;
    final keys = touches.keys.toList();
    final winner = keys[_random.nextInt(keys.length)];
    
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {'type': 'result_revealed', 'winnerId': winner}
    });
  }

  void _emitReset() {
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {'type': 'reset_game'}
    });
  }

  @override
  void dispose() {
    SocketService().socket.off('game_move', _onGameMove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'multi_touch',
      title: 'تحدى اللمس المتعدد (أونلاين)',
      backgroundColor: const Color(0xFF0F172A),
      showAi: false,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: Listener(
        onPointerDown: (e) => _updateTouch(e.localPosition, e.pointer),
        onPointerMove: (e) => _updateTouch(e.localPosition, e.pointer),
        onPointerUp: (e) => _removeTouch(e.pointer),
        onPointerCancel: (e) => _removeTouch(e.pointer),
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    if (!isSelecting && !showResult)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          'الكل يحط صباعه! 👆', 
                          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)
                        ),
                      ).animate(onPlay: (c)=>c.repeat()).shimmer(duration: 2.seconds),
                    
                    if (isSelecting) 
                      Text('$_countdown', 
                        style: GoogleFonts.cairo(
                          fontSize: 120, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          shadows: [const Shadow(color: Colors.black26, blurRadius: 10)],
                        )
                      ).animate(key: ValueKey(_countdown)).scale(duration: 300.ms, curve: Curves.elasticOut),
                    
                    if (showResult)
                       Text('🎯', style: const TextStyle(fontSize: 80)).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 20),
                    Text(
                      'الموجودين: ${touches.length}', 
                      style: GoogleFonts.cairo(color: Colors.white38, fontSize: 16)
                    ),

                    if (widget.isHost && !isSelecting && !showResult && touches.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: ElevatedButton(
                          onPressed: _emitStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: Text('ابدأ الغرفة 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        ),
                      ).animate().fadeIn().scale(),

                    if (widget.isHost && showResult)
                       Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: TextButton.icon(
                          onPressed: _emitReset,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('إعادة تعيين', style: GoogleFonts.cairo(color: Colors.white70)),
                        ),
                      ),
                  ],
                ),
              ),
              ...touches.entries.map((entry) => _buildTouchIndicator(entry.key, entry.value)),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTouch(Offset pos, int pointer) {
    if (isSelecting || showResult) return;
    
    final id = "${SocketService().socket.id}_$pointer";
    setState(() => touches[id] = pos);
    
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {
        'type': 'touch_update',
        'dx': pos.dx,
        'dy': pos.dy,
        'id': id,
      }
    });
  }

  void _removeTouch(int pointer) {
    if (isSelecting || showResult) return;

    final id = "${SocketService().socket.id}_$pointer";
    setState(() => touches.remove(id));
    
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': {
        'type': 'touch_remove',
        'id': id,
      }
    });
  }

  Widget _buildTouchIndicator(String id, Offset pos) {
    final isWinner = showResult && selectedId == id;
    final isLoser = showResult && selectedId != id;

    if (isLoser) return const SizedBox.shrink();

    return Positioned(
      left: pos.dx - 60,
      top: pos.dy - 60,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isWinner ? Colors.amberAccent.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isWinner ? Colors.amberAccent : Colors.greenAccent.withValues(alpha: 0.3), 
            width: isWinner ? 4 : 2
          ),
          boxShadow: [
            if (isWinner) BoxShadow(color: Colors.amberAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5),
            const BoxShadow(color: Colors.black26, blurRadius: 10),
          ],
        ),
        child: isWinner ? Center(child: Text('🏆', style: TextStyle(fontSize: 40))) : null,
      ).animate(onPlay: (c)=> isWinner ? null : c.repeat())
       .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1), duration: 1.seconds, curve: Curves.easeInOut),
    );
  }
}
