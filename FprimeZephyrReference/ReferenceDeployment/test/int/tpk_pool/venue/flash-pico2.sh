#!/bin/sh
# bench.json `flash` of the Pico 2 venue: program the image through the debug probe, verify, reset,
# then wait until the board's USB console is back.
# usage: flash-pico2.sh <probe serial> <image.bin> <console device>
set -eu
openocd -f interface/cmsis-dap.cfg -c "adapter serial $1" -f target/rp2350.cfg -c "adapter speed 5000" \
    -c "program $2 0x10000000 verify reset exit"
sleep 1  # the reset drops the USB console; wait for it to leave, then to return
i=0
while [ ! -e "$3" ] && [ $i -lt 100 ]; do sleep 0.2; i=$((i+1)); done
[ -e "$3" ] || { echo "flash-pico2.sh: $3 did not come back after the reset" >&2; exit 1; }
sleep 2
echo "console $3 present"
