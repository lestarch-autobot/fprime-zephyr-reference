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

The bench host is shared with a GitHub Actions runner (user `fprime`) whose jobs flash the same Pico 2.
`fuser` does not see that, so every run on the bench, a run for record included, is bracketed by the guard:

```sh
fuser /dev/pico2 /dev/pico2-probe && exit 9          # nothing may hold the console or the probe
$T/venue/bench-guard.sh pre runs/dry-1.guard /dev/pico2 || exit 9
fth run --unsealed --run-dir runs/dry-1 --manifest manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T
$T/venue/bench-guard.sh post runs/dry-1.guard /dev/pico2
```

`pre` requires that no `Runner.Worker` process runs and notes the newest `Worker_*` log of the runner and the
time. `post` requires again no worker, the same newest log, and exactly the run's own two re-enumerations of
the console in the kernel log (the resets after the flash and after the read-back). If either step prints
`GUARD TRIPPED` the run is bench-invalid: keep its record, wait for the worker to exit, and run again
(the run flashes and reads back the image itself). Every line the guard prints is also appended, with the
UTC time, to `<state file>.out` (`runs/dry-1.guard.out` above): keep it beside the run directory; a run without
that file, or without `GUARD pre` and `GUARD post: ok` in it, is not a guarded run. The guard needs `sudo -n ls` on the runner's `_diag`
directory and read access to `dmesg`. It does not stop or touch the runner.

A run for record is bracketed in the same way (`fth rfr` flashes and runs inside the bracket):

```sh
fuser /dev/pico2 /dev/pico2-probe && exit 9
$T/venue/bench-guard.sh pre rfr/<run-id>.guard /dev/pico2 || exit 9
fth rfr rfr-input.zip --out rfr --run-id <run-id>
$T/venue/bench-guard.sh post rfr/<run-id>.guard /dev/pico2 <own>     # ship rfr/<run-id>.guard.out with the package
```

`<own>` is the number of console re-enumerations the run makes itself: 2 for one `fth run` (above). For
`fth rfr` it has not been measured; take it from the stage-3 rehearsal before the run for record.

`../../campaign/dry-runs.sh` runs the clean run and the four planted runs under the guard, at most three attempts each.

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

## Mutation vectors

`../../vectors/` holds the vector set of this venue: one clean record and one record per planted fault applied
alone, as the dry runs made them (`vector.json`, `record/` with `record.sha256`, `sealed/faults.json`, `runner/`,
`replay-verdicts.json`, `audit/`, the logs), the plan copy they were judged with (`plans/tpk-pool/`, hashes in
`SOURCE.json`) and the manifest of those runs. `../../campaign/dry-runs.sh` makes the runs, replays each record
(`fth run --replay-record`), builds the set (`../../campaign/mk-vectors.py`) and applies the vector rule:

```sh
python3 $T/venue/check-vectors.py $T/../../vectors     # one line per vector; exit 1 on a mismatch or an empty set
```

`fth vectors` (v0.1.29) cannot judge a plan whose pass rules live in the tests; `check-vectors.py` applies its rule
(`fth.vectors.verdict_problems`, imported unmodified) to the replay verdicts.
The campaign scripts sit outside this directory (`../../campaign/`) because they name the planted fault of each
run, which the stimulus directory must not (`fth verify-plan` refuses it).

## Notes for the reader of a record

- **L0-1 and the image identity.** The test's check is `FrameworkVersion count >= 1`, as in the plan. That the
  image carries the manifest's describe strings is judged by the tooling, not by this test: `fth manifest`
  refuses an image without them and `fth audit` compares the dictionary versions with the manifest.
- **Two packets, one sample.** `TpkA` (60) and `TpkB` (61) both carry `cmdDisp.CommandsDispatched`. With both
  enabled (L0-2, L7-1) each change is downlinked twice with one time tag; the recorder writes the lines one after
  the other and the tool's export collapses adjacent identical lines, so the window holds one sample per change.
  The helper does not collapse equal samples: a second copy that is not adjacent (a held packet released later
  with its old time tag, as in the teardown windows of L2-1 and L2-2) stays a second row, and in a judged
  window it would be a step of 0 and FAIL. `test/kat` pins both.
- **State a planted fault leaves behind.** A test's teardown clears only the test's own override.
  `first_packet_also_held` leaves packet 60 held from the setup of L2-1 until the teardown of L2-2 (L2-2 holds
  packet 60 itself). `second_packet_also_held` leaves packet 61 held from the setup of L2-2 through L6-1 until
  the setup of L7-1. `final_packets_held` leaves both held at the end of the run. In plan order no other verdict
  changes (L6-1 judges no packet flow), so `ripples_to` is empty; a single test run after a planted run starts
  from a new image.

## What this branch changes in the reference deployment

Against `fprime-community/fprime-zephyr-reference` @ 6444eb6, outside `test/`:

| file | change | why |
|---|---|---|
| `ReferenceDeployment/Top/ReferenceDeploymentPackets.fppi` | `CommandsDispatched` moved into the new packets `TpkA` (60), `TpkB` (61) | plan, venue B packet set |
| `project/config/TlmPacketizerCfg.fpp`, `.hpp` | `MAX_PACKETIZER_PACKETS` 5 to 7; `MAX_PACKETIZER_MEMBERSHIPS = 31`; the index types `FwTlmPacketizePacketIndexType = U8`, `FwTlmPacketizePoolIndexType = U16` | plan (limits); the two types are new configuration the unit under test requires, not named in the plan text |
| `ReferenceDeployment/Top/topology.fpp` | `rateGroup1Hz.RateGroupMemberOut[6] -> CdhCore.Subtopology.cmdDispRun` | plan amendment 3 |
| `settings.ini` | `FPRIME_TLM_PACKETIZER_OMIT_LIST=OFF` | the deployment already passes `Svc::IGNORE_OMIT_LIST` (`project/config/CdhCoreTlmConfig.fpp`), and the unit under test's build then requires this setting; not named in the plan text (the plan's not-covered entry: an omit list the test deployments do not supply) |
| `.gitmodules`, `lib/fprime` | `lestarch-autobot/fprime` @ 14dc2e3077 | the unit under test lives in that fork; not named in the plan text |
