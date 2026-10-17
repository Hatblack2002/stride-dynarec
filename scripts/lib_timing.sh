#!/usr/bin/env bash
# Stride Dynarec — timing and sensor helpers sourced by other scripts.
# Does not execute anything on its own. Source from another script.

# Monotonic nanoseconds since epoch. No external deps.
now_ns() {
  python3 -c 'import time; print(int(time.monotonic_ns()))' 2>/dev/null \
    || date +%s%N
}

# Duration in seconds (float) between two nanosecond timestamps.
elapsed_s() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.6f", (b - a) / 1e9 }'
}

# UTC ISO 8601 timestamp for log lines.
iso_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Best-effort thermal reading without root.
# Reads /sys/class/thermal/thermal_zone*/temp and prints "<type>:<temp_mC>" per zone.
# Returns 0 even if no zones are readable (caller treats as unavailable).
read_thermal() {
  local z t
  for z in /sys/class/thermal/thermal_zone*; do
    [ -r "$z/temp" ] || continue
    [ -r "$z/type" ] || continue
    t=$(cat "$z/type" 2>/dev/null | tr -d '\n')
    printf "%s:%s\n" "$t" "$(cat "$z/temp" 2>/dev/null)"
  done
  return 0
}

# Best-effort battery level without root.
# Uses termux-battery-status if available, else prints "n/a".
read_battery() {
  if command -v termux-battery-status >/dev/null 2>&1; then
    termux-battery-status 2>/dev/null \
      | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"{d.get(\"percentage\",\"n/a\")}%")' 2>/dev/null \
      || echo "n/a"
  else
    echo "n/a"
  fi
}

# Current CPU frequency per core, in kHz. Empty if not readable (no root).
read_cpufreqs() {
  local c
  for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [ -r "$c" ] || continue
    printf "%s:%s\n" "$(echo "$c" | grep -oE 'cpu[0-9]+')" "$(cat "$c" 2>/dev/null)"
  done
  return 0
}
