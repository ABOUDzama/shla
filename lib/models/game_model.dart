import 'package:flutter/material.dart';

class GameModel {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String? badge;

  /// True for same-phone 2/3/4-player arcade games of the dedicated
  /// ١٢٣٤ section.
  final bool arcade1234;

  const GameModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.screen,
    this.badge,
    this.arcade1234 = false,
  });
}
