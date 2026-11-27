import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'croc_logic.dart';

/// تمساح الشلة: crocodile-dentist elimination for 1-4 seats on one phone.
/// Original flat art drawn in the app's style; bots fill the empty seats.
class CrocGameScreen extends StatefulWidget {
  const CrocGameScreen({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<CrocGameScreen> createState() => _CrocGameScreenState();
}

enum _CrocPhase { pickPlayers, pickBots, playing, over }

class _CrocGameScreenState extends State<CrocGameScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _croc = Color(0xFF35C99E);
  static const _crocDark = Color(0xFF17795A);

  bool _showIntro = true;
  _CrocPhase _phase = _CrocPhase.pickPlayers;
  late CrocGame _game;
  Timer? _botTimer;
  int _humans = 2;
  bool _practice = false;

  /// True while the jaws-close chomp animation plays; input is blocked.
  bool _chomping = false;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  String _seatLabel(int seat) =>
      _game.isBot(seat) ? 'بوت ${seat + 1}' : PlayerNames.name(seat);

  @visibleForTesting
  CrocGame get debugGame => _game;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _juiceEnd() {
    final w = _game.winner;
    if (w == null) return;
    (w < _humans) ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

  void _startGame(int humans, bool withBots) {
    ArcadeJuice.tap();
    _botTimer?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final bots = <int>{
      for (var i = humans; i < seats && (withBots || _practice); i++) i,
    };
    setState(() {
      _game = CrocGame(
        playerCount: seats,
        botSeats: bots,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _chomping = false;
      _phase = _CrocPhase.playing;
    });
    _maybeBotTurn();
  }

  bool get _currentIsBot =>
      _phase == _CrocPhase.playing && _game.isBot(_game.currentPlayer);

  void _maybeBotTurn() {
    _botTimer?.cancel();
    if (_phase != _CrocPhase.playing || !_currentIsBot || _game.isOver) return;
    _botTimer = Timer(const Duration(milliseconds: 750), _botStep);
  }

  void _botStep() {
    if (!mounted || _phase != _CrocPhase.playing || _chomping) return;
    _pull(_game.chooseBotPull());
  }

  void _humanPull(int tooth) {
    if (_currentIsBot || _game.isOver || _chomping) return;
    if (!_game.standing.contains(tooth)) return;
    _pull(tooth);
  }

  void _pull(int tooth) {
    final chomped = _game.pull(tooth);
    if (!chomped) {
      ArcadeJuice.tick();
      setState(() {});
      _maybeBotTurn();
      return;
    }
    // Chomp: close the jaws, hold a beat, then reset the round or finish.
    ArcadeJuice.hit();
    setState(() => _chomping = true);
    _botTimer?.cancel();
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _chomping = false;
        if (_game.isOver) {
          _phase = _CrocPhase.over;
          _juiceEnd();
        }
      });
      _maybeBotTurn();
    });
  }

  TextStyle _t(double size,
          {Color? color, FontWeight w = FontWeight.w800, double? h}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback, height: h);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'تمساح الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🐊',
          title: 'تمساح الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'التمساح جعان وعنده ضرسة موجوعة! كل واحد في دوره يدوس على ضرسة من العشرة. اللي يدوس على الموجوعة التمساح يقفل بقه عليه ويخرج من الجولة. آخر واحد عايش ياخد الكأس 🐊',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    switch (_phase) {
      case _CrocPhase.pickPlayers:
        return OfflineGameScaffold(
            title: 'تمساح الشلة',
            backgroundColor: FlatColors.bg,
            body: _pickPlayers());
      case _CrocPhase.pickBots:
        return OfflineGameScaffold(
            title: 'تمساح الشلة',
            backgroundColor: FlatColors.bg,
            body: _pickBots());
      case _CrocPhase.playing:
        return OfflineGameScaffold(
            title: 'تمساح الشلة',
            backgroundColor: FlatColors.bg,
            body: _playing());
      case _CrocPhase.over:
        return OfflineGameScaffold(
            title: 'تمساح الشلة',
            backgroundColor: FlatColors.bg,
            body: _over());
    }
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🐊', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل دور ضرسة.. والموجوعة بتقضم!',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startGame(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _CrocPhase.pickBots;
                });
              }
            }),
        ],
      ),
    );
  }

  Widget _pickBots() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('البوتات تكمل المقاعد؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'لوحدك: تمرين، عّد الضروس اللي بتنجو بيها'
                : 'الأماكن الفاضية تتملى بوتات',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startGame(_humans, true)),
          _bigChoice('لا', () => _startGame(_humans, false)),
        ],
      ),
    );
  }

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  // ---------------------------------------------------------------- game ---

  Widget _playing() {
    final current = _game.currentPlayer;
    return Column(
      children: [
        _turnBar(current),
        const SizedBox(height: 4),
        Text(
          _chomping
              ? 'قضم!! 😱'
              : _currentIsBot
                  ? 'البوت بيلعب…'
                  : 'دوس على ضرسة 🦷',
          style: _t(14,
              w: FontWeight.w900,
              color: _chomping ? FlatColors.mafia : _colors[current]),
          textDirection: TextDirection.rtl,
        ),
        Expanded(
          child: Center(
            child: _crocHead(),
          ),
        ),
        Text(
          'الواقفين: ${_game.alive.length} من ${_game.playerCount}',
          style: _t(12, color: FlatColors.ink.withValues(alpha: 0.55)),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _turnBar(int current) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _colors[current].withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors[current], width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _colors[current], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'دور ${_seatLabel(current)}${_game.isBot(current) ? ' 🤖' : ''}',
              style: _t(14, w: FontWeight.w900, color: _colors[current]),
              textDirection: TextDirection.rtl,
            ),
          ),
          for (var p = 0; p < _game.playerCount; p++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: _game.eliminated.contains(p) ? 0.35 : 1,
                child: Text(
                  _game.eliminated.contains(p) ? '❌' : '🐊',
                  style: TextStyle(
                      fontSize: 13,
                      color: _colors[p],
                      fontFamilyFallback: _emojiFallback),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Original flat croc head: eyes + snout on top, a row of tappable teeth,
  /// bottom jaw. The top jaw slams shut on a chomp.
  Widget _crocHead() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Head with eyes and nostrils
          Container(
            height: 92,
            decoration: const BoxDecoration(
              color: _croc,
              borderRadius: BorderRadius.vertical(top: Radius.circular(60)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _eye(),
                const SizedBox(width: 40),
                _eye(),
              ],
            ),
          ),
          // Upper jaw
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _chomping ? 34 : 18,
            decoration: BoxDecoration(
              color: _crocDark,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 4),
          // Teeth row
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var t = 0; t < _game.toothCount; t++) _tooth(t),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Lower jaw / chin
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _chomping ? 40 : 26,
            decoration: const BoxDecoration(
              color: _croc,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
            ),
          ),
        ],
      ),
    ).animate(target: _chomping ? 1 : 0).shake(duration: 500.ms, hz: 5);
  }

  Widget _eye() {
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(top: 22),
      decoration: const BoxDecoration(
          color: Colors.white, shape: BoxShape.circle),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _chomping ? 16 : 12,
          height: _chomping ? 16 : 12,
          decoration:
              const BoxDecoration(color: FlatColors.ink, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _tooth(int t) {
    final pulled = !_game.standing.contains(t);
    final sore = pulled && t == _game.soreTooth && _game.lastChomped != null;
    final tappable = !_currentIsBot && !_game.isOver && !_chomping && !pulled;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('tooth_$t'),
        onTap: tappable ? () => _humanPull(t) : null,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: pulled ? 14 : 46,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: sore
                  ? FlatColors.mafia
                  : pulled
                      ? FlatColors.border
                      : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                  color: sore ? FlatColors.mafia : FlatColors.ink,
                  width: pulled ? 1.5 : 2),
            ),
            child: sore
                ? const Center(
                    child: Icon(Icons.warning_rounded,
                        color: Colors.white, size: 14))
                : null,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- over -----

  Widget _over() {
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('اتقضمت! 🐊', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text(
              'نجوت من ${_game.practiceStreak} ${_game.practiceStreak == 1 ? 'ضرسة' : 'ضروس'} قبل القضمة',
              style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁', () => setState(() {
                  _phase = _CrocPhase.pickPlayers;
                })),
          ],
        ),
      );
    }
    final w = _game.winner!;
    final humanWin = w < _humans;
    if (!humanWin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BotsWinLabel(gameTitle: 'تمساح الشلة', style: _t(24, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('بوت ${w + 1} هو آخر تمساح واقف',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العبوا تاني 🔁', () => setState(() {
                  _phase = _CrocPhase.pickPlayers;
                })),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VictoryFriends(
              gameTitle: 'تمساح الشلة', winnerName: PlayerNames.name(w)),
          const SizedBox(height: 20),
          _bigChoice('العبوا تاني 🔁', () => setState(() {
                _phase = _CrocPhase.pickPlayers;
              })),
        ],
      ),
    );
  }
}
