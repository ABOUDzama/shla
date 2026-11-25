import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';

/// Pure round/match logic for the reaction game, kept separate from the
/// widget so it can be unit-tested without pumping timers.
enum ReactionOutcome { roundWin, falseStart, ignored }

class ReactionMatch {
  ReactionMatch({required this.playerCount, this.targetScore = 5})
      : scores = List<int>.filled(playerCount, 0);

  final int playerCount;
  final int targetScore;
  final List<int> scores;

  /// True while a round accepts taps (either waiting for green or green).
  bool roundActive = true;
  int? matchWinner;

  /// Registers a tap for [player]. [green] says whether the signal was
  /// already showing. A tap before green is a false start: the player loses
  /// a point (never below zero) and the round ends. The first tap after
  /// green wins the round; reaching [targetScore] wins the match.
  ReactionOutcome tap(int player, {required bool green}) {
    if (!roundActive || matchWinner != null) {
      return ReactionOutcome.ignored;
    }
    roundActive = false;
    if (!green) {
      if (scores[player] > 0) scores[player]--;
      return ReactionOutcome.falseStart;
    }
    scores[player]++;
    if (scores[player] >= targetScore) {
      matchWinner = player;
    }
    return ReactionOutcome.roundWin;
  }

  /// Arms the next round. No-op once the match has a winner.
  void nextRound() {
    if (matchWinner == null) roundActive = true;
  }
}

class ReactionGame extends StatefulWidget {
  const ReactionGame({super.key});

  @override
  State<ReactionGame> createState() => _ReactionGameState();
}

enum _Phase { pickPlayers, waiting, green, resolved, matchOver }

class _ReactionGameState extends State<ReactionGame> {
  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  late ReactionMatch _match;
  Timer? _greenTimer;
  Timer? _nextTimer;
  final Random _random = Random();
  String _banner = '';

  static const List<Color> _zoneColors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _greenTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _greenTimer?.cancel();
    _nextTimer?.cancel();
    setState(() {
      _match = ReactionMatch(playerCount: players);
    });
    _armRound();
  }

  void _armRound() {
    _greenTimer?.cancel();
    setState(() {
      _match.nextRound();
      _phase = _Phase.waiting;
      _banner = 'استنى الأخضر...';
    });
    final delay = Duration(milliseconds: 1500 + _random.nextInt(3000));
    _greenTimer = Timer(delay, () {
      if (!mounted || _phase != _Phase.waiting) return;
      setState(() {
        _phase = _Phase.green;
        _banner = 'دوس!';
      });
    });
  }

  void _onZoneTap(int player) {
    if (_phase != _Phase.waiting && _phase != _Phase.green) return;
    final outcome = _match.tap(player, green: _phase == _Phase.green);
    if (outcome == ReactionOutcome.ignored) return;
    setState(() {
      if (_match.matchWinner != null) {
        _phase = _Phase.matchOver;
        _banner = 'لاعب ${player + 1} كسب الماتش! 🏆';
      } else {
        _phase = _Phase.resolved;
        _banner = outcome == ReactionOutcome.falseStart
            ? 'لاعب ${player + 1} دوس بدري! نقطة تتخصم 😬'
            : 'لاعب ${player + 1} كان الأسرع! ⚡';
      }
    });
    if (_match.matchWinner == null) {
      _nextTimer?.cancel();
      _nextTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _phase == _Phase.resolved) _armRound();
      });
    }
  }

  Widget _buildZone(int player) {
    final isTop = (_match.playerCount == 2 && player == 0) ||
        (_match.playerCount > 2 && player < 2);
    final waiting = _phase == _Phase.waiting;
    final green = _phase == _Phase.green;
    final color = green
        ? FunkyColors.lime
        : waiting
            ? FunkyColors.card
            : _zoneColors[player];
    final label = 'لاعب ${player + 1}';
    final score = _match.scores[player];
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: waiting || green ? FunkyColors.bgDeep : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$score / ${_match.targetScore}',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: waiting || green ? FunkyColors.bgDeep : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () => _onZoneTap(player),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: waiting ? 0.55 : 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _zoneColors[player], width: 2),
          ),
          child:
              isTop ? Transform.rotate(angle: pi, child: content) : content,
        ),
      ),
    );
  }

  Widget _buildArena() {
    final players = _match.playerCount;
    final zones = List.generate(players, _buildZone);
    return Column(
      children: [
        Expanded(
          child: players == 2
              ? Column(children: [zones[1], zones[0]])
              : Column(
                  children: [
                    Expanded(
                      child: Row(children: [zones[1], zones[0]]),
                    ),
                    Expanded(
                      child: Row(
                        children: players == 4
                            ? [zones[3], zones[2]]
                            : [Expanded(child: const SizedBox()), zones[2]],
                      ),
                    ),
                  ],
                ),
        ),
        if (_phase == _Phase.matchOver)
          VictoryFriends(winnerName: 'لاعب ${_match.matchWinner! + 1}'),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: FunkyColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FunkyColors.amber, width: 1.6),
          ),
          child: Text(
            _banner,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: FunkyColors.amber,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
        ),
        if (_phase == _Phase.matchOver)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton(
              onPressed: () => setState(() => _phase = _Phase.pickPlayers),
              child: Text(
                'العب تاني',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'كام لاعب؟',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الكل على نفس الموبايل، وأول واحد يوصل ٥ نقط يكسب',
            style: GoogleFonts.cairo(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [2, 3, 4])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _zoneColors[n - 2],
                      foregroundColor: FunkyColors.bgDeep,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                    ),
                    onPressed: () => _startMatch(n),
                    child: Text(
                      '$n',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'أسرع رد فعل',
        description:
            'الشاشة هتستنى شوية وبعدين تقلب خضرا.. أول واحد يدوس يكسب الجولة! اللي يدوس قبل الأخضر تتخصم منه نقطة. أول واحد يوصل ٥ نقط يكسب الماتش ⚡',
        icon: '⚡',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'أسرع رد فعل',
      backgroundColor: FunkyColors.amber,
      body: SafeArea(
        child: _phase == _Phase.pickPlayers ? _buildPicker() : _buildArena(),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
