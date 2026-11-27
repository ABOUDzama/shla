import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exactly once per round id; fast rematch counts; blank ignored; survives restart', () async {
    final s = ResultsService.instance;
    final t = DateTime(2026, 11, 26, 1);
    expect(await s.recordWin(game: 'xo', winner: 'عبود', players: ['عبود', 'سارة'], roundId: 'r1', now: t), true);
    expect(await s.recordWin(game: 'xo', winner: 'عبود', roundId: 'r1', now: t), false, reason: 'same round twice');
    expect(await s.recordWin(game: 'xo', winner: 'عبود', roundId: 'r2', now: t.add(const Duration(seconds: 1))), true, reason: 'fast rematch');
    expect(await s.recordWin(game: 'sumo', winner: 'سارة', now: t.add(const Duration(minutes: 1))), true);
    expect(await s.recordWin(game: 'sumo', winner: 'لاعب 2', now: t.add(const Duration(minutes: 2))), true);
    expect(await s.recordWin(game: 'sumo', winner: '  ', now: t.add(const Duration(minutes: 3))), false);
    // "restart": a fresh read from the stored prefs
    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues({'match_results_v1': prefs.getStringList('match_results_v1')!});
    await SharedPreferences.getInstance().then((p) => p.reload());
    final all = await s.load();
    expect(all.length, 4);
    expect(ResultsService.standings(all).map((e) => '${e.key}:${e.value}').toList(), ['عبود:2', 'سارة:1']);
  });

  test('bots wins are recorded but never enter standings', () async {
    final s = ResultsService.instance;
    final t = DateTime(2026, 11, 27);
    expect(await s.recordWin(game: 'سومو الشلة', winner: kBotsWinnerLabel, players: ['عبود'], now: t), true);
    expect(await s.recordWin(game: 'سومو الشلة', winner: 'عبود', now: t.add(const Duration(minutes: 1))), true);
    final all = await s.load();
    expect(all.length, 2, reason: 'bots round is kept in history so the cup can close it');
    final board = ResultsService.standings(all);
    expect(board.map((e) => e.key), isNot(contains(kBotsWinnerLabel)), reason: 'bots are not a profile');
    expect(board.single.key, 'عبود');
  });

  test('history capped at maxEntries', () async {
    final s = ResultsService.instance;
    final t = DateTime(2026, 11, 26);
    for (var i = 0; i < ResultsService.maxEntries + 5; i++) {
      await s.recordWin(game: 'g$i', winner: 'a', now: t.add(Duration(minutes: i)));
    }
    final all = await s.load();
    expect(all.length, ResultsService.maxEntries);
    expect(all.last.game, 'g${ResultsService.maxEntries + 4}');
  });
}
