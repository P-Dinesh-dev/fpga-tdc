# fpga-tdc

A time-to-digital converter built from an FPGA's carry chain, and characterised like an
instrument rather than demonstrated like a toy.

A TDC is a stopwatch with picosecond ticks. A plain counter on a 100 MHz clock resolves
10 ns; detector physics wants tens of picoseconds. The gap is closed by measuring whole
clock cycles with a counter (coarse) and the leftover fraction of a cycle with a delay
line (fine). The delay line here is the FPGA's own carry chain, which propagates a signal
bit-to-bit in roughly 10-30 ps.

The deliverables are plots and numbers, not a demo:

- bin width, from a code-density test
- DNL and INL
- single-shot precision as a standard deviation in picoseconds
- drift over an hour, against on-die temperature

Status and every decision taken so far are in [SPEC.md](SPEC.md). The target numbers are
in [GOAL.md](GOAL.md).

## Cost

Zero. GHDL, Vivado ML Standard, Python, Git, Zenodo and arXiv are free; the FPGA board is
borrowed for about fifteen hours rather than bought.
