# How tdc-core works

Gate 1 exit criterion. To be written by Dinesh, in his own words, with his own diagrams.

This is not a summary of the paper. It is the document that has to hold up when someone
asks a follow-up question in an interview, which means it only works if the understanding
behind it is real. The answers are deliberately not pre-filled.

## tdc_lbc.vhd, the encoder

- What is a bubble, physically? Why does real silicon produce them?
- Why would searching for the first 1-to-0 transition give the wrong answer?
- How does counting ones make the result immune to a bubble anywhere in the vector?
- What does the polarity signal in tb_lbc do, and why does the encoder need it?

## tdc_ringosc.vhd, the online calibration reference

- Why does a carry chain's delay drift at all? What physically changes?
- How does a free-running ring oscillator act as a proxy for that drift?
- Draw the calibration loop. Where does the ring oscillator frequency enter the maths?

## tdc_channelbank_single.vhd, folding calibration back in

- Where does the measured histogram become a lookup table?
- What is g_EXHIS_COUNT for, and why are guard bits needed before the division?

## ordertaps.py, why taps need reordering

- Why are the carry chain taps not already in time order?
- What goes wrong in the DNL plot if they are left unordered?

## The diagram

One picture of the whole data path: hit in, carry chain, sampling flip-flops, encoder,
coarse counter, calibration LUT, timestamp out. Hand-drawn is fine. Photograph it and
commit the photo.
