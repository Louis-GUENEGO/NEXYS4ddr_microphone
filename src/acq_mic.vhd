-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity acq_mic is
    port (
      clk  : in std_logic;
      rst : in boolean;

      clk_mic : in boolean; -- 2.5 MHz
      data_mic : in std_logic;
      clk_int : in boolean; -- 312.5 kHz
      clk_ech : in boolean; -- 39062.5 Hz
      
      ech_out : out signed (17 downto 0)
      );
end entity;

architecture rtl of acq_mic is

    signal ech_fir : signed (17 downto 0);

begin



  fir1: entity work.fir1
    port map -- decimation : premier filtre fir
      (
      clk => clk,
      rst => rst,
      clk_ce_in => clk_mic,
      data_in => data_mic,
      clk_ce_out => clk_int,
      ech_out => ech_fir
      );

  fir2: entity work.fir2
    port map -- decimation : second filtre fir
      (
      clk => clk,
      rst => rst,
      clk_ce_in => clk_int,
      data_in => ech_fir,
      clk_ce_out => clk_ech,
      ech_out => ech_out
      );

end architecture;
