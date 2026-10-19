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
| Controle rápido | Wi-Fi, Bluetooth, modo escuro, luz noturna, volume, brilho |
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

Dentro da faixa esperada do Flutter (150-250 MB). Meta definitiva: ver "Em aberto".

## Fase 4: como testar sem controle físico

`tools/virtual_pad.py` cria um controle virtual (imita um Xbox 360) via `/dev/uinput` e aperta botões em sequência:

```
python3 tools/virtual_pad.py 1.5 DPAD_DOWN SOUTH EAST MODE   # MODE = Guide: o app fecha
```

- Precisa de acesso de escrita a `/dev/uinput` (no Pop!_OS o usuário da sessão já tem por ACL). O `gilrs` só aceita dispositivos com **pelo menos 1 botão e 2 eixos**, e só aplica o mapeamento SDL (D-pad como botão, Guide reconhecido) se o dispositivo for um modelo conhecido; por isso o script imita um Xbox 360 de verdade.
- Dependência de sistema para compilar o núcleo: `libudev-dev`.

### Fase 4: pendência para a Fase 5 (da revisão de código)

- **Diálogos e rotas empilhadas:** o `InputRouter` resolve a travessia de foco a partir do contexto da tela de baixo, e o Ctrl+Q fica dentro dessa tela. Com um diálogo ou o painel de controle rápido aberto, a direção pode focar um item escondido atrás dele, e o Ctrl+Q não age ali (o Guide continua funcionando). Ao criar o primeiro painel sobreposto: usar o contexto do foco primário para a travessia e subir o `Shortcuts` para acima do `Navigator`. Não há diálogos hoje, por isso não foi tratado.

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
- A janela em tela cheia ainda não tem como fechar; atalho (Esc/botão Guide) entra na Fase 4.
- Atalho global para abrir/fechar o launcher.
- Quais apps entram como favoritos padrão.

## Fase 7 (empacotamento Linux): preparado, falta validar o AppImage na CI

Scripts em `packaging/linux/` (testes: `packaging/linux/tests/test_packaging.sh`, 31 verificações, rodam em segundos com um bundle de mentira):

- `build-deb.sh <bundle> <saída> [versão]` → `gamer-launcher_<versão>_amd64.deb` (bundle em `/opt/gamer-launcher`, comando `gamer-launcher` em `/usr/bin`, atalho de menu e ícone SVG). Validado com o app real: instalado em pasta temporária, abre e fecha com o Guide do controle virtual. Tamanho: 7,6 MB (23 MB instalado).
- `build-appdir.sh` / `build-appimage.sh`: montam o AppDir (estrutura conferida nos testes) e chamam o `appimagetool`. **A geração do AppImage em si não foi executada localmente** (exigiria baixar o `appimagetool`); ela roda na CI de release (`.github/workflows/release.yml`, em tags `v*`), com a versão do `appimagetool` fixada. Confirmar na primeira execução da CI.
- A versão do pacote vem de `app/pubspec.yaml` (hoje 0.1.0).
- A release compila no Ubuntu 22.04 de propósito (glibc mais antiga roda nas mais novas). O binário atual exige no máximo glibc 2.34, então em teoria roda no Pop!_OS/Ubuntu 22.04+; **não foi testado em outra versão**.
- Campo `Maintainer` do .deb usa um endereço genérico; defina `MAINTAINER="Nome <email>"` na CI/ambiente antes de publicar.

### Compatibilidade fora do COSMIC (não implementado)

O núcleo do launcher não depende do COSMIC, mas: o modo escuro do sistema só lê/grava o arquivo de tema do COSMIC; as páginas de configurações da busca chamam `cosmic-settings`; o volume usa `wpctl` (PipeWire). Em GNOME/PulseAudio esses itens ficam indisponíveis ou dão erro. Caminho futuro: `gsettings` para o modo escuro, `gnome-control-center` por ambiente e `pactl` como alternativa ao `wpctl`.

