# LorcArcana

Simulador de Disney Lorcana para Windows. Dá para montar um deck e jogar no mesmo computador: sozinho, contra o treino, ou com outra pessoa, passando o computador na troca de vez.

Projeto de fã, feito para estudo e jogo casual. Não é da Disney nem da Ravensburger. O nome Lorcana e as cartas pertencem aos seus donos. O texto e as imagens das cartas **não vêm neste download**. Na primeira abertura, o programa baixa a base pública do [LorcanaJSON](https://lorcanajson.org/) e guarda uma cópia só no seu computador.

O código deste repositório está sob a licença MIT. Ver o arquivo `LICENSE`.

## Baixar e jogar

Quem só quer jogar não precisa instalar Flutter nem abrir o código.

Baixe o programa aqui: [LorcArcana-Windows.zip](https://github.com/RicoMig/LorcArcana/raw/main/download/LorcArcana-Windows.zip)

O mesmo arquivo está na pasta `download` deste repositório. Ele traz o `lorcarcana.exe` e os arquivos que o Windows precisa para abrir o jogo. O executável sozinho não funciona.

1. Clique no link acima e salve o zip.
2. Clique com o botão direito no arquivo e escolha **Extrair tudo**.
3. Abra a pasta extraída e dê dois cliques em **lorcarcana.exe**.

Deixe o `lorcarcana.exe` junto da pasta `data` e dos arquivos `.dll`. Se separar o programa desses arquivos, ele não abre.

Na primeira vez, deixe a internet ligada. O programa baixa as cartas. Decks e essa cópia das cartas ficam no seu Windows, na pasta de dados do aplicativo `LorcArcana`. Não há conta, senha nem envio do seu deck para um servidor.

O Windows pode mostrar um aviso azul de proteção. Isso acontece porque o arquivo não tem assinatura digital de uma empresa. Se você baixou o zip deste repositório, escolha **Mais informações** e depois **Executar assim mesmo**.

## Como jogar

1. Espere o menu mostrar a quantidade de cartas. Se a base não atualizar, abra **Ajustes** e peça para baixar de novo.
2. Em **Editar deck**, monte as cartas ou use **Montar treino** (60 cartas, até duas tintas) e clique em **Salvar**.
3. **Praticar** usa o seu deck contra um deck de treino. **Partida local** pede um deck para cada pessoa. Casual aceita qualquer deck com cartas. Core e Infinity exigem 60 cartas, no máximo duas tintas e o limite de cópias da base.
4. No começo, marque as cartas que voltam para o fundo do deck, ou confirme a mão. Na partida local, passe o computador antes de mostrar a mão da outra pessoa.
5. No seu turno: tintar, jogar, cantar, explorar, desafiar e encerrar. Um toque longo na carta abre a ficha.

A vitória é aos 20 de lore. Perde quem termina o turno com o deck vazio, ou quem desiste.

Algumas frases de carta o programa aplica sozinho. O que ele não entende aparece na mesa: use **Resolver efeito** para dano, cura, banimento, compra, lore, exercer e endireitar. Habilidade que dispara fica no registro para os jogadores cumprirem.

Não há jogo pela internet, replay nem side deck.

## Para quem programa

Pré-requisitos: Flutter estável com Windows desktop, e o Visual Studio 2022 Build Tools com a carga **VCTools** (C++ de desktop) e o SDK do Windows.

```bash
flutter pub get
flutter test
flutter run -d windows
```

O executável de release:

```bash
flutter build windows
```

sai em `build\windows\x64\runner\Release\`. Distribua a pasta inteira, não só o `lorcarcana.exe`.

Se o caminho da pasta tiver acento, a compilação nativa pode falhar. Copie o projeto para uma pasta cujo caminho use só letras sem acento, apague `build`, `.dart_tool` e `windows\flutter\ephemeral` nessa cópia, e compile lá.

Arquivo de deck, uma carta por linha:

```
#name Treino
#main
123
123
```

A pasta dos decks aparece em **Ajustes**.

| Arquivo | Papel |
| :--- | :--- |
| `lib/main.dart` | Arranque, SQLite, tema, título |
| `lib/services/card_database.dart` | Download do LorcanaJSON e cache local |
| `lib/services/deck_store.dart` | Ler e gravar `.deck` |
| `lib/features/cards/lorcana_card.dart` | Ficha da carta |
| `lib/features/deck/deck_rules.dart` | Casual, Core e Infinity |
| `lib/features/deck/deck_editor_screen.dart` | Editor |
| `lib/features/match/match_table.dart` | Regras da partida |
| `lib/features/match/effects/effect_script.dart` | Frases curtas que o motor aplica |
| `lib/features/match/match_screen.dart` | Mesa |
| `lib/features/practice/practice_ai.dart` | Oponente de treino |
| `test/rules_test.dart` | Regras com cartas de teste, sem rede |

Endereços da base, baixados na hora de jogar:

- `https://lorcanajson.org/files/current/en/metadata.json`
- `https://lorcanajson.org/files/current/en/allCards.json`

O texto em inglês da carta é o texto usado no jogo. O resumo das regras deste motor segue o Comprehensive Rules 2.3.0, sem copiar o regulamento oficial.
