# gamer-launcher (nome provisório)

Launcher em tela cheia, estilo console, que roda **por cima** do desktop e é controlável por gamepad, teclado e mouse. Multiplataforma, leve e rápido.

A arte de conceito é referência **visual**. As funcionalidades são só as definidas neste documento.

## Decisões

- **Stack:** Flutter (UI) + Rust (acesso ao sistema), ligados por `flutter_rust_bridge` (Rust roda dentro do app, sem processo separado).
- **Modo:** por cima do desktop, tela cheia. Não substitui o desktop/COSMIC.
- **Plataformas:** Linux (Pop!_OS/COSMIC, Wayland) primeiro; Windows depois; macOS por último (exige conta paga para assinar).
- **Desenvolvimento:** TDD (teste primeiro, 80%+ de cobertura), sem retrocompatibilidade até o 1º lançamento.
- **Desempenho:** sem Electron; sondagem de sistema a 1 Hz só com a tela visível; imagens em cache e carregadas sob demanda; meta de RAM a medir na Fase 1.

## Funcionalidades da v1

Todos os painéis são **ocultáveis** pelo usuário (sobra só a navegação principal).

| Painel | Conteúdo |
|---|---|
| Navegação | Início, Aplicativos, Jogos, Arquivos, Configurações |
| Cartões de destaque | Continuar (último app), Projetos, Jogos, Músicas |
| Pesquisa global | Apps, arquivos e configurações |
| Controle rápido | Wi-Fi, Bluetooth, modo escuro, volume, brilho (luz noturna fora da v1, ver Fase 3) |
| Sistema | CPU, RAM, disco (gráficos) |
| Recentes | Arquivos/pastas recentes |
| Favoritos | Grade de apps favoritos, com "Adicionar" |
| Barra superior | Wi-Fi, volume, controle conectado, hora/data |

**Jogos:** só um atalho para abrir Steam/Heroic/Lutris. Sem biblioteca própria.

### Personalização

- **Tema:** claro, escuro ou **automático pela hora do dia** (horários configuráveis).
- **Wallpaper:** escolhido pelo usuário ou nenhum (fundo de cor lisa do tema).
- **Painéis:** cada um pode ser exibido ou oculto.
- Configurações salvas em arquivo local, validadas ao carregar.

## Arquitetura

```
gamer-launcher/
  app/            Flutter: telas, tema, navegação por foco, entrada de gamepad
  core/           Rust (crate): lógica testável, sem UI
    system/       trait SystemControl + implementação por SO (linux, windows)
    stats/        CPU/RAM/disco (sysinfo)
    recents/      arquivos recentes
    apps/         descoberta e abertura de apps (.desktop no Linux)
    search/       busca global
    input/        gamepad (gilrs)
  app/rust/       crate da ponte (flutter_rust_bridge), fina: só chama o core
  docs/
```

- O Rust expõe uma **trait por capacidade** (rede, áudio, brilho, energia). Cada SO implementa a sua. Os testes usam implementações falsas.
- A UI nunca fala com o SO diretamente, só com o `core` pela ponte.
- Linux (decidido na Fase 3): programas de linha de comando por trás de um `CommandRunner` (trocável por um falso nos testes): `nmcli` (Wi-Fi), `bluetoothctl` + `rfkill` (Bluetooth), `wpctl` (volume), brilho lido de `/sys/class/backlight` e escrito pelo `logind` via `busctl`, e modo escuro do sistema no arquivo `is_dark` do COSMIC. Sem `zbus`. Windows: crate `windows`.

### Entrada e navegação

- Gamepad via `gilrs` no Rust, enviado à UI como eventos.
- Navegação por **foco direcional** (D-pad/analógico), com `Focus`/`FocusTraversalGroup` do Flutter.
- Mapeamento (implementado): A confirma, B volta, Y pesquisa, Start abre o controle rápido, LB/RB trocam de aba, **Guide fecha o app** (Ctrl+Q no teclado). D-pad e analógico esquerdo movem o foco; segurar uma direção repete (400 ms de espera, depois a cada 120 ms).
- A lógica é pura (`core/src/input.rs`, tempo como parâmetro) e só a casca fina (`gamepad.rs`) lê o `gilrs`. No Flutter, o `InputRouter` traduz as ações em foco/ativação, como se fossem teclas.
- (Fase 5) O `InputRouter` fica em `MaterialApp.builder`, **acima do `Navigator`**: o Ctrl+Q vale com diálogos abertos e a travessia parte sempre do foco primário (a camada de cima). Esquerda/direita primeiro tentam um `AdjustIntent` no item focado (volume, brilho, horários); se ninguém aceitar, movem o foco.

### UI (decidido na Fase 5)

- **Ponte:** tipos próprios e simples (`LauncherSettings`, `LauncherThemeMode`, `ResolvedTheme`, `AppCatalog`, `RecentFile`, `QuickControls`, `StatsSample`), com nomes que não colidem com os do Flutter. Erros chegam como `String` e viram `BackendException`. Conversões em `app/rust/src/convert/` (testadas, fora de `api` para o gerador não expor). Funções pesadas (listar apps, ler controles, stats) são assíncronas: rodam fora da thread da UI. Tamanhos em bytes vão como `f64` (o `u64` viraria `BigInt` no Dart).
- **Estado sem pacote:** `ValueNotifier`/`ChangeNotifier` e estado imutável (`LauncherState`, edição por cópia). A UI só conhece a interface `LauncherBackend` (`RustBackend` no app, `FakeBackend` nos testes).
- **Sondagem:** CPU/RAM/disco a 1 Hz só com o painel Sistema na tela; controle rápido a cada **5 s** (cada leitura roda nmcli, bluetoothctl e wpctl) só com a barra superior ou o painel na tela; controle conectado a 1 Hz (lê um contador atômico da thread do gilrs). Tudo pausa quando o app sai de `resumed` (um jogo por cima, por exemplo). Cada tela "se inscreve" no `Poller` enquanto existe.
- **Escrita no sistema:** otimista (a tela muda na hora; se o sistema recusar, aviso e releitura). Leituras que chegam durante uma escrita são descartadas. Volume e brilho são coalescidos: segurando o direcional só o último valor espera.
- **Ícones:** localizados no núcleo (temas `hicolor`, `Cosmic`, `Pop`, `Adwaita`, `breeze` e `pixmaps`, do usuário para o sistema; SVG primeiro, depois o maior PNG). SVG desenhado com `flutter_svg`; bitmaps decodificados no tamanho exibido; sem ícone, a inicial num quadrado colorido. Grades preguiçosas (só os itens visíveis são montados).
- **Histórico:** último app aberto pelo launcher em `$XDG_STATE_HOME/gamer-launcher/history.json` (separado das configurações, que são escolhas do usuário).
- **Saudação:** "Bom dia/Boa tarde/Boa noite" pela hora + primeiro nome do campo GECOS do `/etc/passwd` (sem nome, só a saudação).
- **Cartões de destaque:** *Continuar* abre o último app aberto pelo launcher; *Projetos* mostra quantos recentes há e leva à seção Arquivos; *Jogos* abre o lançador se houver um só (Steam, Heroic ou Lutris, nessa ordem) ou leva à seção Jogos se houver mais; *Músicas* abre o primeiro app com categorias `Player` + `Music` (ou `Player` + `Audio`). Cartão sem app fica apagado e diz por quê. Sem ilustrações próprias: degradês no lugar das imagens da arte.
- **Seções:** Início (painéis), Aplicativos (todos os apps), Jogos (lançadores instalados), Arquivos (lista completa de recentes), Configurações (tema e horários do automático de 30 em 30 min, wallpaper, painéis visíveis).
- **Botões:** Start abre o controle rápido **sobreposto** em qualquer seção (Start ou B fecham; com o painel oculto nas configurações, não abre). Y vai à Início e foca a pesquisa (só avisa que chega na Fase 6). LB/RB levam o foco junto para o item da seção na navegação; com um painel sobreposto aberto, LB/RB/Y são ignorados.
- **Favoritos:** escolhidos num diálogo com todos os apps (A marca/desmarca, B fecha). Sem favoritos padrão.
- **Wallpaper:** imagens da pasta de imagens do usuário (`user-dirs.dirs`) e de `/usr/share/backgrounds`, até 2 níveis e 60 imagens; decodificado na largura da tela, com um véu do tema por cima. Arquivo que não abre volta à cor lisa.
- **Foco visível:** borda de 3 px na cor de destaque, brilho e leve aumento (1,04×); segue o foco real (não o modo de destaque do Flutter, que só liga com teclado).
- **Avisos:** falhas (abrir app, salvar configurações, alterar Wi-Fi...) aparecem como SnackBar; nada derruba a tela. Leitura de controle que falha mostra o item como "Indisponível" (com o motivo numa dica).

## Fases (cada uma termina com testes verdes e commit antes da próxima)

1. **Fundação:** estrutura do projeto, ponte Flutter↔Rust, CI com testes, medição de RAM/CPU em repouso. Janela em tela cheia vazia.
2. **Núcleo em Rust (TDD):** `stats`, `apps`, `recents`, `search`, configurações em arquivo.
3. **Controle do sistema (Linux):** Wi-Fi, Bluetooth, volume, brilho, modo escuro, luz noturna. Testes com implementações falsas; teste manual no Pop!_OS.
4. **Entrada:** gamepad, navegação por foco, mapeamento de botões.
5. **UI** (modelo Opus recomendado): tema claro/escuro/automático, wallpaper, painéis ocultáveis, cartões, grade de favoritos, gráficos do sistema. Testes de widget e golden tests.
6. **Pesquisa e polimento:** pesquisa global, animações, sons opcionais, ajustes de desempenho.
7. **Empacotamento:** AppImage e .deb; CI gera os artefatos a cada versão.
8. **Windows:** implementações de `SystemControl` e instalador.
9. **macOS:** só se houver interesse.

## Testes

- **Rust:** unitários por módulo; traits permitem falsos; integração leve no Linux.
- **Flutter:** testes de widget (foco, tema, painéis ocultos) e golden tests dos temas.
- **E2E:** fluxo principal por gamepad simulado (navegar, abrir app, abrir controle rápido).
- **Meta:** 80%+ de cobertura.

## Riscos

| Risco | Mitigação |
|---|---|
| COSMIC é novo; sem APIs estáveis para configurações | Usar NetworkManager/BlueZ/PipeWire direto, sem depender do COSMIC; testar cedo na Fase 3 |
| Janela em tela cheia "por cima" no Wayland | Validar na Fase 1 (layer-shell ou janela fullscreen normal) |
| Flutter mais pesado que o ideal | Medir na Fase 1; se passar da meta, reavaliar com Slint |
| Curva de aprendizado do Rust | Escopo pequeno e módulos isolados; começar por `stats` e `recents` |
| Gamepad no Wayland sem foco da janela | Ler pelo `gilrs` (evdev), que independe do foco |

## Notas de ambiente (descobertas na Fase 1)

- **Linux:** o build do Flutter exige `clang`, `cmake`, `libgtk-3-dev` e `libstdc++-14-dev` (apt).
- **Rust:** 1.99.1 (stable) no asdf e no rustup global; Flutter 3.47.7 (stable, fixado em `.tool-versions`). Se o `~/.rustup` global voltar a ficar antigo, o build quebra com `Cargo.lock` v4/edition 2024: rodar `rustup update stable`.
- Se o CMake reclamar de `build/native_assets/linux`, criar o diretório vazio (`mkdir -p build/native_assets/linux`).
- Geração da ponte: `flutter_rust_bridge_codegen generate` dentro de `app/` (precisa de `cargo-expand`).
- Contra o asdf, usar sempre o shim (`asdf reshim rust` após `cargo install`).

## Medições

| Fase | RAM em repouso | CPU em repouso |
|---|---|---|
| 1 (tela cheia vazia, release, Linux) | ~209 MB | 0% |
| 2 (só núcleo Rust, sem mudança na UI) | igual à Fase 1 | igual |
| 5 (tela inicial completa, release, Linux, sem wallpaper) | ~207 MB RSS (~184 MB PSS) | 0 a 0,6% de um núcleo (0 a 6 ticks em 10 s, com as sondagens ativas) |

Dentro da faixa esperada do Flutter (150-250 MB). Meta definitiva: ver "Em aberto".

## Fase 4: como testar sem controle físico

`tools/virtual_pad.py` cria um controle virtual (imita um Xbox 360) via `/dev/uinput` e aperta botões em sequência:

```
python3 tools/virtual_pad.py 1.5 DPAD_DOWN SOUTH EAST MODE   # MODE = Guide: o app fecha
```

- Precisa de acesso de escrita a `/dev/uinput` (no Pop!_OS o usuário da sessão já tem por ACL). O `gilrs` só aceita dispositivos com **pelo menos 1 botão e 2 eixos**, e só aplica o mapeamento SDL (D-pad como botão, Guide reconhecido) se o dispositivo for um modelo conhecido; por isso o script imita um Xbox 360 de verdade.
- Dependência de sistema para compilar o núcleo: `libudev-dev`.

### Fase 4: pendência para a Fase 5 (resolvida na Fase 5)

- **Diálogos e rotas empilhadas:** resolvido. O `InputRouter` subiu para acima do `Navigator` e a travessia parte do foco primário; há testes com diálogo aberto (direção, confirmar, voltar e Ctrl+Q).

## Fase 5: como testar à mão

- **Alternar Wi-Fi e Bluetooth de verdade** pelo controle rápido (Start): só foram testados com executor falso. Pode derrubar a conexão; fazer com o computador ao lado.
- **Modo escuro do sistema** pelo painel: grava o `is_dark` do COSMIC (testado com executor falso).
- **Wallpaper real:** escolher uma imagem em Configurações e conferir legibilidade nos dois temas.
- **Volume** segurando o direcional (coalescido; conferir que o valor final bate).
- **Abrir apps e recentes** de verdade (só o caminho de erro e o `true` foram testados automaticamente); confirmar que o cartão Continuar passa a mostrar o app.
- Ícones reais (SVG e PNG) e a navegação por controle físico em todas as seções.
- Monitor ultrawide (2560×1080): os goldens são em 1920×1080.

## Fase 5: pendências e dúvidas para a Fase 6

- **Pesquisa:** o campo existe e recebe foco (Y), mas a busca é da Fase 6 (o núcleo já tem `search`).
- **Dúvidas de design (a arte sugere, o PLAN não define; ficaram de fora):** a linha de atalhos "Tela, Som, Energia, Rede" no controle rápido; o que exatamente é "Projetos" (hoje: conta de recentes e leva a Arquivos); qual player usar em "Músicas" se houver vários; favoritos padrão; ilustrações dos cartões; se Start deve abrir o painel mesmo com ele oculto.
- **Limitações da Fase 2 que continuam:** nomes localizados (`Name[pt_BR]`), `TryExec`/`OnlyShowIn`, `%i`/`%c`, apps de terminal (a UI mostra o erro amigável ao abrir).
- **Ícones:** só os temas listados acima; o tema de ícones configurado no COSMIC não é lido; ícones `.ico`/`.xpm` caem na inicial. Ícones de categorias que não ficam em `apps/` (ex.: impressoras) também.
- **Golden tests** usam Roboto e os ícones do SDK; podem diferir em outra máquina/versão do Flutter (regenerar com `flutter test --update-goldens`).
- **Captura de tela do app real:** `grim` não funciona no COSMIC (sem wlr-screencopy) e o `cosmic-screenshot` não interativo falhou pelo portal; a verificação visual foi pelos goldens.
- **Animações e sons** (Fase 6): só há a animação curta do foco.
- **Da revisão de código (LOW, não corrigidos):** alguns `build` passam de 50 linhas (`FeaturedCards`, `FocusTile`, `QuickControlsPanel`) e há medidas soltas (paddings e fontes) fora de `Dimens`; o `MaterialApp` inteiro é reconstruído a cada minuto e a cada mudança do controlador (o tema chama o `resolveTheme` síncrono do Rust nessas horas). A barra superior mantém a leitura do controle rápido (5 s) em qualquer seção, por projeto.

## Fase 3: o que ficou de fora

- **Luz noturna:** não encontrei API estável no COSMIC; fica fora da v1 (o painel mostra o botão desativado ou o oculta).
- **Escrita de Wi-Fi/Bluetooth/modo escuro** foi testada com executor falso; só o brilho foi validado de verdade na máquina (leituras dos demais conferem com o sistema). Alternar o Wi-Fi e o Bluetooth de verdade fica para teste manual na Fase 5, para não derrubar a conexão sem você ver.
- Modo escuro do sistema só atua em apps que seguem o tema do COSMIC.

## Fase 2: limitações conhecidas (da revisão de código)

Ficam para quando a UI for ligada (Fase 5), pois dependem do locale e do ambiente do usuário:

- **Nomes localizados:** só `Name=` é lido; `Name[pt_BR]=` ainda não (precisa receber o locale).
- **Filtros do `.desktop`:** `TryExec`, `OnlyShowIn` e `NotShowIn` são ignorados.
- **Códigos de campo `%i` e `%c`** são removidos em vez de expandidos; o unescape de string do `.desktop` (`\s`, `\n`) ainda não é aplicado.
- **Apps de terminal** (`Terminal=true`): `launch` recusa com erro `Unsupported` até existir uma forma de abri-los num terminal.
- Flatpak do usuário usa `$HOME/.local/share/flatpak`; a spec do Flatpak usa `$XDG_DATA_HOME/flatpak`.

## Em aberto

- Nome definitivo do projeto.
- Meta de RAM/CPU em repouso (referência atual: ~209 MB / 0%).
- Atalho global para abrir/fechar o launcher.
- Quais apps entram como favoritos padrão (hoje nenhum).

## Fase 7 (empacotamento Linux): preparado, falta validar o AppImage na CI

Scripts em `packaging/linux/` (testes: `packaging/linux/tests/test_packaging.sh`, 31 verificações, rodam em segundos com um bundle de mentira):

- `build-deb.sh <bundle> <saída> [versão]` → `gamer-launcher_<versão>_amd64.deb` (bundle em `/opt/gamer-launcher`, comando `gamer-launcher` em `/usr/bin`, atalho de menu e ícone SVG). Validado com o app real: instalado em pasta temporária, abre e fecha com o Guide do controle virtual. Tamanho: 7,6 MB (23 MB instalado).
- `build-appdir.sh` / `build-appimage.sh`: montam o AppDir (estrutura conferida nos testes) e chamam o `appimagetool`. **A geração do AppImage em si não foi executada localmente** (exigiria baixar o `appimagetool`); ela roda na CI de release (`.github/workflows/release.yml`, em tags `v*`), com a versão do `appimagetool` fixada. Confirmar na primeira execução da CI.
- A versão do pacote vem de `app/pubspec.yaml` (hoje 0.1.0).
- A release compila no Ubuntu 22.04 de propósito (glibc mais antiga roda nas mais novas). O binário atual exige no máximo glibc 2.34, então em teoria roda no Pop!_OS/Ubuntu 22.04+; **não foi testado em outra versão**.
- Campo `Maintainer` do .deb usa um endereço genérico; defina `MAINTAINER="Nome <email>"` na CI/ambiente antes de publicar.

### Compatibilidade fora do COSMIC (não implementado)

O núcleo do launcher não depende do COSMIC, mas: o modo escuro do sistema só lê/grava o arquivo de tema do COSMIC; as páginas de configurações da busca chamam `cosmic-settings`; o volume usa `wpctl` (PipeWire). Em GNOME/PulseAudio esses itens ficam indisponíveis ou dão erro. Caminho futuro: `gsettings` para o modo escuro, `gnome-control-center` por ambiente e `pactl` como alternativa ao `wpctl`.

## Decisões de comportamento (a implementar na Fase 6, com a UI pronta)

- **Pesquisa por teclado físico é o caminho principal.** O campo recebe o foco ao abrir (barra ou Y no controle). Teclado na tela para quem usa só o controle **não está previsto**; reavaliar só se o uso no sofá mostrar que faz falta.
- **Ao abrir outro programa, o launcher se esconde** para o programa aparecer (comportamento de console). **O Guide passa a alternar** esconder/mostrar (a leitura do controle independe do foco da janela) e **Ctrl+Q continua fechando**. Isso muda o mapeamento da Fase 4, em que o Guide fecha o app.
- **Riscos a testar no COSMIC antes de implementar:** (1) um cliente Wayland consegue se minimizar, mas trazer a própria janela de volta à frente depende de o compositor permitir (ativação de janela); (2) um programa aberto pelo launcher pode não ganhar o foco sozinho. Plano B se (1) falhar: atalho de teclado do COSMIC que chama o launcher, ou reabrir uma janela nova. Alternativa descartada: fechar o launcher ao abrir (perde o estado).

## Feedback do primeiro teste real (2026-10-19)

Testado pelo Bryant com um **Pro Controller da Nintendo** (vendor `057e`, produto `2009`) por Bluetooth, no Pop!_OS 24.04 com COSMIC.

1. **Botões "invertidos" em controle Nintendo.** O launcher segue a **posição** dos botões do Xbox (confirmar = botão de baixo, voltar = o da direita, Y = o de cima). Num controle Nintendo os nomes são outros (o de baixo é o B, o da direita é o A), então a tela ("A marca, B fecha") e o roteiro confundem. Proposta (Fase 6, no núcleo e na UI): um `ButtonLayout` (Xbox, Nintendo, Automático) aplicado no `InputMapper`, trocando confirmar/voltar e os botões de cima/esquerda; o automático detecta Nintendo pelo vendor `0x057e` (`gilrs` expõe `vendor_id`); ajuste manual em Configurações; as dicas na tela mostram os nomes do layout ativo. O controle virtual (`tools/virtual_pad.py`) precisa de uma opção para imitar esse vendor nos testes.
2. **Pesquisa no seletor de favoritos ("Escolha os favoritos").** Pedido: filtrar os apps por nome ao adicionar favoritos. Reaproveita o `search` do núcleo; campo no topo do seletor, com a digitação pelo teclado físico (decisão já tomada). Fase 6, UI.
3. **Bluetooth e Wi-Fi no controle rápido só ligam e desligam.** Não há lista de dispositivos nem de redes, então para conectar foi preciso ir às configurações do sistema (o Wi-Fi não foi testado, mas deve ser igual). Opções, da mais barata à mais completa:
   - atalho "Configurações de Bluetooth/Rede" no painel, abrindo `cosmic-settings bluetooth` e `wireless` (o `open.rs` já abre essas páginas);
   - lista de dispositivos **pareados** com conectar/desconectar (`bluetoothctl devices Paired`, `connect`, `disconnect`);
   - varredura e pareamento de dispositivos novos (`scan on`, `pair`; pode pedir confirmação de PIN);
   - Wi-Fi: lista de redes (`nmcli dev wifi list`) e conectar; redes com senha exigem digitar (teclado físico ou na tela).
   Escolha de escopo pendente do usuário; a primeira opção cabe junto da Fase 6.
4. **Abrir outro programa funcionou sem tratamento próprio.** O launcher foi para trás quando o outro programa abriu e voltou quando esse foi fechado ("aparentemente está funcionando"). Pode ser o próprio COSMIC; **entender o que de fato aconteceu antes de implementar o "esconder ao abrir" e o "Guide alterna"** decididos antes (talvez não sejam necessários).

