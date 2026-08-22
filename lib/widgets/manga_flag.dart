import 'package:flutter/material.dart';

class MangaFlag extends StatelessWidget {
  final String type;

  const MangaFlag({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final lower = type.toLowerCase();
    String emoji = '🇰🇷';

    if (lower.contains('manga') || lower.contains('jp') || lower.contains('japan')) {
      emoji = '🇯🇵';
    } else if (lower.contains('manhua') || lower.contains('cn') || lower.contains('china')) {
      emoji = '🇨🇳';
    }

    return Container(
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.6),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 12, height: 1),
      ),
    );
  }
}
