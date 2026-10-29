# Ideia: controle remoto pelo celular

Estado: **ideia, nada implementado.** Para fazer depois, no Linux.

## Objetivo

Um controle remoto no celular, como o de uma TV, que comanda o launcher da própria pessoa e de mais ninguém.

## Desenho proposto

- **Página web instalável (PWA)** servida pelo próprio launcher na rede local. Sem loja de aplicativos e sem conta de
  desenvolvedor. Um app nativo (Android/iPhone) fica para depois, se valer a pena.
- **Servidor no launcher**, desligado por padrão e ligado nas configurações. Sugestão: `HttpServer` do Dart com
  WebSocket, no mesmo processo do app, entregando as ações ao `InputRouter` pelo mesmo `Stream` que o controle de
  videogame já usa (`gamepadStream`). Assim o resto do app não muda.
- **Botões do controle:** setas, confirmar, voltar, início, pesquisar, controle rápido (Start), LB/RB, volume e,
  depois, um teclado para a pesquisa.
- **Pareamento:** na primeira vez o launcher mostra na tela um código (ou QR com o endereço e o código). Quem digita o
  código no celular recebe uma chave aleatória, guardada só naquele aparelho. Sem a chave o servidor recusa tudo.
  Nas configurações, a lista de aparelhos pareados permite apagar qualquer um.
- **Sem nuvem:** o celular fala direto com o PC, na mesma rede.

## Cuidados

- **Segurança:** dentro da rede local o tráfego não é criptografado; aceitável em casa, não em rede pública. Limitar
  tentativas de código, expirar o código de pareamento em poucos minutos e comparar chaves em tempo constante.
- **Firewall:** o Windows pede permissão na primeira vez que o launcher escuta na rede; quem decide é a dona do PC.
- **Descoberta:** mostrar o endereço (IP e porta) na tela de configurações. Descoberta automática (mDNS) é opcional.
- **Testes:** o servidor precisa de testes no Linux e no Windows; a regra de ouro do projeto (atualizar o roteiro em
  `docs/roteiro`) vale para os novos itens visíveis.

## Primeiro protótipo sugerido

Servidor desligado por padrão, pareamento por código, e só setas + confirmar + voltar. Depois somar o resto.
