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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x8C1C2038),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.8),
      ),
      child: Text(
        emoji,
        semanticsLabel: type,
        style: const TextStyle(fontSize: 11, height: 1),
      ),
    );
  }
}
