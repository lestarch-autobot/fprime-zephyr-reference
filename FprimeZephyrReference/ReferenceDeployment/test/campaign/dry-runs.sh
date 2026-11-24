#!/bin/sh
# Venue B (Pico 2) full cycle, run from the campaign root on the bench host: clean run and 4 planted runs, each
# under the shared-bench guard (at most 3 attempts), audit, replay, vector set, vector rule.
# The planted fault -> run id mapping lives only here. usage: dry-runs.sh [all | run <n> [plant] | check <n>]
T=zref/FprimeZephyrReference/ReferenceDeployment/test/int/tpk_pool
A="--manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T"
n=${2:-}
case ${1:-all} in
run)
  fuser /dev/pico2 /dev/pico2-probe && { echo "bench held, stop"; exit 9; }
  $T/venue/bench-guard.sh pre runs/dry-$n.guard /dev/pico2 || exit 9
  rm -f /tmp/fth-tpk-pool-*
  fth run --unsealed ${3:+--plant $3} --run-dir runs/dry-$n $A > runs/dry-$n.log 2>&1
  echo "dry-$n rc=$?" >> runs/dry-$n.log
  tail -2 runs/dry-$n.log | cut -c1-200
  fuser /dev/pico2 /dev/pico2-probe; echo "fuser-after-rc=$?"
  $T/venue/bench-guard.sh post runs/dry-$n.guard /dev/pico2 || exit 8;;   # both guard lines: runs/dry-$n.guard.out
check)
  python3 -c "
import json;v=json.load(open('runs/dry-$n/runner/verdicts.json'))
for k,t in v['tests'].items(): print(' ',k,t['verdict'],t['failed'])"
  fth audit --unsealed --run-dir runs/dry-$n $A > runs/dry-$n.audit.log 2>&1
  echo "  audit rc=$? FAILED-lines=$(grep -c FAILED runs/dry-$n.audit.log) DIVERGENCE=$(grep -ci divergence runs/dry-$n.audit.log)"
  rm -rf runs/dry-$n-replay
  fth run --replay-record runs/dry-$n/record --run-dir runs/dry-$n-replay $A > runs/dry-$n.replay.log 2>&1
  python3 - <<P
import json
a=json.load(open('runs/dry-$n/runner/verdicts.json'))['tests'];b=json.load(open('runs/dry-$n-replay/runner/verdicts.json'))['tests']
print('  replay', 'equal' if a.keys()==b.keys() and all((a[k]['verdict'],a[k]['failed'])==(b[k]['verdict'],b[k]['failed']) for k in a) else 'DIFFER')
P
;;
all)
  for p in 1: 2:L2-1=first_packet_also_held 3:L2-2=second_packet_also_held 4:L6-1=known_packet_requested 5:L7-1=final_packets_held; do
    n=${p%%:*}; f=${p#*:}; a=1
    while :; do
      while pgrep -u fprime -f Runner.Worker >/dev/null; do sleep 20; done
      sh "$0" run $n $f; rc=$?
      [ $rc -eq 0 ] && break
      echo "dry-$n attempt $a bench-invalid rc=$rc"; mkdir -p runs/invalid   # the record is kept
      for x in runs/dry-$n runs/dry-$n.log runs/dry-$n.guard runs/dry-$n.guard.out; do [ -e $x ] && mv $x runs/invalid/$(basename $x).attempt$a; done
      a=$((a+1)); [ $a -gt 3 ] && { echo "dry-$n: 3 attempts, STOP"; exit 1; }
    done
    sh "$0" check $n
    grep -a -h "MATCH" runs/dry-$n/record/raw/flash.log | cut -c1-100
  done
  rm -rf vectors && python3 $T/../../campaign/mk-vectors.py runs $T vectors "venue B (Pico 2), fth run --unsealed, zephyr harness $(git -C zref rev-parse --short HEAD)" && cp manifest.json vectors/
  python3 $T/venue/check-vectors.py vectors; echo "vector rule rc=$?";;
esac
