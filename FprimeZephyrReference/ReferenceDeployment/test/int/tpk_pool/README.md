# TPK-POOL system tests (Svc.TlmPacketizer membership pool)

External stimulus of the approved plan `plan.json` (rendered: `plan.md`). The unit under test is not
changed by anything here. Tooling: `fprime-testing-harness` v0.1.29 (`fth`), `fprime-gds`.

| file | what |
|---|---|
| `plan.json`, `plan.md` | the approved plan and its rendering (`fth render-plan plan.json -o plan.md`) |
| `planted_faults.py`, `faults-menu.json` | plan helper and planted faults; the menu is generated (`fth planted-faults-menu plan.json`) |
| `test_L*.py` | one stimulus file per plan test |
| `bench-ref.json` | venue A: `Ref` on a Linux host, GDS over TCP |
| `../../kat/` | known-answer tests of the plan helper (`pytest test/kat`) |
| `/venues/ref/` | venue A: `FPRIME_SHA` (the Ref test deployment commit) and the UUT start/stop/read-back scripts |

## Layout of a campaign root

All paths in `bench-*.json` are relative to the campaign root, the directory every command below is run from:

```
<root>/harness/   this repository
<root>/uut-ref/   lestarch-autobot/fprime at harness/venues/ref/FPRIME_SHA (branch tlm-packetizer-membership-pool-harness:
                 the UUT commit plus one commit under TestDeploymentsProject/Ref only), built
```

```sh
(cd uut-ref/TestDeploymentsProject/Ref && fprime-util generate -DFPRIME_TLM_PACKETIZER_OMIT_LIST=OFF && fprime-util build)
T=harness/FprimeZephyrReference/ReferenceDeployment/test/int/tpk_pool
```

## Static checks (no bench)

```sh
fth verify-plan $T/plan.json --tests $T
fth verify-stimulus $T/plan.json --tests $T
pytest harness/FprimeZephyrReference/ReferenceDeployment/test/kat
```

## Dry run (no bench, nothing sent)

```sh
fth run --dry-run --run-dir runs/dry-0 --manifest manifest.json --plan $T/plan.json --bench $T/bench-ref.json --tests $T
```

## Whole plan on the bench (development, unsealed)

```sh
fth run --unsealed --run-dir runs/dry-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-ref.json --tests $T
harness/venues/ref/stop-uut.sh
```

`fth run` starts the image (`start-uut.sh`, read back with `readback-uut.sh`, MATCH/MISMATCH in
`record/raw/flash.log`), the GDS and one recorder, runs the six tests in plan order and stops the GDS.
One planted fault alone: add `--plant L2-1=first_packet_also_held` (development only).

## One test

Append the pytest selection after `--`:

```sh
fth run --unsealed --run-dir runs/one-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-ref.json --tests $T -- -k test_L2_1
```

## Replay of a record

```sh
fth run --replay-record runs/dry-1/record --run-dir runs/dry-1-replay --manifest manifest.json --plan $T/plan.json --bench $T/bench-ref.json --tests $T
fth audit --run-dir runs/dry-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-ref.json --tests $T --unsealed
```
