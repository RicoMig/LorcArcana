import 'package:flutter/material.dart';

import '../features/cards/lorcana_card.dart';
import 'ink_style.dart';

class CardChip extends StatelessWidget {
  const CardChip({
    super.key,
    required this.card,
    this.width = 96,
    this.selected = false,
    this.exerted = false,
    this.drying = false,
    this.damage = 0,
    this.caption,
    this.onTap,
    this.onLongPress,
  });

  final LorcanaCard? card;
  final double width;
  final bool selected;
  final bool exerted;
  final bool drying;
  final int damage;
  final String? caption;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ink = card?.inks.isNotEmpty == true ? inkColor(card!.inks.first) : const Color(0xFF6E7480);
    final face = _face(ink);
    final body = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedRotation(
            turns: exerted ? 0.25 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: width,
              height: width * 1.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? const Color(0xFFF0D48A) : ink,
                  width: selected ? 3 : 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: face,
            ),
          ),
          if (caption != null)
            SizedBox(
              width: width + 24,
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
    return body;
  }

  Widget _face(Color ink) {
    final current = card;
    if (current == null) {
      return const ColoredBox(
        color: Color(0xFF2A3142),
        child: Center(child: Icon(Icons.style)),
      );
    }
    final url = current.thumb ?? current.image;
    final fallback = _Fallback(card: current, ink: ink);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url.isEmpty)
          fallback
        else
          Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 240,
            errorBuilder: (context, error, stack) => fallback,
          ),
        if (drying)
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.water_drop, size: 16, color: Colors.white),
            ),
          ),
        if (damage > 0)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8E1B1B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$damage',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.card, required this.ink});

  final LorcanaCard card;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B2030),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${card.cost}',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              card.fullName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            const Spacer(),
            Text(
              [
                if (card.strength != null) '${card.strength}',
                if (card.willpower != null) '${card.willpower}',
                if (card.lore != null) '${card.lore}◇',
              ].join(' · '),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
