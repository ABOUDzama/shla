import 'package:flutter/material.dart';
import '../theme/flat_theme.dart';

/// HARNESS-ONLY prototype of the home games grid in the flat/cartoon
/// direction (WePlay home pattern: light bg, flat pastel tiles, big emoji
/// "character", tiny tags). Not referenced by the app; used by the
/// small_screen capture to preview the direction for review.
class FlatHomePreview extends StatelessWidget {
  const FlatHomePreview({super.key});

  static const _tiles = <(String, String, Color, String?)>[
    ('مافيا', '🔫', FlatColors.mafia, 'جديد'),
    ('أندر كافر', '🥷', Color(0xFF9B7EDE), 'جديد'),
    ('الجاسوس', '🕵', FlatColors.detective, null),
    ('كلمة السر', '🔑', FlatColors.day, null),
    ('إكس أو', '❌', FlatColors.doctor, null),
    ('مين قالها؟', '💬', Color(0xFFFF6FA5), null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flat header: avatar chip + plain title.
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B7EDE).withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF9B7EDE), width: 3),
                    ),
                    child: Center(
                      child: Text('أ',
                          style: FlatDecor.title(size: 20)),
                    ),
                  ),
                  const Spacer(),
                  Text('شِلَّة', style: FlatDecor.title(size: 26)),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text('الألعاب 🎮',
                    style: FlatDecor.title(size: 18)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: [
                    for (final (title, emoji, color, tag) in _tiles)
                      _FlatGameTile(
                          title: title, emoji: emoji, color: color, tag: tag),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatGameTile extends StatelessWidget {
  final String title;
  final String emoji;
  final Color color;
  final String? tag;

  const _FlatGameTile({
    required this.title,
    required this.emoji,
    required this.color,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FlatDecor.tile(color),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlatDecor.title(size: 17, color: Colors.white),
                ),
              ],
            ),
          ),
          if (tag != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: FlatDecor.tag(),
                child: Text(tag!, style: FlatDecor.body(size: 11)),
              ),
            ),
        ],
      ),
    );
  }
}
