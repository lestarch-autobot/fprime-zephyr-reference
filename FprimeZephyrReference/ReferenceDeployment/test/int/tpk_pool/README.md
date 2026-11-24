# TPK-POOL system tests (Svc.TlmPacketizer membership pool)

External stimulus of the approved plan `plan.json` (rendered: `plan.md`). The unit under test is not
changed by anything here. Tooling: `fprime-testing-harness` v0.1.29 (`fth`), `fprime-gds`.

| file | what |
|---|---|
| `plan.json`, `plan.md` | the approved plan and its rendering (`fth render-plan plan.json -o plan.md`) |
| `planted_faults.py`, `faults-menu.json` | plan helper and planted faults; the menu is generated (`fth planted-faults-menu plan.json`) |
| `test_L*.py` | one stimulus file per plan test |
| `bench-pico2.json`, `venue/` | venue B: Raspberry Pi Pico 2 on a bench host, console on USB, debug probe with OpenOCD; scripts that flash and read back the image |
| `../../kat/` | known-answer tests of the plan helper (`pytest test/kat`) |

## Layout of a campaign root

All paths in `bench-*.json` are relative to the campaign root, the directory every command below is run from.

Venue B (`bench-pico2.json`): `<root>/zref/` is this repository on branch `tlm-packetizer-membership-pool-harness`,
with `lib/fprime` at the unit under test. It is both the image source and the harness checkout:

```sh
(cd zref && fprime-util generate -DBOARD=rpi_pico2/rp2350a/m33 && fprime-util build)
T=zref/FprimeZephyrReference/ReferenceDeployment/test/int/tpk_pool
I=zref/build-fprime-automatic-zephyr/zephyr/zephyr.bin
fth manifest --uut zref/lib/fprime --harness zref --plan $T/plan.json --menu $T/faults-menu.json --bench $T/bench-pico2.json --tests $T --image ReferenceDeployment=$I -o manifest.json
```

Venue A (`Ref` on a Linux host) keeps the same plan and stimulus files beside the `Ref` deployment
(`lestarch-autobot/fprime`, same branch name, `TestDeploymentsProject/Ref/test/int/tpk_pool`);
`diff -r` of the two directories shows only the venue files (`bench-*.json`, `venue/`, the venue part of this file).

## Static checks (no bench)

```sh
fth verify-plan $T/plan.json --tests $T
fth verify-stimulus $T/plan.json --tests $T
pytest $T/../../kat
```

## Dry run (no bench, nothing sent)

```sh
fth run --dry-run --run-dir runs/dry-0 --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T
```

## Whole plan on the bench (development, unsealed)

```sh
fth run --unsealed --run-dir runs/dry-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T
```

`fth run` flashes the image (`venue/flash-pico2.sh`, read back with `venue/readback-pico2.sh`, MATCH/MISMATCH in
`record/raw/flash.log`), the GDS and one recorder, runs the six tests in plan order and stops the GDS.
One planted fault alone: add `--plant L2-1=first_packet_also_held` (development only).

## One test

Append the pytest selection after `--`:

```sh
fth run --unsealed --run-dir runs/one-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T -- -k test_L2_1
```

## Replay of a record

```sh
fth run --replay-record runs/dry-1/record --run-dir runs/dry-1-replay --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T
fth audit --run-dir runs/dry-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T --unsealed
```
