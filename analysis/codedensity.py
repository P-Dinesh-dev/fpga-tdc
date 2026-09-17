"""Code-density calibration of a TDC delay line.

This is the trick that makes the whole project possible without a reference instrument.

Feed the TDC hits whose phase is uniform with respect to the clock. If every bin were the
same width, every code would get the same number of hits. They do not, and the count in a
bin is proportional to its width, so the histogram measures the bin widths directly. The
calibration is bootstrapped out of counting statistics and nothing picosecond-accurate is
ever needed.

Uniform phase comes from an oscillator independent of the FPGA clock: two separate crystals
always drift against each other, so the phase walks through the clock period on its own.
"""

import numpy as np


def bin_widths(codes, n_bins, clock_period_ps):
    """Width of each bin in ps, from a histogram of measured codes."""
    counts = np.bincount(codes, minlength=n_bins)
    return counts / counts.sum() * clock_period_ps


def width_uncertainty(codes, n_bins, clock_period_ps):
    """One-sigma uncertainty on each bin width, from counting statistics alone.

    Counts are binomial: N_i ~ B(N, p_i), so sigma(N_i) = sqrt(N p_i (1-p_i)) and the width
    inherits it scaled by T_clk / N. This is the floor on how well a code-density test can
    ever know a bin, and it is what decides how many hits a run needs. It belongs in the
    uncertainty budget.
    """
    counts = np.bincount(codes, minlength=n_bins)
    n = counts.sum()
    p = counts / n
    return np.sqrt(n * p * (1 - p)) / n * clock_period_ps


def dnl(widths):
    """Differential non-linearity in LSB. Exactly -1 means a bin that never fires."""
    return widths / widths.mean() - 1


def inl(dnl_lsb):
    """Integral non-linearity in LSB: the running sum of DNL."""
    return np.cumsum(dnl_lsb)


def calibration_lut(widths):
    """Time in ps at the centre of each bin.

    Reporting the bin centre instead of the raw code is what turns a raw ~40 ps sigma into
    ~15 ps. The lower edge of bin k is the sum of every width below it; the centre is that
    plus half its own width.
    """
    edges = np.concatenate([[0.0], np.cumsum(widths)[:-1]])
    return edges + widths / 2
