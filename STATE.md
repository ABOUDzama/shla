# Shla flat-rollout state (updated 2026-11-25 23:28 EET)

HEAD: 55ef081 pushed to origin/main (GitHub push authorized by user WhatsApp 23:04:44; keep remote current at batch boundaries). Coverage: 33/45 interiors.

## Flat rollout coverage (user-approved direction: XO trial 21:32 "حلو اوي يلا عمم التعديل ع كل الالعاب")
- Stage 1 (commit e13ff72): shared OfflineGameScaffold header + GameIntroWidget flat for ALL 45 games. Settings screen flat (commit with contrast pass).
- Stage 2 bodies DONE (28/45): xo (approved trial), quiz, memory, taboo, most_likely, spy, undercover, who_said, emoji_guess, password, proverb, mafia (all phases), bus_complete, would_rather, never_have_i, opposite_day, truth_or_lie, truth_or_dare, five_seconds, charades, word_chain, first_letter, word_story, ranking_challenge, odd_one_out, tick_tock_boom, reverse_quiz, code_names (+ gate/keymap/board phase captures, glowCard + invisible clue-text fixed), pictionary (drawing+guess+decide+result captured, result phase made scrollable after 41px overflow), who_am_i, seega, gobblet (scrollable after 100px overflow), multi_touch.
- Shared GlobalPlayerSelectionScreen (player picker) flat: cream bg, white tiles, pastel avatar circles, mintDark checks (batch7).
- Shared FunkyButton now flat (solid + darker bottom edge), used by 14 games.
- Contrast pass 1: quiz reveal hint + scoreboard small text ink75; memory scoreboard ink75.
- Contrast pass 2 (commit b1e4d74, rendered-pixel verified): FlatDecor.textOn(bg) picks ink vs white by fill luminance (>0.32 -> ink). White text now only on violet/sky/mafia (>=3:1); ink on mint/coral/amber/pink (>=4.6:1). FlatColors.mintDark 1F9E77 (3.4:1 on white) for success text on light bg. Quiz neon +/- buttons flattened. Taboo pills -> flat tags. would_rather/never_have_i now have small360 goldens, pixel-viewed OK. Contrast floor raised to 4.5:1 for small text (parent 22:31): textOn = max-contrast ink/white, ink wins on all pastels; mintDark 17795A 5.4:1; ink alpha floor 0.7.

## Stage 2 bodies REMAINING (~17)
- Word/party: DONE. Remaining: 10 arcade interiors (reaction, tap_race, tug_of_war, sumo, snake_arena, whack_mole, coin_grab, catch, touch_ball, snow_brawl) + tank_battle verify + balance_game check.
- Arcade custom-painted interiors: reaction, tap_race, tug_of_war, sumo, snake_arena, whack_mole, coin_grab, catch, touch_ball, snow_brawl, tank_battle (tank UI mostly done in v4, check).

## Verification status
- Suites green at batch7: small_screen 42/42; game_interaction 28/28 rerun post-sweep (code_names team-color expectations updated to C63730/2B5CD6) (code_names test added); golden_interiors 8/8, arcade_play_proof 11/11, game_interaction 28/28 (28 pre-elevation-sweep, rerun pending).
- Every converted game's golden pixel-viewed (combos in /downloads/stage2_batch*.png).
- Regenerated goldens != visual acceptance; pixels viewed per batch.

## APK gate
- NO interim APKs. ONE combined reviewed APK (next versionCode 7) only after: 1234 games done + full flat rollout + user preview approval via main. Zip-wrapped, PRIVATE File (v6 = file-01M88MS2WCKTSVFMWT7YKNSWSY).

## Soccer (bounded, after rollout priority)
- Observed rules: docs/1234_popularity_research.md section 6 (youtube.com/watch?v=CSY9vl8Zk5M).
- Design: 2v2, bots fill to 4 ONLY if user picks bots=اه; bots=لا honored (2P=1v1, 3P=2v1 disclosed, 1P=honest practice). 90s, first-to-3, draw ok, no kick button, static keepers, ONE original flat map, no coins/ads.
- Must attach SAVED observed frames + scheme-ful source URLs in staged report.

## Wakes
- wakeschedule-01M8A09XSV2D2SCH0G5MHTJA1E recurring 45min (stage-2 prompt).
- wakeschedule-01M89SM6ACSAAAZ6YZMPFTKT6W one-shot 2026-11-26T00:05 EET (midnight art queue).
- wakeschedule-01M89SM6ACSAAAZ6YZMPFTKT6W one-shot 2026-11-26T00:05 EET midnight art queue (16/20 budget).
- Task agent expires 2026-11-26 02:02:56 EET. Repo bundle owed to parent before expiry.


## Batch 4 (b79df37+fix)
- opposite_day, truth_or_lie, truth_or_dare, five_seconds, charades, word_chain converted + small360 captures (6 new, 31 tests in small_screen suite)
- truth_or_lie tofu fix: statement/feedback/explanation/button labels now GoogleFonts.cairo (harness has no Arabic in default font; device consistency too)
- word_chain setup title white->ink fix after pixel inspection
- Remaining 22: word_story, first_letter, odd_one_out, tick_tock_boom, ranking_challenge, code_names, pictionary, seega, gobblet, multi_touch, reverse_quiz, who_am_i accents; arcade: reaction, tap_race, tug_of_war, sumo, snake_arena, whack_mole, coin_grab, catch, touch_ball, snow_brawl; verify tank_battle

## Batch 4 corrections (parent feedback 22:58)
- Count fix: 21/45, not 23. Ledger: 15 reported at 22:31 + opposite_day/truth_or_lie (converted pre-compaction, first captures this batch) + 4 newly converted (truth_or_dare, five_seconds, charades, word_chain) = 21. would_rather/never_have_i were already inside the 15 with captures from the earlier newcaptures batch.
- Removed duplicate per-game home IconButtons in all 6 batch-4 games; shared OfflineGameScaffold home covers exit.
- Tofu root cause: google_fonts 6.3.3 cairo() has no fontFamilyFallback param; scaffold title had it via raw TextStyle. Added flatCairo() wrapper in flat_theme.dart (Cairo + kEmojiFontFallback) and swept all GoogleFonts.cairo call sites in offline games + widgets (49 files). Chip emoji now render in goldens (verified pixels).
- first_letter converted (batch 5 start): ink on orange hue, white cards, removed duplicate home, success/fail to mintDark/mafia. Capture pixel-viewed.
- batch5: word_story, ranking_challenge, odd_one_out, tick_tock_boom converted. odd_one_out + tick_tock_boom needed TextStyle->flatCairo (harness tofu). tick_tock explosion phase keeps white on black (intentional dark phase). Elevation/shadow sweep validated by suites; tank control glow restored.
- batch6: reverse_quiz converted; ranking_challenge SegmentedButton labels got flatCairo (digit tofu); ROOT CAUSE of heavy button outlines: flutter_test renders elevation as crisp black shadow-approximation; swept elevation:0 into 41 ElevatedButton.styleFrom blocks app-wide (incl. theme in main.dart). Verified flat in captures.


## Batch 11 (00:20)
- Arcade flat conversion: tap_race, tug_of_war, sumo, snake_arena, whack_mole, coin_grab, catch, touch_ball, snow_brawl (cream bg, white bordered arenas, ink text). 44/45 interiors incl. tank_battle (already flat, captured). balance_game still to verify.
- Art: user-approved 8 card-character cast (user 00:11:56 approval of group8): 8 avatars in picker (assets/avatars/card_*.png), group hero on home (assets/avatars_2d/group.jpg). Old new-cast on branch art-preview (parked, unused).
- Suites: small_screen 53/53 (run in parts), game_interaction 28/28, golden_interiors 8/8, shellty + avatar picker golden pass.

- Batch 12 (00:25): balance_game flat -> 45/45 interiors converted (balance play/lost states not captured). VictoryFriends + GlobalPlayerSelection now use card-character circular avatars (builtInAvatars only appended: saved asset: ids unchanged). Winner text color fixed (was white on cream). small_screen 55 tests green (run in parts), game_interaction not rerun after this commit.

## Batch 13+ (1234 section, reference-driven) - updated 01:04
- Reference app (user's link, 00:47): https://play.google.com/store/apps/details?id=com.ction.playergames "2 3 4 Player Mini Games" (Better World Games). Listing names: Snake Arena, Skateboard Racing, Tank Battle, Grab the Fish, Soccer, Sumo, Chicken Run, Rally Drifters, Micro Speed Racers, Feed the Pigeon; screenshots also show Monster Attack. Soccer CANCELLED by user (code kept in lib/games/offline/soccer_*.dart, not in registry).
- Profile/first-launch flow, leaderboard page (الترتيب), cream flat 1234 section: done and pushed.
- جري الفراخ (chicken_run_*): one-touch gravity-flip runner, ORIGINAL adaptation (rules inferred from listing text + App Store review, not verified). Tests: logic 7, widget 6 with captures (holes, midair, elimination, win with cast, draw).
- سباق العربيات (car_race_*): oval track, 3 laps, hold left/right corner pads, grass slows. Tests: logic 6, widget 4 with captures. Based on the observed reference screenshot.
- Covers: all 13 section games now have bright 3D card-cast covers (assets/covers/*.png, generated from goblet tile + cast avatars as references).
- Parked, not in repo: farmer-collecting chicken logic in /downloads/parked (from a different app, not the reference).
- Next: Feed the Pigeon style slingshot game; other reference-listing games not yet covered (Monster Attack low confidence); mid-play/win captures for older arcade games; winner screen should highlight the winner among the 4 avatars.
- Gaps: no real-device test; persistence checked by SharedPreferences reread only; icon fonts only verified in test harness; Chicken Run rules inferred.

## Batch 14 (01:00-01:35 EET, Nov 26) and SUCCESSOR HANDOFF
- Pushed this batch: أطعم الحمامة; crown on winner (VictoryFriends: winnerSeats, parses "لاعب N", otherwise no crown; one call site passes a friend name = no crown yet); old-11 reworks DONE: لمّ الفلوس (claw sweeps+stretches, 60s clock, HUD clock), اقطفها (4 corner quadrants matching pads, wrong-tap lockout), أسرع رد فعل (1-4+bots, practice ms, top zone text faces its player, `reactionNow` test clock), اضرب الخلد (per-player equal mole schedule, bots, 2p big face-to-face grids).
- User directives to honor: crown the winner (done for 1234 screens); "old 11 weren't fun" -> fix controls/setup/bots/responsiveness FIRST, keep each game's core mechanic (main 01:09), do not turn timing games into movement games; hold user delivery until captures are clean (fonts loaded: add `tester.runAsync(Future.delayed(500ms))` + pump before goldens), label timings as controlled test delays, never imply human measurement.
- Template for converting a game: pigeon_game.dart / coin_grab_game.dart / whack_mole_game.dart (picker 1-4 -> bots yes/no; 1P+لا = practice, no winner, no record; bots only fill seats >= humans; debugMatch getter; pads keyed pad_N or zones keyed; VictoryFriends(gameTitle)).
- TODO old games in order: tap_race (سباق الدوس), snake_arena, tug_of_war, snow_brawl, sumo, touch_ball, tank_battle (has 1P; needs bots yes/no + banner/emoji cleanup). Update arcade_play_proof_test / small_screen_test (they tap '2 لاعبين' then 'لا') and per-game widget tests; regenerate goldens with --update-goldens only after viewing.
- Test commands (workspace box, `export PATH=$HOME/sdk/flutter/bin:$PATH`): per-game `flutter test test/<game>_widget_test.dart [--update-goldens]`; `flutter test test/small_screen_test.dart --name arcade` (10 tests, ~30s); do NOT run the whole suite in one call (110s limit); run small_screen in parts.
- Push: tools box `tools vault write-file --key password --name "GitHub PAT (fitnic)" --return-channel whatsapp`, then workspace credential.helper one-shot push and `rm` the file (see earlier STATE).
- Gaps: no real-device run; persistence checked by SharedPreferences reread only; Chicken Run/Pigeon rules inferred from listing text; Pigeon art is a simple blob; bot skill numbers are my tuning; winner crown missing on the friend-name site; old non-arcade games lack result captures. NO interim APK; next APK versionCode 7 only after user approval.

## Batch 14b (01:42) tap_race rework done
- tap_race (سباق الدوس): 1-4 humans + bots yes ('اه 🤖') / no ('لا'); 1P+لا = practice; lane msgs; FittedBox lanes (fixed 3-lane overflow); test/tap_race_widget_test.dart (2 tests) pass; arcade proof golden updated and viewed (top lane rotated: its "6" reads as 9 by design).
- Reaction uses monotonic Stopwatch; test asserts controlled 320ms delay reports 320-420.
- KNOWN: 7 other goldens in test/arcade_play_proof_test.dart (sumo, touch-ball, snake, tank, tug, snow) fail pixel diffs in this env (not touched by me; need regenerate after viewing, or are due to their own pending reworks).
- Whack: still owed an explicit tap test on the rotated top grid hole.
- Remaining old-11: snake_arena, tug_of_war, snow_brawl, sumo, touch_ball, tank_battle (bots yes/no + banner/emoji cleanup), friend-name crown site.

## Batch 15 (01:55 EET, Nov 26) snake_arena rework (successor agent, Flutter 3.50.1 exact env match)
- حية الشلة: picker 1-4 -> bots yes/no (4 humans skips); 1P+لا = practice (no winner, shows تفاحة count, no record). Bots fill to 4; logic-level steering (survive, then seek food, one cw turn/tick).
- Controls: turn buttons split per side - bottom half of human seats at bottom, rest at top rotated 180 deg (face-to-face); keys snake_turn_N. Bot pills labeled بوت.
- debugMatch getter; over screen: practice count / البوتات كسبوا / VictoryFriends / draw.
- Tests: logic 5 pass; widget rewritten 6 pass (picker incl. solo, 2p+لا, 4p direct, bots steer, practice, turn stability). proof golden regenerated AND pixel-viewed (rotated top buttons, 4 pills, corner spawns). small_screen snake passes.

## Batch 15b (02:03) tug_of_war rework
- شد الحبل: picker 1-4 -> bots yes/no; 1P+لا practice (shows شدّة صح/غلط stats, no record). Bots fill to 4 and self-tap near the green window (80% at <=0.75*perfectWindow).
- Controls split per side like snake (bottom half bottom, rest top rotated 180); keys tug_pull_N. Over: practice stats / البوتات كسبوا / VictoryFriends.
- Tests: logic+widget 11 pass (incl. new bots-pull and solo-practice). proof golden regenerated + pixel-viewed. small_screen tug passes. Removed stale funky_theme import.

## Batch 15c (02:04) rotated whack tap coverage
- whack widget test added: in 2p face-to-face, tapping the VISUAL position of an up mole in the rotated top grid (player 1) scores for player 1 only. 5/5 whack widget tests pass. The owed rotated-hole tap test is DONE.

## Successor env note (02:07)
- Fresh sandbox per agent: install Flutter 3.50.1 stable linux x64 (storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz -> ~/sdk/flutter). 3.50.1 is the best-supported choice: `flutter pub get` leaves pubspec.lock byte-identical (3.38.x/3.41.x do NOT) and the previously-passing goldens still pass unchanged under it, so its dependency resolution AND golden rendering match the predecessor. Byte-identical lock proves dependency resolution, not SDK identity; the unchanged-golden pass is the rendering evidence. The predecessor's exact SDK string was not independently recorded. Do not commit test/failures (gitignored now); small_screen capture360 rewrites PNGs every run - revert non-touched games' captures before committing.
- Push: tools box vault write-file (GitHub PAT (fitnic)) -> workspace credential.helper push -> rm file.

## Batch 16 (02:34) snow_brawl rework
- معركة التلج: picker 1-4 -> bots yes/no; 1P+لا = practice: 10 throws at a target dummy (no fort damage), over shows أصبت X من 10, no record. Bots fill to 4 and self-throw near the needed power.
- Per-side rotated controls (keys snow_throw_N); fort row labels بوت; practice banner differs (إصابة / رميت بعيد).
- Tests: logic 6 + widget 8 pass (new: bots self-throw, solo practice 10 throws + over text). proof golden regenerated + pixel-viewed. small_screen snow passes.

## Batch 16b (02:39) sumo rework
- سومو الشلة: core 1v1 tap war kept; 3-4 seats run a mini bracket (semis -> final, bot-vs-bot matches resolve instantly with seeded RNG). Picker 1-4 -> bots yes/no (fill to 4); 1P+لا = practice vs training dummy (دمية تدريب), over shows tap count, no record.
- Zones keyed sumo_zone_0/1, top rotated; bots can't be tapped. Over: dummy result / البوتات كسبوا البطولة / VictoryFriends champion.
- Tests: SumoMatch logic 6 unchanged pass; new sumo_widget_test 4 pass (picker, 2p, bracket bots final is human-vs-bot, practice tap-count). proof golden regenerated + pixel-viewed (rotated top zone, off-center ring). small_screen sumo passes (bots screen shown after 2 لاعبين).

## Batch 17 (touch_ball rework)
- Picker 1-4 → bots yes/no ('اه 🤖'/'لا'); 4 humans skips bots question; 1P+لا = practice to 5 pts, no winner, no recordWin; bots fill seats >= humans and self-tap their own balls after a 400-1000ms delay; VictoryFriends only for human champions, 'البوتات كسبوا 🤖' for bot winners.
- Gameplay fixes: balls now spawn and bounce strictly inside the owner's zone rect (owner can always reach own ball; "only owner may tap" rule unchanged); fixed RTL mirroring bug in _zoneAt/_zoneRect (seat 0 = visual right; ball color/zone attribution was mirrored, a real fun-killer); tick now skips while the arena has never been laid out (_arenaW <= 1) so the ball can't wedge at x=0.5 on the first frame after the picker.
- Tests: touch_ball_widget_test.dart 4/4; proof golden play_touchball_live_4p regenerated and pixel-verified (ball "1" inside top-right orange zone 1); small_screen touch_ball pass.

## Batch 18 (tank_battle verdict + touch_ball polish)
- tank_battle: bot winner now shows 'البوتات كسبوا 🤖' instead of VictoryFriends with a bot name; human winners keep VictoryFriends. New widget test covers both verdicts (debugForceWin hook). Widget 6/6, proof live-4p pass, small_screen pass, logic 11/11.
- touch_ball polish (Main feedback): static zone numerals faded to alpha 0.28 so the moving ball never obscures them; golden regenerated and pixel-verified (ball readable over zone numeral).

## Batch 19 (crown seat mapping)
- VictoryFriends seat parser now maps EVERY 'لاعب N' label in winnerName to a crown (shared wins like 'لاعب 1 و لاعب 3' crown seats 0 and 2; single labels unchanged; non-seat names like friend names or 'بوت N' still crown nobody - we never guess). This closes the "winner crown missing on the friend-name/team-name site" gap generically.
- victory_crown_test: 4/4 incl. new shared-win-label test; seat-2 golden unchanged.

## Batch 20 (crown grounded in seat data)
- All 14 arcade VictoryFriends call sites now pass winnerSeats explicitly from match state ([w], [_match.matchWinner!], [_match.winner!], [_champion!]): the crown lands on the winning seat because the game says so, not because the name text parses. The name-label parser stays only as a fallback for label-only callers. Named-friend winners (seega/xo/gobblet) record wins via ResultsService directly and have no crown UI - the crown path is arcade-only and now seat-grounded everywhere it is used. Soccer untouched (removed from playable list).
- tank_battle widget test asserts crown_1 key on a human seat-1 win. All arcade widget suites green (59 tests), crown 4/4, analyze clean of errors.

## Batch 21 (تحدّي الإيقاع rhythm game implemented)
- New game (user-approved 00:40-00:42): phone plays a short clap pattern, players take turns imitating, levels get longer/faster, most accurate timing wins. 1-4 players (solo = practice, no winner/recordWin), per-match input mode choice: clap at the mic 👏 clearly labeled '(تجريبي)' or tap a pad 👆. Mic unavailable/permission refused -> truthful banner + automatic tap fallback (widget-tested). Mic-mode scores carry an in-UI provisional label; mic detection thresholds are ear-tuned, real-device accuracy validation still owed. VictoryFriends + recordWin only for human winners, winnerSeats grounded.
- Files: rhythm_logic.dart (pattern gen + scoring, 9/9 tests), rhythm_mic.dart (ClapDetector + MicClapDetector on record ^6.1.1 amplitude), rhythm_game.dart (widget, 5/5 tests incl. fake detector + manual clock), registry entry inside الألعاب (arcade1234 section), proof golden play_rhythm_tap_listening (pixel-verified), small360_arc_rhythm a/b (360px, no overflow).
- AudioService gained mutedForTests static (widget tests have no audioplayers plugin; async event-channel errors escape the try/catch and fail tests).
- pubspec: added record ^6.1.1 -> pubspec.lock CHANGED (first dependency change since env check; lock no longer byte-identical to the 3.50.1 baseline by design).
- KNOWN PRE-EXISTING DEBT: test/arcade_widget_test.dart (old combined suite, last touched in 1929a7f before the reworks) has 14 stale failures at HEAD (reaction/tap_race/sumo/catch/touch_ball expecting pre-rework text like 'دوسوا'); the dedicated per-game suites are the current ones and are green. Decide: delete the stale file or port remaining unique cases.
- interiors golden test writes captures every run (line 130) - pass = render/no-overflow, not pixel equality. 5 interior PNGs refreshed as current-state captures for the review package.

## Batch 22 (2026-11-26 ~03:20 EET)
- Rhythm mode-choice buttons: white text on purple fill (contrast gate from Main); small360_arc_rhythm_a/b regenerated, b pixel-verified.
- touch_ball: restored whole-arena ball drift (spawn still in owner zone; wrong-zone penalty mechanic was silently killed by owner-zone clamp). play_touchball_live_4p golden regenerated + pixel-verified; proof recopied to /downloads/shla_review.
- Legacy suite test/arcade_widget_test.dart (14 stale failures) DELETED after porting unique still-valid cases into dedicated suites: touch_ball wrong-zone penalty (drift-aware), tap_race countdown-ignore + exact tap counts + full match win + replay + 4p lanes, sumo 2p shove-out win + replay, reaction 4-human false start, four 3-player render checks (reaction/catch/tap_race/touch_ball).
- All 5 touched suites green (27 tests). Full-suite rerun: one -1 failure seen in a killed partial run, not yet identified (was not in any touched suite).

## Batch 23 (2026-11-26 ~03:35 EET): full-suite accounting, 3 stragglers fixed
- soccer_widget golden soccer_win.png regenerated: still rendered the pre-crown victory (5809843 changed all VictoryFriends call sites; soccer's golden was never regenned). New render pixel-verified: crowns on seats 2+4 (winning team), same text/button otherwise. Soccer stays OUT of the registry (user-cancelled); code+tests kept.
- verification_test '1234 tab': rhythm registration made the card grid lazy-build beyond the cache extent, so scrollUntilVisible hit StateError on unbuilt cards. Replaced with incremental drag loops; added تحدّي الإيقاع to the expected 1234 card list (now 12 cards).
- new_games_test registry count: stale since 7696f76 (chicken added, count never bumped). Now asserts 49 games / 25 new-badge, containsAll adds جري الفراخ، سباق العربيات، أطعم الحمامة، تحدّي الإيقاع.
- FULL SUITE GREEN: all 48 test files run and pass in chunks (~335 tests); capture_tank_video self-skips unless CAPTURE_VIDEO=1 (by design). flutter analyze: 0 errors.

## Batch 24 — release APK build config (2026-11-26)
- android/gradle.properties: raised daemon heap 512m/256m → 1536m/512m (2GB sandbox OOM-killed the default during dex); workers.max stays 1, daemon off.
- android/app/build.gradle.kts: added packaging { jniLibs.useLegacyPackaging = true } so .so entries are compressed in future APKs.
- Universal release APK built and verified (apksigner OK, debug cert; v1.2.2 vc6; arm64-v8a/armeabi-v7a/x86_64). 181MB: 83MB game-tile PNGs + ~88MB native libs; arm64-only split still ~104MB, and split build OOMs on this box. No physical device/emulator available: install/launch/mic/restart unverified.

## Batch 25 — asset diet for a lighter APK (2026-11-26)
- Game tiles 1254²→640² + pngquant q60-85: assets/tiles 65MB→5.9MB. covers/avatars/avatars_2d pngquant'd too (4 covers kept original: catch, pigeon, snake_arena, touch_ball — quality floor). Total image assets ~82MB→~13.5MB. Originals backed up at /tmp/assets_orig (this sandbox only; git history also has them).
- Visual QA: before/after contact sheets of all 33 tiles + 14 covers + 5 avatars_2d inspected, no visible artifacts at card scale.
- 20 goldens regenerated (diffs only from new asset pixels), regenerated images inspected; full suite 369 tests green after regeneration.

## Batch 26 — كأس الشلة cup mode (2026-11-26)
- New: lib/services/cup_service.dart (ChangeNotifier, persisted cup_state_v1): N rounds over arcade games, listens to ResultsService for wins (1 point/win, bot win = no points, ties share the cup), dedupe by round id, replay/skip for abandoned rounds, restart-resume.
- New screens: cup/cup_setup_screen.dart (3/5/7 rounds, random or manual game pick grid with covers) + cup/cup_screen.dart (round card, standings, rounds list, champion card reusing VictoryFriends, no-champion case).
- Entry: golden cup banner on top of the ١٢٣٤ tab (arcade_section_screen.dart) with resume state; added emojiOf() + تحدي الإيقاع emoji.
- Tests: cup_service_test (9) + cup_widget_test (5, 3 goldens inspected) — full suite green; home_arcade_section/full goldens regenerated for the banner and inspected.

## Batch 28 — flat-light lobby/room/scoreboard + chat (2026-11-26)
- Last dark surfaces flattened to the approved flat-light look (FlatColors.bg cream, white cards + cream border, ink text, solid pastel buttons with darker bottom edge): lib/screens/lobby_screen.dart, room_screen.dart, scoreboard_screen.dart rewritten flat (gradients/glows/dark cards removed).
- lib/widgets/chat_widget.dart flattened (cream sheet, white incoming bubbles, playerBlue outgoing, flat input bar) + real small-width fixes found by the new capture: header Row overflow (title wrapped in Expanded), status text Flexible, timestamps use flatCairo (were tofu in tests).
- lib/widgets/voice_chat_widget.dart mic button flattened (white circle + cream border, ink/red/mintDark states).
- Tests: new 'small screen: room chat restyle' capture; small360 lobby/room/scoreboard/room_chat goldens regenerated and pixel-inspected; small_screen suite 57/57 named tests green (one pre-existing async audioplayers MissingPluginException flake, unrelated).
