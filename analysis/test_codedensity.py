"""Validate the code-density pipeline against synthetic data with known bin widths.

This tests the ANALYSIS, not the device.

Synthetic bin widths are whatever we choose them to be. Real ones come from random process
mismatch in silicon and are the entire point of the project. Nothing in this file produces
a DNL plot that says anything at all about hardware, and no figure from here goes in the
paper. What it does buy is that when real data finally arrives, the maths applied to it is
already known to be right.

Run: python analysis/test_codedensity.py
"""

import numpy as np

from codedensity import bin_widths, width_uncertainty, dnl, inl, calibration_lut


def synthetic_widths(n_bins=400, seed=0):
    """Bin widths with the structure a real carry chain actually shows.

    Three features, all of them real:
      - random scatter from process mismatch
      - every fourth bin wider, because the hop between CARRY4 primitives is slower than
        the hops inside one
      - one very wide bin where the chain crosses a clock region boundary
      - a few zero-width bins that never fire
    """
    rng = np.random.default_rng(seed)
    w = rng.normal(25.0, 4.0, n_bins).clip(0.1)
    w[3::4] *= 1.6
    w[n_bins // 2] *= 8.0
    w[[17, 143, 276]] = 0.0
    return w


def sample_codes(widths, n_hits, seed=1):
    """Draw hits with phase uniform over the clock period, return the code each lands in."""
    edges = np.concatenate([[0.0], np.cumsum(widths)])
    t = np.random.default_rng(seed).uniform(0.0, edges[-1], n_hits)
    return np.searchsorted(edges, t, side="right") - 1


def main():
    w_true = synthetic_widths()
    period = w_true.sum()
    codes = sample_codes(w_true, 2_000_000)

    w_meas = bin_widths(codes, len(w_true), period)
    sigma = width_uncertainty(codes, len(w_true), period)

    # Bins that never fire must come back at exactly zero width, i.e. DNL of exactly -1.
    dead = w_true == 0
    assert np.all(w_meas[dead] == 0), "a zero-width bin was assigned counts"
    assert np.allclose(dnl(w_meas)[dead], -1), "a dead bin did not give DNL = -1"

    # Everywhere else, the recovered width should sit within counting-statistics error of
    # the truth. The pull is (measured - true) / sigma and should look standard normal; if
    # it does not, the estimator is biased rather than merely noisy.
    live = ~dead
    pull = (w_meas[live] - w_true[live]) / sigma[live]
    print(f"bins            {len(w_true)}  ({dead.sum()} dead)")
    print(f"hits            {len(codes):,}")
    print(f"mean bin width  {w_meas[live].mean():.2f} ps   (true {w_true[live].mean():.2f})")
    print(f"clock period    {period:.1f} ps")
    print(f"pull mean       {pull.mean():+.3f}   (expect 0)")
    print(f"pull std        {pull.std():.3f}   (expect 1)")
    print(f"worst pull      {np.abs(pull).max():.2f} sigma")
    assert abs(pull.mean()) < 0.1, "estimator is biased"
    assert 0.9 < pull.std() < 1.1, "uncertainty estimate is wrong"
    assert np.abs(pull).max() < 5.0, "an outlier no counting model explains"

    # INL must return to zero: DNL is defined against the mean width, so it sums to zero by
    # construction. If it does not, the normalisation is wrong.
    assert abs(inl(dnl(w_meas))[-1]) < 1e-9, "INL does not close"

    # The LUT must be monotonic and span the period. A non-monotonic LUT would report time
    # going backwards.
    lut = calibration_lut(w_meas)
    assert np.all(np.diff(lut) >= 0), "calibration LUT is not monotonic"
    assert lut[0] >= 0 and lut[-1] <= period, "LUT leaves the clock period"

    print(f"INL range       {inl(dnl(w_meas)).min():+.2f} to "
          f"{inl(dnl(w_meas)).max():+.2f} LSB")
    print(f"DNL range       {dnl(w_meas).min():+.2f} to {dnl(w_meas).max():+.2f} LSB")
    print("\nTest passed.")


if __name__ == "__main__":
    main()
