# Goal

One sentence. The numbers get filled in as they are measured, never estimated.

> I built a carry-chain time-to-digital converter on ______, measured ____ ps mean bin
> width, DNL [____, ____] LSB, INL [____, ____] LSB, single-shot precision sigma = ____ ps
> after calibration, and a drift coefficient of ____ ps/degC which I reduced to ____ ps/degC
> with on-chip compensation.

Every blank is a measurement on real silicon. None of them can come from simulation, and
that is the whole point of the project: simulated carry delays are uniform, so simulated
DNL is a flat line at zero.

If a change does not help fill a blank, it does not belong in this repo.
