import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'snow_brawl_logic.dart';

/// معركة التلج: 2-4 forts, one throw button per player.
class SnowBrawlGame extends StatefulWidget {
  const SnowBrawlGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SnowBrawlGame> createState() => _SnowBrawlGameState();
}

enum _SnowPhase { pickPlayers, playing, over }

class _SnowBrawlGameState extends State<SnowBrawlGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _SnowPhase _phase = _SnowPhase.pickPlayers;
  late SnowBrawlMatch _match;
  Timer? _ticker;
  String _banner = '';

  static const List<Color> _colors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _ticker?.cancel();
    setState(() {
      _match = SnowBrawlMatch(
        playerCount: players,
        random:
            widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'دوس لما عدّاد القوة يوصل للعلامة! ❄';
      _phase = _SnowPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _SnowPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _SnowPhase.over;
        }
      });
    });
  }

  void _throw(int i) {
    if (_phase != _SnowPhase.playing || !_match.alive(i)) return;
    final hit = _match.throwSnowball(i);
    setState(() {
      _banner = hit
          ? 'لاعب ${i + 1} أصاب قلعة لاعب ${_match.targetOf(i) == i ? i + 1 : _match.targetOf(i) + 1}! ❄'
          : 'لاعب ${i + 1} رمى بعيد 😬';
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _SnowPhase.over;
      }
    });
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'كام لاعب؟',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(height: 20),
          for (final n in [2, 3, 4])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () => _startMatch(n),
                  child: Text(
                    '$n لاعبين',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ).copyWith(fontFamilyFallback: _emojiFallback),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _powerBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const tol = SnowBrawlMatch.tolerance;
        return SizedBox(
          height: 30,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: w * (_match.neededPower - tol),
                width: w * tol * 2,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FunkyColors.cyan.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: (w * _match.phase - 4).clamp(0.0, w - 8),
                top: 2,
                bottom: 2,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fortsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < _match.playerCount; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _match.alive(i)
                      ? _colors[i].withValues(alpha: 0.35)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _match.alive(i) ? _colors[i] : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _match.alive(i) ? '🏰' : '💥',
                    style: const TextStyle(fontSize: 22)
                        .copyWith(fontFamilyFallback: _emojiFallback),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'لاعب ${i + 1}: ${_match.hp[i]}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _match.alive(i) ? Colors.white : Colors.white38,
                ).copyWith(fontFamilyFallback: _emojiFallback),
              ),
            ],
          ),
      ],
    );
  }

  Widget _throwButton(int i) {
    final active = _phase == _SnowPhase.playing && _match.alive(i);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: active ? () => _throw(i) : null,
          child: Text(
            'لاعب ${i + 1} ❄',
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ),
    );
  }

  Widget _buildOver() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VictoryFriends(winnerName: 'لاعب ${_match.winner! + 1}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _SnowPhase.pickPlayers),
          child: Text(
            'العبوا تاني ❄',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'معركة التلج',
        description:
            '٢-٤ قلاع على نفس الموبايل. عدّاد القوة بيطلع وينزل.. دوس لما يوصل للعلامة الزرقا عشان كورت التلج توصل قلعة خصمك. أول واحد يهد كل القلاع يكسب ❄',
        icon: '❄',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _SnowPhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'معركة التلج',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: _phase == _SnowPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: _fortsRow(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _powerBar(),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ).copyWith(fontFamilyFallback: _emojiFallback),
                    ),
                  ),
                  Expanded(
                    child: _phase == _SnowPhase.over
                        ? Center(child: _buildOver())
                        : const SizedBox.shrink(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < players; i++) _throwButton(i)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
