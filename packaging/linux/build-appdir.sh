#!/usr/bin/env bash
# Monta o AppDir (base do AppImage) a partir do bundle do Flutter.
# Uso: build-appdir.sh <bundle> <appdir>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

bundle="${1:?uso: build-appdir.sh <bundle> <appdir>}"
appdir="${2:?uso: build-appdir.sh <bundle> <appdir>}"

require_bundle "$bundle"
rm -rf "$appdir"
install -d "$appdir/usr/lib/$APP_NAME"
cp -a "$bundle/." "$appdir/usr/lib/$APP_NAME/"

# resolve o próprio caminho real, para funcionar também chamado por link simbólico
cat >"$appdir/AppRun" <<APPRUN
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/lib/$APP_NAME/$BINARY" "\$@"
APPRUN
chmod 755 "$appdir/AppRun"

install -m 644 "$LINUX_PACKAGING_DIR/$APP_NAME.desktop" "$appdir/$APP_NAME.desktop"
install -m 644 "$LINUX_PACKAGING_DIR/$APP_NAME.svg" "$appdir/$APP_NAME.svg"
ln -sf "$APP_NAME.svg" "$appdir/.DirIcon"
