--  GUENEGO
--
library ieee;
  use ieee.std_logic_1164.all;      -- defines std_logic types
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity tb_dsmod2 is
  end entity;

architecture tb_arch of tb_dsmod2 is

  signal clk             : std_logic := '0'; -- 100MHz
  signal rst             : boolean := false; -- reset synchrone � la lib�ration, asynchrone � l'assertion

  signal clk_ce_in       : boolean := false; -- clock enable en entr�e, 2.5MHz
  signal data_in         : signed(17 downto 0) := (others => '0'); -- sur-�chantillon filtr� @ 2.5MHz

  signal data_out        : std_logic; -- sortie du modulateur


  begin

 -- component instantiation
  uut: entity work.dsmod2
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in, data_in => data_in,
      data_out => data_out
      );

 -- clock generation
  process
    variable cpt1,cpt2,cpt3 : integer;
    begin
    clk <= '0';
    clk_ce_in <= false;
    cpt1:=0;
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
      cpt1:=cpt1+1;
      if (cpt1=40) then
        clk_ce_in <= true after 1 ns, false after 11 ns; -- 2.5MHz
        cpt1:=0;
        end if;
      end loop;
    end process;

 -- signal 10kHz @2.5MHz
  process
    variable a : real;
    begin
    a := 0.0;
    data_in <= to_signed(0,data_in'length);
    loop
      wait until clk_ce_in and rising_edge(clk);
      a:=a+2.0*MATH_PI*100.0/2500000.0; -- 10kHz phase en radians
      data_in <= to_signed(integer(ROUND(131000.0*SIN(a))),data_in'length);
      end loop;
    end process;


 -- main process
  process
    begin

    wait until clk'event and clk='1'; wait for 1 ns;

    wait for 100 ns;

    wait for 21000 us; -- 21 periodes � 10kHz


    assert (false) report  "Simulation ended." severity failure;

    end process;

  end architecture;
