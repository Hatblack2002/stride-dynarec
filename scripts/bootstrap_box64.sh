#!/usr/bin/env bash
# Stride Dynarec — bootstrap Box64 at the pinned tag v0.4.4.
# Resolves the tag to its literal hash and checks out that exact commit.
set -eu

BOX64_URL="https://github.com/ptitSeb/box64.git"
BOX64_TAG="v0.4.4"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HERE/third_party/box64"

if [ -d "$DEST/.git" ]; then
  echo "box64 already cloned at $DEST"
  cd "$DEST"
  git rev-parse HEAD
else
  mkdir -p "$HERE/third_party"
  git clone "$BOX64_URL" "$DEST"
  cd "$DEST"
fi

git fetch --tags --depth=1 origin "$BOX64_TAG"
BOX64_HASH=$(git rev-parse "$BOX64_TAG")
git checkout "$BOX64_HASH"

echo "=== Box64 pin resolved ==="
echo "tag:    $BOX64_TAG"
echo "hash:   $BOX64_HASH"
echo "url:    $BOX64_URL"
git log -1 --format="date:    %ai%nauthor:  %an <%ae>%nsubject: %s"
