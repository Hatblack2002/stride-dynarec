#!/data/data/com.termux/files/usr/bin/bash
# Stride Dynarec — device profile probe. Run inside Termux. No root.
set -u

echo "===== STRIDE_DYNAREC_DEVICE_PROFILE_PROBE ====="
echo "[fecha_utc]        $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[fecha_local]      $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "[host]             $(hostname 2>/dev/null || echo n/a)"
echo "[whoami]           $(whoami 2>/dev/null || echo n/a)"
echo

echo "----- 1. Modelo y variante -----"
for p in ro.product.model ro.product.name ro.product.device ro.product.brand \
        ro.boot.hwc_model ro.boot.hwc_platform ro.hardware ro.boot.hardware \
        ro.vendor.product.device ro.vendor.product.name; do
  printf "  %-28s = %s\n" "$p" "$(getprop "$p" 2>/dev/null)"
done
echo

echo "----- 2. SoC -----"
for p in ro.soc.manufacturer ro.soc.model ro.board.platform \
        ro.vendor.qti.soc_name ro.vendor.qti.soc_model; do
  printf "  %-28s = %s\n" "$p" "$(getprop "$p" 2>/dev/null)"
done
echo

echo "----- 3. Android -----"
for p in ro.build.version.release ro.build.version.sdk ro.build.id \
        ro.product.cpu.abilist ro.build.fingerprint; do
  printf "  %-28s = %s\n" "$p" "$(getprop "$p" 2>/dev/null)"
done
echo

echo "----- 4. Memoria -----"
head -3 /proc/meminfo
echo

echo "----- 5. Almacenamiento -----"
df -h "$HOME" 2>/dev/null || df -h /data/data/com.termux 2>/dev/null
df -h /data 2>/dev/null
echo

echo "----- 6. CPU -----"
echo "nproc = $(nproc 2>/dev/null)"
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq; do
  [ -r "$c" ] && { freq=$(cat "$c"); printf "  %-50s = %s (%s MHz)\n" "$c" "$freq" "$((freq/1000))"; }
done 2>/dev/null
echo

echo "----- 7. GPU / GLES -----"
dumpsys SurfaceFlinger 2>/dev/null | grep -E "GLES|GL_VERSION|GL_RENDERER|Vendor|Renderer" | head -8 || echo "  (no dumpsys)"
echo

echo "----- 8. Termux -----"
echo "TERMUX_VERSION = ${TERMUX_VERSION:-n/a}"
echo "PREFIX         = ${PREFIX:-n/a}"
command -v termux-info >/dev/null 2>&1 && termux-info 2>/dev/null | head -30 || echo "(no termux-info)"
echo

echo "----- 9. Toolchain -----"
for t in clang clang++ gcc g++ make cmake git curl wget pkg-config python; do
  command -v "$t" >/dev/null 2>&1 && printf "  %-14s OK   %s\n" "$t" "$(command -v $t)" || printf "  %-14s NO\n" "$t"
done
echo

echo "----- 10. Versiones -----"
clang   --version 2>/dev/null | head -1 || true
clang++ --version 2>/dev/null | head -1 || true
gcc     --version 2>/dev/null | head -1 || true
cmake   --version 2>/dev/null | head -1 || true
git     --version 2>/dev/null || true
pkg-config --version 2>/dev/null || true
echo

echo "----- 11. Paquetes Termux -----"
pkg list-installed 2>/dev/null | grep -E "^(clang|cmake|make|git|libandroid-sysv-semaphore|libandroid-spawn|proot|proot-distro|zlib|pkg-config)/" || echo "(n/a)"
echo

echo "----- 12. Box64 instalado -----"
command -v box64 >/dev/null 2>&1 && { echo "box64: $(command -v box64)"; box64 --version 2>&1 | head -5; } || echo "(no box64 en PATH)"
echo

echo "----- 13. Root -----"
command -v su >/dev/null 2>&1 && echo "su presente" || echo "sin su (consistente con no-root)"
id 2>/dev/null
echo

echo "----- 14. Sensores térmicos -----"
ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -5 || echo "(no accesibles)"
for z in /sys/class/thermal/thermal_zone*/type; do
  [ -r "$z" ] && printf "  %s = %s\n" "$z" "$(cat "$z" 2>/dev/null)"
done 2>/dev/null | head -10
echo

echo "===== END ====="
