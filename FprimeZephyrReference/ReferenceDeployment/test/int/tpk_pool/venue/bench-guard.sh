#!/bin/sh
# Shared-bench guard of the Pico 2 venue. The bench host also runs a GitHub Actions runner (user
# `fprime`) whose jobs flash the same board; `fuser` does not see that. Run `pre` immediately before
# `fth run` and `post` immediately after it; a run whose guard trips is bench-invalid.
# usage: bench-guard.sh pre  <state file> <console device>
#        bench-guard.sh post <state file> <console device> [own re-enumerations, default 2]
# Every line the guard prints is also appended, with the UTC time, to <state file>.out: keep it beside the run.
# The run itself re-enumerates the console twice: the reset after the flash and after the read-back.
set -u
mode=$1; state=$2; dev=$3; own=${4:-2}
diag=/home/fprime/actions-runner/_diag
worker() { pgrep -u fprime -f Runner.Worker >/dev/null; }
# newest Worker_* log; fails when the directory cannot be listed or holds no such log (no silent pass)
newest() { l=$(sudo -n ls -t "$diag") || return 1; l=$(printf '%s\n' "$l" | grep '^Worker_' | head -1); [ -n "$l" ] && echo "$l"; }
say() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$state.out"; echo "$*"; }
usbpath() { udevadm info -q property "$dev" | sed -n 's|^DEVPATH=.*/\([0-9][0-9.-]*\):[0-9.]*/tty/.*|\1|p'; }
case $mode in
pre)
  worker && { say "GUARD TRIPPED (pre): a Runner.Worker process is running"; exit 9; }
  n=$(newest) || { say "GUARD TRIPPED (pre): cannot list $diag or no Worker_ log in it"; exit 9; }
  p=$(usbpath); [ -n "$p" ] || { say "GUARD TRIPPED (pre): no USB path for $dev"; exit 9; }
  printf '%s\n%s\n%s\n' "$n" "$p" "$(cut -d' ' -f1 /proc/uptime)" > "$state"
  say "GUARD pre: no worker; newest worker log $n; console on usb $p";;
post)
  { read -r n0; read -r p; read -r t0; } < "$state"
  rc=0
  worker && { say "GUARD TRIPPED (post): a Runner.Worker process is running"; rc=9; }
  n=$(newest) || { say "GUARD TRIPPED (post): cannot list $diag or no Worker_ log in it"; rc=9; }
  [ "$n" = "$n0" ] || { say "GUARD TRIPPED (post): newest worker log $n0 -> $n"; rc=9; }
  c=$(dmesg | awk -v t0="$t0" -v p="usb $p: USB disconnect" '{ts=$0; sub(/^\[ */,"",ts); sub(/\].*/,"",ts)} ts+0>t0+0 && index($0,p) {k++} END {print k+0}')
  [ "$c" -eq "$own" ] || { say "GUARD TRIPPED (post): $c re-enumerations of usb $p during the run, own $own"; rc=9; }
  [ $rc -eq 0 ] && say "GUARD post: ok (no worker; newest worker log $n; $c re-enumerations, all own)"
  exit $rc;;
esac
