import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shella/services/cup_service.dart';
import 'package:shella/services/results_service.dart';

MatchResult r(String game, String winner, int at, [String id = '']) =>
    MatchResult(game, winner, const [], at, id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CupService.instance.endCup();
  });

  test('start initializes and persists', () async {
    await CupService.instance
        .start(rounds: 3, games: const ['سومو الشلة', 'لمّ الفلوس', 'سباق الدوس']);
    final c = CupService.instance;
    expect(c.active, isTrue);
    expect(c.rounds, 3);
    expect(c.currentGame, 'سومو الشلة');
    expect(c.roundNumber, 1);
    expect(c.finished, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cup_state_v1'), isNotNull);
  });

  test('win in current game scores a point and advances the round', () async {
    final c = CupService.instance;
    await c.start(rounds: 2, games: const ['سومو الشلة', 'لمّ الفلوس']);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.ingestResults([r('سومو الشلة', 'لاعب 2', now, 'id1')]);
    expect(c.points, {'لاعب 2': 1});
    expect(c.roundIndex, 1);
    expect(c.currentGame, 'لمّ الفلوس');
    expect(c.roundOpen, isFalse);
  });

  test('same round id is never counted twice', () async {
    final c = CupService.instance;
    await c.start(rounds: 3, games: const ['سومو الشلة', 'لمّ الفلوس', 'سباق الدوس']);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    final res = [r('سومو الشلة', 'لاعب 1', now, 'same-id')];
    // Simulate a fresh cup instance re-reading history after a restart:
    // the round advanced already, so the id must stay consumed.
    await c.ingestResults(res);
    expect(c.points['لاعب 1'], 1);
    await c.markRoundStarted();
    await c.ingestResults(res); // stale re-notify with the old result
    expect(c.points['لاعب 1'], 1);
    expect(c.roundIndex, 1);
  });

  test('bot win counts the round with no points', () async {
    final c = CupService.instance;
    await c.start(rounds: 2, games: const ['لمّ الفلوس', 'سباق الدوس']);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.ingestResults([r('لمّ الفلوس', CupService.botsLabel, now, 'b1')]);
    expect(c.points, isEmpty);
    expect(c.roundIndex, 1);
  });

  test('results from before the round started or for other games are ignored',
      () async {
    final c = CupService.instance;
    await c.start(rounds: 1, games: const ['سومو الشلة']);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.ingestResults([
      r('سومو الشلة', 'لاعب 3', now - 60000, 'old'),
      r('لمّ الفلوس', 'لاعب 3', now, 'other'),
    ]);
    expect(c.points, isEmpty);
    expect(c.roundIndex, 0);
    expect(c.roundOpen, isTrue);
  });

  test('skip advances without points and cup finishes after last round',
      () async {
    final c = CupService.instance;
    await c.start(rounds: 2, games: const ['سومو الشلة', 'لمّ الفلوس']);
    await c.markRoundStarted();
    await c.skipRound();
    expect(c.roundIndex, 1);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.ingestResults([r('لمّ الفلوس', 'لاعب 4', now, 'x1')]);
    expect(c.finished, isTrue);
    expect(c.standings.single.key, 'لاعب 4');
  });

  test('leaders shares the cup on a tie, empty when no points', () async {
    final c = CupService.instance;
    await c.start(rounds: 2, games: const ['سومو الشلة', 'لمّ الفلوس']);
    expect(c.leaders, isEmpty);
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.markRoundStarted();
    await c.ingestResults([r('سومو الشلة', 'لاعب 1', now, 't1')]);
    await c.markRoundStarted();
    await c.ingestResults([r('لمّ الفلوس', 'لاعب 2', now, 't2')]);
    expect(c.finished, isTrue);
    expect(c.leaders.map((e) => e.key), ['لاعب 1', 'لاعب 2']);
  });

  test('state survives a restore (restart mid-cup)', () async {
    final c = CupService.instance;
    await c.start(rounds: 3, games: const ['سومو الشلة', 'لمّ الفلوس', 'سباق الدوس']);
    await c.markRoundStarted();
    final now = DateTime.now().millisecondsSinceEpoch;
    await c.ingestResults([r('سومو الشلة', 'لاعب 2', now, 'p1')]);

    // Simulate process death: fresh fields loaded from prefs.
    await c.restore();
    expect(c.active, isTrue);
    expect(c.roundIndex, 1);
    expect(c.points, {'لاعب 2': 1});
    expect(c.currentGame, 'لمّ الفلوس');
    // And the consumed id still cannot score twice.
    await c.markRoundStarted();
    await c.ingestResults([r('سومو الشلة', 'لاعب 2', now, 'p1')]);
    expect(c.points['لاعب 2'], 1);
  });

  test('endCup clears the active cup', () async {
    final c = CupService.instance;
    await c.start(rounds: 1, games: const ['سومو الشلة']);
    await c.endCup();
    expect(c.active, isFalse);
    expect(c.finished, isFalse);
  });
}
