import 'dart:math';

import 'package:flutter/material.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../data/codenames_data.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// كود نيمز — exact clone of Codenames (CGE): a 5x5 board of 25 words.
/// Red and blue teams each have one spymaster who sees the secret key:
/// 9 agents for the starting team, 8 for the other, 7 bystanders and
/// 1 assassin. The spymaster says a ONE-WORD clue plus a NUMBER aloud;
/// his team may guess up to number+1 words. Revealing an own agent lets
/// them continue; a bystander or opponent agent ends the turn (opponent
/// agents score for the opponent); the assassin loses the game
/// instantly. First team to reveal all its agents wins.
/// One-phone adaptation: both spymasters view the key privately via
/// pass-phone, and can re-peek it secretly during play.
class CodenamesGame extends StatefulWidget {
  const CodenamesGame({super.key});

  @override
  State<CodenamesGame> createState() => _CodenamesGameState();
}

enum _CPhase {
  intro,
  players,
  teams,
  keyPass,
  keyShow,
  clue,
  guessing,
  keyPeekPass,
  keyPeekShow,
  gameOver,
}

enum _CardKind { red, blue, neutral, assassin }

class _CodenamesGameState extends State<CodenamesGame> {
  _CPhase _phase = _CPhase.intro;
  final Random _rng = Random();

  List<String> _players = [];
  List<List<int>> _teams = [[], []]; // player indices per team
  final List<int> _spyIdx = [0, 0]; // spymaster pointer per team

  List<String> _words = [];
  List<_CardKind> _kinds = [];
  final List<bool> _revealed = List.filled(25, false);

  int _currentTeam = 0; // red starts
  int _guessesLeft = 0;
  int? _clueNumber;
  int _peekSpy = 0; // which team's spymaster is peeking

  static const _teamColors = [Color(0xFFE53935), Color(0xFF1E88E5)];
  static const _teamNames = ['الأحمر', 'الأزرق'];
  static const _teamEmojis = ['🔴', '🔵'];

  int _remaining(int team) {
    var n = 0;
    for (var i = 0; i < 25; i++) {
      if (!_revealed[i] &&
          _kinds[i] == (team == 0 ? _CardKind.red : _CardKind.blue)) {
        n++;
      }
    }
    return n;
  }

  // ---------------------------------------------------------------- flow

  void _start(List<String> names) {
    _players = List<String>.from(names);
    // Alternating split into two teams.
    _teams = [[], []];
    final idxs = List.generate(_players.length, (i) => i)..shuffle(_rng);
    for (var i = 0; i < idxs.length; i++) {
      _teams[i % 2].add(idxs[i]);
    }
    _spyIdx[0] = 0;
    _spyIdx[1] = 0;
    _setupBoard();
    AudioService.playClick();
    setState(() => _phase = _CPhase.teams);
  }

  void _setupBoard() {
    final pool = codenamesWords.toSet().toList()..shuffle(_rng);
    _words = pool.take(25).toList();
    final kinds = <_CardKind>[
      ...List.filled(9, _CardKind.red),
      ...List.filled(8, _CardKind.blue),
      ...List.filled(7, _CardKind.neutral),
      _CardKind.assassin,
    ]..shuffle(_rng);
    _kinds = kinds;
    for (var i = 0; i < 25; i++) {
      _revealed[i] = false;
    }
    _currentTeam = 0; // red (9 agents) starts
    _clueNumber = null;
  }

  int get _currentSpy => _teams[_currentTeam][_spyIdx[_currentTeam]];

  void _pickClueNumber(int n) {
    _clueNumber = n;
    // official: number + 1 bonus guess; ∞ = unlimited
    _guessesLeft = n < 0 ? 25 : n + 1;
    AudioService.playClick();
    setState(() => _phase = _CPhase.guessing);
  }

  void _revealCard(int i) {
    if (_revealed[i] || _phase != _CPhase.guessing) return;
    _revealed[i] = true;
    final kind = _kinds[i];
    final own = _currentTeam == 0 ? _CardKind.red : _CardKind.blue;
    final other = _currentTeam == 0 ? _CardKind.blue : _CardKind.red;
    if (kind == _CardKind.assassin) {
      AudioService.playFailure();
      _winner = 1 - _currentTeam;
      _assassinEnd = true;
      setState(() => _phase = _CPhase.gameOver);
      return;
    }
    if (kind == own) {
      AudioService.playSuccess();
      _guessesLeft--;
      if (_remaining(_currentTeam) == 0) {
        _winner = _currentTeam;
        _assassinEnd = false;
        AudioService.playWinVoice();
        setState(() => _phase = _CPhase.gameOver);
        return;
      }
      if (_guessesLeft <= 0) {
        _endTurn();
        return;
      }
      setState(() {});
      return;
    }
    // Bystander or opponent agent: turn ends. Opponent agents stay
    // revealed and score for the opponent — maybe finishing their board.
    AudioService.playFailure();
    if (kind == other && _remaining(1 - _currentTeam) == 0) {
      _winner = 1 - _currentTeam;
      _assassinEnd = false;
      AudioService.playWinVoice();
      setState(() => _phase = _CPhase.gameOver);
      return;
    }
    _endTurn();
  }

  void _endTurn() {
    _currentTeam = 1 - _currentTeam;
    _clueNumber = null;
    setState(() => _phase = _CPhase.clue);
  }

  int? _winner;
  bool _assassinEnd = false;

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _CPhase.intro:
        return OfflineGameScaffold(
          title: '🕵️ كود نيمز',
          backgroundColor: FunkyColors.sky,
          body: GameIntroWidget(
            title: 'كود نيمز 🕵️',
            icon: '🕵️',
            description:
                'اللعبة الأصلية Codenames!\n\n'
                '🟥🟦 فريقين على لوحة 25 كلمة. لكل فريق قائد شايف المفتاح السري: مين عملاءكم ومين القاتل!\n'
                '🗣️ القائد يقول تلميح من كلمة واحدة + رقم ("بحر 3") بصوت عالي.\n'
                '👆 الفريق يدوس على الكلمات: صح = كمّل (رقم + تخمينة زيادة)، غلط = الدور يروح.\n'
                '☠️ اللي يلمس كلمة "القاتل" يخسر فوراً!\n\n'
                'أول فريق يكشف كل عملاءه يكسب.',
            onStart: () {
              AudioService.playClick();
              setState(() => _phase = _CPhase.players);
            },
          ),
        );
      case _CPhase.players:
        return GlobalPlayerSelectionScreen(
          gameTitle: '🕵️ كود نيمز',
          minPlayers: 4,
          maxPlayers: 10,
          onStartGame: (ctx, selected) => _start(selected),
        );
      case _CPhase.teams:
        return _buildTeams();
      case _CPhase.keyPass:
        return _buildKeyPass();
      case _CPhase.keyShow:
        return _buildKeyShow();
      case _CPhase.clue:
        return _buildClue();
      case _CPhase.guessing:
        return _buildGuessing();
      case _CPhase.keyPeekPass:
        return _buildKeyPeekPass();
      case _CPhase.keyPeekShow:
        return _buildKeyPeekShow();
      case _CPhase.gameOver:
        return _buildGameOver();
    }
  }

  Widget _scaffold(Widget body) => OfflineGameScaffold(
    title: '🕵️ كود نيمز',
    backgroundColor: FunkyColors.sky,
    body: body,
  );

  Widget _buildTeams() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Text(
              'الفرق والقادة 🕵️',
              style: flatCairo(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: List.generate(2, (t) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: t == 0 ? 5 : 0,
                        right: t == 1 ? 5 : 0,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _teamColors[t], width: 3),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_teamEmojis[t]} فريق ${_teamNames[t]}',
                            style: flatCairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _teamColors[t],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              children: [
                                for (var k = 0; k < _teams[t].length; k++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      k == _spyIdx[t]
                                          ? '🕵️ ${_players[_teams[t][k]]} (القائد)'
                                          : _players[_teams[t][k]],
                                      textAlign: TextAlign.center,
                                      style: flatCairo(
                                        fontSize: 14,
                                        fontWeight: k == _spyIdx[t]
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                        color: FlatColors.ink,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            _bigButton('سلّم الموبايل للقادة يشوفوا المفتاح 🔑', () {
              _peekSpy = 0;
              AudioService.playClick();
              setState(() => _phase = _CPhase.keyPass);
            }),
          ],
        ),
      ),
    );
  }

  // Both spymasters view the SAME key privately (official: one shared key
  // card). Order: red spymaster first, then blue.
  Widget _buildKeyPass() {
    final spy = _teams[_peekSpy][_spyIdx[_peekSpy]];
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'عدّي الموبايل لقائد فريق\n${_teamNames[_peekSpy]}: ${_players[spy]} 🔑',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'القادة بس اللي يشوفوا المفتاح!',
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.mafia,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا القائد 👀', () {
                AudioService.playClick();
                setState(() => _phase = _CPhase.keyShow);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyShow() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'المفتاح السري 🤫\n🔴 أحمر  🔵 أزرق  ⬜ محايد  ⬛ القاتل',
              textAlign: TextAlign.center,
              style: flatCairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            Expanded(child: _board(forSpymaster: true)),
            const SizedBox(height: 10),
            _bigButton(
              _peekSpy == 0 ? 'حفظته! عدّيها للقائد التاني ⏭️' : 'يلا نبدأ! 🚀',
              () {
                AudioService.playClick();
                if (_peekSpy == 0) {
                  _peekSpy = 1;
                  setState(() => _phase = _CPhase.keyPass);
                } else {
                  setState(() => _phase = _CPhase.clue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClue() {
    final spy = _currentSpy;
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _remainingStrip(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _teamColors[_currentTeam],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FlatColors.ink, width: 2.5),
              ),
              child: Text(
                '${_teamEmojis[_currentTeam]} دور فريق ${_teamNames[_currentTeam]}\nالقائد ${_players[spy]}: قول تلميحك بصوت عالي (كلمة واحدة بس!)',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.7,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'وبعدين اختار رقم التلميح:',
              style: flatCairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (var n = 0; n <= 9; n++) _numberChip(n),
                _numberChip(-1), // ∞: unlimited guesses (official)
              ],
            ),
            const Spacer(),
            _bigButton('القائد عايز يبص على المفتاح؟ 🔑', () {
              _peekSpy = _currentTeam;
              AudioService.playClick();
              setState(() => _phase = _CPhase.keyPeekPass);
            }, color: FlatColors.ink),
          ],
        ),
      ),
    );
  }

  Widget _numberChip(int n) {
    final label = n < 0 ? '∞' : '$n';
    return GestureDetector(
      key: ValueKey('cn_clue_$label'),
      onTap: () => _pickClueNumber(n),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _teamColors[_currentTeam], width: 3),
        ),
        child: Center(
          child: Text(
            label,
            style: flatCairo(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _teamColors[_currentTeam],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuessing() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _remainingStrip(),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _teamColors[_currentTeam],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlatColors.ink, width: 2),
              ),
              child: Text(
                '${_teamEmojis[_currentTeam]} فريق ${_teamNames[_currentTeam]} بيخمّن  •  فاضل $_guessesLeft تخمينة',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _board(forSpymaster: false)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _bigButton('كفاية، سلّم الدور ✋', () {
                    AudioService.playClick();
                    _endTurn();
                  }, color: FlatColors.ink),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bigButton('المفتاح 🔑', () {
                    _peekSpy = _currentTeam;
                    AudioService.playClick();
                    setState(() => _phase = _CPhase.keyPeekPass);
                  }, color: FlatColors.mintDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPeekPass() {
    final spy = _teams[_peekSpy][_spyIdx[_peekSpy]];
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'بصّة سريعة على المفتاح 🔑\nعدّي الموبايل لـ ${_players[spy]} بس!',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              _bigButton('تمام، أنا القائد 👀', () {
                AudioService.playClick();
                setState(() => _phase = _CPhase.keyPeekShow);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyPeekShow() {
    return _scaffold(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'المفتاح السري 🤫',
              style: flatCairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            Expanded(child: _board(forSpymaster: true)),
            const SizedBox(height: 10),
            _bigButton('رجّعني للعبة ⏪', () {
              AudioService.playClick();
              setState(
                () => _phase = _clueNumber == null
                    ? _CPhase.clue
                    : _CPhase.guessing,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    return _scaffold(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _assassinEnd
                    ? '☠️ القاتل!\nفريق ${_teamNames[_winner!]} ${_teamEmojis[_winner!]} كسب!'
                    : '🏆 فريق ${_teamNames[_winner!]} ${_teamEmojis[_winner!]} كشف كل عملاءه!',
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
              Expanded(child: _board(forSpymaster: true)),
              const SizedBox(height: 14),
              _bigButton('العبوا تاني 🔄', () {
                AudioService.playClick();
                setState(() => _phase = _CPhase.intro);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _remainingStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlatColors.ink, width: 2),
      ),
      child: Text(
        '🔴 فاضل ${_remaining(0)}   •   🔵 فاضل ${_remaining(1)}',
        style: flatCairo(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: FlatColors.ink,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Color _kindColor(_CardKind k) {
    switch (k) {
      case _CardKind.red:
        return const Color(0xFFE53935);
      case _CardKind.blue:
        return const Color(0xFF1E88E5);
      case _CardKind.neutral:
        return const Color(0xFFD7CCC8);
      case _CardKind.assassin:
        return FlatColors.ink;
    }
  }

  Widget _board({required bool forSpymaster}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1.55,
      ),
      itemCount: 25,
      itemBuilder: (ctx, i) {
        final revealed = forSpymaster || _revealed[i];
        final kind = _kinds[i];
        return GestureDetector(
          key: ValueKey('cn_card_$i'),
          onTap: forSpymaster ? null : () => _revealCard(i),
          child: Container(
            decoration: BoxDecoration(
              color: revealed ? _kindColor(kind) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: revealed ? _kindColor(kind) : FlatColors.border,
                width: 2,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    _words[i],
                    style: flatCairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: revealed
                          ? (kind == _CardKind.neutral
                                ? FlatColors.ink
                                : Colors.white)
                          : FlatColors.ink,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bigButton(String label, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? FlatColors.mintDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: flatCairo(fontSize: 16, fontWeight: FontWeight.w900),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
