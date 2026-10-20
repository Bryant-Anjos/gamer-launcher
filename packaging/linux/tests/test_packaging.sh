#!/usr/bin/env bash
# Testes dos scripts de empacotamento, com um bundle de mentira (rápido).
# Uso: packaging/linux/tests/test_packaging.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

check() { # check "descrição" comando...
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    passed=$((passed + 1))
    echo "ok   - $description"
  else
    failed=$((failed + 1))
    echo "FAIL - $description"
  fi
}

fails() { ! "$@"; }
contains() { grep -q -- "$2" <<<"$1"; }

# ---- bundle de mentira -----------------------------------------------------
BUNDLE="$WORK/bundle"
mkdir -p "$BUNDLE/lib" "$BUNDLE/data/flutter_assets"
printf '#!/bin/sh\necho launcher "$@"\n' >"$BUNDLE/gamer_launcher"
chmod 755 "$BUNDLE/gamer_launcher"
echo lib >"$BUNDLE/lib/libfake.so"
echo asset >"$BUNDLE/data/flutter_assets/AssetManifest.json"

PUBSPEC="$WORK/pubspec.yaml"
printf 'name: gamer_launcher\nversion: 2.5.1+7\n' >"$PUBSPEC"

# ---- versão ----------------------------------------------------------------
# shellcheck source=../common.sh
source "$LINUX_DIR/common.sh"
check "a versão vem do pubspec sem o número de build" \
  test "$(app_version "$PUBSPEC")" = "2.5.1"
check "pubspec sem versão é erro" fails app_version "$WORK/missing.yaml"

# ---- .deb ------------------------------------------------------------------
OUT="$WORK/out"
"$LINUX_DIR/build-deb.sh" "$BUNDLE" "$OUT" 2.5.1 >"$WORK/deb.log" 2>&1
DEB="$(ls "$OUT"/*.deb 2>/dev/null | head -1)"
check "o .deb foi gerado" test -f "$DEB"
check "o nome do arquivo tem pacote, versão e arquitetura" \
  contains "$(basename "$DEB")" "gamer-launcher_2.5.1_$(dpkg --print-architecture).deb"

CONTROL="$(dpkg-deb -f "$DEB" 2>/dev/null)"
check "control: pacote" contains "$CONTROL" "^Package: gamer-launcher"
check "control: versão" contains "$CONTROL" "^Version: 2.5.1"
check "control: depende de gtk e udev" \
  bash -c "grep -q 'libgtk-3-0' <<<\"\$1\" && grep -q 'libudev1' <<<\"\$1\"" _ "$CONTROL"
check "control: tem tamanho instalado" contains "$CONTROL" "^Installed-Size: [0-9]"
check "control: tem mantenedor" contains "$CONTROL" "^Maintainer: .*<.*@.*>"

LISTING="$(dpkg-deb -c "$DEB" 2>/dev/null)"
check "instala o bundle em /opt" contains "$LISTING" "./opt/gamer-launcher/gamer_launcher"
check "instala as bibliotecas junto" contains "$LISTING" "./opt/gamer-launcher/lib/libfake.so"
check "instala o atalho de menu" contains "$LISTING" "./usr/share/applications/gamer-launcher.desktop"
check "instala o ícone" contains "$LISTING" "./usr/share/icons/hicolor/scalable/apps/gamer-launcher.svg"
check "cria o comando em /usr/bin apontando para o bundle" \
  contains "$LISTING" "./usr/bin/gamer-launcher -> /opt/gamer-launcher/gamer_launcher"
# os donos no pacote são sempre root; nunca quem gerou o pacote
if [ "$(id -un)" != root ]; then
  check "os arquivos não pertencem a quem gerou o pacote" fails contains "$LISTING" " $(id -un)/"
fi

EXTRACTED="$WORK/extracted"
mkdir -p "$EXTRACTED"
dpkg-deb -x "$DEB" "$EXTRACTED"
check "o executável mantém a permissão de execução" \
  test -x "$EXTRACTED/opt/gamer-launcher/gamer_launcher"
# o link de /usr/bin aponta para /opt (só existe depois de instalar), então
# aqui roda-se o executável extraído; o destino do link já foi checado acima
check "o executável do pacote roda e repassa os argumentos" \
  test "$("$EXTRACTED/opt/gamer-launcher/gamer_launcher" ola 2>&1)" = "launcher ola"
check "o .desktop do pacote é válido" \
  desktop-file-validate "$EXTRACTED/usr/share/applications/gamer-launcher.desktop"

# ---- erros -----------------------------------------------------------------
check "bundle inexistente é erro" fails "$LINUX_DIR/build-deb.sh" "$WORK/nao-existe" "$WORK/o2" 1.0.0
mkdir -p "$WORK/vazio"
check "bundle sem executável é erro" fails "$LINUX_DIR/build-deb.sh" "$WORK/vazio" "$WORK/o3" 1.0.0
check "versão inválida é erro" fails "$LINUX_DIR/build-deb.sh" "$BUNDLE" "$WORK/o4" "1.0 beta"

# ---- AppDir / AppImage -----------------------------------------------------
APPDIR="$WORK/AppDir"
"$LINUX_DIR/build-appdir.sh" "$BUNDLE" "$APPDIR" >"$WORK/appdir.log" 2>&1
check "AppDir: tem AppRun executável" test -x "$APPDIR/AppRun"
check "AppDir: AppRun roda o launcher e repassa argumentos" \
  test "$("$APPDIR/AppRun" oi 2>&1)" = "launcher oi"
check "AppDir: tem o .desktop na raiz" test -f "$APPDIR/gamer-launcher.desktop"
check "AppDir: tem o ícone na raiz e como .DirIcon" \
  bash -c 'test -f "$1/gamer-launcher.svg" && test -e "$1/.DirIcon"' _ "$APPDIR"
check "AppDir: o bundle está em usr/lib" test -x "$APPDIR/usr/lib/gamer-launcher/gamer_launcher"
check "AppDir: o .desktop é válido" desktop-file-validate "$APPDIR/gamer-launcher.desktop"
check "AppDir: AppRun funciona por link simbólico" \
  bash -c 'ln -s "$1/AppRun" "$2/link" && test "$("$2/link" a 2>&1)" = "launcher a"' _ "$APPDIR" "$WORK"

check "AppImage sem appimagetool dá erro explicativo" \
  bash -c 'out="$(APPIMAGETOOL=/nao/existe "$1/build-appimage.sh" "$2" "$3" 2>&1)"; rc=$?; [ $rc -ne 0 ] && grep -qi appimagetool <<<"$out"' \
  _ "$LINUX_DIR" "$BUNDLE" "$WORK/o5"

# ---- arquivos estáticos ----------------------------------------------------
check "o ícone SVG é um SVG bem formado" \
  bash -c 'python3 -c "import sys, xml.dom.minidom as m; m.parse(sys.argv[1])" "$1"' _ "$LINUX_DIR/gamer-launcher.svg"
check "o .desktop de origem é válido" desktop-file-validate "$LINUX_DIR/gamer-launcher.desktop"
check "o release da CI não corta a fonte de ícones" \
  grep -q -- "flutter build linux --release --no-tree-shake-icons" "$LINUX_DIR/../../.github/workflows/release.yml"

echo
echo "$passed passaram, $failed falharam"
[ "$failed" -eq 0 ]
