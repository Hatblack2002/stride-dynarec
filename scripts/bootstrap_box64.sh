#!/usr/bin/env bash
# Bootstrap: clone Box64 at the pinned commit used by Stride Dynarec.
set -eu

BOX64_URL="https://github.com/ptitSeb/box64.git"
BOX64_COMMIT="27860e6aee72dd33c2588d081652d6e9becc1089"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HERE/third_party/box64"

if [ -d "$DEST/.git" ]; then
  echo "box64 already cloned at $DEST"
  cd "$DEST" && git rev-parse HEAD
  exit 0
fi

mkdir -p "$HERE/third_party"
git clone "$BOX64_URL" "$DEST"
cd "$DEST"
git checkout "$BOX64_COMMIT"
git log -1 --format="commit: %H%nauthor:  %an <%ae>%ndate:    %ai%nsubject: %s"
