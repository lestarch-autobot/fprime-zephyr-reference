#!/bin/sh
# bench.json `dump` of the Pico 2 venue: read the flash back through the debug probe and compare it with the image.
# usage: readback-pico2.sh <probe serial> <image.bin> <readback> <console device>
set -eu
size="$(wc -c < "$2")"
openocd -f interface/cmsis-dap.cfg -c "adapter serial $1" -f target/rp2350.cfg -c "adapter speed 5000" \
    -c "init" -c "halt" -c "dump_image $3 0x10000000 $size" -c "reset run" -c "exit"
if cmp -s "$2" "$3"; then echo "MATCH: flash holds $2 ($size bytes)"; else echo "MISMATCH: flash differs from $2"; exit 1; fi
sleep 1  # the reset drops the USB console; wait for it to leave, then to return
i=0
while [ ! -e "$4" ] && [ $i -lt 100 ]; do sleep 0.2; i=$((i+1)); done
[ -e "$4" ] || { echo "readback-pico2.sh: $4 did not come back after the reset" >&2; exit 1; }
sleep 2
