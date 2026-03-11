#!/bin/sh

set -e

RAW_BASE_URL="${TERMIFY_PUBLIC_BASE_URL:-https://raw.githubusercontent.com/diegorodriguez-hellomatik/termify-tui-public/main}"
BINARY_NAME="termify"

if [ -t 1 ]; then
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  CYAN='\033[36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' YELLOW='' RED='' CYAN='' BOLD='' RESET=''
fi

info()  { printf "  ${CYAN}>${RESET} %s\n" "$*"; }
ok()    { printf "  ${GREEN}✔${RESET} %s\n" "$*"; }
warn()  { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
fatal() { printf "  ${RED}✖${RESET} %s\n" "$*" >&2; exit 1; }

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
    return
  fi
  fatal "Neither curl nor wget is available."
}

detect_asset() {
  os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m 2>/dev/null)

  case "$os" in
    darwin*) os='darwin' ;;
    linux*) fatal "Linux binary is not published yet in the public bootstrap repo." ;;
    msys*|mingw*|cygwin*) fatal "Windows should use PowerShell once a public installer is published." ;;
    *) fatal "Unsupported OS: $os" ;;
  esac

  case "$arch" in
    arm64|aarch64) arch='arm64' ;;
    x86_64|amd64) arch='x64' ;;
    *) fatal "Unsupported architecture: $arch" ;;
  esac

  ASSET_NAME="${BINARY_NAME}-${os}-${arch}.tar.gz"
}

install_binary() {
  tmpdir=$(mktemp -d)
  archive="$tmpdir/$ASSET_NAME"
  asset_url="$RAW_BASE_URL/$ASSET_NAME"

  info "Downloading $ASSET_NAME..."
  download "$asset_url" "$archive" || fatal "Failed to download $asset_url"

  tar -xzf "$archive" -C "$tmpdir" || fatal "Failed to extract $ASSET_NAME"
  [ -f "$tmpdir/$BINARY_NAME" ] || fatal "Archive did not contain $BINARY_NAME"
  chmod +x "$tmpdir/$BINARY_NAME"

  dest=''
  if [ -n "${TERMIFY_BIN_DIR:-}" ]; then
    bindir="$TERMIFY_BIN_DIR"
    mkdir -p "$bindir"
    cp "$tmpdir/$BINARY_NAME" "$bindir/$BINARY_NAME"
    chmod +x "$bindir/$BINARY_NAME"
    dest="$bindir/$BINARY_NAME"
  elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    cp "$tmpdir/$BINARY_NAME" "/usr/local/bin/$BINARY_NAME"
    dest="/usr/local/bin/$BINARY_NAME"
  elif [ -d /usr/local/bin ] && command -v sudo >/dev/null 2>&1; then
    info "Installing to /usr/local/bin (requires sudo)..."
    sudo cp "$tmpdir/$BINARY_NAME" "/usr/local/bin/$BINARY_NAME"
    sudo chmod +x "/usr/local/bin/$BINARY_NAME"
    dest="/usr/local/bin/$BINARY_NAME"
  else
    bindir="$HOME/.local/bin"
    mkdir -p "$bindir"
    cp "$tmpdir/$BINARY_NAME" "$bindir/$BINARY_NAME"
    chmod +x "$bindir/$BINARY_NAME"
    dest="$bindir/$BINARY_NAME"
  fi

  rm -rf "$tmpdir"
  ok "Installed $BINARY_NAME to $dest"
}

main() {
  printf "\n"
  printf "  ${BOLD}${CYAN}Termify TUI Installer${RESET}\n"
  printf "\n"
  detect_asset
  ok "Asset: $ASSET_NAME"
  install_binary
  printf "\n"
  if command -v "$BINARY_NAME" >/dev/null 2>&1; then
    ok "$BINARY_NAME is ready"
  else
    warn "Installation finished, but $BINARY_NAME is not visible in PATH yet."
  fi
  printf "  ${GREEN}${BOLD}Done!${RESET} Run ${CYAN}termify${RESET} to open the TUI.\n"
  printf "\n"
}

main
