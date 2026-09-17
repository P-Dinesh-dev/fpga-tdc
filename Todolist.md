# Todolist

Things only Dinesh can do. Everything here is understanding or access, not code.

## Gate 1 exit: answer these from the source

Nine questions. Answer each in `docs/how-it-works.md` in your own words. Do not paste
from the paper. These are interview questions, and the interview version has follow-ups.

Source is in `reference/tdc-core/` after running `sim/run-reference-tb.sh`.

### tdc_lbc.vhd, the encoder

- [ ] What is a bubble, physically? Why does real silicon produce them?
- [ ] Why would searching for the first 1-to-0 transition give the wrong answer?
- [ ] How does counting ones make the result immune to a bubble anywhere in the vector?
- [ ] What does the polarity signal in tb_lbc do, and why does the encoder need it?

### tdc_ringosc.vhd, the online calibration reference

- [ ] Why does a carry chain's delay drift at all? What physically changes?
- [ ] How does a free-running ring oscillator act as a proxy for that drift?
- [ ] Draw the calibration loop. Where does the ring oscillator frequency enter the maths?

### tdc_channelbank_single.vhd

- [ ] Where does the measured histogram become a lookup table?
- [ ] What is g_EXHIS_COUNT for, and why are guard bits needed before the division?

### ordertaps.py

- [ ] Why are the carry chain taps not already in time order?
- [ ] What goes wrong in the DNL plot if they are left unordered?

### The diagram

- [ ] One picture of the whole data path: hit in, carry chain, sampling flip-flops,
      encoder, coarse counter, calibration LUT, timestamp out. Hand-drawn is fine.
      Photograph it and commit the photo.

## Gate 2: board access

The hard blocker. Nothing from Gate 3 onward can start without it.

- [ ] Ask the HOD. Two asks, not one: about 15 hours on a board outside lab hours, and a
      faculty mentor. The mentor matters more - SRFP needs a supervisor, the AMD donation
      route needs a professor to submit it, arXiv may need an endorsement, and every
      application wants a referee.
- [ ] If no: VLSI lab in-charge, separately
- [ ] If no: final-year students currently holding boards for their projects
- [ ] If no: NSRIT (you already have a foot in from HackYatra), GITAM, Andhra University
- [ ] If no: AMD University Program donation, aup@amd.com, professor submits, 1-2 weeks
- [ ] If no: check whether ANITS is a MeitY C2S participant
- [ ] If no: r/FPGA and EEVblog, honestly, as a student without access

Any Xilinx or Altera board works. Basys 3 and Nexys are ideal. Do not turn down an old
Spartan-6 board - that is exactly what tdc-core was written for.

## Gate 15: applications

- [ ] CERN Short-Term Internship, rolling, apply once Gate 6 produces a DNL plot
- [ ] DESY Summer Student, opens around December
- [ ] Science Academies SRFP, needs the mentor from Gate 2
- [ ] GSoC / CERN-HSF
- [ ] Cold emails: VECC Kolkata, BARC Electronics Division, IUAC Delhi, NCRA/GMRT
