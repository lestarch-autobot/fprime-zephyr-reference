# Runner report — run `dry-3`

Record `31938e9d220fcdbfe397a83968cf3a54b07942b53e452c5ceb5af06652ff563f` · checker `fth.junit` · 5 PASS / 1 FAIL / 0 UNVERIFIED

| test | title | verdict | failed checks |
|---|---|---|---|
| L0-1 | Image identity | PASS |  |
| L0-2 | Packets flow on change | PASS |  |
| L2-1 | Channel value reaches its first packet | PASS |  |
| L2-2 | Channel value reaches its second packet | FAIL | `cmdDisp.CommandsDispatched tracks cmdDisp.OpCodeDispatched: >= 2 increasing samples, each step == dispatches between them, a sample within 2 ticks after each dispatch` |
| L6-1 | Unknown packet is refused | PASS |  |
| L7-1 | Final state | PASS |  |

pytest exit code: 1
