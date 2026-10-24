import 'package:flutter/material.dart';

import '../../app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = LorcanaScope.of(context);
    final catalog = scope.catalog;
    return AnimatedBuilder(
      animation: catalog,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(catalog.status),
              if (catalog.error != null) ...[
                const SizedBox(height: 8),
                Text(catalog.error!),
              ],
              if (catalog.loading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: catalog.progress),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: catalog.loading ? null : () => catalog.load(force: true),
                child: const Text('Atualizar a base'),
              ),
              const SizedBox(height: 24),
              const Text(
                'As cartas vêm do LorcanaJSON e as imagens dos endereços indicados nessa base. '
                'O aplicativo guarda uma cópia no seu computador e não redistribui o arquivo. '
                'O texto em inglês da carta é o texto de jogo.',
              ),
              const SizedBox(height: 16),
              const Text(
                'A partida segue o regulamento 2.3.0: preparar, definir, comprar e fase principal. '
                'Tintar, jogar, explorar, desafiar, cantar, Shift numérico, Boost e as palavras-chave '
                'de combate são automáticos. O texto que o motor não lê aparece para você resolver, '
                'com dano, cura, banimento, compra e lore no menu da mesa.',
              ),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: scope.decks.folder().then((dir) => dir.path),
                builder: (context, snapshot) {
                  return SelectableText(snapshot.data ?? 'Pasta dos decks…');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
