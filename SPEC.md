# SPEC — build log

Every step taken on this project, in order, with the reasoning. Newest entries at the
bottom. If a decision was made, it is written down here with why, so that a decision can
be revisited later without re-deriving it.

Gate numbering follows the project plan: Gate 0 fixes the claim, Gate 1 is simulation
literacy, Gates 2-4 are hardware bring-up, Gates 5-10 are the measurement, Gates 11-15 are
the differentiators and publication.

---

## 2026-09-17 — Gate 0: repo created, claim fixed

Created the repository and wrote `GOAL.md` before writing any code.

`GOAL.md` holds one sentence with the numbers blank. It is there to stop scope creep: the
test for any future change is whether it helps fill a blank. Adding a fourth channel or a
GUI does not, so neither gets built.

The important property of those blanks is that **none of them can be produced in
simulation**. Bin widths in a simulator come from the timing model, which gives every
carry element the same delay, so simulated DNL is a flat line at exactly zero. Real DNL is
jagged because of random process mismatch in the silicon. The entire value of this project
is the part that has to be measured.

### Environment audit

Checked what is already on the machine before planning anything:

| Tool | Status |
|---|---|
| git 2.53.0 | present |
| Python 3.13.14, pip 26.1.2 | present |
| numpy 2.4.6, scipy 1.17.1, matplotlib 3.10.9 | present |
| winget 1.29 | present |
| GHDL / NVC / iverilog / Verilator / GTKWave | **absent** |

Gate 1 needs a VHDL simulator because the reference design (`m-labs/tdc-core`) is VHDL.
`winget search` finds two free options:

- `ghdl.ghdl.ucrt64.mcode` 6.0.0
- `NickGasson.NVC` 1.22.1

Chose **GHDL**, because the `simulate.sh` scripts inside `tdc-core/tb/` invoke `ghdl`
directly. Using anything else means rewriting the upstream test scripts before having read
them, which is backwards.

### Decision: upstream repos live in `reference/`, which is gitignored

Reference designs get cloned into `reference/` and that directory is excluded from git.

The reason is licensing, and it is worth being precise about it because it becomes a
credibility question later:

- `m-labs/tdc-core` — CERN-funded, and the licence terms come with it
- `jobisoft/jTDC` — GPL-3.0
- `madamic/zynq_tdc` — GPL-3.0
- `koliazak/tdc_zynq7010` — **no licence file at all**, which means default copyright: it
  can be read and learned from, but not copied into this tree

Keeping them outside the tracked tree means nothing is accidentally relicensed, and the
question "is this yours or theirs?" always has a clean answer. Anything genuinely derived
from upstream will be a separate, clearly attributed repository (Gate 11), not quietly
mixed in here.

### Cost so far

Zero rupees. Recorded because the budget constraint on this project is hard: every tool
chosen has to be free, and where a paid option exists the free one gets used or the step
gets redesigned.
