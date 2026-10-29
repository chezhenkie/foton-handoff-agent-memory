Benchmark complete (correctness checks passed: right file read, archive grew by exactly 1 per write). All timings are end-to-end wall time per invocation including Windows process spawn, median of N runs after warmup, isolated sandboxes:

| Scenario | Iters | Min | Median | Mean | P95 | Max | Ops/sec |
|---|---|---|---|---|---|---|---|
| startup only (no args) | 200 | 4.25 | 4.82 | 4.91 | 5.46 | 9.02 | 204 |
| read, 10 md files | 200 | 4.53 | 5.20 | 5.20 | 5.77 | 6.94 | 192 |
| read, 1,000 md files | 200 | 5.01 | 5.83 | 5.76 | 6.21 | 7.17 | 174 |
| read, 5,000 md files | 100 | 7.29 | 8.08 | 8.07 | 8.89 | 9.31 | 124 |
| write, 10 md files | 200 | 5.85 | 8.71 | 8.75 | 11.21 | 12.89 | 114 |
| write, 1,000 md files | 200 | 6.87 | 9.87 | 9.93 | 12.47 | 13.75 | 101 |
| write -n, 1,000 md files | 200 | 7.68 | 8.51 | 8.53 | 9.18 | 19.79 | 117 |

All numbers in milliseconds.

Exact breakdown:

- **Floor**: ~4.9 ms mean is pure process startup + runtime init (the no-args usage-error path touches no handoff logic).
- **read overhead over baseline**: +0.3 ms at 10 files, +0.9 ms at 1,000, +3.2 ms at 5,000 — i.e. ~0.6 microseconds per `.md` file in the root for the directory scan and name match.
- **write** costs ~3–4 ms more than read: stdin pipe transfer, archive rename of the old file, write of the new one. Scaling from 10 to 1,000 files adds ~1.2 ms.
- **Worst single observation** across all 1,300 timed runs: 19.79 ms (one dry-run outlier). P95 stays under 13 ms everywhere.
- **Throughput**: never below ~101 full write cycles per second even in a 1,000-file root.

Scaling behavior: linear in directory size as expected from the scan (`matching_files` reads every root entry), at roughly half a microsecond per file — a root would need on the order of hundreds of thousands of files before a read approaches 0.1 s.

## Running speedtests locally

Two scripts reproduce these benchmarks on demand:

```bash
bash scripts/speedtest-linux.sh <path-to-foton-handoff>
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\speedtest-windows.ps1 -Bin <path-to-foton-handoff.exe>
```

Or run both via the orchestrator (which also runs fmt, clippy, unit tests, builds, and e2e suites):

```bash
bash scripts/build-and-test-all.sh
```

The Linux speedtest copies the binary to `/tmp/` (native ext4); the Windows speedtest copies to `%TEMP%\foton-handoff\` (NTFS). This follows the speedtest methodology rules: no cross-filesystem testing.
