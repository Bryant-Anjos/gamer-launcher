.PHONY: app-release check core-check app-check packaging-check roteiro-test roteiro-check roteiro-build roteiro-ack roteiro-baseline

# Tudo o que precisa estar verde antes de cada commit.
check: core-check app-check packaging-check roteiro-test roteiro-check

core-check:
	cd core && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test

app-check:
	cd app/rust && cargo clippy -- -D warnings
	cd app && flutter analyze && flutter test

packaging-check:
	packaging/linux/tests/test_packaging.sh

# Roteiro de testes manuais (docs/roteiro): veja a seção no CLAUDE.md.
roteiro-test:
	python3 -m unittest discover -s tools/roteiro

roteiro-check:
	python3 tools/roteiro/roteiro.py check

# Gera dist/roteiro-de-testes.html (a página que é publicada).
roteiro-build:
	python3 tools/roteiro/roteiro.py build

# Marca uma seção como revisada depois de mexer nos itens dela:
#   make roteiro-ack SECAO=sistema
# Se nenhum teste precisa mudar, diga por quê (fica gravado no arquivo):
#   make roteiro-ack SECAO=sistema MOTIVO="Refatoração interna, sem efeito visível."
roteiro-ack:
	@test -n "$(SECAO)" || (echo 'use: make roteiro-ack SECAO=<id> [MOTIVO="..."]' >&2; exit 2)
	python3 tools/roteiro/roteiro.py ack $(SECAO) $(if $(MOTIVO),--sem-mudanca "$(MOTIVO)")

# Só para criar a linha de base de um roteiro novo; no dia a dia use roteiro-ack.
roteiro-baseline:
	python3 tools/roteiro/roteiro.py baseline

# Compila o release do zero. Sem cortar a fonte de ícones: um bundle
# incremental chegou a ficar com a fonte cortada de um build antigo, e os
# ícones novos viraram outros caracteres (ideogramas) na tela.
app-release:
	rm -rf app/build/linux/x64/release/bundle
	cd app && mkdir -p build/native_assets/linux && flutter build linux --release --no-tree-shake-icons
