import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shella/services/results_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records wins, dedupes same result within 8s, standings exclude seats', () async {
    final s = ResultsService.instance;
    final t = DateTime(2026, 11, 26, 1);
    expect(await s.recordWin(game: 'xo', winner: 'عبود', players: ['عبود', 'سارة'], now: t), true);
    expect(await s.recordWin(game: 'xo', winner: 'عبود', now: t.add(const Duration(seconds: 2))), false);
    expect(await s.recordWin(game: 'xo', winner: 'عبود', now: t.add(const Duration(seconds: 30))), true);
    expect(await s.recordWin(game: 'sumo', winner: 'سارة', now: t.add(const Duration(minutes: 1))), true);
    expect(await s.recordWin(game: 'sumo', winner: 'لاعب 2', now: t.add(const Duration(minutes: 2))), true);
    expect(await s.recordWin(game: 'sumo', winner: '  ', now: t.add(const Duration(minutes: 3))), false);
    final all = await s.load();
    expect(all.length, 4);
    final st = ResultsService.standings(all);
    expect(st.map((e) => '${e.key}:${e.value}').toList(), ['عبود:2', 'سارة:1']);
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
