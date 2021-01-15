-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- pour sinus

entity tb_fir2 is
end entity;

architecture tb_arch of tb_fir2 is

  signal clk             : std_logic := '0'; -- 100MHz
  signal rst             : boolean := false; -- reset synchrone � la lib�ration, asynchrone � l'assertion

  signal clk_ce_in1      : boolean := false; -- clock enable en entr�e, 2.5MHz
  signal data_in1        : std_logic := '0'; -- PDM data en entr�e 0 ou 1 modul� sigma delta

  signal clk_ce_in2      : boolean := false; -- clock enable en entr�e, 312.5kHz
  signal data_in2        : signed(17 downto 0); -- echantillon interm�diaire, provenant de fir1

  signal clk_ce_out      : boolean := false; -- clock enable decimation 312.5Hz/8 = 39.0625kHz, se produit en m�me temps que clk_ce_in
  signal ech_out         : signed(17 downto 0); -- echantillon d�cim�s en sortie, 18bits sign�, valide lorsque clk_ce_out est actif

  signal data_in_ana : integer;

begin

 -- component instantiation
  uut1: entity work.fir1
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in1, data_in => data_in1,
      clk_ce_out => clk_ce_in2, ech_out => data_in2
      );

 -- component instantiation
  uut2: entity work.fir2
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in2, data_in => data_in2,
      clk_ce_out => clk_ce_out, ech_out => ech_out
      );


 -- clock generation
  process
    variable cpt1,cpt2,cpt3 : integer;
    begin
    clk <= '0';
    clk_ce_in1 <= false;
    clk_ce_in2 <= false;
    clk_ce_out <= false;
    cpt1:=0;
    cpt2:=0;
    cpt3:=0;
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
      cpt1:=cpt1+1;
      if (cpt1=40) then
        clk_ce_in1 <= true after 1 ns, false after 11 ns; -- 2.5MHz
        cpt1:=0;
        cpt2:=cpt2+1;
        if (cpt2=8) then
          clk_ce_in2 <= true after 1 ns, false after 11 ns; -- 312.5kHz
          cpt2:=0;
          cpt3:=cpt3+1;
          if (cpt3=8) then
            clk_ce_out <= true after 1 ns, false after 11 ns; -- 39.0625kHz
            cpt3:=0;
          end if;
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
    data_in_ana <= 0;
    loop
      wait until clk_ce_in1 and rising_edge(clk);
      a:=a+2.0*MATH_PI*10000.0/2500000.0; -- 1kHz phase en radians
      ana:=0.9*SIN(a);
      acc:=acc+ana;
      if acc>=0.0 then
        data_in1 <= '1';
        acc:=acc - (+1.0);
      else
        data_in1 <= '0';
        acc:=acc - (-1.0);
      end if;
      data_in_ana <= integer(ROUND(1000.0*ana));
    end loop;
  end process;


 -- main process
  process
    begin

    wait until clk'event and clk='1'; wait for 1 ns;

    wait for 30 us; -- latence fir1
    wait for 408 us; -- latence fir2
    wait for 2100 us; -- 2,1 periode � 1kHz


    wait for 100 ns;

    assert (false) report  "Simulation ended." severity failure;

  end process;

end architecture;
