import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import '../../widgets/game_intro_widget.dart';
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

enum _SumoPhase { pickPlayers, pickBots, countdown, fighting, matchBreak, over }

/// سومو الشلة: 1-4 players (+ optional bots). The core 1v1 tap war is
/// kept; with 3-4 seats it runs as a small bracket (semis then a final),
/// bot-vs-bot matches resolve instantly. Solo without bots is a training
/// dummy practice.
class SumoGame extends StatefulWidget {
  const SumoGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SumoGame> createState() => _SumoGameState();
}

class _SumoGameState extends State<SumoGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  bool _entranceFaded = false;
  _SumoPhase _phase = _SumoPhase.pickPlayers;
  late SumoMatch _match;
  int _countdown = 3;
  int _timeLeft = 30;
  Timer? _timer;
  Timer? _botTimer;

  int _humans = 2;
  bool _practice = false;
  final Set<int> _botSeats = {};
  late List<int> _contenders;
  List<int> _pair = const [0, 1];
  String _breakText = '';
  int? _champion;
  late Random _rng;

  @visibleForTesting
  SumoMatch get debugMatch => _match;

  @visibleForTesting
  List<int> get debugPair => _pair;

  @override
  void dispose() {
    _timer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  String _seatName(int s) => _botSeats.contains(s) ? 'بوت ${s + 1}' : PlayerNames.name(s);

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

  void _startBracket(int humans, bool withBots) {
    _timer?.cancel();
    _botTimer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _rng = widget.randomSeed != null ? Random(widget.randomSeed!) : Random();
    _botSeats.clear();
    if (_practice) {
      // player 0 vs a training dummy (seat -1 never taps)
      _contenders = [];
      _pair = const [0, -1];
      _champion = null;
      _startMatch();
      return;
    }
    final seats = withBots ? 4 : humans;
    for (var i = humans; i < seats && withBots; i++) {
      _botSeats.add(i);
    }
    _contenders = List.generate(seats, (i) => i);
    _champion = null;
    _advanceBracket();
  }

  /// Pops the next pair; bot-vs-bot matches resolve instantly. Starts a
  /// human match immediately, or crowns the champion when one seat remains.
  void _advanceBracket() {
    while (true) {
      if (_contenders.length == 1) {
        _champion = _contenders.first;
        setState(() => _phase = _SumoPhase.over);
        return;
      }
      final a = _contenders.removeAt(0);
      final b = _contenders.removeAt(0);
      final aBot = _botSeats.contains(a), bBot = _botSeats.contains(b);
      if (aBot && bBot) {
        final w = _rng.nextBool() ? a : b;
        _breakText = '${_seatName(w)} كسب ماتش البوتات 🤖';
        _contenders.add(w);
        continue;
      }
      _pair = [a, b];
      _breakText = 'الماتش الجاي: ${_seatName(a)} ضد ${_seatName(b)}';
      _startMatch();
      return;
    }
  }

  void _startMatch() {
    ArcadeJuice.tap();
    _timer?.cancel();
    _botTimer?.cancel();
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
            _finishMatch();
          }
        }
      });
      if (_match.isOver && _phase == _SumoPhase.fighting) {
        setState(_finishMatch);
      }
    });
    // bot taps during the fight
    _botTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted || _phase != _SumoPhase.fighting || _practice) return;
      for (var zone = 0; zone < 2; zone++) {
        if (_botSeats.contains(_pair[zone]) && _rng.nextDouble() < 0.5) {
          setState(() {
            _match.tap(zone);
            if (_match.isOver) _finishMatch();
          });
        }
      }
    });
  }

  /// A UI match just ended: report it, then continue the bracket.
  void _finishMatch() {
    _timer?.cancel();
    _botTimer?.cancel();
    if (_practice) {
      setState(() => _phase = _SumoPhase.over);
      ArcadeJuice.win();
      return;
    }
    final w = _match.winner;
    if (w == null) {
      // true tie: replay the same pair
      setState(() {
        _breakText = 'تعادل! جولة تانية بين ${_seatName(_pair[0])} و ${_seatName(_pair[1])}';
        _phase = _SumoPhase.matchBreak;
      });
      _contenders.insert(0, _pair[1]);
      _contenders.insert(0, _pair[0]);
      return;
    }
    final winnerSeat = _pair[w];
    _contenders.add(winnerSeat);
    if (_contenders.length == 1) {
      _champion = winnerSeat;
      setState(() => _phase = _SumoPhase.over);
      _botSeats.contains(winnerSeat) ? ArcadeJuice.lose() : ArcadeJuice.win();
    } else {
      setState(() {
        _breakText = '${_seatName(winnerSeat)} كسب الماتش! 💪';
        _phase = _SumoPhase.matchBreak;
      });
    }
  }

  void _onTapZone(int zone) {
    if (_phase != _SumoPhase.fighting) return;
    if (_botSeats.contains(_pair[zone]) || _pair[zone] < 0) return;
    setState(() {
      _match.tap(zone);
      if (_match.isOver) _finishMatch();
    });
  }

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(onPressed: onTap, child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _buildPicker() => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('كام لاعب؟', style: _t(26)),
            const SizedBox(height: 20),
            _bigChoice('لاعب واحد', () {
              _humans = 1;
              setState(() => _phase = _SumoPhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startBracket(4, false);
                } else {
                  setState(() => _phase = _SumoPhase.pickBots);
                }
              }),
          ]),
        ),
      );

  Widget _buildBots() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('نضيف بوتات؟', style: _t(26)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'من غير بوتات هتتدرب على دمية وتشوف سرعتك'
                : 'البوتات بتكمّل لحد ٤ لاعبين ويتلعبوا بطولة صغيرة',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startBracket(_humans, true)),
          _bigChoice('لا', () => _startBracket(_humans, false)),
        ]),
      );

  Widget _buildBreak() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_breakText,
              style: _t(20),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl),
          const SizedBox(height: 20),
          _bigChoice('ابدأ الماتش 💪', () => _advanceBracket()),
        ]),
      );

  Widget _buildZone(int zone) {
    final isTop = zone == 1;
    final seat = _pair[zone];
    final color = zone == 0 ? const Color(0xFFFF8A5C) : const Color(0xFF4D8DFF);
    final isBot = _botSeats.contains(seat);
    final label = seat < 0 ? 'دمية تدريب 🎯' : _seatName(seat);
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _t(22, w: FontWeight.w900)),
          Text(
            _phase == _SumoPhase.fighting
                ? (isBot || seat < 0 ? '...' : 'دووووس!')
                : 'استنى البداية',
            style: _t(15, color: FlatColors.ink.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
    return Expanded(
      child: GestureDetector(
        key: Key('sumo_zone_$zone'),
        onTap: () => _onTapZone(zone),
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
    final pos = _match.position;
    final fighting = _phase == _SumoPhase.fighting;
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
            _phase == _SumoPhase.countdown ? '$_countdown' : '⏱ $_timeLeft',
            style: _t(26, w: FontWeight.w900),
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
                      child: Container(height: 2, color: FlatColors.border),
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
                        style: TextStyle(fontSize: 40, fontFamily: 'Noto Color Emoji'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (!fighting && _phase != _SumoPhase.countdown) const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildOver() {
    Widget head;
    if (_practice) {
      head = _match.winner == 0 && _match.position <= -1.0
          ? Text('طلّعت الدمية برا في ${_match.taps[0]} دوسة 💪', style: _t(20), textAlign: TextAlign.center)
          : Text('الوقت خلص قبل ما تطلّعها! جرب تدوس أسرع', style: _t(20), textAlign: TextAlign.center);
    } else if (_champion != null && _botSeats.contains(_champion)) {
      head = Text('البوتات كسبوا البطولة 🤖', style: _t(22));
    } else if (_champion != null) {
      head = VictoryFriends(gameTitle: 'سومو الشلة', winnerName: '${PlayerNames.name(_champion!)}', winnerSeats: [_champion!]);
    } else {
      head = Text('تعادل!', style: _t(20));
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        head,
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _SumoPhase.pickPlayers),
          child: Text('العبوا تاني 🤼', style: _t(18, color: Colors.white)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'سومو الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'سومو الشلة',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            '١-٤ لاعبين على نفس الموبايل، وتقدر تضيف بوتات! دوس بأقصى سرعة على ناحيتك عشان تدفع خصمك برا الحلبة. مع ٣ أو ٤ لاعبين تتقسموا ماتشات والفائزين يقابلوا بعض في النهائي 🤼',
        icon: '🤼',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    if (_phase == _SumoPhase.pickPlayers || _phase == _SumoPhase.pickBots) {
      return OfflineGameScaffold(
        title: 'سومو الشلة',
        backgroundColor: FlatColors.bg,
        body: SafeArea(
          child: _phase == _SumoPhase.pickPlayers ? _buildPicker() : _buildBots(),
        ),
      );
    }
    if (_phase == _SumoPhase.over) {
      return OfflineGameScaffold(
        title: 'سومو الشلة',
        backgroundColor: FlatColors.bg,
        body: SafeArea(child: _buildOver()),
      );
    }
    if (_phase == _SumoPhase.matchBreak) {
      return OfflineGameScaffold(
        title: 'سومو الشلة',
        backgroundColor: FlatColors.bg,
        body: SafeArea(child: _buildBreak()),
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
          ],
        ),
      ),
    );
    if (_entranceFaded) return scaffold;
    _entranceFaded = true;
    return scaffold.animate().fadeIn(duration: 300.ms);
  }
}
