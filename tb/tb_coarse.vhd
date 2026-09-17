-- Exhaustive test of the coarse/fine boundary arbitration.
--
-- Sweeps the hit across every tap position of three consecutive clock periods, including
-- both quarter-period decision boundaries and the wrap at the end of each period, and
-- requires the reconstructed coarse value to be the true period index every time.
--
-- This is the case that is trivial here and close to impossible on hardware. On silicon you
-- cannot place a hit at a chosen picosecond offset from a clock edge on demand, so the
-- boundary cases arrive at random and rarely, and a polarity error hides for hours before
-- showing up as a single nanosecond-scale outlier. Here every case is visited by
-- construction.
--
-- The testbench encodes the contract the two counters are built to: coarse_r holds n
-- throughout period n, and coarse_f, ticking half a period later, still holds n-1 until the
-- half-way point. The assertion is against the true period index n, which is ground truth
-- and independent of the arbitration under test, so a backwards polarity fails here rather
-- than passing consistently with a matching mistake.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_coarse is
    generic(
        g_WIDTH : positive := 16;
        g_TAPS_PER_PERIOD : positive := 60
    );
end entity;

architecture tb of tb_coarse is

signal clk      : std_logic := '0';
signal reset    : std_logic := '0';
signal coarse_r : unsigned(g_WIDTH-1 downto 0) := (others => '0');
signal coarse_f : unsigned(g_WIDTH-1 downto 0) := (others => '0');
signal fine     : natural range 0 to g_TAPS_PER_PERIOD := 0;
signal coarse   : unsigned(g_WIDTH-1 downto 0);
signal done     : boolean := false;

begin
    dut: entity work.tdc_coarse
        generic map(g_WIDTH => g_WIDTH, g_TAPS_PER_PERIOD => g_TAPS_PER_PERIOD)
        port map(clk_i => clk, reset_i => reset,
                 coarse_r_i => coarse_r, coarse_f_i => coarse_f,
                 fine_i => fine, coarse_o => coarse);

    process
    begin
        while not done loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    process
        constant c_TPP : natural := g_TAPS_PER_PERIOD;
    begin
        for n in 1 to 3 loop
            -- step is where in period n the hit landed, in taps from the rising edge that
            -- opened the period. step = 0 is exactly on that edge.
            for step in 0 to c_TPP-1 loop
                -- The delay line is stopped by the next rising edge, so fine counts taps
                -- from the hit forward to it. A hit early in the period gives a large fine.
                fine <= c_TPP - step;
                coarse_r <= to_unsigned(n, g_WIDTH);
                if step < c_TPP / 2 then
                    coarse_f <= to_unsigned(n - 1, g_WIDTH);
                else
                    coarse_f <= to_unsigned(n, g_WIDTH);
                end if;

                wait until rising_edge(clk);
                wait for 1 ns;

                assert coarse = to_unsigned(n, g_WIDTH)
                    report "period " & integer'image(n)
                         & ", step " & integer'image(step)
                         & " (fine " & integer'image(c_TPP - step) & "):"
                         & " expected coarse " & integer'image(n)
                         & ", got " & integer'image(to_integer(coarse))
                    severity failure;
            end loop;
        end loop;

        report "Test passed.";
        done <= true;
        wait;
    end process;
end architecture;
