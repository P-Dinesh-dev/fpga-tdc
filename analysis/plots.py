"""Figures for the TDC characterisation.

Every plotting function takes a mandatory `source` string and stamps it on the figure.
There is no default and it cannot be omitted. A figure that does not say where its data
came from is exactly how synthetic data ends up in a paper, and on this project the
difference between measured and simulated is the difference between a result and nothing
at all. If `source` mentions simulation or synthesis, the figure is also watermarked so it
cannot be mistaken at a glance.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from codedensity import dnl, inl

_FAKE = ("synthetic", "simulated", "simulation", "test", "example")


def _stamp(fig, source):
    fig.text(0.99, 0.01, source, ha="right", va="bottom", fontsize=7, color="0.4")
    if any(word in source.lower() for word in _FAKE):
        fig.text(0.5, 0.5, "SYNTHETIC", fontsize=72, color="red", alpha=0.18,
                 ha="center", va="center", rotation=30, transform=fig.transFigure)


def dnl_inl(widths, source, path, sigma=None):
    """Two-panel DNL and INL against code, the headline figure of the whole project.

    Pass `sigma` (from width_uncertainty) to draw the counting-statistics band, which shows
    whether structure in the plot is real or just too few hits.
    """
    d, i = dnl(widths), inl(dnl(widths))
    codes = np.arange(len(widths))

    fig, (ax_d, ax_i) = plt.subplots(2, 1, figsize=(9, 6), sharex=True)

    ax_d.step(codes, d, where="mid", linewidth=0.8)
    if sigma is not None:
        ax_d.fill_between(codes, -sigma / widths.mean(), sigma / widths.mean(),
                          color="0.8", zorder=0, label="counting statistics, 1 sigma")
        ax_d.legend(fontsize=8)
    ax_d.axhline(-1, color="red", linewidth=0.6, linestyle=":")
    ax_d.set_ylabel("DNL [LSB]")
    ax_d.set_title(f"mean bin {widths.mean():.1f} ps, "
                   f"DNL {d.min():+.2f} to {d.max():+.2f}, "
                   f"INL {i.min():+.2f} to {i.max():+.2f} LSB")

    ax_i.plot(codes, i, linewidth=0.8)
    ax_i.axhline(0, color="0.6", linewidth=0.6)
    ax_i.set_ylabel("INL [LSB]")
    ax_i.set_xlabel("code (tap)")

    _stamp(fig, source)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path
