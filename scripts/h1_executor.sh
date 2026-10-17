#!/usr/bin/env bash
# Stride Dynarec — h1_executor.sh
# Executes B0 (build Box64 + verify CoreMark + run smoke test).
# Runs on Termux on the S20 FE. No root.
#
# Output: results/b0_<TS>/
#   env.txt, repo.txt, cmake.log, make.log, box64_version.txt,
#   coremark_check.txt, b0_run.log, h1_executor.log, verdict.txt
#
# verdict.txt states:
#   B0_OK                       — all 7 conditions passed (only the device can produce this)
#   B0_FAIL_prerequisites       — required tool missing
#   B0_FAIL_bootstrap           — bootstrap_box64.sh failed
#   B0_FAIL_resolve_pin         — v0.4.4 did not resolve to a valid commit
#   B0_FAIL_cmake               — cmake step failed
#   B0_FAIL_make                — make step failed
#   B0_FAIL_no_binary           — box64 binary not produced
#   B0_FAIL_box64_version       — box64 --version failed
#   B0_FAIL_readelf             — readelf could not parse coremark_x86_64
#   B0_FAIL_not_elf64           — coremark_x86_64 is not ELF64
#   B0_FAIL_not_x86_64          — coremark_x86_64 is not X86-64
#   B0_FAIL_not_static          — coremark_x86_64 has NEEDED entries
#   B0_FAIL_sha256              — SHA-256 mismatch
#   B0_FAIL_run_exit            — box64 coremark_x86_64 exit_code != 0
#   B0_FAIL_no_validation_str   — 'Correct operation validated' missing from log
#   BLOQUEO_PRE_B0              — coremark_x86_64 binary not present in benchmarks/
#
# Error handling: `set -eu` is retained for unhandled errors. Critical commands
# (cmake, make, sha256sum -c, box64 run, bootstrap) explicitly capture their
# exit codes via `set +e ... set -e` blocks so the script can record the
# failing phase in verdict.txt before exiting. No `|| true` is used to mask
# mandatory operations.

set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

# shellcheck source=lib_timing.sh
. "$HERE/scripts/lib_timing.sh"

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$HERE/results/b0_$TS"
mkdir -p "$OUT"

LOG="$OUT/h1_executor.log"
# Tee all stdout/stderr to the log so every command and its output are preserved.
exec > >(tee -a "$LOG") 2>&1

# ---- Phase tracking and verdict helpers --------------------------------
PHASE="init"
set_phase() {
  PHASE="$1"
  echo ""
  echo "===== PHASE: $PHASE ====="
}

# write_verdict <state>: writes verdict.txt with state, phase, and any
# captured values that exist at the time of the call.
write_verdict() {
  local state="$1"
  {
    echo "verdict=$state"
    [ -n "${PHASE:-}" ] && echo "phase=$PHASE"
    [ -n "${ROUTE:-}" ] && echo "build_route=$ROUTE"
    [ -n "${ENV_ROUTE:-}" ] && echo "detected_env=$ENV_ROUTE"
    echo "ts_utc=$TS"
    [ -n "${BOX64_HASH:-}" ] && echo "box64_hash=$BOX64_HASH"
    [ -n "${BOX64_TAG:-}" ] && echo "box64_tag=$BOX64_TAG"
    [ -n "${CMAKE_EXIT:-}" ] && echo "cmake_exit=$CMAKE_EXIT"
    [ -n "${MAKE_EXIT:-}" ] && echo "make_exit=$MAKE_EXIT"
    [ -n "${VERSION_EXIT:-}" ] && echo "box64_version_exit=$VERSION_EXIT"
    [ -n "${SHA_EXIT:-}" ] && echo "sha256_exit=$SHA_EXIT"
    [ -n "${BOX64_EXIT:-}" ] && echo "box64_run_exit=$BOX64_EXIT"
    [ -n "${ELAPSED:-}" ] && echo "elapsed_s=$ELAPSED"
    [ -n "${CM_SHA256:-}" ] && echo "coremark_sha256=$CM_SHA256"
  } > "$OUT/verdict.txt"
  echo "----- verdict.txt -----"
  cat "$OUT/verdict.txt"
  echo "-----------------------"
}

# fail <state>: write verdict and exit with non-zero.
fail() {
  local state="$1"
  echo "::error::Failing state: $state (phase: ${PHASE:-<none>})"
  write_verdict "$state"
  exit 2
}

echo "=== Stride Dynarec B0 — $TS ==="
echo "host: $(hostname 2>/dev/null || echo n/a)"
echo "user: $(whoami 2>/dev/null || echo n/a)"
echo "pwd:  $HERE"

# ============================================================
# PHASE: prerequisites
# ============================================================
set_phase "prerequisites"

# binary:termux-package
PREREQS=(
  "git:git"
  "gcc:gcc"
  "g++:g++"
  "make:make"
  "cmake:cmake"
  "readelf:binutils"
  "sha256sum:coreutils"
  "file:file"
  "python3:python"
)

MISSING=()
for entry in "${PREREQS[@]}"; do
  bin="${entry%%:*}"
  pkg="${entry##*:}"
  if command -v "$bin" >/dev/null 2>&1; then
    printf "  %-12s OK   %s\n" "$bin" "$(command -v "$bin")"
  else
    printf "  %-12s MISSING  (pkg install -y %s)\n" "$bin" "$pkg"
    MISSING+=("$pkg")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "::error::Missing prerequisites. Install with:"
  echo "  pkg install -y ${MISSING[*]}"
  fail "B0_FAIL_prerequisites"
fi

echo ""
echo "git:       $(git --version)"
echo "gcc:       $(gcc --version | head -1)"
echo "cmake:     $(cmake --version | head -1)"
echo "readelf:   $(readelf --version | head -1)"
echo "sha256sum: $(sha256sum --version | head -1)"

# ---- env snapshot -------------------------------------------------------
{
  echo "ts_utc=$TS"
  echo "host=$(hostname 2>/dev/null || echo n/a)"
  echo "user=$(whoami 2>/dev/null || echo n/a)"
  echo "pwd=$HERE"
  echo "TERMUX_VERSION=${TERMUX_VERSION:-n/a}"
  echo "PREFIX=${PREFIX:-n/a}"
  echo "STRIDE_FORCE_ROUTE=${STRIDE_FORCE_ROUTE:-n/a}"
  echo "git=$(git --version)"
  echo "gcc=$(gcc --version | head -1)"
  echo "cmake=$(cmake --version | head -1)"
  echo "readelf=$(readelf --version | head -1)"
  echo "sha256sum=$(sha256sum --version | head -1)"
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

# ============================================================
# PHASE: resolve v0.4.4
# ============================================================
set_phase "resolve_v0.4.4"

if [ ! -d "$HERE/third_party/box64/.git" ]; then
  echo "Bootstrapping Box64..."
  # bootstrap_box64.sh uses set -eu internally; capture its exit code so a
  # bootstrap failure is recorded as a verdict instead of aborting silently.
  set +e
  bash "$HERE/scripts/bootstrap_box64.sh"
  BOOTSTRAP_EXIT=$?
  set -e
  if [ $BOOTSTRAP_EXIT -ne 0 ]; then
    echo "::error::bootstrap_box64.sh failed (exit $BOOTSTRAP_EXIT)"
    fail "B0_FAIL_bootstrap"
  fi
fi

cd "$HERE/third_party/box64"
BOX64_TAG="v0.4.4"

# git rev-parse: capture combined stdout+stderr so the error message is in
# the log even on failure.
set +e
BOX64_HASH=$(git rev-parse "$BOX64_TAG" 2>&1)
REV_PARSE_EXIT=$?
set -e
if [ $REV_PARSE_EXIT -ne 0 ]; then
  echo "::error::git rev-parse $BOX64_TAG failed (exit $REV_PARSE_EXIT)"
  echo "output: $BOX64_HASH"
  fail "B0_FAIL_resolve_pin"
fi

if ! echo "$BOX64_HASH" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "::error::v0.4.4 did not resolve to 40 hex chars: $BOX64_HASH"
  fail "B0_FAIL_resolve_pin"
fi

# git cat-file -e is mandatory. Do not mask its exit code.
if ! git cat-file -e "${BOX64_HASH}^{commit}" 2>&1; then
  echo "::error::git cat-file -e reports commit $BOX64_HASH does not exist"
  fail "B0_FAIL_resolve_pin"
fi

# git checkout is mandatory. Capture combined output, fail explicitly on error.
set +e
CHECKOUT_OUT=$(git checkout "$BOX64_HASH" 2>&1)
CHECKOUT_EXIT=$?
set -e
if [ $CHECKOUT_EXIT -ne 0 ]; then
  echo "::error::git checkout $BOX64_HASH failed (exit $CHECKOUT_EXIT)"
  echo "output: $CHECKOUT_OUT"
  fail "B0_FAIL_resolve_pin"
fi
echo "$CHECKOUT_OUT"

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

# ============================================================
# PHASE: build Box64
# ============================================================
set_phase "build_box64"

# Detect the execution environment and select the appropriate CMake route.
#
# docs/COMPILE.md of Box64 v0.4.4 documents two routes for Android devices:
#
#   Ruta A (CHRoot/PRoot Linux ARM64):
#     -DARM64=1 -DCMAKE_C_COMPILER=gcc -DBAD_SIGNAL=ON
#     Requires a real Linux ARM64 filesystem (glibc, full POSIX headers).
#     Works inside proot-distro ubuntu/debian, or in a real ARM64 Linux box.
#     Produces a binary linked against glibc that runs Linux x86-64 binaries.
#
#   Ruta B (Termux nativo):
#     -DTERMUX=1 -DCMAKE_C_COMPILER=clang
#     Compiles against bionic libc with libandroid-sysv-semaphore and
#     libandroid-spawn. The official doc warns: "Box64 in native termux is
#     experimental and won't run linux binaries!"
#
# The previous version of this script always used Ruta A flags, which fails
# in Termux nativo because gcc there links against bionic and the glibc
# headers are missing. We now detect the environment explicitly:
#
#   - TERMUX_VERSION set OR PREFIX contains com.termux  -> Ruta B (Termux)
#   - /etc/debian_version or /etc/redhat-release present -> Ruta A (CHRoot)
#   - otherwise -> Ruta A (default, may fail; the user can override via
#     environment variable STRIDE_FORCE_ROUTE=A|B)

ENV_ROUTE="unknown"

if [ -n "${STRIDE_FORCE_ROUTE:-}" ]; then
  ENV_ROUTE="forced-$STRIDE_FORCE_ROUTE"
  ROUTE="$STRIDE_FORCE_ROUTE"
elif [ -n "${TERMUX_VERSION:-}" ] || \
     ( [ -n "${PREFIX:-}" ] && echo "$PREFIX" | grep -q "com.termux" ); then
  ENV_ROUTE="termux-native"
  ROUTE="B"
elif [ -f /etc/debian_version ] || [ -f /etc/redhat-release ] || [ -f /etc/arch-release ]; then
  ENV_ROUTE="linux-chroot"
  ROUTE="A"
else
  ENV_ROUTE="unknown"
  ROUTE="A"
fi

echo "=== Environment detection ==="
echo "TERMUX_VERSION: ${TERMUX_VERSION:-n/a}"
echo "PREFIX:         ${PREFIX:-n/a}"
echo "STRIDE_FORCE_ROUTE: ${STRIDE_FORCE_ROUTE:-n/a}"
echo "detected_env:   $ENV_ROUTE"
echo "selected_route: $ROUTE"
echo ""

if [ "$ROUTE" = "B" ]; then
  # Ruta B — Termux nativo. Requires clang and Android-specific packages.
  echo "=== Ruta B prerequisites (Termux native) ==="
  for pkg in libandroid-sysv-semaphore libandroid-spawn; do
    # pkg list-installed returns 0 even if grep finds nothing, so we check the line.
    if ! pkg list-installed 2>/dev/null | grep -q "^${pkg}/"; then
      echo "::error::Missing Termux package: $pkg"
      echo "  Install with: pkg install -y $pkg"
      fail "B0_FAIL_prerequisites"
    fi
    echo "  OK: $pkg installed"
  done
  CMAKE_C_COMPILER="clang"
  CMAKE_FLAGS=(
    -DTERMUX=1
    -DCMAKE_C_COMPILER="$CMAKE_C_COMPILER"
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
  )
  echo "=== CMake configuration: Ruta B (Termux native) ==="
  printf "  %s\n" "${CMAKE_FLAGS[@]}"
else
  # Ruta A — CHRoot/PRoot Linux ARM64. Requires gcc and glibc.
  CMAKE_C_COMPILER="gcc"
  CMAKE_FLAGS=(
    -DARM64=1
    -DCMAKE_C_COMPILER="$CMAKE_C_COMPILER"
    -DBAD_SIGNAL=ON
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
  )
  echo "=== CMake configuration: Ruta A (CHRoot/PRoot Linux ARM64) ==="
  printf "  %s\n" "${CMAKE_FLAGS[@]}"
fi
echo ""

BUILD_DIR="$HERE/third_party/box64/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# cmake: explicit capture. set -e is disabled around the call so a failure
# falls through to the if-block instead of terminating the script.
set +e
cmake .. "${CMAKE_FLAGS[@]}" > "$OUT/cmake.log" 2>&1
CMAKE_EXIT=$?
set -e
echo "cmake exit=$CMAKE_EXIT"

if [ $CMAKE_EXIT -ne 0 ]; then
  echo "::error::cmake failed (exit $CMAKE_EXIT). Last 30 lines of cmake.log:"
  tail -30 "$OUT/cmake.log"
  fail "B0_FAIL_cmake"
fi

# make: explicit capture. -j2 respects the 6GB RAM constraint on the S20 FE.
set +e
make -j2 >> "$OUT/make.log" 2>&1
MAKE_EXIT=$?
set -e
echo "make exit=$MAKE_EXIT"

if [ $MAKE_EXIT -ne 0 ]; then
  echo "::error::make failed (exit $MAKE_EXIT). Last 30 lines of make.log:"
  tail -30 "$OUT/make.log"
  fail "B0_FAIL_make"
fi

if [ ! -x "$BUILD_DIR/box64" ]; then
  echo "::error::box64 binary not found or not executable at $BUILD_DIR/box64"
  ls -la "$BUILD_DIR/" | head -20
  fail "B0_FAIL_no_binary"
fi

file "$BUILD_DIR/box64"

BOX64_BIN="$BUILD_DIR/box64"

# box64 --version: explicit capture.
set +e
"$BOX64_BIN" --version > "$OUT/box64_version.txt" 2>&1
VERSION_EXIT=$?
set -e
echo "box64 --version exit=$VERSION_EXIT"

if [ $VERSION_EXIT -ne 0 ]; then
  echo "::error::box64 --version failed (exit $VERSION_EXIT)"
  echo "----- box64_version.txt -----"
  cat "$OUT/box64_version.txt"
  fail "B0_FAIL_box64_version"
fi

echo "box64_version.txt written"
cat "$OUT/box64_version.txt"
cd "$HERE"

# ============================================================
# PHASE: verify coremark_x86_64 ELF/NEEDED
# ============================================================
set_phase "verify_coremark_elf"

CM_BIN="$HERE/benchmarks/coremark_x86_64"
CM_SHA="$HERE/benchmarks/coremark_x86_64.sha256"

if [ ! -f "$CM_BIN" ]; then
  echo "::error::BLOQUEO_PRE_B0: $CM_BIN missing."
  echo "Run the workflow .github/workflows/build-coremark-x86_64.yml and"
  echo "place the artifact files in benchmarks/."
  write_verdict "BLOQUEO_PRE_B0"
  exit 3
fi

# readelf: capture output. If readelf fails (non-ELF, permission, etc.),
# CM_HDR will be empty and we fail explicitly.
CM_HDR=$(readelf -h "$CM_BIN" 2>/dev/null)
if [ -z "$CM_HDR" ]; then
  echo "::error::readelf -h $CM_BIN produced no output (not ELF or readelf failed)"
  fail "B0_FAIL_readelf"
fi

if ! echo "$CM_HDR" | grep -qE "Class:.*ELF64"; then
  echo "::error::$CM_BIN is not ELF64"
  echo "$CM_HDR" | grep -E "Class:|Machine:"
  fail "B0_FAIL_not_elf64"
fi

if ! echo "$CM_HDR" | grep -qE "Machine:.*X86-64"; then
  echo "::error::$CM_BIN is not X86-64"
  echo "$CM_HDR" | grep -E "Class:|Machine:"
  fail "B0_FAIL_not_x86_64"
fi

# NEEDED check: readelf -d may return non-zero on static binaries (no dynamic
# section). The grep -q NEEDED is the actual check; if no NEEDED lines are
# found, the binary is static. Wrap in a subshell so the non-zero exit of
# readelf on static binaries does not propagate.
if ( readelf -d "$CM_BIN" 2>/dev/null | grep -q NEEDED ); then
  echo "::error::$CM_BIN has NEEDED entries (not static)"
  readelf -d "$CM_BIN" 2>/dev/null | grep NEEDED
  fail "B0_FAIL_not_static"
fi

echo "readelf -h $CM_BIN:"
echo "$CM_HDR" | grep -E "Class:|Machine:"
echo "readelf -d (NEEDED check): (no NEEDED — static OK)"

# ============================================================
# PHASE: SHA-256 verification
# ============================================================
set_phase "sha256_verify"

# sha256sum -c: explicit capture. The subshell isolates the working directory.
set +e
( cd "$HERE/benchmarks" && sha256sum -c coremark_x86_64.sha256 ) > "$OUT/coremark_check.txt" 2>&1
SHA_EXIT=$?
set -e
echo "sha256sum -c exit=$SHA_EXIT"
echo "----- coremark_check.txt -----"
cat "$OUT/coremark_check.txt"

if [ $SHA_EXIT -ne 0 ]; then
  echo "::error::SHA-256 mismatch (exit $SHA_EXIT)"
  fail "B0_FAIL_sha256"
fi

CM_SHA256=$(cut -d' ' -f1 "$CM_SHA")

# ============================================================
# PHASE: run box64 coremark_x86_64
# ============================================================
set_phase "run_box64_coremark"

RUN_LOG="$OUT/b0_run.log"
echo "Running: $BOX64_BIN $CM_BIN (no args)"
echo "  log -> $RUN_LOG"

# box64 coremark: explicit capture of exit code and timing.
T0=$(now_ns)
set +e
"$BOX64_BIN" "$CM_BIN" > "$RUN_LOG" 2>&1
BOX64_EXIT=$?
set -e
T1=$(now_ns)
ELAPSED=$(elapsed_s "$T0" "$T1")

echo "box64_exit=$BOX64_EXIT"
echo "elapsed_s=$ELAPSED"
echo ""
echo "----- b0_run.log (head, 40 lines) -----"
head -40 "$RUN_LOG"
echo ""
echo "----- b0_run.log (tail, 20 lines) -----"
tail -20 "$RUN_LOG"

# ============================================================
# PHASE: verdict
# ============================================================
set_phase "verdict"

# Condition 6: exit_code == 0
if [ $BOX64_EXIT -ne 0 ]; then
  echo "::error::box64 coremark_x86_64 exited with $BOX64_EXIT (condition 6 failed)"
  fail "B0_FAIL_run_exit"
fi
echo "OK: condition 6 — exit_code == 0"

# Condition 7: 'Correct operation validated' in b0_run.log
if ! grep -q "Correct operation validated" "$RUN_LOG"; then
  echo "::error::'Correct operation validated' not found in b0_run.log (condition 7 failed)"
  fail "B0_FAIL_no_validation_str"
fi
echo "OK: condition 7 — 'Correct operation validated' found"

echo ""
echo "=== ALL 7 CONDITIONS PASSED ==="
write_verdict "B0_OK"
exit 0
