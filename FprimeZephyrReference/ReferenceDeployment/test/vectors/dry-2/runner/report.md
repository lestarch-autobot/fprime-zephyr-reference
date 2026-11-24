# Runner report — run `dry-2`

Record `327a6d0d829d8c3539c256ac1fb572c2f352ba20cf671e30ffcdca16e8dd7bb5` · checker `fth.junit` · 5 PASS / 1 FAIL / 0 UNVERIFIED

| test | title | verdict | failed checks |
|---|---|---|---|
| L0-1 | Image identity | PASS |  |
| L0-2 | Packets flow on change | PASS |  |
| L2-1 | Channel value reaches its first packet | FAIL | `cmdDisp.CommandsDispatched tracks cmdDisp.OpCodeDispatched: >= 2 increasing samples, each step == dispatches between them, a sample within 2 ticks after each dispatch` |
| L2-2 | Channel value reaches its second packet | PASS |  |
| L6-1 | Unknown packet is refused | PASS |  |
| L7-1 | Final state | PASS |  |

pytest exit code: 1
