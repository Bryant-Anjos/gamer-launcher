# Roteiro de testes manuais

A lista que o usuário segue para testar o launcher à mão, publicada como um site (mesmo formato do roteiro do
projeto de cartas): seções que abrem e fecham, progresso, bandeira de "deu problema", feedback por seção e um
relatório pronto para o WhatsApp. O progresso fica salvo no navegador de quem testa.

## Arquivos

| Arquivo | O que é |
|---|---|
| `roteiro.json` | O conteúdo: seções, itens, avisos e o mapa do código que cada seção cobre. **Fonte da verdade.** |
| `template.html` | A página. O marcador `__ROTEIRO_DATA__` recebe as seções na hora de gerar. |
| `../../tools/roteiro/roteiro.py` | Verificador e gerador (`check`, `ack`, `build`, `baseline`). |
| `../../tools/roteiro/test_roteiro.py` | Testes do verificador. |

## Campos de uma seção

| Campo | Obrigatório | Para quê |
|---|---|---|
| `id` | sim | Minúsculas, números e hífens. Não mude depois de publicado: o progresso salvo usa o id. |
| `title`, `sub` | sim | Nome da seção e subtítulo. |
| `items` | sim | Os testes, em português, cada um terminando com o que conferir. Novos vão no **fim**. |
| `covers` | sim | Padrões (glob) dos arquivos de código que a seção testa. `[]` só em seção puramente manual. |
| `priority` | não | Aviso em destaque (ex.: "Precisa de controle físico", "Ainda em desenvolvimento"). |
| `desc` | não | Nota explicativa no topo da seção. |
| `reviewed`, `itemsHash`, `reviews` | gerados | Controlados pelo `ack`. Não editar à mão. |

`watch` e `ignore` (na raiz do JSON) definem quais arquivos de código são vigiados e quais ficam de fora
(código gerado, por exemplo).

## Fluxo

```
# mudei o código de uma funcionalidade
make roteiro-check                      # falha e diz qual seção revisar
# edite os itens em docs/roteiro/roteiro.json
make roteiro-ack SECAO=sistema          # libera (recusa se os itens não mudaram)
make roteiro-ack SECAO=sistema MOTIVO="Refatoração interna, sem efeito visível."   # sem mudança, com motivo
make roteiro-build                      # gera dist/roteiro-de-testes.html para publicar
```

A regra completa está no `CLAUDE.md` (seção "Roteiro de testes manuais").
