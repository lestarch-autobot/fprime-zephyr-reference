#!/bin/sh
# Put a saved image back on the Pico 2 under the shared-bench guard, with read-back, from the campaign root on the
# bench host. usage: restore-pico2.sh <saved image> [probe serial]
# The image the board held before this campaign's first flash: /home/devin/tpk-campaign/saved/pico2-before.bin
# on pi-ci-1 (4194304 bytes from 0x10000000, sha256 269aed1a1f73a4a0e14db43b18d430a658159e036e0615ed8893ee79b31c266a).
set -u
T=uut/FprimeZephyrReference/ReferenceDeployment/test/int/tpk_pool
img=${1:?usage: restore-pico2.sh <saved image> [probe serial]}; serial=${2:-E6647C74036F8730}
mkdir -p restore
fuser /dev/pico2 /dev/pico2-probe && { echo "bench held, stop"; exit 9; }
$T/venue/bench-guard.sh pre restore/restore.guard /dev/pico2 || exit 9
$T/venue/flash-pico2.sh $serial "$img" /dev/pico2 > restore/flash.log 2>&1 || { echo "flash failed, see restore/flash.log"; exit 1; }
$T/venue/readback-pico2.sh $serial "$img" restore/readback.bin /dev/pico2 > restore/readback.log 2>&1; rc=$?
grep -a "MATCH" restore/readback.log
sha256sum "$img" restore/readback.bin
$T/venue/bench-guard.sh post restore/restore.guard /dev/pico2 || exit 8   # 2 own re-enumerations: flash reset, read-back reset
exit $rc
