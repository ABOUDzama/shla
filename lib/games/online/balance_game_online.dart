import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/base_game_scaffold.dart';
import '../../services/socket_service.dart';
import '../../services/audio_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/funky_theme.dart';

class BalanceGameOnline extends StatefulWidget {
  final bool isHost;
  final String roomCode;
  final String? playerName;
  final List<dynamic>? roomPlayers;

  const BalanceGameOnline({
    super.key,
    required this.isHost,
    required this.roomCode,
    this.playerName,
    this.roomPlayers,
  });

  @override
  State<BalanceGameOnline> createState() => _BalanceGameOnlineState();
}

class _BalanceGameOnlineState extends State<BalanceGameOnline>
    with TickerProviderStateMixin {
  double ballX = 0;
  double ballY = 0;
  double tiltX = 0; // For visual tilt effect
  double tiltY = 0;

  StreamSubscription? _accelerometerSubscription;
  bool isPlaying = false;
  int score = 0;
  Timer? _scoreTimer;
  Timer? _gameLoop;
  bool hasLost = false;
  double shrinkFactor = 1.0;

  // Power-up state
  bool hasShield = false;
  bool isFrozen = false;
  int _freezeTicks = 0;

  List<Map<String, dynamic>> obstacles = [];
  List<Map<String, dynamic>> powerUps = [];

  final List<String> obstacleIcons = ['💥', '☄️', '⚡', '💣', '👾'];
  final Map<String, String> powerUpIcons = {
    'shield': '🛡️',
    'freeze': '❄️',
    'points': '✨',
  };

  String _statusText = 'بانتظار المضيف...';
  final Map<String, dynamic> _playerStates = {};

  @override
  void initState() {
    super.initState();
    _initPlayers();
    _setupSocket();
  }

  void _initPlayers() {
    final players = widget.roomPlayers ?? [];
    for (var p in players) {
      final id = p['id']?.toString() ?? 'unknown';
      _playerStates[id] = {
        'name': p['name'] ?? p['playerName'] ?? 'لاعب',
        'hasLost': false,
        'score': 0,
      };
    }
  }

  void _setupSocket() {
    SocketService().socket.on('game_move', _onBalanceSync);
  }

  void _onBalanceSync(dynamic data) {
    if (!mounted) return;
    final move = (data is Map && data['moveData'] != null)
        ? Map<String, dynamic>.from(data['moveData'])
        : Map<String, dynamic>.from(data);
    final type = move['type'];

    setState(() {
      if (type == 'start_game') {
        _resetLogic();
        isPlaying = true;
        _statusText = 'توازن!';
        _startLogic();
        AudioService.playTick();
        _playerStates.forEach((key, value) {
          value['hasLost'] = false;
          value['score'] = 0;
        });
      } else if (type == 'player_lost') {
        final pid = move['playerId']?.toString();
        if (pid != null && _playerStates.containsKey(pid)) {
          _playerStates[pid]['hasLost'] = true;
          _playerStates[pid]['score'] = move['score'] ?? 0;
        }
      }
    });
  }

  void _startLogic() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!isPlaying || hasLost) return;
      setState(() {
        tiltX = event.x;
        tiltY = event.y;

        double speed = isFrozen ? 1.0 : 2.5;
        ballX -= event.x * speed;
        ballY += event.y * speed;

        final fullSize = 280.0;
        final maxX = (fullSize * shrinkFactor) / 2 - 22;
        final maxY = (fullSize * shrinkFactor) / 2 - 22;

        ballX = ballX.clamp(-138.0, 138.0);
        ballY = ballY.clamp(-138.0, 138.0);

        if (ballX.abs() >= maxX || ballY.abs() >= maxY) {
          _handleCollision('وقعت من على الثقب!');
        }
      });
    });

    _scoreTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPlaying) return;
      setState(() {
        score++;
        if (score > 10 && !isFrozen) {
          shrinkFactor = (shrinkFactor - 0.012).clamp(0.4, 1.0);
        }
      });
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!isPlaying || hasLost) return;
      setState(() {
        if (isFrozen) {
          _freezeTicks++;
          if (_freezeTicks > 150) {
            // ~5 seconds
            isFrozen = false;
            _freezeTicks = 0;
          }
        }

        // Difficulty scaling
        double spawnProb = (isFrozen ? 0.01 : 0.02 + score / 500).clamp(
          0.01,
          0.15,
        );
        if (Random().nextDouble() < spawnProb) {
          obstacles.add({
            'x': Random().nextDouble() * 200 - 100,
            'y': -280,
            'speed': (3.0 + score / 15) * (isFrozen ? 0.5 : 1.0),
            'icon': obstacleIcons[Random().nextInt(obstacleIcons.length)],
          });
        }

        // Power-up spawning
        if (Random().nextDouble() < 0.005) {
          final types = powerUpIcons.keys.toList();
          powerUps.add({
            'x': Random().nextDouble() * 200 - 100,
            'y': -280,
            'speed': 2.0 * (isFrozen ? 0.5 : 1.0),
            'type': types[Random().nextInt(types.length)],
            'icon': powerUpIcons[types[Random().nextInt(types.length)]]!,
          });
        }

        // Move items & Check collisions
        _processItems(obstacles, 40, (o) => _handleCollision('خبطت في $o'));
        _processItems(powerUps, 45, (p) => _collectPowerUp(p), isPowerUp: true);
      });
    });
  }

  void _processItems(
    List<Map<String, dynamic>> list,
    double dist,
    Function(String) onHit, {
    bool isPowerUp = false,
  }) {
    for (var i in List.from(list)) {
      i['y'] += i['speed'];
      double dx = ballX - i['x'];
      double dy = ballY - i['y'];
      if (sqrt(dx * dx + dy * dy) < dist) {
        if (isPowerUp) {
          onHit(i['type']);
          list.remove(i);
        } else {
          onHit(i['icon']);
          break;
        }
      }
      if (i['y'] > 300) list.remove(i);
    }
  }

  void _handleCollision(String reason) {
    if (hasShield) {
      setState(() => hasShield = false);
      AudioService.playSuccess();
      HapticService.lightImpact();
      obstacles.clear(); // Clear board as a bonus
      return;
    }
    _lose(reason);
  }

  void _collectPowerUp(String type) {
    HapticService.success();
    AudioService.playTick();
    setState(() {
      if (type == 'shield') {
        hasShield = true;
      } else if (type == 'freeze') {
        isFrozen = true;
        _freezeTicks = 0;
      } else if (type == 'points') {
        score += 10;
      }
    });
  }

  void _lose(String reason) {
    if (hasLost) return;
    setState(() {
      hasLost = true;
      isPlaying = false;
      _statusText = reason;
      final myId = SocketService().socket.id;
      if (myId != null && _playerStates.containsKey(myId)) {
        _playerStates[myId]['hasLost'] = true;
        _playerStates[myId]['score'] = score;
      }
    });
    _stopLogic();
    AudioService.playExplosion();
    HapticService.vibrate(duration: 200);

    final moveData = {
      'type': 'player_lost',
      'playerId': SocketService().socket.id,
      'playerName': widget.playerName ?? 'لاعب',
      'score': score,
    };
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
  }

  void _emitStart() {
    final moveData = {'type': 'start_game'};
    SocketService().socket.emit('game_move', {
      'roomCode': widget.roomCode,
      'moveData': moveData,
    });
    _onBalanceSync(moveData);
  }

  void _resetLogic() {
    _stopLogic();
    setState(() {
      ballX = 0;
      ballY = 0;
      score = 0;
      shrinkFactor = 1.0;
      obstacles = [];
      powerUps = [];
      hasLost = false;
      isPlaying = false;
      hasShield = false;
      isFrozen = false;
      _freezeTicks = 0;
    });
  }

  void _stopLogic() {
    _accelerometerSubscription?.cancel();
    _scoreTimer?.cancel();
    _gameLoop?.cancel();
  }

  @override
  void dispose() {
    _stopLogic();
    SocketService().socket.off('game_move', _onBalanceSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScaffold(
      isHost: widget.isHost,
      gameName: 'balance',
      title: 'لعبة التوازن (أونلاين)',
      backgroundColor: FunkyColors.cyan,
      roomCode: widget.roomCode,
      myId: SocketService().socket.id,
      playerName: widget.playerName,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              _buildCompetitionPanel(),
              const SizedBox(height: 20),
              _buildHUD(),
              const SizedBox(height: 30),
              _buildStage(),
              const SizedBox(height: 40),
              if (widget.isHost && !isPlaying) _buildStartButton(),
              if (!widget.isHost && !isPlaying && !hasLost) _buildWaitingCard(),
              if (hasLost) _buildGameOverCard(),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatCard(
          'الزمن',
          '$scoreث',
          Icons.timer_outlined,
          Colors.cyanAccent,
        ),
        const SizedBox(width: 15),
        if (hasShield)
          _buildStatCard('درع', 'نشط', Icons.shield, Colors.greenAccent),
        if (isFrozen)
          _buildStatCard(
            'تجميد',
            '${5 - (_freezeTicks ~/ 30)}ث',
            Icons.ac_unit,
            Colors.blueAccent,
          ),
      ],
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitionPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch,
                color: Colors.purpleAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'المنافسة الفضائية',
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          Wrap(
            spacing: 10,
            children: _playerStates.entries.map((e) {
              final st = e.value;
              final isMe = e.key == SocketService().socket.id;
              final color = isMe
                  ? Colors.purpleAccent
                  : (st['hasLost'] ? Colors.redAccent : Colors.greenAccent);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  color: color.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      st['name'],
                      style: GoogleFonts.cairo(color: color, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      st['hasLost'] ? '${st['score']}ث' : '🚀',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    const size = 300.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Safe zone grid
            Center(
              child: AnimatedContainer(
                duration: 500.ms,
                width: size * shrinkFactor,
                height: size * shrinkFactor,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: shrinkFactor < 0.6
                        ? Colors.redAccent
                        : Colors.cyanAccent,
                    width: 2,
                  ),
                  color:
                      (shrinkFactor < 0.6
                              ? Colors.redAccent
                              : Colors.cyanAccent)
                          .withValues(alpha: 0.05),
                ),
              ),
            ),
            // The Hole (outer area)
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 1),
                ),
              ),
            ),
            // Ball (Core)
            Center(
              child: Transform.translate(
                offset: Offset(ballX, ballY),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Colors.white,
                        Colors.cyanAccent,
                        Colors.blueAccent,
                      ],
                      stops: [0.1, 0.4, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ).animate(target: hasLost ? 1 : 0).shake().fadeOut(),
              ),
            ),
            // Obstacles
            ...obstacles.map(
              (o) => Positioned(
                left: (size / 2) + o['x'] - 20,
                top: (size / 2) + o['y'] - 20,
                child: Text(
                  o['icon'],
                  style: const TextStyle(fontSize: 32),
                ).animate().scale(duration: 200.ms),
              ),
            ),
            // Power-ups
            ...powerUps.map(
              (p) => Positioned(
                left: (size / 2) + p['x'] - 20,
                top: (size / 2) + p['y'] - 20,
                child:
                    Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.white30),
                            boxShadow: [
                              BoxShadow(color: Colors.white10, blurRadius: 10),
                            ],
                          ),
                          child: Text(
                            p['icon'],
                            style: const TextStyle(fontSize: 24),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer()
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                        ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut);
  }

  Widget _buildStartButton() {
    return InkWell(
      onTap: _emitStart,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.cyanAccent, Colors.blueAccent],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Text(
          'انطلاق بالمركبة 🚀',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
    ).animate().scale();
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.cyanAccent),
          const SizedBox(height: 15),
          Text(
            'المستضيف يستعد للإقلاع...',
            style: GoogleFonts.cairo(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text('💥', style: TextStyle(fontSize: 50)),
          Text(
            'فقدت التوازن!',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _statusText,
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'النتيجة النهائية: $score ثانية',
            style: GoogleFonts.cairo(
              color: Colors.redAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().shake().fadeIn();
  }
}

// ─── Custom Painter for Neon Grid ───────────────────────────────
class NeonGridPainter extends CustomPainter {
  final double tiltX;
  final double tiltY;
  NeonGridPainter({required this.tiltX, required this.tiltY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    final dotPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.15)
      ..strokeWidth = 2.0;

    double spacing = 40.0;
    // Parallax effect
    double offsetX = (tiltX * 10) % spacing;
    double offsetY = (tiltY * 10) % spacing;

    for (double x = offsetX; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = offsetY; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw grid intersections as small glowy dots
    for (double x = offsetX; x < size.width; x += spacing) {
      for (double y = offsetY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(NeonGridPainter old) =>
      old.tiltX != tiltX || old.tiltY != tiltY;
}
