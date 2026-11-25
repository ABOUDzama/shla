# Shla flat-rollout state (updated 2026-11-25 22:23 EET)

HEAD: local commits only, NEVER push (standing rule).

## Flat rollout coverage (user-approved direction: XO trial 21:32 "حلو اوي يلا عمم التعديل ع كل الالعاب")
- Stage 1 (commit e13ff72): shared OfflineGameScaffold header + GameIntroWidget flat for ALL 45 games. Settings screen flat (commit with contrast pass).
- Stage 2 bodies DONE (13/45): xo (approved trial), quiz, memory, taboo, most_likely, spy, undercover, who_said, emoji_guess, password, proverb, mafia (all phases), bus_complete.
- Shared FunkyButton now flat (solid + darker bottom edge), used by 14 games.
- Contrast pass: quiz reveal hint + scoreboard small text ink75; memory scoreboard ink75.

## Stage 2 bodies REMAINING (~32)
- Word/party: would_rather, opposite_day, never_have_i, who_am_i (accents only), charades, five_seconds, code_names, word_chain, word_story, truth_or_lie, truth_or_dare, ranking_challenge, pictionary, first_letter, odd_one_out, tick_tock_boom, seega, gobblet, multi_touch, reverse_quiz.
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
