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

## 6. Qualifications

- Fan-site mechanics (stickmanpartyapk.com, stickmanpartymodapk.app) are
  treated as proposed design guidance, NOT confirmed official rules.
- Gameplay videos corroborate game identity/catalog; mechanics here come from
  text sources, not frame-by-frame video observation.
- No reference assets, code, or APKs are downloaded or copied. Original
  implementations only, in the approved flat visual language.
