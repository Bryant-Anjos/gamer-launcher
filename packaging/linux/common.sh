# Funções e constantes compartilhadas pelos scripts de empacotamento (use com `source`).

APP_NAME="gamer-launcher"
APP_TITLE="Gamer Launcher"
BINARY="gamer_launcher"
APP_SUMMARY="Launcher em tela cheia, estilo console, controlado por gamepad"
DEFAULT_MAINTAINER="Gamer Launcher <noreply@example.com>"
LINUX_PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "erro: $*" >&2
  exit 1
}

# Versão do app (sem o número de build depois do "+") a partir do pubspec.yaml.
app_version() {
  local pubspec="$1" version
  [ -f "$pubspec" ] || return 1
  version="$(sed -n 's/^version:[[:space:]]*\([0-9][0-9A-Za-z.+~-]*\).*/\1/p' "$pubspec" | head -1)"
  [ -n "$version" ] || return 1
  echo "${version%%+*}"
}

valid_version() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)*([~+-][0-9A-Za-z.]+)?$ ]]
}

# O bundle do Flutter precisa existir e ter o executável.
require_bundle() {
  local bundle="$1"
  [ -d "$bundle" ] || die "bundle não encontrado: $bundle (rode 'flutter build linux --release')"
  [ -x "$bundle/$BINARY" ] || die "o bundle não tem o executável $BINARY: $bundle"
}
