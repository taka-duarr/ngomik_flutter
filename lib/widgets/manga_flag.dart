import 'package:flutter/material.dart';

class MangaFlag extends StatelessWidget {
  final String type;

  const MangaFlag({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final lower = type.toLowerCase();
    String code = 'KR';
    String emoji = '????';
    Color bg = const Color(0xFF1E3A8A); // Deep Blue
    Color textCol = const Color(0xFF93C5FD);

    if (lower.contains('manga') || lower.contains('jp')) {
      code = 'JP';
      emoji = '????';
      bg = const Color(0xFF831843); // Deep Pink/Red
      textCol = const Color(0xFFF9A8D4);
    } else if (lower.contains('manhua') || lower.contains('cn')) {
      code = 'CN';
      emoji = '????';
      bg = const Color(0xFF7C2D12); // Deep Amber/Red
      textCol = const Color(0xFFFDBA74);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 3),
          Text(
            code,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textCol,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
