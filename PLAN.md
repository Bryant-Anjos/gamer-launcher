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
- Linux: `zbus` (NetworkManager, BlueZ, energia), PipeWire/PulseAudio para volume. Windows: crate `windows`.

### Entrada e navegação

- Gamepad via `gilrs` no Rust, enviado à UI como eventos.
- Navegação por **foco direcional** (D-pad/analógico), com `Focus`/`FocusTraversalGroup` do Flutter.
- Mapeamento: A confirma, B volta, Y pesquisa, Start abre o controle rápido.

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
