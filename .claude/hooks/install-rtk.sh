#!/bin/sh
# SessionStart: instala o rtk (https://github.com/rtk-ai/rtk) se ainda não existir.
# Versão fixada porque, na nuvem, o github.com bloqueia a consulta "latest" (403)
# mas libera o download de releases por tag. O instalador oficial confere o SHA-256.
RTK_VERSION="${RTK_VERSION:-v1.2.0}"
export RTK_VERSION
BIN="$HOME/.local/bin"
if [ -x "$BIN/rtk" ] || command -v rtk >/dev/null 2>&1; then exit 0; fi
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh >&2 \
  || echo "rtk: instalação falhou, seguindo sem rtk" >&2
# Deixa o rtk no PATH das próximas chamadas de Bash da sessão
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export PATH=\"$BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
exit 0
