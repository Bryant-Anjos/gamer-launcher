#!/usr/bin/env bash
# Gera o .deb a partir do bundle do Flutter.
# Uso: build-deb.sh <bundle> <pasta-de-saída> [versão]
# A versão vem de app/pubspec.yaml quando omitida; MAINTAINER define o campo
# Maintainer (padrão: um endereço genérico).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

bundle="${1:?uso: build-deb.sh <bundle> <pasta-de-saída> [versão]}"
out_dir="${2:?uso: build-deb.sh <bundle> <pasta-de-saída> [versão]}"
version="${3:-}"

require_bundle "$bundle"
[ -n "$version" ] || version="$(app_version "$LINUX_PACKAGING_DIR/../../app/pubspec.yaml")" ||
  die "não foi possível ler a versão do pubspec.yaml"
valid_version "$version" || die "versão inválida: $version"

arch="$(dpkg --print-architecture)"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
root="$staging/${APP_NAME}_${version}_${arch}"

install -d "$root/DEBIAN" "$root/opt/$APP_NAME" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/scalable/apps"
cp -a "$bundle/." "$root/opt/$APP_NAME/"
ln -s "/opt/$APP_NAME/$BINARY" "$root/usr/bin/$APP_NAME"
install -m 644 "$LINUX_PACKAGING_DIR/$APP_NAME.desktop" "$root/usr/share/applications/$APP_NAME.desktop"
install -m 644 "$LINUX_PACKAGING_DIR/$APP_NAME.svg" "$root/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg"
chmod -R u+rwX,go+rX,go-w "$root"

installed_size_kb="$(du -sk --exclude=DEBIAN "$root" | cut -f1)"
cat >"$root/DEBIAN/control" <<CONTROL
Package: $APP_NAME
Version: $version
Section: utils
Priority: optional
Architecture: $arch
Maintainer: ${MAINTAINER:-$DEFAULT_MAINTAINER}
Installed-Size: $installed_size_kb
Depends: libgtk-3-0t64 | libgtk-3-0, libudev1
Description: $APP_SUMMARY
 Interface estilo console para abrir aplicativos, arquivos e configurações,
 navegável por controle de videogame, teclado e mouse.
CONTROL

mkdir -p "$out_dir"
deb="$out_dir/${APP_NAME}_${version}_${arch}.deb"
dpkg-deb --root-owner-group --build "$root" "$deb" >/dev/null
echo "$deb"
