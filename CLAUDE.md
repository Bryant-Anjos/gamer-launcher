# Gamer Launcher: instruções para o assistente de código

Launcher em tela cheia, estilo console, controlado por gamepad, para o Pop!_OS 24.04 (COSMIC).
Flutter (`app/`) + Rust (`core/` é o núcleo sem UI; `app/rust/` é a ponte flutter_rust_bridge, fina).
Comece por `PLAN.md` (decisões, fases, medições, pendências e notas de ambiente).

## Comandos

- `make check`: tudo que precisa estar verde antes de cada commit (núcleo Rust, app Flutter, empacotamento e roteiro).
- `make core-check` / `make app-check` / `make packaging-check`: cada parte isolada.
- Regenerar a ponte depois de mudar `app/rust/src/api/`: `cd app && flutter_rust_bridge_codegen generate`.
- Compilar o app: `cd app && mkdir -p build/native_assets/linux && flutter build linux --release`.
- Controle virtual para testar sem hardware: `tools/virtual_pad.py` (veja o `PLAN.md`).
- Se o build reclamar de `Cargo.lock` ou edition 2024, o `~/.rustup` global está velho: `rustup update stable`.

## Como trabalhar

- **TDD**: escreva o teste, veja falhar (RED), implemente (GREEN), refatore. Cobertura de 80% ou mais.
- **Imutabilidade**: devolva valores novos; não altere os recebidos. Arquivos pequenos, funções curtas, erros tratados.
- Não invente comportamento: **execute** os comandos e confira os resultados antes de afirmar que funcionam.
- UI complexa só com o modelo Opus (preferência do usuário); avise e pare se estiver em outro.
- Não alterne Wi-Fi/Bluetooth de verdade em testes; use o executor falso.

## Commits

- Conventional commits, **em português**, com o porquê no corpo.
- **Sem linhas `Co-Authored-By` nem `Claude-Session`**: pedido explícito do usuário.
- Commite o trabalho concluído **antes de começar a próxima fase**, só com os arquivos dela.
- Código, testes e a documentação/roteiro dele vão no **mesmo commit**.

## Roteiro de testes manuais (regra de ouro)

`docs/roteiro/` guarda o roteiro que o usuário segue para testar o launcher à mão (a página publicada como site,
com progresso, bandeira de problema e relatório para o WhatsApp). **Toda alteração de conteúdo tem que mudar os
testes do roteiro.** "Conteúdo" é qualquer coisa que o usuário vê ou faz: telas, botões, atalhos, comportamento
de um painel, instalação, mensagens de erro, limites.

| Se mudou... | Faça |
|---|---|
| uma funcionalidade existente | altere, acrescente ou remova itens da seção em `docs/roteiro/roteiro.json` |
| uma funcionalidade nova | crie uma seção nova (ou itens numa existente) e mapeie os arquivos dela em `covers` |
| um arquivo vigiado novo | mapeie-o em `covers` de uma seção, ou acrescente a `ignore` se não afeta o usuário |
| algo só interno (refatoração, sem efeito visível) | rode o ack com motivo escrito (veja abaixo) |
| a página (visual, comportamento do site) | edite `docs/roteiro/template.html` |
| uma fase que muda o que dá para testar | tire ou ponha o aviso `priority` das seções afetadas |

Como a regra é imposta (`make roteiro-check`, parte do `make check` e da CI):

1. Cada seção declara em `covers` os arquivos de código que testa e guarda o hash deles na última revisão.
2. Se um arquivo coberto mudar, aparecer ou sumir, ou se existir um arquivo vigiado (`watch`) que nenhuma seção
   cobre, a verificação **falha** e diz qual seção revisar.
3. Para liberar: edite os itens da seção e rode `make roteiro-ack SECAO=<id>`. O ack **recusa** se os itens não
   mudaram desde a última revisão, a não ser que você diga por que nenhum teste precisa mudar:
   `make roteiro-ack SECAO=<id> MOTIVO="..."`. O motivo fica gravado em `reviews` (as últimas 5), então um ack
   sem mudança real aparece no diff para quem revisa.
4. Não edite `reviewed`, `itemsHash` nem `reviews` à mão, e não use `roteiro-baseline` para "calar" a verificação.

A verificação não julga se o roteiro está *bom*: se o **sentido** de algo mudou, reescreva os itens mesmo sem teste
falhando. Itens novos vão no **fim** da lista da seção (o progresso salvo no navegador do testador usa a posição).
Depois de mudar o roteiro: `make roteiro-build` gera `dist/roteiro-de-testes.html`, que é o arquivo a publicar no
mesmo Artifact (https://claude.ai/artifact/HznhVG4EyHwr44chCNjjCN), para o link do usuário continuar o mesmo.

## Armadilhas conhecidas

- Dois Rust no PC: o do asdf e o do `~/.rustup`; ambos precisam estar na versão estável atual.
- `gilrs` só aceita dispositivos com 1 botão e 2 eixos; o controle virtual imita um Xbox 360 por isso.
- O `lib.rs` do núcleo e os arquivos gerados da ponte ficam em `ignore` no roteiro de propósito.
