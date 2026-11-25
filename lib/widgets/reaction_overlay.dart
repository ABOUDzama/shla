import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shows flying emoji reactions coming from the room's reaction stream.
class ReactionOverlay extends StatefulWidget {
  final Stream<String> reactionStream;

  const ReactionOverlay({super.key, required this.reactionStream});

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _FlyingEmoji {
  final int id;
  final String emoji;
  final double xFraction; // 0..1 horizontal start position
  final double drift;
  final double size;
  _FlyingEmoji(this.id, this.emoji, this.xFraction, this.drift, this.size);
}

class _ReactionOverlayState extends State<ReactionOverlay> {
  final List<_FlyingEmoji> _emojis = [];
  final Random _random = Random();
  StreamSubscription<String>? _sub;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.reactionStream.listen(_onReaction);
  }

  void _onReaction(String emoji) {
    if (!mounted || emoji.isEmpty) return;
    setState(() {
      // Cap concurrent particles to keep the UI smooth.
      if (_emojis.length >= 24) _emojis.removeAt(0);
      _emojis.add(_FlyingEmoji(
        _nextId++,
        emoji,
        0.1 + _random.nextDouble() * 0.8,
        (_random.nextDouble() - 0.5) * 60,
        28 + _random.nextDouble() * 22,
      ));
    });
    final id = _nextId - 1;
    Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _emojis.removeWhere((e) => e.id == id));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final e in _emojis)
              Positioned(
                left: e.xFraction * constraints.maxWidth,
                bottom: 0,
                child: Text(e.emoji, style: TextStyle(fontSize: e.size))
                    .animate()
                    .moveY(
                      begin: 0,
                      end: -constraints.maxHeight * 0.85,
                      duration: 2400.ms,
                      curve: Curves.easeOut,
                    )
                    .moveX(begin: 0, end: e.drift, duration: 2400.ms)
                    .fadeOut(delay: 1600.ms, duration: 800.ms),
              ),
          ],
        );
      },
    );
  }
}
