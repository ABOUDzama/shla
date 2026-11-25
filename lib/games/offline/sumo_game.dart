import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// Pure logic for Shla Sumo (سومو الشلة), kept separate from the widget so
/// it can be unit-tested without pumping frames.
///
/// Two players share one phone. Each tap pushes the wrestlers toward the
/// opponent's edge. Push the opponent fully out (position reaches ±1) to
/// win, or be ahead when time runs out.
class SumoMatch {
  SumoMatch({this.pushStep = 0.02, this.roundSeconds = 30});

  /// How far one tap moves the ring, as a fraction of half the ring.
  final double pushStep;

  /// Round length; whoever is ahead when it ends wins.
  final int roundSeconds;

  /// Ring position: 0 is center, +1 is player 2's edge out, -1 player 1's.
  double position = 0;

  /// Number of pushes each player landed, for stats/animations.
  final List<int> taps = [0, 0];

  int? winner;

  bool get isOver => winner != null;

  /// Registers a tap for [player] (0 or 1). Player 0 pushes the position
  /// up (toward player 1's edge at -1)... player 0 sits at the bottom and
  /// shoves the opponent upward, so player 0's taps move the position
  /// toward -1 and player 1's taps move it toward +1.
  void tap(int player) {
    if (isOver) return;
    taps[player]++;
    position += player == 0 ? -pushStep : pushStep;
    position = position.clamp(-1.0, 1.0);
    if (position <= -1.0) winner = 0;
    if (position >= 1.0) winner = 1;
  }

  /// Resolves the round when the timer expires: the player who pushed the
  /// ring further into the opponent's half wins. A perfectly centered ring
  /// goes to whoever tapped more; a true tie has no winner (replay).
  void timeUp() {
    if (isOver) return;
    if (position < 0) {
      winner = 0;
    } else if (position > 0) {
      winner = 1;
    } else if (taps[0] != taps[1]) {
      winner = taps[0] > taps[1] ? 0 : 1;
    }
  }
}

enum _SumoPhase { countdown, fighting, over }

class SumoGame extends StatefulWidget {
  const SumoGame({super.key});

  @override
  State<SumoGame> createState() => _SumoGameState();
}

class _SumoGameState extends State<SumoGame> {
  bool _showIntro = true;
  /// Entrance fade runs once; flutter_animate restarts effects on every
  /// rebuild (new effect instances), which made the whole screen re-fade
  /// on every tap during play.
  bool _entranceFaded = false;
  late SumoMatch _match;
  _SumoPhase _phase = _SumoPhase.countdown;
  int _countdown = 3;
  int _timeLeft = 30;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startMatch() {
    _timer?.cancel();
    setState(() {
      _match = SumoMatch();
      _phase = _SumoPhase.countdown;
      _countdown = 3;
      _timeLeft = _match.roundSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_phase == _SumoPhase.countdown) {
          if (_countdown <= 1) {
            _phase = _SumoPhase.fighting;
          } else {
            _countdown--;
          }
        } else if (_phase == _SumoPhase.fighting) {
          _timeLeft--;
          if (_timeLeft <= 0) {
            _match.timeUp();
            _phase = _SumoPhase.over;
            t.cancel();
          }
        }
      });
      if (_match.isOver && _phase != _SumoPhase.over) {
        setState(() => _phase = _SumoPhase.over);
        t.cancel();
      }
    });
  }

  void _onTapZone(int player) {
    if (_phase != _SumoPhase.fighting) return;
    setState(() {
      _match.tap(player);
      if (_match.isOver) {
        _phase = _SumoPhase.over;
        _timer?.cancel();
      }
    });
  }

  Widget _buildZone(int player) {
    final isTop = player == 1;
    final color = player == 0 ? const Color(0xFFFF8A5C) : const Color(0xFF4D8DFF);
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'لاعب ${player + 1}',
            style: flatCairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: FlatColors.ink,
            ),
          ),
          Text(
            _phase == _SumoPhase.fighting ? 'دووووس!' : 'استنى البداية',
            style: flatCairo(fontSize: 15, color: FlatColors.ink.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTapZone(player),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlatColors.ink, width: 2),
          ),
          child: isTop
              ? Transform.rotate(angle: pi, child: content)
              : content,
        ),
      ),
    );
  }

  Widget _buildRing() {
    // position: -1 (player 0 edge) .. +1 (player 1 edge)
    final pos = _match.position;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _phase == _SumoPhase.countdown
                ? '$_countdown'
                : _phase == _SumoPhase.over
                    ? (_match.winner != null
                        ? 'لاعب ${_match.winner! + 1} كسب! 🏆'
                        : 'تعادل! جولـة تانية')
                    : '⏱ $_timeLeft',
            style: flatCairo(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: FlatColors.ink,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth - 56;
              final dx = (pos + 1) / 2 * w;
              return SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    Positioned(
                      top: 27,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: FlatColors.border,
                      ),
                    ),
                    Positioned(
                      top: 20,
                      left: 0,
                      child: Container(
                        width: 12,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A5C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D8DFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 80),
                      top: 0,
                      left: dx,
                      child: const Text(
                        '🤼',
                        style: TextStyle(
                          fontSize: 40,
                          fontFamily: 'Noto Color Emoji',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'سومو الشلة',
        description:
            'لاعبان على نفس الموبايل! دوس بأقصى سرعة على ناحيتك عشان تدفع خصمك برا الحلبة. عندك ٣٠ ثانية، واللي دافع الكورة أكتر لناحية التاني هو الفائز 🤼',
        icon: '🤼',
        onStart: () {
          setState(() => _showIntro = false);
          _startMatch();
        },
      );
    }
    final scaffold = OfflineGameScaffold(
      title: 'سومو الشلة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildZone(1),
            _buildRing(),
            _buildZone(0),
            if (_phase == _SumoPhase.over && _match.winner != null)
              VictoryFriends(winnerName: 'لاعب ${_match.winner! + 1}'),
            if (_phase == _SumoPhase.over)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton(
                  onPressed: _startMatch,
                  child: Text(
                    'العب تاني',
                    style: flatCairo(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (_entranceFaded) return scaffold;
    _entranceFaded = true;
    return scaffold.animate().fadeIn(duration: 300.ms);
  }
}
