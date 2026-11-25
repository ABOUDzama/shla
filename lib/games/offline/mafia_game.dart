import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/global_player_selection_screen.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/game_intro_widget.dart';
import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';

/// مافيا (Mafia/Werewolf): social deduction, pass-and-play, app is the
/// moderator. Rules grounded in the classic game (Wikipedia: Mafia party
/// game):
/// - Informed minority (mafiosi) vs uninformed majority (villagers);
///   original Davidoff setup: about a third of players are mafia.
/// - Alternating night and day phases, starting with night. At night the
///   mafia secretly choose a victim; a doctor secretly protects one player;
///   a detective secretly investigates one player. By day everyone discusses
///   and votes to eliminate a suspect.
/// - The village wins by eliminating all mafiosi; the mafia wins on
///   numerical parity with the village.
/// - Winning team members score +3 each (Shla convention).
class MafiaGame extends StatefulWidget {
  const MafiaGame({super.key, this.seed = 7});

  /// Deterministic seed for tests.
  final int seed;

  static const String mafia = 'mafia';
  static const String doctor = 'doctor';
  static const String detective = 'detective';
  static const String villager = 'villager';

  /// Role list for [playerCount] players, shuffled with [rng].
  /// Mafia about a third (Davidoff), min 1; doctor+detective from 6 players.
  static List<String> rolesFor(int playerCount, Random rng) {
    final mafiaCount = max(1, (playerCount / 3).round());
    final hasDoctor = playerCount >= 6;
    final hasDetective = playerCount >= 6;
    final roles = <String>[
      for (var i = 0; i < mafiaCount; i++) mafia,
      if (hasDoctor) doctor,
      if (hasDetective) detective,
      for (var i = 0;
          i < playerCount - mafiaCount - (hasDoctor ? 1 : 0) - (hasDetective ? 1 : 0);
          i++)
        villager,
    ];
    roles.shuffle(rng);
    return roles;
  }

  /// Classic win check. Returns 'village', 'mafia', or null.
  static String? winner(Map<String, String> roles, Set<String> alive) {
    var mafiaAlive = 0;
    var villageAlive = 0;
    roles.forEach((name, role) {
      if (!alive.contains(name)) return;
      if (role == mafia) {
        mafiaAlive++;
      } else {
        villageAlive++;
      }
    });
    if (mafiaAlive == 0) return 'village';
    if (mafiaAlive >= villageAlive) return 'mafia';
    return null;
  }

  /// House tie-break: seeded random pick among tied names (labeled in the
  /// intro; classic games revote or use a moderator).
  static String breakTie(List<String> tied, Random rng) =>
      tied[rng.nextInt(tied.length)];

  /// Winning team members +3 each.
  static Map<String, int> scoreWin(
    Map<String, int> scores,
    Map<String, String> roles, {
    required String winnerSide,
  }) {
    final next = Map<String, int>.from(scores);
    roles.forEach((name, role) {
      final isMafia = role == mafia;
      if ((winnerSide == 'mafia' && isMafia) ||
          (winnerSide == 'village' && !isMafia)) {
        next[name] = (next[name] ?? 0) + 3;
      }
    });
    return next;
  }

  @override
  State<MafiaGame> createState() => _MafiaGameState();
}

class _MafiaGameState extends State<MafiaGame> {
  late final Random _rng = Random(widget.seed);
  bool _showIntro = true;
  bool _started = false;

  List<String> _names = [];
  Map<String, int> _scores = {};
  Map<String, String> _roles = {};
  final Set<String> _alive = {};

  int _dayNumber = 0;

  // Deal phase.
  int _dealIndex = 0;
  bool _cardRevealed = false;

  // Night phase: every alive player gets a private prompt in turn, behind a
  // reveal gate so the previous player cannot see the next one's role.
  int _nightIndex = 0;
  bool _nightRevealed = false;
  final Map<String, String> _mafiaVotes = {};
  String? _protectedName;
  String? _nightVictim;
  bool _victimSaved = false;
  String? _investigateResult;

  // Day phase: announce first, then secret ballot.
  bool _dayVoteStarted = false;
  int _voteIndex = 0;
  final Map<String, String> _dayVotes = {};
  String? _eliminatedName;

  String? _winnerSide;

  List<String> get _aliveList =>
      _names.where(_alive.contains).toList(growable: false);

  void _start(List<String> names) {
    final roles = MafiaGame.rolesFor(names.length, _rng);
    setState(() {
      _names = names;
      _scores = {for (final n in names) n: 0};
      _roles = {for (var i = 0; i < names.length; i++) names[i]: roles[i]};
      _alive
        ..clear()
        ..addAll(names);
      _dayNumber = 0;
      _dealIndex = 0;
      _cardRevealed = false;
      _winnerSide = null;
      _started = true;
    });
  }

  void _beginNight() {
    setState(() {
      _dayNumber++;
      _dayVoteStarted = false;
      _voteIndex = 0;
      _dayVotes.clear();
      _nightIndex = 0;
      _nightRevealed = false;
      _mafiaVotes.clear();
      _protectedName = null;
      _nightVictim = null;
      _victimSaved = false;
      _investigateResult = null;
    });
  }

  /// The current night player's private action resolved; move on.
  void _nightAction(String? choice) {
    final player = _aliveList[_nightIndex];
    final role = _roles[player]!;
    setState(() {
      if (role == MafiaGame.mafia && choice != null) {
        _mafiaVotes[player] = choice;
      } else if (role == MafiaGame.doctor && choice != null) {
        _protectedName = choice;
      } else if (role == MafiaGame.detective && choice != null) {
        _investigateResult =
            _roles[choice] == MafiaGame.mafia ? 'مافيا 🔫' : 'مش مافيا 😶';
      }
    });
  }

  void _nightNext() {
    setState(() {
      _investigateResult = null;
      _nightRevealed = false;
      if (_nightIndex + 1 < _aliveList.length) {
        _nightIndex++;
      } else {
        _resolveNight();
      }
    });
  }

  void _resolveNight() {
    // Mafiosi "agree": most-voted victim wins, ties broken by seeded rng.
    String? victim;
    if (_mafiaVotes.isNotEmpty) {
      final counts = <String, int>{};
      for (final v in _mafiaVotes.values) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      final top = counts.values.fold(0, max);
      final tied = counts.keys.where((n) => counts[n] == top).toList();
      victim = MafiaGame.breakTie(tied, _rng);
    }
    setState(() {
      _nightVictim = victim;
      _victimSaved = victim != null && victim == _protectedName;
      if (victim != null && !_victimSaved) {
        _alive.remove(victim);
      }
      _winnerSide = MafiaGame.winner(_roles, _alive);
      if (_winnerSide != null) _applyWin();
    });
  }



  void _castDayVote(String suspect) {
    _dayVotes[_aliveList[_voteIndex]] = suspect;
    if (_voteIndex + 1 < _aliveList.length) {
      setState(() => _voteIndex++);
    } else {
      _tallyDayVotes();
    }
  }

  void _tallyDayVotes() {
    final counts = <String, int>{};
    for (final v in _dayVotes.values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final top = counts.values.fold(0, max);
    final tied = counts.keys.where((n) => counts[n] == top).toList();
    final eliminated = MafiaGame.breakTie(tied, _rng);
    setState(() {
      _alive.remove(eliminated);
      _eliminatedName = eliminated;
      _winnerSide = MafiaGame.winner(_roles, _alive);
      if (_winnerSide != null) _applyWin();
    });
  }

  void _applyWin() {
    _scores = MafiaGame.scoreWin(_scores, _roles, winnerSide: _winnerSide!);
  }

  void _continueAfterElimination() {
    setState(() {
      _eliminatedName = null;
      _beginNight();
    });
  }

  String _roleLabel(String role) {
    switch (role) {
      case MafiaGame.mafia:
        return 'مافيا 🔫';
      case MafiaGame.doctor:
        return 'دكتور 🩺';
      case MafiaGame.detective:
        return 'محقق 🕵';
      default:
        return 'من المدنيين 🧑';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: '🔫 مافيا',
        backgroundColor: FunkyColors.coral,
        showAi: false,
        body: GameIntroWidget(
          title: '🔫 مافيا',
          icon: '🔫',
          description:
              'الليل بيجمع والمافيا بتختار ضحية في السر، والدكتور بيحمي والمحقق بيكشف. بالنهار كلكم تتناقشوا وتصوّتوا تشيلوا واحد. المدنيين يكسبوا لو خلصوا على المافيا، والمافيا تكسب لو بقوا زيهم عددًا. مبني على قواعد المافيا الكلاسيكية، بس التصويت عندنا سري بالتناوب على الموبايل والتعادل بيتحسم عشوائيًا، والدكتور والمحقق بيدخلوا من ٦ لاعبين.',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }

    if (!_started) {
      return GlobalPlayerSelectionScreen(
        gameTitle: '🔫 مافيا',
        minPlayers: 5,
        onStartGame: (ctx, selected) {
          _start(selected);
          _beginNight();
        },
      );
    }

    if (_winnerSide != null) return _buildWin();
    if (_eliminatedName != null) return _buildEliminated();
    // Deal phase uses its own flat-design scaffold (direction preview).
    if (_dealIndex < _names.length) return _buildDeal();

    return OfflineGameScaffold(
      title: '🔫 مافيا',
      backgroundColor: FunkyColors.coral,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _nightVictim == null && _dayVotes.isEmpty && _voteIndex == 0
            ? _buildNight()
            : _buildDay(),
      ),
    );
  }

  // ---- Deal ----
  // Reference-led flat/cartoon direction, grounded in observed screenshots:
  // WePlay home (light cream bg, flat pastel game tiles, cartoon character,
  // small tags) and WePlay "Who's the Imposter" (flat top info card, avatar
  // circles, solid yellow action button), plus Heads Up! flat solid color
  // + giant type. No gradients, no glow, no neon.

  static const Color _flatBg = Color(0xFFFFF6E9);
  static const Color _flatInk = Color(0xFF2B2140);
  static const Color _flatBorder = Color(0xFFEFE3D0);

  (Color, String, String) _roleVisual(String role) {
    switch (role) {
      case MafiaGame.mafia:
        return (const Color(0xFFFF5A5A), '🔫', 'مافيا');
      case MafiaGame.doctor:
        return (const Color(0xFF35C99E), '🩺', 'الدكتور');
      case MafiaGame.detective:
        return (const Color(0xFF4D8DFF), '🕵', 'المحقق');
      default:
        return (const Color(0xFF9B7EDE), '🧑', 'من المدنيين');
    }
  }

  /// Cartoon-flat solid button: solid fill, darker bottom edge, no gradient.
  Widget _flatButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final dark = HSLColor.fromColor(color)
        .withLightness(
            (HSLColor.fromColor(color).lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border(bottom: BorderSide(color: dark, width: 5)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
        ),
      ),
    );
  }

  Widget _buildDeal() {
    final name = _names[_dealIndex];
    final (accent, heroEmoji, roleTitle) = _roleVisual(_roles[name]!);
    final isLast = _dealIndex + 1 >= _names.length;
    return Scaffold(
      backgroundColor: _flatBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flat header: plain dark title + round white icon buttons.
              Row(
                children: [
                  _roundIcon(Icons.settings_rounded),
                  const Spacer(),
                  Text(
                    'مافيا',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _flatInk,
                    ),
                  ),
                  const Spacer(),
                  _roundIcon(Icons.arrow_forward_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                ],
              ),
              const SizedBox(height: 14),
              // Progress tag: flat bordered, not a gradient pill.
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: FlatColors.ink,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _flatBorder, width: 2),
                  ),
                  child: Text(
                    'الدور ${_dealIndex + 1} من ${_names.length} 🤫',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _flatInk,
                    ).copyWith(
                        fontFamilyFallback: const ['Noto Color Emoji']),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Avatar: flat solid pastel circle + initial.
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      name.characters.first,
                      style: GoogleFonts.cairo(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _flatInk,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _flatInk,
                ),
              ),
              const SizedBox(height: 12),
              // The card: white flat tile when hidden; solid flat role color
              // when revealed (Heads Up! style color moment).
              Expanded(
                child: AnimatedContainer(
                  duration: 250.ms,
                  decoration: BoxDecoration(
                    color: _cardRevealed ? accent : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: _cardRevealed ? accent : _flatBorder,
                        width: 2),
                  ),
                  child: Center(
                    child: _cardRevealed
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(heroEmoji,
                                      style:
                                          const TextStyle(fontSize: 84))
                                  .animate()
                                  .scale(
                                      duration: 350.ms,
                                      curve: Curves.elasticOut),
                              const SizedBox(height: 10),
                              Text(
                                roleTitle,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ).copyWith(
                                    fontFamilyFallback: const [
                                      'Noto Color Emoji'
                                    ]),
                              ).animate().fadeIn(duration: 250.ms),
                              const SizedBox(height: 6),
                              Text(
                                'افتكر دورك كويس.. ومتوريهوش لحد!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                    fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.75)),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Original illustrated scene (generated for
                              // Shla): the game's visual identity, WePlay-style
                              // richness instead of a bare emoji.
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.asset(
                                      'assets/tiles/mafia.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  'بس $name اللي يشوف! 🤫',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                          fontSize: 13, color: _flatInk)
                                      .copyWith(
                                          fontFamilyFallback: const [
                                            'Noto Color Emoji'
                                          ]),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!_cardRevealed)
                _flatButton(
                  label: 'شوف دورك يا $name',
                  color: accent,
                  onPressed: () => setState(() => _cardRevealed = true),
                )
              else
                _flatButton(
                  label: isLast ? 'ابدأ الليل 🌙' : 'اللاعب اللي بعده',
                  color: _flatInk,
                  onPressed: () {
                    if (!isLast) {
                      setState(() {
                        _dealIndex++;
                        _cardRevealed = false;
                      });
                    } else {
                      setState(() => _dealIndex++);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _flatBorder, width: 2),
        ),
        child: Icon(icon, color: _flatInk, size: 20),
      ),
    );
  }

  // ---- Night ----

  Widget _buildNight() {
    final player = _aliveList[_nightIndex];
    final role = _roles[player]!;
    final others =
        _aliveList.where((n) => n != player).toList(growable: false);

    if (!_nightRevealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الليل $_dayNumber 🌙',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7))
                .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: FlatDecor.card(radius: 26),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🤫', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FunkyButton(
                        label: 'شوف مهمتك يا $player',
                        accent: FunkyColors.violet,
                        icon: Icons.visibility_rounded,
                        onPressed: () =>
                            setState(() => _nightRevealed = true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'بس $player اللي يشوف!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: FlatColors.ink.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_investigateResult != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الليل $_dayNumber 🌙',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7))
                .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: FlatDecor.card(radius: 26),
              child: Center(
                child: Text(
                  _investigateResult!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: FlatColors.ink,
                  ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                ).animate().scale(duration: 300.ms),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FunkyButton(
            label: 'خبّي وادّي للي بعده',
            accent: FunkyColors.mint,
            icon: Icons.arrow_forward_rounded,
            onPressed: _nightNext,
          ),
        ],
      );
    }

    final prompt = switch (role) {
      MafiaGame.mafia => 'إنت مافيا 🔫 اختار ضحيتك:',
      MafiaGame.doctor => 'إنت الدكتور 🩺 اختار مين تحمي:',
      MafiaGame.detective => 'إنت المحقق 🕵 اختار مين تحقق فيه:',
      _ => 'ميعملش حاجة بالليل 😴',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الليل $_dayNumber 🌙 - الدور على $player',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7))
              .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 8),
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: FlatColors.ink,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 16),
        if (role == MafiaGame.villager)
          Expanded(
            child: Center(
              child: FunkyButton(
                label: 'تمام، عدّي للي بعده',
                accent: FunkyColors.violet,
                icon: Icons.nightlight_round,
                onPressed: _nightNext,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: role == MafiaGame.doctor
                  ? _aliveList.length
                  : others.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final candidate =
                    role == MafiaGame.doctor ? _aliveList[i] : others[i];
                return GestureDetector(
                  onTap: () {
                    _nightAction(candidate);
                    if (role != MafiaGame.detective) _nightNext();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration:
                        FlatDecor.card(radius: 20),
                    child: Text(
                      candidate,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---- Day ----

  Widget _buildDay() {
    // Announce first, then vote.
    if (!_dayVoteStarted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الصبح $_dayNumber ☀',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7))
                .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: FlatDecor.card(radius: 26),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _nightVictim == null
                        ? 'الليلة دي عدّت بسلام 😴'
                        : _victimSaved
                            ? 'المافيا حاولت تاخد ${_nightVictim!} بس الدكتور أنقذه! 🩺'
                            : 'المافيا أخدت ${_nightVictim!} 💀',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ).copyWith(
                        fontFamilyFallback: const ['Noto Color Emoji']),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'اتناقشوا.. وبعدين صوّتوا تشيلوا أكتر واحد مشكوك فيه',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 12),
          FunkyButton(
            label: 'ابدأ التصويت ⚖️',
            accent: FunkyColors.amber,
            icon: Icons.how_to_vote_rounded,
            onPressed: () => setState(() {
              _voteIndex = 0;
              _dayVoteStarted = true;
            }),
          ),
        ],
      );
    }

    // Hmm: _voteIndex stays 0; use a separate flag for vote start.
    return _buildDayVote();
  }

  Widget _buildDayVote() {
    final voter = _aliveList[_voteIndex];
    final others =
        _aliveList.where((n) => n != voter).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التصويت ⚖️',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontSize: 14, color: FlatColors.ink.withValues(alpha: 0.7))
              .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
        ),
        const SizedBox(height: 4),
        Text(
          'يا $voter، مين أكتر واحد مشكوك فيه؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: FlatColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final candidate = others[i];
              return GestureDetector(
                onTap: () => _castDayVote(candidate),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration:
                      FlatDecor.card(radius: 20),
                  child: Text(
                    candidate,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Eliminated / Win ----

  Widget _buildEliminated() {
    final role = _roles[_eliminatedName]!;
    return OfflineGameScaffold(
      title: '🔫 مافيا',
      backgroundColor: FunkyColors.amber,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المجموعة قررت! ⚖️',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 16, color: FlatColors.ink.withValues(alpha: 0.75))
                  .copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 12),
            Text(
              _eliminatedName!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ),
            ).animate().scale(duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'كان ${_roleLabel(role)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FlatColors.ink,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 32),
            FunkyButton(
              label: 'كمّلوا',
              accent: FunkyColors.amber,
              icon: Icons.arrow_forward_rounded,
              onPressed: _continueAfterElimination,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWin() {
    final title = _winnerSide == 'village'
        ? 'المدنيون كسبوا! 🎉'
        : 'المافيا كسبت! 🔫';
    final sorted = _scores.keys.toList()
      ..sort((a, b) => _scores[b]!.compareTo(_scores[a]!));
    return OfflineGameScaffold(
      title: '🔫 مافيا',
      backgroundColor: FunkyColors.mint,
      showAi: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: FlatColors.ink,
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ),
            const SizedBox(height: 20),
            for (final n in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '$n (${_roleLabel(_roles[n]!)}): ${_scores[n]}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: FlatColors.ink.withValues(alpha: 0.75),
                  ).copyWith(
                      fontFamilyFallback: const ['Noto Color Emoji']),
                ),
              ),
            const SizedBox(height: 24),
            FunkyButton(
              label: 'العب تاني',
              accent: FunkyColors.mint,
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() {
                _started = false;
                _showIntro = true;
                _alive.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }

}
