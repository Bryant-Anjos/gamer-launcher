#!/usr/bin/env bash
# Gera o AppImage. Precisa do appimagetool (no PATH ou em $APPIMAGETOOL).
# Uso: build-appimage.sh <bundle> <pasta-de-saída> [versão]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

bundle="${1:?uso: build-appimage.sh <bundle> <pasta-de-saída> [versão]}"
out_dir="${2:?uso: build-appimage.sh <bundle> <pasta-de-saída> [versão]}"
version="${3:-}"

require_bundle "$bundle"
tool="${APPIMAGETOOL:-appimagetool}"
command -v "$tool" >/dev/null 2>&1 ||
  die "appimagetool não encontrado ($tool). Baixe de https://github.com/AppImage/appimagetool/releases e coloque no PATH ou defina APPIMAGETOOL."
[ -n "$version" ] || version="$(app_version "$LINUX_PACKAGING_DIR/../../app/pubspec.yaml")" ||
  die "não foi possível ler a versão do pubspec.yaml"
valid_version "$version" || die "versão inválida: $version"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"$LINUX_PACKAGING_DIR/build-appdir.sh" "$bundle" "$work/AppDir"

mkdir -p "$out_dir"
arch="$(uname -m)"
image="$out_dir/Gamer_Launcher-${version}-${arch}.AppImage"
ARCH="$arch" "$tool" "$work/AppDir" "$image" >/dev/null
echo "$image"
