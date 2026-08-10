#!/bin/bash
# Installe le SDK Flutter (et le Dart embarque) pour les sessions
# Claude Code sur le web, puis recupere les dependances de MemoTack.
#
# Ce hook est volontairement tolerant : il ne doit jamais empecher une
# session de demarrer, donc il se termine toujours avec le code 0 et
# affiche des diagnostics plutot que d'echouer.

set -uo pipefail

# Sur une machine locale, Flutter est deja installe par l'utilisateur.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_ROOT="${FLUTTER_ROOT:-/opt/flutter}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Git doit accepter les depots appartenant a root (dont /opt/flutter).
git config --global --add safe.directory '*' || true

# Flutter stable, clone superficiel (rapide).
if [ ! -d "$FLUTTER_ROOT" ]; then
  echo "Clonage de Flutter (stable) dans $FLUTTER_ROOT..."
  if ! git clone --depth 1 -b stable \
      https://github.com/flutter/flutter.git "$FLUTTER_ROOT"; then
    echo "ERREUR : le clone de Flutter a echoue." >&2
    exit 0
  fi
else
  echo "Flutter est deja present dans $FLUTTER_ROOT."
fi

# Rendre flutter/dart accessibles a toutes les sessions.
ln -sf "$FLUTTER_ROOT/bin/flutter" /usr/local/bin/flutter || true
ln -sf "$FLUTTER_ROOT/bin/dart"    /usr/local/bin/dart    || true

export PATH="$FLUTTER_ROOT/bin:$PATH"

# Filet de securite si /usr/local/bin n'est pas inscriptible.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_ROOT/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Premier appel : telecharge le SDK Dart embarque.
if ! flutter --version; then
  echo "ERREUR : Flutter est installe mais ne demarre pas." >&2
  exit 0
fi

flutter config --no-analytics || true
flutter precache --no-android --no-ios --universal || true

# Dependances du projet (pubspec.yaml) : l'etat du conteneur est mis en
# cache apres le hook, donc flutter analyze / flutter test demarrent vite.
if [ -f "$PROJECT_DIR/pubspec.yaml" ]; then
  if ! (cd "$PROJECT_DIR" && flutter pub get); then
    echo "ERREUR : flutter pub get a echoue." >&2
  fi
fi

exit 0
