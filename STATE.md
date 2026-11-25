# Shla flat-rollout state (updated 2026-11-25 22:31 EET)

HEAD: local commits only, NEVER push (standing rule).

## Flat rollout coverage (user-approved direction: XO trial 21:32 "حلو اوي يلا عمم التعديل ع كل الالعاب")
- Stage 1 (commit e13ff72): shared OfflineGameScaffold header + GameIntroWidget flat for ALL 45 games. Settings screen flat (commit with contrast pass).
- Stage 2 bodies DONE (15/45): xo (approved trial), quiz, memory, taboo, most_likely, spy, undercover, who_said, emoji_guess, password, proverb, mafia (all phases), bus_complete, would_rather, never_have_i.
- Shared FunkyButton now flat (solid + darker bottom edge), used by 14 games.
- Contrast pass 1: quiz reveal hint + scoreboard small text ink75; memory scoreboard ink75.
- Contrast pass 2 (commit b1e4d74, rendered-pixel verified): FlatDecor.textOn(bg) picks ink vs white by fill luminance (>0.32 -> ink). White text now only on violet/sky/mafia (>=3:1); ink on mint/coral/amber/pink (>=4.6:1). FlatColors.mintDark 1F9E77 (3.4:1 on white) for success text on light bg. Quiz neon +/- buttons flattened. Taboo pills -> flat tags. would_rather/never_have_i now have small360 goldens, pixel-viewed OK. Contrast floor raised to 4.5:1 for small text (parent 22:31): textOn = max-contrast ink/white, ink wins on all pastels; mintDark 17795A 5.4:1; ink alpha floor 0.7.

## Stage 2 bodies REMAINING (~30)
- Word/party: opposite_day, who_am_i (accents only), charades, five_seconds, code_names, word_chain, word_story, truth_or_lie, truth_or_dare, ranking_challenge, pictionary, first_letter, odd_one_out, tick_tock_boom, seega, gobblet, multi_touch, reverse_quiz.
- Arcade custom-painted interiors: reaction, tap_race, tug_of_war, sumo, snake_arena, whack_mole, coin_grab, catch, touch_ball, snow_brawl, tank_battle (tank UI mostly done in v4, check).

## Verification status
- Suites green after each batch: golden_interiors 8/8, small_screen 23/23, arcade_play_proof 11/11, game_interaction 28/28.
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
