import 'package:flutter/material.dart' hide Ink;

import '../features/cards/lorcana_card.dart';

Color inkColor(Ink ink) {
  return switch (ink) {
    Ink.amber => const Color(0xFFE0A100),
    Ink.amethyst => const Color(0xFFB06AD8),
    Ink.emerald => const Color(0xFF1F9D6A),
    Ink.ruby => const Color(0xFFD64545),
    Ink.sapphire => const Color(0xFF3C7DCC),
    Ink.steel => const Color(0xFF9AA3B2),
  };
}

String inkLabel(Ink ink) {
  return switch (ink) {
    Ink.amber => 'Âmbar',
    Ink.amethyst => 'Ametista',
    Ink.emerald => 'Esmeralda',
    Ink.ruby => 'Rubi',
    Ink.sapphire => 'Safira',
    Ink.steel => 'Aço',
  };
}

String kindLabel(CardKind kind) {
  return switch (kind) {
    CardKind.character => 'Personagem',
    CardKind.action => 'Ação',
    CardKind.item => 'Item',
    CardKind.location => 'Local',
  };
}
