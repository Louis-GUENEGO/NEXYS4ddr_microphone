-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fir1 is
end entity;

architecture tb_arch of tb_fir1 is

  signal clk             : std_logic := '0'; -- 100MHz
  signal rst             : boolean := false; -- reset synchrone � la lib�ration, asynchrone � l'assertion

  signal clk_ce_in       : boolean := false; -- clock enable en entr�e, 2.5MHz
  signal data_in         : std_logic := '0'; -- PDM data en entr�e 0 ou 1 modul� sigma delta

  signal clk_ce_out      : boolean := false; -- clock enable decimation 2.5MHz/8 = 312.5kHz, se produit en m�me temps que clk_ce_in
  signal ech_out         : signed(17 downto 0); -- echantillon d�cim�s en sortie, 18bits sign�,valide lorsque clk_ce_out est actif

  signal data_in_ana : signed(17 downto 0);

  begin

 -- component instantiation
  uut: entity work.fir1
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in, data_in => data_in,
      clk_ce_out => clk_ce_out, ech_out => ech_out
      );

 -- clock generation
  process
    variable cpt1,cpt2 : integer;
    begin
    clk <= '0';
    clk_ce_in <= false;
    clk_ce_out <= false;
    cpt1:=0;
    cpt2:=0;
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
      cpt1:=cpt1+1;
      if (cpt1=40) then
        clk_ce_in <= true after 1 ns, false after 11 ns; -- 2.5MHz
        cpt1:=0;
        cpt2:=cpt2+1;
        if (cpt2=8) then
          clk_ce_out <= true after 1 ns, false after 11 ns;
          cpt2:=0;
          end if;
        end if;
      end loop;
    end process;

 -- microphone avec modulateur sigma delta ici 1er ordre
  process
    variable ana,a,acc : real;
    begin
    a := 0.0;
    acc := 0.0;
    data_in_ana <= to_signed(0,data_in_ana'length);
    loop
      wait until clk_ce_in and rising_edge(clk);
      a:=a+2.0*MATH_PI*10000.0/2500000.0; -- 10kHz phase en radians
      ana:=0.9*SIN(a);
      acc:=acc+ana;
      if acc>=0.0 then
        data_in <= '1';
        acc:=acc - (+1.0);
      else
        data_in <= '0';
        acc:=acc - (-1.0);
        end if;
      data_in_ana <= to_signed ( integer(ROUND(10000.0*ana)) , data_in_ana'length);
      end loop;
    end process;


 -- main process
  process
    begin

    wait until clk'event and clk='1'; wait for 1 ns;

    wait for 5 us;
    wait for 1100 us; -- 1 periode � 1kHz


    wait for 100 ns;

    assert (false) report  "Simulation ended." severity failure;

    end process;

  end architecture;
