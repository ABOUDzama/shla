# ألعاب ١٢٣٤ — popularity & mechanics research (2026-11-25)

Mandate: user asked us to research the most popular 1-2-3-4-player games on the
internet and implement similar ones ("روح دور ع النت و ابحث ع اشهر الالعاب ١٢٣٤
و شوفهم و اعمل زيهم"). This file records the grounded evidence and the chosen
cohesive set. All implementations must be original art/code — never copy
reference assets.

## 1. Popularity evidence (live sources, observed 2026-11-25)

| App | Store evidence | Lifetime downloads | Rating |
| --- | --- | --- | --- |
| Stickman Party 234 MiniGames (PlayMax, com.PlayMax.playergames) | play.google.com/store/apps/details?id=com.PlayMax.playergames (500M+, 4.6★, 2.92M reviews, "50 different games") | 572,310,914 (appcurves.com/app/stickman-party-234-minigames, reading 2026-11-15) | 4.60 from 2.91M |
| 1 2 3 4 Player Games - Offline (JindoBlu, com.JindoBlu.FourPlayers) | play.google.com/store/apps/details?id=com.JindoBlu.FourPlayers (100M+, 4.6★, ~180K reviews) | 137,385,580 (appcurves.com/app/1-2-3-4-player-games, reading 2026-11-15) | 4.59 from 178,881 |
| 2 Player games: the Challenge (JindoBlu) | play.google.com/store/apps/details?id=com.JindoBlu.TwoPlayerGamesChallenge (100M+, 4.6★, 739K reviews) | — | 4.6 |

Gameplay-video evidence (identity corroboration; not frame-watched):
- YouTube "Stickman Party - Gameplay Walkthrough Part 41" youtube.com/watch?v=iJk6xCwGeOE
- YouTube "Stickman BEST MINIGAMES Tournament Stickman Party 1234 Player 2026" youtube.com/watch?v=1JvZX8_QQhs (2026-06-02)
- "Stickman Party 1 2 3 4 Players - ALL MINIGAMES Gameplay Walkthrough" via alizta.com/stickman-party-1-2-3-4-players-all-minigames-gameplay-walkthrough-android-ios/

Mechanics sources:
- OFFICIAL store text: PlayMax App Store/Play descriptions (tanks, soccer,
  racing, sea battle, chickens, ghost, run named explicitly); JindoBlu Play
  description (Snakes, Tic tac toe, Pool, Paint fight, Spinner war, Archery,
  Tug of war, Whack a mole, Memory, Maths, Racing cars, Sword duels named).
- QUALIFIED FAN sources (not official): stickmanpartyapk.com/all-stickman-party-mini-games/
  (all-50 catalog + one-paragraph mechanics each, 2026-09-11);
  stickmanpartymodapk.app per-game pages (detailed controls/rules, e.g. /soccer/).
  Fan mechanics are treated as proposed design guidance, not confirmed official rules.

## 2. Stickman Party 50-game catalog (fan catalog, qualified)

Survival: Ghost Attack, Shockwave, Boulder Bash, Block Breakers, Epic Fail,
Police Chase, Zombie Survival, UFO Battle, DangerField
Racing/movement: Stickman Run, Car Race, Fun Race, Fast Boats, Ninja Warriors
Combat: Tank Battle, Snow Brawl, Gladiators, Missile Battle, Pirate Island,
Wild West, The Planes, Dynamite, Explosive Tennis
Collecting/scoring: The Chickens, Knock Coins, Candy Hunters, Pizza Time,
Magnets, Mushroom Panic, Go Shopping, Ice Cream Master, Karaoke Master,
Bank Heist, Fishing, Knight Match
Sports: Soccer, Basketball, Stick and Ball
Strategy/puzzle: Sea Battle, Color Claim, Color Switch, Treasure Seekers,
Prison Break, Paintball
Rhythm: Guitar Heroes

## 3. JindoBlu 1-2-3-4 roster (OFFICIAL listing text)

Snakes, Tic tac toe, Pool, Paint fight, Spinner war, Archery, Tug of war,
Whack a mole, Memory, Maths, Solitaire, Jigsaw, Racing cars, Sword duels;
recent: Guess the Animal, Triple, Farkle.

## 4. Current Shla ١٢٣٤ section (11 games) mapped to references

| Shla game | Reference counterpart | Source |
| --- | --- | --- |
| دبابات الشلة (tank_battle) | SP Tank Battle (#3, named official) | rebuilt v4, committed 8779e67+6be640f |
| حية الشلة (snake_arena) | SP Witching Snake / JindoBlu Snakes (official) | live |
| معركة التلج (snow_brawl) | SP Snow Brawl (#28) | live |
| شد الحبل (tug_of_war) | JindoBlu Tug of war (official) | live |
| اضرب الخلد (whack_mole) | JindoBlu Whack a mole (official) / SP Garden Defense (#34) | live |
| لمّ الفلوس (coin_grab) | SP Knock Coins (#11) / Candy Hunters (#25) | live |
| سومو الشلة (sumo) | JindoBlu Spinner war/Sumo (official) / SP Push All (#12) | live |
| سباق الدوس (tap_race) | SP Fast Boats (#27 tapping race) | live |
| اقطفها (catch_game) | SP Fishing (#43) | live |
| كورة اللمسة (touch_ball) | SP Stick and Ball (#7) | live |
| أسرع رد فعل (reaction_game) | SP Wild West (#18 quick-draw) | live |

## 5. Chosen next set (judgment, evidence-ranked)

Selection criteria: named in OFFICIAL store text or top-15 fan catalog rank,
family-friendly, one-touch corner-pad control fit (approved control style),
distinct mechanic families (sport, survival, race, hot-potato, collecting),
feasible with existing top-down arena engine.

Batch 1 (5 games):
1. كورة الشلة (Soccer). Top-down football, 1v1..2v2. No kick button: run into
   the ball, momentum+angle set the shot; walls bounce; most goals when the
   timer ends wins; wide goals, body-checking allowed.
   Evidence: named in PlayMax OFFICIAL App Store text ("Stickman football");
   mechanics stickmanpartymodapk.app/soccer/ (fan, 2025-11-11).
2. هجوم الشبح (Ghost Attack). Roaming ghost hunts players in a small arena;
   players cannot fight back; last player standing wins.
   Evidence: PlayMax OFFICIAL text ("Run away from the ghost"); SP fan catalog #1.
3. سباق العربيات (Car Race). Top-down lap race; hold corner pad to steer
   (reuse tank one-button steering), first to finish the laps wins.
   Evidence: PlayMax OFFICIAL text ("Racing cars"); SP fan catalog #4.
4. الديناميت (Dynamite). Hot potato: bomb carrier tags another player to pass
   it; bomb explodes on a timer and eliminates the carrier; last alive wins.
   Evidence: SP fan catalog #14 (qualified).
5. الفراخ (The Chickens). Collecting race: chickens scatter unpredictably;
   most chickens caught when the timer ends wins.
   Evidence: PlayMax OFFICIAL text ("catch chickens"); SP fan catalog #10.

Batch 2 (candidates, after batch 1 lands): Sea Battle (2P strategy, official
named), Paintball/Paint fight (territory painting, official JindoBlu named),
Air hockey (2P, official JindoBlu named), Color Claim (trail loops), Bank
Heist (collect + avoid police).

## 6. Observed gameplay footage (2026-11-25, cloud browser on YouTube)

Method: seek + pause + screenshot at multiple timestamps; frames actually
viewed. Sources:
- Soccer: youtube.com/watch?v=CSY9vl8Zk5M ("Stickman Party : Soccer
  Gameplay.", EBRUZA Gaming, 1:19).
- Tanks: youtube.com/watch?v=gXi19-b_miY ("TANK BATTLE WITH BOTS |
  Stickman Party", Atlista Gaming, 9:07, 143K views).

### Soccer — observed
- CHOOSE MAP screen with 2 maps: classic green grass pitch and a blue
  pool/beach pitch (swim-ring players).
- Landscape field, white markings, netted goals on left and right ends.
- 4 players, one per color (red/blue/yellow/green); 2v2 teams (the win
  screen shows TWO winner faces: blue + yellow beat red + green).
- Scoreboard rendered twice, rotated 180°, once per side of the phone
  (same score + timer mirrored for players sitting opposite each other).
- Timer counts down from 90s. Match ends EARLY when a team reaches 3
  goals (observed 3-0 with 65s left → Winner screen). Win screen: Winner
  ribbons, MENU / PLAY AGAIN, coin reward (+37, with ad multiplier).
- Ball: classic soccer ball, starts center at kickoff; players run into
  it to shoot (no kick button visible anywhere); an AI/static goalkeeper
  sits in each goal mouth; body collisions and goal-mouth scrambles are
  the core action; GOAL! banner then kickoff reset.
- No persistent on-screen buttons seen; players run continuously.

### Tanks — observed (with an important variant caveat)
- Industrial/metal arena with obstacle blocks and hazard-striped edges;
  corner battery-segment HUD per player.
- This 5-year-old footage shows SEGMENTED HEALTH bars (blue drops 4→2
  after hits), flag-topped base pads, and respawn with a glow ring —
  consistent with the "Capture The Flag" tank mode (a separate listed
  video title), not necessarily the classic elimination mode.
- Our implementation (one-hit elimination, last tank standing) matches
  the classic mode described by the rules screen quote "Be the last tank
  standing!" and the fan mechanics pages; the observed footage is a
  different/older variant. Logged as a discrepancy, not silently merged.

### Adaptation decisions for our Soccer (pending implementation)
- One original map (our own art in the approved flat language), not the
  two reference maps.
- 2v2 fixed teams (players 1+3 vs 2+4), bots fill empty slots; 2 humans =
  1v1 with optional bot teammates... simplest: always 2 teams, bots fill
  to 4 total players.
- 90s countdown, first to 3 goals ends early; draw possible at 0-0 etc.
- No kick button: run into the ball, momentum + contact angle set the
  shot. Static AI keeper per goal (matches footage).
- Controls: our approved corner pads (hold = steer while auto-running),
  the same control family as دبابات الشلة and the reference's one-touch
  scheme. Corner pads are our approved control adaptation, not a
  reference-copied UI.

## 7. Qualifications

- Fan-site mechanics (stickmanpartyapk.com, stickmanpartymodapk.app) are
  treated as proposed design guidance, NOT confirmed official rules.
- Gameplay videos corroborate game identity/catalog; mechanics here come from
  text sources, not frame-by-frame video observation.
- No reference assets, code, or APKs are downloaded or copied. Original
  implementations only, in the approved flat visual language.
