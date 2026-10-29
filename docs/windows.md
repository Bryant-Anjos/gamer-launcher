# Gamer Launcher no Windows (experimental)

Este documento registra como o launcher foi levado do Linux para o Windows 11, o que funciona, o que ainda não
funciona e o que foi medido. A branch com o trabalho é `windows-port`.

## Como compilar

Requisitos:

- Flutter (a versão do `.tool-versions` ou mais nova) e Rust estável com o alvo MSVC.
- **Visual Studio Build Tools** com a carga de trabalho "Desenvolvimento para desktop com C++".
- **Modo de Desenvolvedor** do Windows ligado (Configurações > Sistema > Para desenvolvedores). O Flutter cria
  links simbólicos para os plugins, e o Windows só permite isso com esse modo.
- **Caminho curto para o projeto** (por exemplo `C:\gl\src`). O MSBuild falha com caminhos acima de 260 caracteres.
- **Smart App Control desativado.** Ele bloqueia os programas sem assinatura que o Rust e o Flutter geram durante a
  compilação (erro 4551, "uma política de Controle de Aplicativo bloqueou este arquivo"). Desativar é permanente
  (só reinstalando o Windows ele volta), então prefira compilar em outro computador e só copiar o resultado.

```powershell
cd app
flutter pub get
flutter build windows --release
```

O programa fica em `app\build\windows\x64\runner\Release\`. Copie a pasta inteira (o `.exe`, as `.dll` e `data`).
Renomear o `.exe` não quebra nada.

## O que muda em relação ao Linux

Tudo que é específico de sistema entra por `cfg(windows)` / `cfg(not(windows))`; o comportamento no Linux não muda.

| Assunto | Linux | Windows |
|---|---|---|
| Pastas de configuração e dados | XDG (`~/.config`, `~/.local/share`) | `%APPDATA%`, `%LOCALAPPDATA%` |
| Lista de aplicativos | arquivos `.desktop` | atalhos `.lnk` do Menu Iniciar (usuário e todos os usuários), sem desinstaladores |
| Abrir um aplicativo | `Exec` do `.desktop` | `cmd /C start "" "<atalho>"` (passar o atalho ao `explorer.exe` só abre Documentos) |
| Ícones dos aplicativos | temas de ícones freedesktop | extraídos do atalho com `PrivateExtractIcons`, 128 px, em `%LOCALAPPDATA%\gamer-launcher\icons` |
| Abrir arquivos | `xdg-open` | `explorer.exe` |
| Volume | `wpctl` | API de áudio do Windows (COM), via PowerShell |
| Brilho | `/sys/class/backlight` | WMI (só tela interna; monitor externo fica "indisponível") |
| Modo escuro do sistema | arquivo do COSMIC | registro (`AppsUseLightTheme`, `SystemUsesLightTheme`) |
| Bateria | `/sys/class/power_supply` | `GetSystemPowerStatus` |
| Wi-Fi (estado e nome da rede) | `nmcli` | PowerShell (`Get-NetAdapter`, `Get-NetConnectionProfile`) |
| Bluetooth (estado) | `bluetoothctl` | estado do serviço `bthserv` |
| Energia | `systemctl`, `loginctl` | `shutdown`, `rundll32 powrprof` |
| Iniciar com o sistema | arquivo em `~/.config/autostart` | valor `GamerLauncher` em `HKCU\...\Run` (sem administrador) |
| Nome na saudação | `/etc/passwd` (GECOS) | nome de exibição da conta, ou o nome de usuário |
| Janela | tela cheia (GTK) | janela sem bordas cobrindo o monitor, ícone do projeto |
| Fechar o launcher | `SystemNavigator.pop` | `exit(0)` (o `pop` não faz nada em desktop Windows) |

Arquivos novos: `core/src/system/windows.rs` (controles do sistema) e `app/windows/` (runner do Flutter).

## O que ainda não funciona no Windows

- Ligar e desligar Wi-Fi e Bluetooth (só mostram o estado) e a lista de dispositivos Bluetooth pareados.
- Sons da interface (dependem de `pw-play`, `paplay` ou `aplay`).
- Papéis de parede do sistema.
- Dicas de botão de PlayStation (✕ ○ □ △): o launcher mostra os rótulos do Xbox (A/B).
- O Wi-Fi usa PowerShell porque `netsh wlan` exige a permissão de localização do Windows para mostrar a rede.

## Mudanças que valem também para o Linux

Estas mudanças não são específicas do Windows e alteram a tela inicial no Linux em telas pequenas:

- **Carga em paralelo:** configurações, apps, recentes e nome começam juntos, e a tela aparece quando configurações e
  apps chegam (antes, uma leitura lenta segurava tudo).
- **Duas colunas em telas estreitas:** abaixo de 1500 px lógicos os cartões de destaque e os favoritos ficam em duas
  colunas e a coluna da direita encolhe (`Dimens.compactPanelScale`). Abaixo de 1280 px o layout é ampliado como um todo.

Por isso os testes de captura de tela (`app/test/goldens`) e o roteiro de testes manuais (`docs/roteiro`) precisam
ser revistos no Linux. Eles não foram atualizados nesta branch.

## Medições (um notebook de 1366x768, Windows 11)

- Abertura até o conteúdo da tela inicial: 4,8 a 5,3 s em quatro execuções seguidas, com ou sem cache de ícones.
  A janela leva de 4,2 a 4,8 s só para aparecer (Flutter e Rust iniciando); não foi investigado onde vão esses segundos.
- Antes da correção, a abertura passava de 15 s: o PowerShell (3 a 13 s para abrir neste PC) rodava a cada abertura
  para atalhos sem ícone, e a tela esperava. Agora a extração roda em segundo plano e atalhos sem ícone ficam
  marcados (`.none`) para não serem tentados de novo.
- Testes: o núcleo Rust passa por inteiro no Windows (testes que supõem caminhos e comandos de Linux ficam em
  `cfg(unix)`). No Flutter, 340 testes passam e 14 de captura de tela falham por diferença de renderização.

## Testes feitos à mão

- Tela cheia, fechar, ícones, nome do usuário, Wi-Fi, volume, brilho, bateria e layout: conferidos na tela.
- Controle: um controle foi testado e funcionou (o modelo não foi registrado). O de PlayStation não está confirmado.
- Iniciar com o Windows: só os comandos de registro foram testados; ligar na tela de configurações e abrir no login
  ainda não foram verificados.
- Abrir programas pelo launcher: o comando `cmd /C start` foi testado fora do app; dentro do app depende da
  confirmação de quem usa.

## Armadilhas encontradas

- `SystemNavigator.pop` não fecha o app no Windows desktop.
- Variáveis de ambiente com valor vazio somem no Windows (relevante para configuração do Git por ambiente).
- `Add-Type`/PowerShell abrem devagar em PCs com antivírus ativo; evite chamar PowerShell em sequência no caminho de
  abertura.
- `flutter create` gera `app/.metadata` e `pubspec.lock` diferentes; não commite essas mudanças.
- O Git do Windows com `core.autocrlf=true` marca centenas de arquivos como modificados ao copiar arquivos com LF.
