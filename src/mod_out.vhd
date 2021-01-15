-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mod_out is
    port (
      clk  : in std_logic;
      rst : in boolean;

      clk_ech : in boolean; -- 39062.5 Hz
      ech_in : in signed (17 downto 0);

      clk_int : in boolean; -- 312.5 kHz
      
      clk_mic : in boolean; -- 2.5 MHz
      PDM_out : out std_logic
      );
end entity;

architecture rtl of mod_out is

    signal ech_fir : signed (17 downto 0);
    signal ech_int : signed (17 downto 0);
    signal ech_mod : signed (17 downto 0);

begin



      se1: entity work.intfir1
    port map -- surechantillonneur, x8 (39.0625kHz->312.5kHz)
      (
      clk => clk,
      rst => rst,
      clk_ce_in => clk_ech,
      data_in => ech_in,
      clk_ce_out => clk_int,
      ech_out => ech_int
      );

  se2: entity work.intfir2
    port map -- surechantillonneur, x8 (312.5kHz->2.5MHz)
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_int, data_in => ech_int,
      clk_ce_out => clk_mic, ech_out => ech_mod
      );

  dac: entity work.dsmod2
    port map -- DAC sigma delta modulator
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_mic, data_in => ech_mod,
      data_out => PDM_out
      );

end architecture;
