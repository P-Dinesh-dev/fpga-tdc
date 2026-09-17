-- Thermometer-to-binary encoder for the carry chain taps.
--
-- Counts every one in the latched vector rather than measuring the leading run.
--
-- The physical bubble is a local reordering, not a random bit error: the hit edge lands
-- between two taps, and adjacent sampling flip-flops resolve in different orders, so bits
-- near the transition come out swapped. A swap moves a one from one position to another
-- and leaves the total untouched, so a popcount is exactly invariant under it. That is a
-- stronger guarantee than "usually right" - it holds for any permutation of the vector.
--
-- m-labs/tdc-core takes the other route (tdc_lbc.vhd, count leading ones by divide and
-- conquer over halves). That is pure OR logic with no adders, which is the right call on a
-- Spartan-6. It is not invariant under a swap that straddles the transition: 1110100000
-- has a leading run of 3 but four ones, and four is the better answer. We have LUTs to
-- spare on a 7-series and care more about the bin being right than about area, so we pay
-- for the adder tree.
--
-- Not pipelined. At 250 MHz over a few hundred taps the adder tree may not close timing,
-- but guessing how many stages it needs before Vivado has reported a single number would
-- be inventing a problem. Add stages when the timing report asks for them.

library ieee;
use ieee.std_logic_1164.all;

entity tdc_encoder is
    generic(
        -- Taps on the delay line. taps_i(0) is nearest the carry-in, so the edge fills
        -- the vector from the bottom up and the count is the bin number directly.
        g_TAPS : positive
    );
    port(
        clk_i  : in  std_logic;
        taps_i : in  std_logic_vector(g_TAPS-1 downto 0);
        bin_o  : out natural range 0 to g_TAPS
    );
end entity;

architecture rtl of tdc_encoder is
begin
    process(clk_i)
        variable v_ones : natural range 0 to g_TAPS;
    begin
        if rising_edge(clk_i) then
            v_ones := 0;
            for i in taps_i'range loop
                if taps_i(i) = '1' then
                    v_ones := v_ones + 1;
                end if;
            end loop;
            bin_o <= v_ones;
        end if;
    end process;
end architecture;
