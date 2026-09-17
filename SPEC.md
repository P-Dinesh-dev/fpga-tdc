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
wrong bin. `tdc_lbc` avoids that, and all 64 injected vectors decoded correctly.

(Corrected 2026-09-17, later the same day: the first version of this entry said `tdc_lbc`
counts ones. It does not - it counts the *leading* run. See the encoder entry below.)

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

---

## 2026-09-17 — Gate 4 (part): encoder written and exhaustively tested

### Correction: tdc_lbc is not a ones-counter

The Gate 1 entry above said `tdc_lbc` counts ones. It does not. It is a count-leading-
symbol using divide and conquer over halves: check whether an entire half is all-symbol,
recurse into the lower half if so, into the upper half if not. Because the comparisons are
against whole halves and never propagate a carry, the additions collapse into ORs, so it
costs pure LUT logic and no adders.

That is a different mechanism with different bubble behaviour, and it changes what our own
encoder should be, so the decision is made explicitly below rather than inherited.

### Decision: popcount, not count-leading-ones

`rtl/tdc_encoder.vhd` counts every one in the vector.

The physical bubble is a **local reordering**, not a random bit error. The hit edge lands
between two taps and adjacent sampling flip-flops resolve in different orders, so bits near
the transition come out swapped. A swap moves a one from one position to another and leaves
the total untouched, which makes a popcount *exactly* invariant under it - for any
permutation of the vector, not just the likely ones.

Count-leading-ones does not have that property. `1110100000` has a leading run of 3 but
four ones, and four is the better estimate of where the edge actually got to.

The tradeoff is area: CLS is OR logic, popcount is an adder tree. tdc-core was written for
a Spartan-6 where that matters. We have LUTs to spare on a 7-series and care more about the
bin being right, so we pay for the tree. Recorded as a decision, not a default.

### Deliberately not pipelined

At 250 MHz over a few hundred taps the adder tree may not close timing. It is written flat
anyway. Choosing a pipeline depth before Vivado has reported a single number would be
inventing a problem and then solving the invented version. Stages get added when the timing
report asks for them, and the report is a Gate 2 artefact.

### The testbench tests swaps, not random bits

`tb/tb_encoder.vhd` sweeps the edge across all 65 positions, checks the clean thermometer
code at each, then corrupts it and checks the answer does not move.

The corruption is a swap across the transition, because that is what a bubble physically is.
Injecting random bit flips would be testing the wrong failure mode - a single flipped bit
genuinely does change the count by one, and no popcount encoder can or should be immune to
that. The swaps accumulate as k grows, so the later cases test several simultaneous bubbles.

Deterministic, no random seed. Reproducible matters more than exotic here.

### Mutation test: the coverage is real

A test that passes first time proves nothing until you have watched it fail. Replacing the
popcount with a true count-leading-ones from tap 0 upward gives:

    clean edge at 0 .. 64      pass
    1 bubble(s) at edge 1      FAIL, expected 1, got 0

Exactly the intended split: the clean sweep cannot tell the two encoders apart, and the
first bubble case can. The bubble tests have teeth, and they empirically demonstrate the
design decision above rather than just asserting it.

(A first attempt at this mutation exited on the first zero while iterating `taps_i'range`,
which runs high to low, so it failed at the clean sweep instead and proved nothing. Worth
recording because the mutation looked right and was not.)

### Status

`sim/run-tb.sh` runs our testbenches. `sim/run-reference-tb.sh` runs upstream's.

    PASS  tb_encoder

Cost so far: still zero rupees.

---

## 2026-09-17 — Gates 6 and 7 (software half): analysis pipeline built and validated

The measurement needs hardware. The maths applied to the measurement does not, so it is
written and validated now. When fifteen hours of board time finally exist, none of them get
spent debugging a histogram.

### analysis/codedensity.py

Five functions, no classes, no configuration:

    bin_widths(codes, n_bins, clock_period_ps)        w_i = N_i / N_total * T_clk
    width_uncertainty(codes, n_bins, clock_period_ps) binomial 1 sigma on each width
    dnl(widths)                                       w_i / w_mean - 1
    inl(dnl_lsb)                                      running sum
    calibration_lut(widths)                           time at each bin centre

`width_uncertainty` is not decoration. Counts are binomial, so sigma(N_i) is
sqrt(N p (1-p)) and the width inherits it. That is the floor on how well a code-density
test can ever know a bin, it decides how many hits a run needs, and it is a line in the
Gate 10 uncertainty budget.

### Validated against synthetic ground truth, and only that

`analysis/test_codedensity.py` builds bin widths with the structure a real chain shows -
process scatter, every fourth bin wider for the hop between CARRY4 primitives, one very
wide bin at a clock region boundary, three dead bins - then draws two million hits with
uniform phase and checks the pipeline recovers what went in.

    bins            400  (3 dead)
    hits            2,000,000
    mean bin width  29.03 ps   (true 29.03)
    pull mean       +0.003   (expect 0)
    pull std        1.018   (expect 1)
    worst pull      3.70 sigma
    DNL range       -1.00 to +5.19 LSB
    INL range       -2.38 to +4.36 LSB

The test is on the pull, `(measured - true) / sigma`, not on a tolerance someone picked.
A mean of zero says the estimator is unbiased; a standard deviation of one says the
uncertainty estimate is itself correct. A fixed tolerance would have caught neither. Worst
pull of 3.7 sigma across 397 bins is what 397 draws from a standard normal look like.

Also asserted: dead bins come back at exactly DNL = -1, INL closes to zero (it must, since
DNL is defined against the mean), and the LUT is monotonic and stays inside the clock
period. A non-monotonic LUT would report time running backwards.

**This validates the analysis, not the device.** Synthetic bin widths are whatever we
choose them to be. Real ones come from random process mismatch in silicon and are the
entire point of the project. No figure from this file goes anywhere near the paper.

### The figures stamp their own provenance

`analysis/plots.py` takes a mandatory `source` string and prints it on every figure. There
is no default and it cannot be omitted. If the string mentions simulation or synthesis, the
figure also gets a large red SYNTHETIC watermark across it.

This is a guard against the single worst thing that could happen to this project. A
simulated DNL plot presented as measured would be both worthless and dishonest, and the
failure mode is not a decision to cheat - it is a stray PNG in a figures directory six
months from now that nobody can place. Making provenance a required argument means a
figure cannot be produced without answering the question.

The synthetic check figure was rendered and inspected: the four-bin periodicity, the three
dead bins pinned at -1, the clock-region spike and the INL step it causes all show up as
expected. It is deliberately not committed, for the reason above.

### What still needs silicon

Everything that matters. Gates 5, 6, 8, 9 and 10 cannot start without a board, and no
amount of Python changes that. What is now true is that the moment real codes exist, DNL,
INL, the calibration LUT and the uncertainty band are one function call away each.
