-- Exhaustive test of tdc_encoder.
--
-- Sweeps the edge across every tap position, then corrupts each clean vector with bubbles
-- and checks the answer does not move. Exhaustive here is cheap and worth it: this is the
-- kind of coverage that is trivial in simulation and impossible on hardware, where you
-- cannot choose where the bubbles land.

library ieee;
use ieee.std_logic_1164.all;

entity tb_encoder is
    generic(
        g_TAPS : positive := 64
    );
end entity;

architecture tb of tb_encoder is

signal clk  : std_logic := '0';
signal taps : std_logic_vector(g_TAPS-1 downto 0) := (others => '0');
signal bin  : natural range 0 to g_TAPS;
signal done : boolean := false;

begin
    dut: entity work.tdc_encoder
        generic map(g_TAPS => g_TAPS)
        port map(clk_i => clk, taps_i => taps, bin_o => bin);

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
        variable v : std_logic_vector(g_TAPS-1 downto 0);

        procedure apply(pattern : std_logic_vector; expect : natural; what : string) is
        begin
            taps <= pattern;
            wait until rising_edge(clk);
            wait for 1 ns;
            assert bin = expect
                report what & ": expected " & integer'image(expect)
                     & ", got " & integer'image(bin)
                severity failure;
        end procedure;
    begin
        for p in 0 to g_TAPS loop
            -- Clean thermometer code: the edge has reached tap p, so taps 0 to p-1 are set.
            v := (others => '0');
            for i in 0 to p-1 loop
                v(i) := '1';
            end loop;
            apply(v, p, "clean edge at " & integer'image(p));

            -- A bubble is a swap across the transition, because the sampling flip-flops
            -- near the edge resolve in different orders. A swap conserves the number of
            -- ones, so the answer must not move. The swaps accumulate as k grows, which
            -- makes this a test of several simultaneous bubbles rather than just one.
            for k in 0 to 2 loop
                if p-1-k >= 0 and p+k <= g_TAPS-1 then
                    v(p-1-k) := '0';
                    v(p+k)   := '1';
                    apply(v, p, integer'image(k+1) & " bubble(s) at edge "
                                & integer'image(p));
                end if;
            end loop;
        end loop;

        report "Test passed.";
        done <= true;
        wait;
    end process;
end architecture;
