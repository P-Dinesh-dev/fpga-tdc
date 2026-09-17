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

---

## 2026-09-17 — Gate 1: GHDL installed, reference testbenches run

Installed GHDL 6.0.0 via `winget install ghdl.ghdl.ucrt64.mcode --source winget`. The
default invocation failed with a certificate error against the `msstore` source; pinning
`--source winget` avoids it. Cost: zero.

Cloned `m-labs/tdc-core` into the gitignored `reference/`. Four testbenches ship with it:
`lbc`, `divider`, `freqc`, `controller`. `sim/run-reference-tb.sh` runs all four from a
clean checkout and is the reproducible entry point.

### Result: 3 pass out of the box, 1 does not compile

    PASS  lbc
    PASS  divider
    PASS  freqc
    FAIL  controller

### What lbc showed, and why it matters

`tb_lbc` is the encoder testbench, and watching it run is the clearest explanation of the
bubble problem anywhere in this project. It feeds the encoder thermometer codes like:

    111111111111111111111111111111111111111111111111111000001000000

That isolated 1 sitting inside the run of zeros is a bubble. On real silicon it happens
because the sampling flip-flops along the chain have slightly different setup and hold
times and see slightly skewed clock, so the latched code is not a clean run of ones
followed by a clean run of zeros.

An encoder that searched for the first 1-to-0 transition would stop early and report the
wrong bin. `tdc_lbc` counts ones instead, so a bubble anywhere in the vector does not move
the answer. All 64 injected vectors decoded correctly.

This is also why the plan puts the ones-counting encoder in Gate 4 rather than treating it
as an optimisation. It is not an optimisation. It is the only thing that works.

### Upstream bug 1: tb_controller is missing a generic (FOUND AND FIXED)

`tb_controller` does not compile:

    error: no actual for constant interface "g_EXHIS_COUNT"

`tdc_controller` declares four generics; the testbench's generic map supplies three.
`g_EXHIS_COUNT` is the number of extra guard bits carried in the histogram accumulator.
`tdc_controller.vhd:181` shifts them off before the multiply, so they are fractional
precision rather than data. It also widens two ports, to
`g_FP_COUNT+g_EXHIS_COUNT-1 downto 0`.

The testbench declares both histogram signals at `g_FP_COUNT` wide, so it is not only
missing the generic, its histogram signals and memory array are the wrong width too. The
testbench was written before `g_EXHIS_COUNT` was added to the core and never caught up.

The fix is six lines, saved as
`patches/0001-tb_controller-add-missing-g_EXHIS_COUNT.patch`:

1. declare `g_EXHIS_COUNT : positive := 4` in the testbench entity. 4 is the default used
   everywhere else in the design: `tdc.vhd:51`, `tdc_package.vhd:48`, `tdc_hostif.vhd:48`
2. widen `his_d_w` and `his_d_r`
3. give the histogram memory its own wider type `t_hismem`. The LUT memory is correctly
   `g_FP_COUNT` wide and is left alone
4. pass the generic down in the generic map

After the patch it compiles, runs to completion, and the histogram accumulates correctly
across all eight bins.

### Upstream bug 2: the LUT assertion fails (FOUND, NOT YET UNDERSTOOD, OPEN)

With bug 1 fixed, `tb_controller` reaches its final check and fails there instead:

    tb_controller.vhd:229:13:@17308ns:(assertion failure): Assertion violation

The calibration LUT the core writes is `0, 2, 4, 6, 7, 9, 11, 13`, which is steps of
`2, 2, 2, 1, 2, 2, 2`. The assertion expects a uniform ramp of step 2. One step is short.

This is not being claimed as a bug. It is equally possible that the core's integer division
legitimately rounds one step down and the testbench's expectation is naive. Deciding which
requires reading `tdc_divider` and the controller's accumulator properly, and that has not
been done yet.

Swept `g_EXHIS_COUNT` over 1, 2, 3, 4, 5, 6 and 8 using `ghdl -r -gg_EXHIS_COUNT=N`. The
LUT output is identical at every value. Two things follow:

- the width fix above is complete and correct, and this failure is independent of it
- the testbench never exercises the guard bits at all. A parameter that changes nothing
  when swept across three octaves is not under test, which is a coverage gap in its own
  right

### Status against the Gate 1 exit criterion

Not met yet, deliberately. The exit criterion is `docs/how-it-works.md` written by Dinesh
in his own words with his own diagrams, covering `tdc_lbc`, `tdc_ringosc`,
`tdc_channelbank_single` and `ordertaps.py`. That document is interview armour and only
works if he writes it, so a skeleton of the questions is committed and the answers are not
pre-filled.

### Carried forward

- Both findings are Gate 12 candidates. Bug 1 is ready to submit as a patch. Bug 2 should
  be raised as a question, not a bug report, until the divider has actually been read.
- Cost so far: still zero rupees.

---

## 2026-09-17 — Upstream bug 2 resolved: the core is right, the testbench is wrong

Closed the open question from the previous entry. The core's arithmetic is correct and the
testbench's expectation is naive. Two separate testbench defects produce the failure.

### The arithmetic

`tdc_divider` is a restoring divider that truncates. There is no rounding anywhere on the
path, so the LUT value for bin `i` is exactly:

    lut[i] = floor( (cumulative_histogram_below_i >> g_EXHIS_COUNT) * oc_sfreq / oc_freq )

The testbench sets `oc_freq = 2` and `oc_sfreq = 1`, so the scale factor is exactly one
half, as its own comment says.

### The actual histogram is not uniform

Dumping the final count per bin:

    bin 0  64      bin 4  64
    bin 1  64      bin 5  64
    bin 2  64      bin 6  64
    bin 3  63      bin 7  64

Bin 3 is one hit short. Feeding those real counts through the formula above predicts the
LUT exactly:

    predicted  [0, 2, 4, 6, 7, 9, 11, 13]
    observed   [0, 2, 4, 6, 7, 9, 11, 13]

All eight values, no residual. The core is doing precisely what it should.

### Root cause of the short bin

The testbench's pulse generator is a free-running process with no synchronisation to the
acquisition window:

```vhdl
process
begin
    c_detect <= '1';
    c_raw <= std_logic_vector(unsigned(c_raw) + 1);
    wait until rising_edge(clk);
    c_detect <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
end process;
```

It cycles forever. When the controller stops accumulating, it stops mid-cycle, so whichever
bin the generator happened to be sitting on receives one fewer hit. Bin 3 is simply where
the window closed. Nothing selects bin 3; change the timing and it moves.

### Verdict

Not a core bug. Two testbench defects:

1. **Unsynchronised stimulus.** The generator must be stopped on a bin boundary, or the
   acquisition window aligned to a whole number of passes, or the histogram will never be
   uniform.
2. **An assertion that cannot tolerate truncation.** `assert lut_memory(i) = v_step*(i-1)`
   assumes both a perfectly uniform histogram and exact division. Neither holds, and the
   second never will, because the divider floors by design.

### Consequence for Gate 12

This is now a much better upstream contribution than bug 1 alone. The submission is: a
patch that makes the testbench compile, plus a precise account of why the remaining
assertion fails, with the arithmetic shown and the root cause identified. That is a report
a maintainer can act on without reproducing anything.

The fix for defect 1 is not written yet, deliberately - changing upstream stimulus timing
without understanding why the window closes where it does would be guessing.

### Method note

The thing that cracked this was dumping the histogram rather than reasoning about the
divider. Two rounds of algebra on the assumption of a uniform histogram produced a
contradiction, because the assumption was the bug. Worth remembering when the real DNL data
arrives: check the input distribution before trusting any conclusion drawn from it.
