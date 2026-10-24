import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../deck/deck_editor_screen.dart';
import '../practice/new_match_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = LorcanaScope.of(context).catalog;
    return AnimatedBuilder(
      animation: catalog,
      builder: (context, _) {
        final ready = catalog.cards.isNotEmpty && !catalog.loading;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'LorcArcana',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Simulador de Lorcana'),
                  const SizedBox(height: 28),
                  if (catalog.loading) ...[
                    Text(catalog.status),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: catalog.progress),
                    const SizedBox(height: 20),
                  ] else ...[
                    Text(
                      catalog.error ?? catalog.status,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _MenuButton(
                    label: 'Partida local',
                    enabled: ready,
                    onPressed: () => _open(context, const NewMatchScreen(hotseat: true)),
                  ),
                  _MenuButton(
                    label: 'Praticar',
                    enabled: ready,
                    onPressed: () => _open(context, const NewMatchScreen(hotseat: false)),
                  ),
                  _MenuButton(
                    label: 'Editar deck',
                    enabled: ready,
                    onPressed: () => _open(context, const DeckEditorScreen()),
                  ),
                  _MenuButton(
                    label: 'Ajustes',
                    onPressed: () => _open(context, const SettingsScreen()),
                  ),
                  _MenuButton(
                    label: 'Sair',
                    onPressed: SystemNavigator.pop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 280,
        height: 48,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          child: Text(label),
        ),
      ),
    );
  }
}
