import 'dart:math';

import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/bluff_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// حقيقي ولا خدعة — the classic "real or fake?" photo voting game.
/// A photo is shown to the whole group; half the photos are real, half hide
/// one impossible or tampered detail. The phone then passes around and
/// every player votes secretly: حقيقي or خدعة. Each correct vote scores 1
/// point (official scoring of the reference game). 8 photos per match;
/// the sharpest eye wins.
class BluffGame extends StatefulWidget {
  const BluffGame({super.key});

  @override
  State<BluffGame> createState() => _BluffGameState();
}

enum _BPhase { intro, players, show, votePass, vote, reveal, finalResults }

class _BluffGameState extends State<BluffGame> {
  static const int _roundsPerMatch = 8;

  _BPhase _phase = _BPhase.intro;
  final Random _rng = Random();

  List<String> _players = [];
  final Map<int, int> _scores = {};
  List<Map<String, dynamic>> _items = [];
  int _round = 0;

  final Map<int, bool> _votes = {}; // player index -> guessed "is real"
  int _voter = 0;

  Map<String, dynamic> get _item => _items[_round];
  bool get _isReal => _item['isReal'] as bool;

  // ---------------------------------------------------------------- flow

  void _start(List<String> names) {
    _players = List<String>.from(names);
    _scores
      ..clear()
      ..addAll({for (var i = 0; i < _players.length; i++) i: 0});
    final pool = List<Map<String, dynamic>>.from(bluffItems)..shuffle(_rng);
    _items = pool.take(_roundsPerMatch).toList();
    _round = 0;
    _setupRound();
  }

  void _setupRound() {
    _votes.clear();
    _voter = 0;
    AudioService.playClick();
    setState(() => _phase = _BPhase.show);
  }

  void _castVote(bool guessReal) {
    _votes[_voter] = guessReal;
    AudioService.playClick();
    if (_voter < _players.length - 1) {
      _voter++;
      setState(() => _phase = _BPhase.votePass);
    } else {
      _reveal();
    }
  }

  void _reveal() {
    var anyCorrect = false;
    for (final e in _votes.entries) {
      if (e.value == _isReal) {
        _scores[e.key] = (_scores[e.key] ?? 0) + 1;
        anyCorrect = true;
      }
    }
    if (anyCorrect) {
      AudioService.playSuccess();
    } else {
      AudioService.playFailure();
    }
    setState(() => _phase = _BPhase.reveal);
  }

  void _next() {
    if (_round < _items.length - 1) {
      _round++;
      _setupRound();
    } else {
      AudioService.playWinVoice();
      setState(() => _phase = _BPhase.finalResults);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _BPhase.intro:
        return OfflineGameScaffold(
          title: '🔍 حقيقي ولا خدعة',
          backgroundColor: FunkyColors.cyan,
          body: GameIntroWidget(
            title: 'حقيقي ولا خدعة 🔍',
            icon: '🔍',
            description:
                'لعبة العيون الحادة!\n\n'
                '📷 هتشوفوا صورة قدامكم..\n'
                'بعض الصور حقيقية، وبعضها متلعب فيها بحاجة واحدة مستحيلة!\n\n'
                '🤫 الموبايل هيدور عليكم وكل واحد يصوّت في سرية: حقيقي ولا خدعة؟\n'
                '✅ كل تصويت صح = نقطة.\n\n'
                '٨ صور.. وأكتر واحد عينه حادة يكسب!',
            onStart: () {
              AudioService.playClick();
              setState(() => _phase = _BPhase.players);
            },
          ),
        );
      case _BPhase.players:
        return GlobalPlayerSelectionScreen(
          gameTitle: '🔍 حقيقي ولا خدعة',
          minPlayers: 2,
          maxPlayers: 8,
          onStartGame: (ctx, selected) => _start(selected),
        );
      case _BPhase.show:
        return _buildShow();
      case _BPhase.votePass:
        return _buildVotePass();
      case _BPhase.vote:
        return _buildVote();
      case _BPhase.reveal:
        return _buildReveal();
      case _BPhase.finalResults:
        return _buildFinal();
    }
  }

  Widget _scaffold(Widget body) => OfflineGameScaffold(
    title: '🔍 حقيقي ولا خدعة',
    backgroundColor: FunkyColors.cyan,
    body: body,
  );

  Widget _photo({double? height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlatColors.ink, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        _item['asset'] as String,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) =>
            Center(child: Text('🔍', style: const TextStyle(fontSize: 64))),
      ),
    );
  }

  Widget _buildShow() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'الصورة ${_round + 1} من ${_items.length}',
              style: flatCairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            Expanded(child: _photo()),
            const SizedBox(height: 12),
            Text(
              '👀 شوفوا الصورة كويس كلكن..\nفي حاجة متلعب فيها؟ ولا الصورة سليمة ومفيهاش خدعة؟',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 14),
            _bigButton('شوفناها.. يلا نصوّت! 🤫', () {
              AudioService.playClick();
              setState(() => _phase = _BPhase.votePass);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVotePass() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'الصورة ${_round + 1} من ${_items.length}',
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                'عدّي الموبايل لـ\n${_players[_voter]} 🤫',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'صوّت في سرية.. محدش يغشّش!',
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا ${_players[_voter]} 👀', () {
                AudioService.playClick();
                setState(() => _phase = _BPhase.vote);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVote() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'يا ${_players[_voter]}..\nالصورة دي حقيقي ولا خدعة؟ 🤔',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            _photo(height: 220),
            const Spacer(),
            _bigButton(
              'حقيقي ✅',
              () => _castVote(true),
              color: FlatColors.mintDark,
            ),
            const SizedBox(height: 10),
            _bigButton(
              'خدعة ❌',
              () => _castVote(false),
              color: FlatColors.mafia,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildReveal() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 4),
            _photo(height: 160),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isReal ? FlatColors.mintDark : FlatColors.mafia,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FlatColors.ink, width: 2.5),
              ),
              child: Text(
                '${_isReal ? 'الصورة سليمة.. مفيش خدعة! ✅' : 'الصورة متلعب فيها.. خدعة! ❌'}\n${_item['explain']}',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < _players.length; i++)
                    _resultRow(
                      _players[i],
                      _votes[i] == _isReal,
                      _scores[i] ?? 0,
                    ),
                ],
              ),
            ),
            _bigButton(
              _round < _items.length - 1
                  ? 'الصورة اللي بعدها ⏭️'
                  : 'النتيجة النهائية! 🏆',
              () {
                AudioService.playClick();
                _next();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinal() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first;
    final tie = sorted.length > 1 && sorted[1].value == winner.value;

    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tie
                    ? '🤝 تعادل في القمة!'
                    : '🏆 ${_players[winner.key]} صاحب أحدّ عين في الشلة!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              _scoreBoard(),
              const SizedBox(height: 24),
              _bigButton('العبوا تاني 🔄', () {
                AudioService.playClick();
                setState(() => _phase = _BPhase.intro);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _resultRow(String name, bool correct, int score) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: correct
            ? FunkyColors.mint.withValues(alpha: 0.25)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: correct ? FlatColors.mintDark : FlatColors.border,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$score ⭐',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: FlatColors.ink,
            ),
          ),
          Expanded(
            child: Text(
              '$name ${correct ? '✅' : '❌'}',
              textAlign: TextAlign.right,
              style: flatCairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBoard() {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Column(
        children: [
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${e.value} ⭐',
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                  Text(
                    _players[e.key],
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.ink,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bigButton(
    String label,
    VoidCallback onTap, {
    Color? color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? FlatColors.mintDark,
          foregroundColor: textColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: color == Colors.white
                ? const BorderSide(color: FlatColors.ink, width: 2)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: flatCairo(fontSize: 17, fontWeight: FontWeight.w900),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
