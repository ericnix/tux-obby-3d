#!/usr/bin/env bash
# Gera um AppImage x86_64 a partir do binário Linux exportado pelo Godot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${1:-$ROOT/build/tux-obby.x86_64}"
OUT="${2:-$ROOT/build/Tux_Obby_3D-x86_64.AppImage}"
APPDIR="$ROOT/build/TuxObby3D.AppDir"
TOOL="${APPIMAGETOOL:-$ROOT/build/appimagetool-x86_64.AppImage}"
TOOL_DIR="$ROOT/build/appimagetool"

if [[ ! -x "$BIN" ]]; then
  echo "Binário não encontrado: $BIN" >&2
  echo "Exporte antes com: godot --headless --path . --export-release \"Linux\" build/tux-obby.x86_64" >&2
  exit 1
fi

if [[ ! -x "$TOOL" ]]; then
  echo "appimagetool não encontrado em $TOOL" >&2
  echo "Baixe em https://github.com/AppImage/AppImageKit/releases/tag/continuous" >&2
  exit 1
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp "$BIN" "$APPDIR/usr/bin/tux-obby"
chmod +x "$APPDIR/usr/bin/tux-obby"
cp "$ROOT/packaging/appimage/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"
cp "$ROOT/packaging/appimage/tux-obby.desktop" "$APPDIR/tux-obby.desktop"
cp "$ROOT/packaging/appimage/tux-obby.png" "$APPDIR/tux-obby.png"
cp "$ROOT/packaging/appimage/tux-obby.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/tux-obby.png"

# appimagetool pode exigir FUSE; extrair e executar o AppRun evita essa dependência.
if [[ ! -x "$TOOL_DIR/squashfs-root/AppRun" ]]; then
  rm -rf "$TOOL_DIR"
  mkdir -p "$TOOL_DIR"
  (cd "$TOOL_DIR" && "$TOOL" --appimage-extract >/dev/null)
fi

ARCH=x86_64 "$TOOL_DIR/squashfs-root/AppRun" --no-appstream "$APPDIR" "$OUT"
chmod +x "$OUT"
echo "AppImage criado: $OUT"
