-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
  use ieee.std_logic_1164.all;      -- defines std_logic types
  use ieee.numeric_std.all;

entity tb_gest_freq is
  end entity;

architecture tb_arch of tb_gest_freq is

  signal clk             : std_logic := '0'; -- 100MHz
  signal rst             : boolean := false; -- reset synchrone � la lib�ration, asynchrone � l'assertion

  signal clk_mic_pin     : std_logic; -- 2.5MHz ( /40 )

  signal clk_mic         : boolean; -- top � 2.5MHz ( /40 )
  signal clk_int        : boolean; -- top � 312.5kHz  ( /8 )
  signal clk_ech         : boolean; -- top � 39.0625kHz ( /8 )


  begin

 -- instanciation du composant � tester
  uut: entity work.gest_freq
    port map
      (
      clk => clk, rst => rst,
      clk_mic_pin => clk_mic_pin,
      clk_mic => clk_mic, clk_int => clk_int, clk_ech => clk_ech
      );

 -- g�n�ration horloge principale
  process
    begin
    clk <= '0';
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
      end loop;
    end process;

 -- process principal
  process
    begin

    for i in 0 to 3000000 loop

      wait until rising_edge(clk); wait for 1 ns;

      end loop;

    wait for 100 ns;

    assert (false) report  "Simulation terminee." severity failure;

    end process;

  end architecture;
