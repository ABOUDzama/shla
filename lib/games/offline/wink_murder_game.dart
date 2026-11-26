import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../services/audio_service.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// الغمّاز — the classic Wink Murder party game, with the phone as
/// moderator (the winking itself happens face to face):
/// - Secret roles dealt by passing the phone: one غمّاز (winker), one
///   محقق (detective, announces himself), everyone else ضحايا.
/// - Everyone makes eye contact; the winker kills by winking. A killed
///   player dramatically "dies" and taps their name on the screen.
/// - The detective gets 3 accusations: pick a suspect and the app reveals
///   whether they are the winker.
/// - Winker caught: the group wins (+3 detective, +1 each survivor).
///   Winker reduces the circle to 2 alive: the winker wins (+5).
/// Best of 1/3/5 rounds, roles reshuffled each round.
class WinkMurderGame extends StatefulWidget {
  const WinkMurderGame({super.key});

  @override
  State<WinkMurderGame> createState() => _WinkMurderGameState();
}

enum _KPhase { rolePass, roleShow, play, accuse, roundEnd }

class _WinkMurderGameState extends State<WinkMurderGame> {
  final Random _rng = Random(53);

  bool _showIntro = true;
  bool _started = false;

  List<Map<String, dynamic>> _players = []; // {name, score}
  int _round = 1;
  int _rounds = 3;

  _KPhase _phase = _KPhase.rolePass;
  int _passIndex = 0;
  int _winker = -1;
  int _detective = -1;
  final Set<int> _dead = {};
  int _accusationsLeft = 3;
  String? _winner; // 'group' | 'winker'
  String? _endReason;
  int? _lastAccused;
  bool? _lastAccuseHit;

  void _start(List<String> names) {
    setState(() {
      _players = names.map((n) => {'name': n, 'score': 0}).toList();
      _round = 1;
      _started = true;
      _newRound();
    });
  }

  void _newRound() {
    _dead.clear();
    _accusationsLeft = 3;
    _winner = null;
    _endReason = null;
    _lastAccused = null;
    _lastAccuseHit = null;
    _passIndex = 0;
    _winker = _rng.nextInt(_players.length);
    int d = _rng.nextInt(_players.length);
    while (d == _winker) {
      d = _rng.nextInt(_players.length);
    }
    _detective = d;
    _phase = _KPhase.rolePass;
  }

  String _roleFor(int i) {
    if (i == _winker) return 'الغمّاز 😉';
    if (i == _detective) return 'المحقق 🕵️';
    return 'ضحية 😇';
  }

  String _roleDesc(int i) {
    if (i == _winker) {
      return 'اقتلهم بالغمز واحد واحد.. من غير ما المحقق يمسكك!';
    }
    if (i == _detective) {
      return 'أعلن نفسك للكل، وراقب العيون.. عندك 3 اتهامات تمسك بيهم الغمّاز!';
    }
    return 'طالع الناس في عيونهم.. لو حد غمزلك، استنى ثواني ومُت بدراما 💀';
  }

  void _markDead(int i) {
    AudioService.playFailure();
    setState(() {
      _dead.add(i);
      final alive = List.generate(
        _players.length,
        (x) => x,
      ).where((x) => !_dead.contains(x)).toList();
      // Winker wins when only 2 remain (the winker + one more).
      if (alive.length <= 2) {
        _winner = 'winker';
        _endReason = 'الغمّاز قضى على الشلة كلها!';
        _players[_winker]['score'] = (_players[_winker]['score'] as int) + 5;
        _phase = _KPhase.roundEnd;
        AudioService.playFailure();
      }
    });
  }

  void _accuse(int i) {
    setState(() {
      _lastAccused = i;
      _lastAccuseHit = i == _winker;
      if (_lastAccuseHit!) {
        _winner = 'group';
        _endReason = 'المحقق مسك الغمّاز!';
        _players[_detective]['score'] =
            (_players[_detective]['score'] as int) + 3;
        for (var x = 0; x < _players.length; x++) {
          if (x != _winker && x != _detective && !_dead.contains(x)) {
            _players[x]['score'] = (_players[x]['score'] as int) + 1;
          }
        }
        _phase = _KPhase.roundEnd;
        AudioService.playSuccess();
      } else {
        _accusationsLeft--;
        AudioService.playFailure();
        if (_accusationsLeft <= 0) {
          _winner = 'winker';
          _endReason = 'المحقق خلّص اتهاماته والغمّاز هرب!';
          _players[_winker]['score'] = (_players[_winker]['score'] as int) + 5;
          _phase = _KPhase.roundEnd;
        } else {
          _phase = _KPhase.play;
        }
      }
    });
  }

  void _nextRound() {
    AudioService.playClick();
    setState(() {
      if (_round < _rounds) {
        _round++;
        _newRound();
      } else {
        _started = false;
        _players = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '😉 الغمّاز',
        backgroundColor: FunkyColors.coral,
        body: GameIntroWidget(
          title: '😉 الغمّاز',
          icon: '😉',
          description:
              'لعبة الحفلات الكلاسيكية!\n\n🎭 الموبايل بيلف وكل واحد يشوف دوره في سرية: غمّاز واحد، محقق واحد، والباقي ضحايا.\n🕵️ المحقق يعلن نفسه. الكل يقعدوا يطالعوا بعض..\n😉 الغمّاز يقتل بالغمزة! اللي اتغمزله يستنى ثواني ويموت بدراما ويدوس على اسمه هنا.\n🔍 المحقق معاه 3 اتهامات بس يمسك بيهم الغمّاز.\n\nالغمّاز يكسب لو فضل هو وواحد بس!',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '😉 الغمّاز',
        minPlayers: 4,
        maxPlayers: 10,
        onStartGame: (ctx, selected) => _start(selected),
      );
    }

    switch (_phase) {
      case _KPhase.rolePass:
        return _buildRolePass();
      case _KPhase.roleShow:
        return _buildRoleShow();
      case _KPhase.play:
        return _buildPlay();
      case _KPhase.accuse:
        return _buildAccuse();
      case _KPhase.roundEnd:
        return _buildRoundEnd();
    }
  }

  Widget _scoreChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(_players.length, (i) {
        final p = _players[i];
        final dead = _dead.contains(i);
        return Opacity(
          opacity: dead ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlatColors.ink, width: 2),
            ),
            child: Text(
              '${p['name']} ${p['score']}${dead ? ' 💀' : ''}',
              style: flatCairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: FlatColors.ink,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRolePass() {
    return OfflineGameScaffold(
      title: '😉 الغمّاز',
      backgroundColor: FunkyColors.coral,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'الجولة $_round من $_rounds',
                style: flatCairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink.withValues(alpha: 0.65),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    const Text('🎭', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      'عدّي الموبايل لـ ${_players[_passIndex]['name']}',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'هيشوف دوره في سرية.. محدش يبص! 🙈',
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 15,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  setState(() => _phase = _KPhase.roleShow);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'تمام، أنا ${_players[_passIndex]['name']}',
                  style: flatCairo(fontSize: 19, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleShow() {
    return OfflineGameScaffold(
      title: '😉 الغمّاز',
      backgroundColor: FunkyColors.coral,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: FlatColors.ink, width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      _roleFor(_passIndex),
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _passIndex == _winker
                            ? FlatColors.mafia
                            : FlatColors.ink,
                      ),
                      textDirection: TextDirection.rtl,
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _roleDesc(_passIndex),
                      textAlign: TextAlign.center,
                      style: flatCairo(
                        fontSize: 16,
                        color: FlatColors.ink.withValues(alpha: 0.75),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  AudioService.playClick();
                  setState(() {
                    if (_passIndex + 1 < _players.length) {
                      _passIndex++;
                      _phase = _KPhase.rolePass;
                    } else {
                      _phase = _KPhase.play;
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _passIndex + 1 < _players.length
                      ? 'فهمت دوري، عدّيها ⏭️'
                      : 'يلا نبدأ الليلة! 🌙',
                  style: flatCairo(fontSize: 19, fontWeight: FontWeight.w900),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlay() {
    return OfflineGameScaffold(
      title: '😉 الغمّاز',
      backgroundColor: FunkyColors.coral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'الجولة $_round من $_rounds  •  اتهامات المحقق: $_accusationsLeft 🔍',
                style: flatCairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FlatColors.night,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '👁️ الكل يطالع بعض! الغمّاز بيقتل بالغمزة..\nاللي يتغمزله يدوس على اسمه 💀',
                  textAlign: TextAlign.center,
                  style: flatCairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: List.generate(_players.length, (i) {
                      final dead = _dead.contains(i);
                      return Material(
                        color: dead
                            ? FlatColors.ink.withValues(alpha: 0.15)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: dead ? null : () => _markDead(i),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: FlatColors.ink,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _players[i]['name'],
                                      style: flatCairo(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        decoration: dead
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: FlatColors.ink,
                                      ),
                                    ),
                                    if (dead)
                                      TextSpan(
                                        text: ' 💀',
                                        style: flatCairo(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: FlatColors.ink,
                                        ),
                                      ),
                                  ],
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  AudioService.playClick();
                  setState(() => _phase = _KPhase.accuse);
                },
                icon: const Icon(Icons.gpp_maybe, size: 26),
                label: Text(
                  'اتهام من المحقق 🔍',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mafia,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccuse() {
    return OfflineGameScaffold(
      title: '😉 الغمّاز',
      backgroundColor: FunkyColors.coral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_lastAccuseHit == false)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlatColors.mafia.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FlatColors.mafia, width: 2),
                  ),
                  child: Text(
                    '❌ ${_players[_lastAccused!]['name']} بريء! فاضل $_accusationsLeft اتهام',
                    textAlign: TextAlign.center,
                    style: flatCairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FlatColors.mafia,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              Text(
                'يا محقق، مين الغمّاز؟ 🕵️',
                style: flatCairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _players.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final dead = _dead.contains(i);
                    final isDetective = i == _detective;
                    return Opacity(
                      opacity: (dead || isDetective) ? 0.4 : 1,
                      child: ElevatedButton(
                        onPressed: (dead || isDetective)
                            ? null
                            : () => _accuse(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FlatColors.ink,
                          disabledBackgroundColor: Colors.white,
                          disabledForegroundColor: FlatColors.ink,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: FlatColors.ink,
                              width: 2,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          dead
                              ? '${_players[i]['name']} 💀'
                              : isDetective
                              ? '${_players[i]['name']} 🕵️ (إنت)'
                              : '${_players[i]['name']}',
                          style: flatCairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  AudioService.playClick();
                  setState(() => _phase = _KPhase.play);
                },
                child: Text(
                  'ارجع للعبة',
                  style: flatCairo(
                    fontSize: 14,
                    color: FlatColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundEnd() {
    final winkerName = _players[_winker]['name'];
    final (emoji, headline) = _winner == 'group'
        ? ('🕵️', 'المحقق مسك الغمّاز!')
        : ('😉', 'الغمّاز كسب الجولة!');
    final isLast = _round >= _rounds;
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return OfflineGameScaffold(
      title: '😉 الغمّاز',
      backgroundColor: FunkyColors.coral,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 64),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: FlatColors.ink,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                'الغمّاز كان: $winkerName 😉',
                style: flatCairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: FlatColors.mafia,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                _endReason ?? '',
                textAlign: TextAlign.center,
                style: flatCairo(
                  fontSize: 15,
                  color: FlatColors.ink.withValues(alpha: 0.7),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FlatColors.ink, width: 2),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, i) => const Divider(height: 8),
                    itemBuilder: (context, i) {
                      final p = sorted[i];
                      return Row(
                        children: [
                          Text(
                            '${i + 1}',
                            style: flatCairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: FlatColors.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p['name'] as String,
                              style: flatCairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: FlatColors.ink,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                          Text(
                            '${p['score']} ⭐',
                            style: flatCairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FlatColors.mintDark,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _nextRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.mintDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? 'خلاص! 🏁' : 'الجولة الجاية ⏭️',
                  style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
