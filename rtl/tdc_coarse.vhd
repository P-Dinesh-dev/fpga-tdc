-- Coarse counter with dual-edge capture, and the arbitration that picks between them.
--
-- The problem this exists to solve is the worst failure mode in the whole instrument. The
-- hit is asynchronous to the clock, so when it arrives within a setup window of a clock
-- edge, a coarse counter captured on that edge may return either the old value or the new
-- one. Getting it wrong is not a small error - it is one entire clock period, nanoseconds,
-- on a device whose whole purpose is picoseconds.
--
-- The fix is to capture two counters half a period apart. One runs on the rising edge and
-- changes at t = nT; the other runs on the falling edge and changes at t = (n+0.5)T. A hit
-- can be close to at most one of those, so at least one capture is always clean. The fine
-- value says where in the period the hit landed, which is exactly what is needed to know
-- which capture to trust.
--
-- Writing down the polarity from first principles is easy to get backwards, so the
-- arbitration below is checked exhaustively in tb/tb_coarse.vhd by sweeping the hit across
-- several clock periods in sub-tap steps and requiring the reconstructed timestamp to stay
-- monotonic. A polarity error shows up there as a jump of one full period.
--
-- The alternative is a Gray-coded counter, where only one bit changes at a time so a
-- metastable capture can only ever yield n or n+1. It is not obviously worse. It is not
-- used here because the dual-edge version makes the ambiguity explicit rather than relying
-- on an encoding property, and explicit is easier to test.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tdc_coarse is
    generic(
        g_WIDTH : positive;
        -- Taps spanning one clock period. Sets where the quarter-period decision
        -- boundaries fall, so it must match the delay line actually fitted.
        g_TAPS_PER_PERIOD : positive
    );
    port(
        clk_i     : in  std_logic;
        reset_i   : in  std_logic;

        -- Captured on the hit, one from each clock edge.
        coarse_r_i : in  unsigned(g_WIDTH-1 downto 0);
        coarse_f_i : in  unsigned(g_WIDTH-1 downto 0);
        -- Taps between the hit and the sampling edge, so a small value means the hit
        -- arrived late in the period.
        fine_i     : in  natural range 0 to g_TAPS_PER_PERIOD;

        coarse_o   : out unsigned(g_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of tdc_coarse is
    constant c_QUARTER       : natural := g_TAPS_PER_PERIOD / 4;
    constant c_THREE_QUARTER : natural := 3 * g_TAPS_PER_PERIOD / 4;
begin
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                coarse_o <= (others => '0');
            elsif fine_i > c_THREE_QUARTER then
                -- Hit landed just after a rising edge, so the rising capture is the
                -- suspect one. The falling counter has not ticked yet this period.
                coarse_o <= coarse_f_i + 1;
            elsif fine_i < c_QUARTER then
                -- Hit landed just before a rising edge. Rising capture is suspect again,
                -- and the falling counter has already ticked.
                coarse_o <= coarse_f_i;
            else
                -- Hit is in the middle of the period, nowhere near a rising edge.
                coarse_o <= coarse_r_i;
            end if;
        end if;
    end process;
end architecture;
