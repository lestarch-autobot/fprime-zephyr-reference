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
I=zref/build-artifacts/zephyr.bin
fth manifest --uut zref/lib/fprime --harness zref --plan $T/plan.json --menu $T/faults-menu.json --bench $T/bench-pico2.json --tests $T --image ReferenceDeployment=$I -o manifest.json
```

Venue A (`Ref` on a Linux host) keeps the same plan and stimulus files beside the `Ref` deployment
(`lestarch-autobot/fprime`, same branch name, `TestDeploymentsProject/Ref/test/int/tpk_pool`);
`diff -r` of the two directories shows only the venue files (`bench-*.json`, `venue/`, the venue part of this file).

## Complete procedure (venue B, from a new machine)

Two machines. The **build host** (Linux x86_64, about 10 GB free) builds the image. The **bench host** is
`pi-ci-1` (aarch64, user `devin`; address and key come from the bench owner), with the Pico 2 console at
`/dev/pico2`, the debug probe (serial `E6647C74036F8730`) at `/dev/pico2-probe`, `openocd` 0.12 in `/usr/bin`,
and user `devin` in `dialout` and `plugdev` with `sudo -n ls` allowed. The bench host is shared with a GitHub
Actions runner that flashes the same board: read "Whole plan on the bench" below before the first run, and
never stop or touch the runner.

1. Build host: clone and build (`west` fetches the Zephyr workspace and the ARM SDK; about 30 minutes).

```sh
mkdir tpk-campaign && cd tpk-campaign
git clone -b tlm-packetizer-membership-pool-harness https://github.com/lestarch-autobot/fprime-zephyr-reference zref
cd zref
git submodule update --init lib/fprime-zephyr lib/zephyr-workspace/zephyr lib/fprime
(cd lib/fprime && git submodule update --init --recursive && git rev-parse HEAD)     # 14dc2e3077b1a5b108a067805abac48c1f765be9
python3 -m venv ../zvenv && . ../zvenv/bin/activate && pip install -r requirements.txt
(cd lib/zephyr-workspace && west update -n -o=--depth=1 && west zephyr-export)
(cd lib/zephyr-workspace/zephyr && west sdk install -t arm-zephyr-eabi)               # into ~/zephyr-sdk-<version>
export ZEPHYR_SDK_INSTALL_DIR=$(ls -d ~/zephyr-sdk-* | tail -1)
git status --short                                 # empty: the image carries `git describe` of this tree
fprime-util generate -DBOARD=rpi_pico2/rp2350a/m33 && fprime-util build -j4 2>&1 | grep "needs MAX_PACKETIZER"
git describe --tags --always; ls -l build-artifacts/zephyr.bin; sha256sum build-artifacts/zephyr.bin
cd ..
```

Expected from the build (the sizing check of the unit under test):

```text
Packet set ReferenceDeploymentPackets needs MAX_PACKETIZER_MEMBERSHIPS >= 31
Packet set ReferenceDeploymentPackets needs MAX_PACKETIZER_CHANNELS >= 30 (30 listed in packets; 42 omitted not counted, FPRIME_TLM_PACKETIZER_OMIT_LIST is OFF)
```

2. Copy the built tree to the bench host, with its `.git` directories and `build-artifacts/` (image and
   dictionary), without the Zephyr workspace:

```sh
rsync -a --delete --exclude build-fprime-automatic-zephyr --exclude lib/zephyr-workspace --exclude .west zref devin@<pi-ci-1>:tpk-campaign-run/
```

3. Bench host: tools and manifest. All further commands are run on the bench host from `~/tpk-campaign-run`.

```sh
cd ~/tpk-campaign-run && mkdir -p runs
python3 -m venv venv && . venv/bin/activate
pip install fprime-gds==4.4.0 pytest git+https://github.com/lestarch-autobot/fprime-testing-harness@v0.1.29   # fth; commit fb09828
T=zref/FprimeZephyrReference/ReferenceDeployment/test/int/tpk_pool
fth verify-plan $T/plan.json --tests $T          # plan ok: ... 6 tests, 1 helpers, 4 planted faults, 1 waived requirements, 0 warnings
fth verify-stimulus $T/plan.json --tests $T      # 6 lines MATCH, 0 FAIL
pytest -q zref/FprimeZephyrReference/ReferenceDeployment/test/kat      # 30 passed
fth manifest --uut zref/lib/fprime --harness zref --plan $T/plan.json --menu $T/faults-menu.json --bench $T/bench-pico2.json --tests $T --image ReferenceDeployment=zref/build-artifacts/zephyr.bin -o manifest.json
```

   `fth manifest` refuses an image that does not carry the describe strings of both trees.

4. Save the image the board holds, if it is to be put back and no saved copy exists. The image the board held
   before this campaign's first flash is on the bench host:
   `/home/devin/tpk-campaign/saved/pico2-before.bin` (4194304 bytes from 0x10000000, SHA-256
   `269aed1a1f73a4a0e14db43b18d430a658159e036e0615ed8893ee79b31c266a`). The CI runner reflashes the board on
   every job, so the board may hold another image by now.

5. The five dry runs under the guard, audit, replay, vector set and vector rule: one script. Each run flashes
   the image through the probe and reads it back (MATCH) before the first test, so there is no separate flash
   step. The planted fault of each run is named only in the script (dry-2 `L2-1=first_packet_also_held`,
   dry-3 `L2-2=second_packet_also_held`, dry-4 `L6-1=known_packet_requested`, dry-5 `L7-1=final_packets_held`,
   each as `fth run --unsealed --plant <test>=<fault>`). A run whose guard trips is bench-invalid: the script
   keeps its record under `runs/invalid/`, waits for the worker to exit and runs again, at most 3 attempts.
   About 25 minutes.

```sh
sh zref/FprimeZephyrReference/ReferenceDeployment/test/campaign/dry-runs.sh all 2>&1 | tee venue-b.out
cat runs/dry-?.guard.out                           # per run: one "GUARD pre" and one "GUARD post: ok" line
```

Expected in `venue-b.out`, per run (`<V>` is the check name `cmdDisp.CommandsDispatched tracks
cmdDisp.OpCodeDispatched: >= 2 increasing samples, each step == dispatches between them, a sample within 2 ticks
after each dispatch`; record ids differ from run to run):

```text
GUARD pre: no worker; newest worker log Worker_<time>-utc.log; console on usb 3-1.1.1
run dry-1: record <id> -> runner/verdicts.json (pytest exit 0)
dry-1 rc=0
fuser-after-rc=1
GUARD post: ok (no worker; newest worker log Worker_<time>-utc.log; 2 re-enumerations, all own)
  L0-1 PASS []          (and L0-2, L2-1, L2-2, L6-1, L7-1: PASS [])
  audit rc=0 FAILED-lines=0 DIVERGENCE=0
  replay equal
MATCH: flash holds zref/build-artifacts/zephyr.bin (310420 bytes)
dry-2: pytest exit 1; L2-1 FAIL ['<V>'], the five others PASS []; audit rc=1 FAILED-lines=3 DIVERGENCE=0; replay equal
dry-3: as dry-2 with L2-2 FAIL ['<V>']
dry-4: L6-1 FAIL ['event cmdDisp.OpCodeError count == 1', 'event tlmSend.PacketNotFound(packetId=999) count == 1', 'event tlmSend.PacketSent count == 0']
dry-5: as dry-2 with L7-1 FAIL ['<V>']
vectors: 5 lines "ok", one per vector
vector rule rc=0
```

   The audit of a planted run ends FAILED by the tool's design (`audit rc=1`, two failed steps: "no development
   plant in the record" and "replay sent exactly the recorded commands"); its runner-versus-replay table must
   still show no DIVERGENCE. Only the clean run's audit ends ok (`runs/dry-1/auditor/`, table
   `diff-runner-replay.md`). `fth dev-campaign` is not part of this venue (no on-target coverage).

6. Put the saved image back, under the same guard, with read-back:

```sh
sh zref/FprimeZephyrReference/ReferenceDeployment/test/campaign/restore-pico2.sh /home/devin/tpk-campaign/saved/pico2-before.bin
```

Expected: `GUARD pre: ...`, `MATCH: flash holds /home/devin/tpk-campaign/saved/pico2-before.bin (4194304 bytes)`,
two SHA-256 lines both `269aed1a…266a`, `GUARD post: ok (... 2 re-enumerations, all own)`. Nothing of the
campaign may be left running on the bench host afterwards (`fuser /dev/pico2 /dev/pico2-probe` prints nothing).

`restore-pico2.sh` and the `mkdir` of `dry-runs.sh` were written for this procedure from the commands used for
the committed evidence; the scripts in this form had not been run on the bench when they were committed.

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
`SOURCE.json`) and two manifests: `manifest-as-run.json`, the one the runs were made with, and `manifest.json`,
made at this branch for the replay (same image entry; plan and stimulus hashes of this branch).
`record.sha256` is the tool's list for the whole record and also names the `raw/` files, which are not
committed (they are in the evidence bundle); `files.sha256` lists the files that are committed.
`rejudge/` holds the verdicts of a replay of each record with the plan files of this branch (amendment 7):
equal to `runner/verdicts.json` in every vector. `../../campaign/dry-runs.sh` makes the runs, replays each record
(`fth run --replay-record`), builds the set (`../../campaign/mk-vectors.py`) and applies the vector rule:

```sh
python3 $T/../../campaign/check-vectors.py $T/../../vectors     # one line per vector; exit 1 on a mismatch or an empty set
```

`fth vectors` (v0.1.29) cannot judge a plan whose pass rules live in the tests; `check-vectors.py` applies its rule
(`fth.vectors.verdict_problems`, imported unmodified) to the replay verdicts.
To repeat the gate on the committed records (no bench; from a campaign root, tools installed as above):

```sh
V=$T/../../vectors
for n in 1 2 3 4 5; do fth run --replay-record $V/dry-$n/record --run-dir replay/dry-$n --manifest $V/manifest.json --plan $T/plan.json --bench $T/bench-pico2.json --tests $T; done
for n in 1 2 3 4 5; do cmp replay/dry-$n/runner/verdicts.json $V/dry-$n/rejudge/verdicts.json && echo "dry-$n equal"; done
```
The campaign scripts sit outside this directory (`../../campaign/`) because they name the planted fault of each
run, which the stimulus directory must not (`fth verify-plan` refuses it).

## Notes for the reader of a record

- **L0-1 and the image identity.** The test's check is `FrameworkVersion count >= 1`, as in the plan. That the
  image carries the manifest's describe strings is judged by the tooling, not by this test: `fth manifest`
  refuses an image without them and `fth audit` compares the dictionary versions with the manifest.
- **Two packets, one sample.** `TpkA` (60) and `TpkB` (61) both carry `cmdDisp.CommandsDispatched`. With both
  enabled (L0-2, L7-1) each change is downlinked twice with one time tag. The tool's export collapses the two
  copies when their recorder lines are adjacent. They need not be: on `Ref` the channel is written on the
  rate-group thread while the packetizer sends on its own, so one copy can leave a tick after the other, and a
  held packet released later carries its old time tag (teardown windows of L2-1 and L2-2). The helper therefore
  drops a sample equal in time and value to the one before it (plan amendment 7) and nothing else: an equal
  value with a later time is a step of 0 and FAIL. `test/kat` pins both.
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
