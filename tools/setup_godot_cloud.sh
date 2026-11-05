#!/usr/bin/env bash
# Instala a Godot 4.3 (a mesma do CI) no ambiente de nuvem do Claude. Seguro rodar de novo.
set -euo pipefail
V="4.3-stable"
DIR="${GODOT_DIR:-/opt/godot}"
if ! command -v godot >/dev/null 2>&1 || ! godot --version 2>/dev/null | grep -q '^4\.3'; then
  mkdir -p "$DIR"
  curl -sSL -o "$DIR/g.zip" "https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_linux.x86_64.zip"
  unzip -q -o "$DIR/g.zip" -d "$DIR" && rm "$DIR/g.zip"
  ln -sf "$DIR/Godot_v${V}_linux.x86_64" /usr/local/bin/godot
fi
godot --version
git lfs pull || true            # assets (fontes, sprites) vêm do Git LFS
godot --headless --path . --import >/dev/null 2>&1 || true   # gera o cache de importação
echo "Pronto. Testes: tools/setup_godot_cloud.sh test | Capturas: tools/setup_godot_cloud.sh shots [pasta]"
case "${1:-}" in
  test) for t in tests/test_*.gd; do echo "== $t"; godot --headless --path . -s "$t" 2>&1 | grep -E "^(FAIL|not ok)|Falhas|OK:" || true; done ;;
  shots) xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capture_scenes.gd -- "${2:-capturas}" ;;
esac
