import 'package:flutter/material.dart';

import '../../widgets/card_chip.dart';
import '../../widgets/ink_style.dart';
import 'lorcana_card.dart';

Future<void> showCardDetail(BuildContext context, LorcanaCard card) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(card.fullName),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: CardChip(card: card, width: 180)),
                const SizedBox(height: 12),
                Text(
                  '${kindLabel(card.kind)} · ${card.inks.map(inkLabel).join(' / ')} · custo ${card.cost}'
                  '${card.inkwell ? ' · tinta' : ''}',
                ),
                if (card.kind == CardKind.character)
                  Text(
                    'Força ${card.strength ?? 0} · Vontade ${card.willpower ?? 0} · Lore ${card.lore ?? 0}',
                  ),
                if (card.kind == CardKind.location)
                  Text(
                    'Vontade ${card.willpower ?? 0} · Lore ${card.lore ?? 0} · mover ${card.moveCost ?? 0}',
                  ),
                if (card.subtypes.isNotEmpty) Text(card.subtypes.join(' · ')),
                if (card.keywords.isNotEmpty)
                  Text(
                    card.keywords
                        .map((keyword) {
                          final value = keyword.value;
                          return value == null ? keyword.name : '${keyword.name} $value';
                        })
                        .join(' · '),
                  ),
                const SizedBox(height: 8),
                Text(card.fullText.isEmpty ? 'Sem texto de regras.' : card.fullText),
                const SizedBox(height: 8),
                Text(
                  '${card.setName} · ${card.rarity}'
                  '${card.coreLegal ? ' · Core' : ''}'
                  '${card.infinityLegal ? ' · Infinity' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    },
  );
}
