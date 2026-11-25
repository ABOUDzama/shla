import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../services/results_service.dart';
import '../services/settings_service.dart';
import '../theme/flat_theme.dart';

/// الترتيب: wins per friend + latest rounds. Local only.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<MatchResult> _results = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ResultsService.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ResultsService.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ResultsService.instance.load();
    if (mounted) setState(() { _results = r; _loaded = true; });
  }

  String? _avatarFor(String name) {
    if (name == SettingsService.userName) return SettingsService.userAvatar;
    for (final p in SettingsService.getSavedPlayersProfiles()) {
      if (p['name'] == name) return p['avatar'];
    }
    return null;
  }

  Widget _face(String name, double size) {
    final provider = AvatarService.providerFor(_avatarFor(name));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: FlatColors.ink, width: 2.5),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Center(child: Text(name.isEmpty ? '?' : name[0], style: FlatDecor.title(size: size * 0.4)))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final standings = ResultsService.standings(_results);
    final recent = _results.reversed.take(15).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Center(child: Text('الترتيب 🏆', style: FlatDecor.title(size: 28))),
          Center(child: Text('مين بطل الشلة؟', style: FlatDecor.body(size: 13))),
          const SizedBox(height: 18),
          if (!_loaded)
            const SizedBox(height: 100)
          else if (_results.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FlatDecor.card(radius: 22),
              child: Column(children: [
                Text('لسه مفيش نتايج', style: FlatDecor.title(size: 18)),
                const SizedBox(height: 6),
                Text('العبوا أي لعبة واتحسموا، وهتتسجل هنا باسم الفايز.',
                    textAlign: TextAlign.center, style: FlatDecor.body(size: 14)),
              ]),
            )
          else ...[
            if (standings.isNotEmpty) _podium(standings),
            const SizedBox(height: 14),
            for (var i = 0; i < standings.length; i++)
              Container(
                key: ValueKey('rank_$i'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: FlatDecor.card(radius: 18),
                child: Row(children: [
                  Text('${i + 1}', style: FlatDecor.title(size: 18)),
                  const SizedBox(width: 12),
                  _face(standings[i].key, 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(standings[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: FlatDecor.title(size: 16))),
                  Text('${standings[i].value} فوز', style: FlatDecor.body(size: 14)),
                ]),
              ),
            const SizedBox(height: 10),
            Text('آخر الجولات', style: FlatDecor.title(size: 18)),
            const SizedBox(height: 8),
            for (final r in recent)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: FlatDecor.card(radius: 16),
                child: Row(children: [
                  Expanded(child: Text(r.game, maxLines: 1, overflow: TextOverflow.ellipsis, style: FlatDecor.title(size: 14))),
                  Text('🏆 ${r.winner}', style: FlatDecor.body(size: 14).copyWith(fontFamilyFallback: const ['Noto Color Emoji'])),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _podium(List<MapEntry<String, int>> s) {
    final top = s.take(3).toList();
    Widget col(int i, double face) {
      if (i >= top.length) return const SizedBox(width: 90);
      return SizedBox(
        width: 96,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(['🥇', '🥈', '🥉'][i], style: const TextStyle(fontSize: 22).copyWith(fontFamilyFallback: const ['Noto Color Emoji'])),
          _face(top[i].key, face),
          const SizedBox(height: 4),
          Text(top[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: FlatDecor.title(size: 14)),
          Text('${top[i].value} فوز', style: FlatDecor.body(size: 12)),
        ]),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [col(1, 60), col(0, 80), col(2, 60)],
    );
  }
}
