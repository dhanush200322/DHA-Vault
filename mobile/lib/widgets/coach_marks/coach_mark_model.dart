import 'package:flutter/material.dart';

enum CoachMarkPosition {
  auto,
  above,
  below,
}

class CoachMarkStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final CoachMarkPosition position;
  final EdgeInsets targetPadding;
  final double borderRadius;

  const CoachMarkStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.position = CoachMarkPosition.auto,
    this.targetPadding = const EdgeInsets.all(6.0),
    this.borderRadius = 14.0,
  });
}
