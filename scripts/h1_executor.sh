#!/usr/bin/env bash
# Stride Dynarec — h1_executor.sh
# Executes B0 (Fase 1 build + Fase 3 instrumentation + Fase 4 smoke test).
# Runs on Termux on the S20 FE. No root.
#
# Outputs everything to results/b0_<TS>/ where <TS> is an ISO-ish timestamp.
# Writes verdict.txt with B0_OK or B0_FAIL.
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

# shellcheck source=lib_timing.sh
. "$HERE/scripts/lib_timing.sh"

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$HERE/results/b0_$TS"
mkdir -p "$OUT"

LOG="$OUT/h1_executor.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Stride Dynarec B0 — $TS ==="
echo "host: $(hostname 2>/dev/null || echo n/a)"
echo "user: $(whoami 2>/dev/null || echo n/a)"
echo "pwd:  $HERE"
echo ""

# ---- Condition 0: prerequisites ----------------------------------------
echo "### [0/7] Prerequisites"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "::error::missing required tool: $1"
    echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
    exit 2
  fi
}
require git
require gcc
require make

if ! command -v cmake >/dev/null 2>&1; then
  echo "::error::cmake missing. Install with: pkg install -y cmake"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi

echo "git:    $(git --version)"
echo "gcc:    $(gcc --version | head -1)"
echo "cmake:  $(cmake --version | head -1)"
echo ""

# ---- Capture env snapshot ----------------------------------------------
{
  echo "=== env.txt ==="
  echo "ts_utc=$TS"
  echo "host=$(hostname 2>/dev/null || echo n/a)"
  echo "user=$(whoami 2>/dev/null || echo n/a)"
  echo "pwd=$HERE"
  echo "TERMUX_VERSION=${TERMUX_VERSION:-n/a}"
  echo "PREFIX=${PREFIX:-n/a}"
  echo "git=$(git --version)"
  echo "gcc=$(gcc --version | head -1)"
  echo "cmake=$(cmake --version | head -1)"
  echo "nproc=$(nproc 2>/dev/null)"
  echo "memory:"
  head -3 /proc/meminfo
  echo "battery=$(read_battery)"
  echo "thermal:"
  read_thermal
  echo "cpufreqs:"
  read_cpufreqs
} > "$OUT/env.txt"
echo "env.txt written"

# ---- Condition 1: resolve v0.4.4 to a 40-hex hash ---------------------
echo ""
echo "### [1/7] Resolve Box64 v0.4.4 to a 40-hex hash"

if [ ! -d "$HERE/third_party/box64/.git" ]; then
  echo "Bootstrapping Box64..."
  bash "$HERE/scripts/bootstrap_box64.sh"
fi

cd "$HERE/third_party/box64"
BOX64_TAG="v0.4.4"
BOX64_HASH=$(git rev-parse "$BOX64_TAG")

if ! echo "$BOX64_HASH" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "::error::v0.4.4 did not resolve to 40 hex chars: $BOX64_HASH"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi

if ! git cat-file -e "${BOX64_HASH}^{commit}"; then
  echo "::error::commit $BOX64_HASH does not exist in repo"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi

git checkout "$BOX64_HASH" 2>/dev/null || true
git rev-parse HEAD
git log -1 --format="hash:   %H%ndate:   %ai%nauthor: %an <%ae>%nsubject: %s"
{
  echo "box64_repo=https://github.com/ptitSeb/box64.git"
  echo "box64_tag=$BOX64_TAG"
  echo "box64_hash=$BOX64_HASH"
  git log -1 --format="box64_date=%ai%nbox64_author=%an <%ae>%nbox64_subject=%s"
} > "$OUT/repo.txt"
echo "repo.txt written"
cd "$HERE"
echo ""

# ---- Conditions 2-3: build Box64 --------------------------------------
echo "### [2/7] Build Box64 with the agreed CMake options"

BUILD_DIR="$HERE/third_party/box64/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake .. \
  -DARM64=1 \
  -DCMAKE_C_COMPILER=gcc \
  -DBAD_SIGNAL=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  > "$OUT/cmake.log" 2>&1
echo "cmake exit=$?"

# Use -j2 to respect the 6GB RAM constraint on the S20 FE.
make -j2 >> "$OUT/make.log" 2>&1
echo "make exit=$?"

if [ ! -x "$BUILD_DIR/box64" ]; then
  echo "::error::box64 binary not found or not executable"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi

file "$BUILD_DIR/box64" | tee -a "$LOG"

BOX64_BIN="$BUILD_DIR/box64"
"$BOX64_BIN" --version > "$OUT/box64_version.txt" 2>&1 || {
  echo "::error::box64 --version failed"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
}
echo "box64_version.txt written"
cat "$OUT/box64_version.txt"
cd "$HERE"
echo ""

# ---- Condition 3-4-5: verify coremark_x86_64 -------------------------
echo "### [3/7] Verify coremark_x86_64 is ELF64 x86-64 with no NEEDED"

CM_BIN="$HERE/benchmarks/coremark_x86_64"
CM_SHA="$HERE/benchmarks/coremark_x86_64.sha256"

if [ ! -f "$CM_BIN" ]; then
  echo "::error::BLOQUEO_PRE_B0: $CM_BIN missing. Run the workflow first."
  echo "verdict=BLOQUEO_PRE_B0" > "$OUT/verdict.txt"
  exit 3
fi

CM_HDR=$(readelf -h "$CM_BIN" 2>/dev/null)
if ! echo "$CM_HDR" | grep -qE "Class:.*ELF64"; then
  echo "::error::$CM_BIN is not ELF64"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi
if ! echo "$CM_HDR" | grep -qE "Machine:.*X86-64"; then
  echo "::error::$CM_BIN is not X86-64"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi
if readelf -d "$CM_BIN" 2>/dev/null | grep -q NEEDED; then
  echo "::error::$CM_BIN has NEEDED entries (not static)"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi

readelf -h "$CM_BIN" | grep -E "Class:|Machine:" | tee -a "$LOG"
echo "readelf -d (NEEDED check):"
readelf -d "$CM_BIN" 2>/dev/null | grep NEEDED || echo "(no NEEDED — static OK)"

# ---- Condition 5: SHA-256 matches manifest ----------------------------
echo ""
echo "### [4/7] Verify SHA-256 of coremark_x86_64"

( cd "$HERE/benchmarks" && sha256sum -c coremark_x86_64.sha256 ) > "$OUT/coremark_check.txt" 2>&1
SHA_EXIT=$?
cat "$OUT/coremark_check.txt"
if [ $SHA_EXIT -ne 0 ]; then
  echo "::error::SHA-256 mismatch"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 2
fi
echo ""

# ---- Condition 6: run box64 coremark_x86_64 ---------------------------
echo "### [5/7] Run box64 coremark_x86_64 (no args)"

RUN_LOG="$OUT/b0_run.log"
T0=$(now_ns)
"$BOX64_BIN" "$CM_BIN" > "$RUN_LOG" 2>&1
BOX64_EXIT=$?
T1=$(now_ns)
ELAPSED=$(elapsed_s "$T0" "$T1")

echo "box64_exit=$BOX64_EXIT"
echo "elapsed_s=$ELAPSED"
echo ""
echo "=== b0_run.log (head) ==="
head -40 "$RUN_LOG"
echo ""
echo "=== b0_run.log (tail) ==="
tail -20 "$RUN_LOG"
echo ""

# ---- Conditions 6 and 7: verdict -------------------------------------
echo "### [6/7] Check exit_code == 0"
if [ $BOX64_EXIT -ne 0 ]; then
  echo "::error::box64 coremark_x86_64 exited with $BOX64_EXIT"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 1
fi
echo "OK: exit_code == 0"
echo ""

echo "### [7/7] Check 'Correct operation validated' in b0_run.log"
if ! grep -q "Correct operation validated" "$RUN_LOG"; then
  echo "::error::'Correct operation validated' not found in b0_run.log"
  echo "verdict=B0_FAIL" > "$OUT/verdict.txt"
  exit 1
fi
echo "OK: 'Correct operation validated' found"
echo ""

# ---- Final verdict ---------------------------------------------------
echo "=== ALL 7 CONDITIONS PASSED ==="
{
  echo "verdict=B0_OK"
  echo "ts_utc=$TS"
  echo "box64_hash=$BOX64_HASH"
  echo "box64_tag=$BOX64_TAG"
  echo "box64_exit=$BOX64_EXIT"
  echo "elapsed_s=$ELAPSED"
  echo "binary_sha256=$(cut -d' ' -f1 "$CM_SHA")"
} > "$OUT/verdict.txt"
cat "$OUT/verdict.txt"
