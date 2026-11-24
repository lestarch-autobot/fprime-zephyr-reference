# Runner report — run `dry-5`

Record `e67d53bbafd86dbb9fdc404ce649e49bb14d53b9bdee22cd76566d709344c30b` · checker `fth.junit` · 5 PASS / 1 FAIL / 0 UNVERIFIED

| test | title | verdict | failed checks |
|---|---|---|---|
| L0-1 | Image identity | PASS |  |
| L0-2 | Packets flow on change | PASS |  |
| L2-1 | Channel value reaches its first packet | PASS |  |
| L2-2 | Channel value reaches its second packet | PASS |  |
| L6-1 | Unknown packet is refused | PASS |  |
| L7-1 | Final state | FAIL | `cmdDisp.CommandsDispatched tracks cmdDisp.OpCodeDispatched: >= 2 increasing samples, each step == dispatches between them, a sample within 2 ticks after each dispatch` |

pytest exit code: 1
