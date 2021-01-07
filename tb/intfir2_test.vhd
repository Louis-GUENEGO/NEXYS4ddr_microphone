library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_intfir2 is
end entity;

architecture tb_arch of tb_intfir2 is

  signal clk             : std_logic := '0'; -- 100MHz
  signal rst             : boolean := false; -- reset synchrone � la lib�ration, asynchrone � l'assertion

  signal clk_ce_in       : boolean := false; -- clock enable en entr�e, 312.5kHz
  signal data_in         : signed(17 downto 0) := (others => '0'); -- echantillon interm�diaire, provenant de fir1

  signal clk_ce_out      : boolean := false; -- clock enable oversampling 312.5*8 = 2.5MkHz, se produit en m�me temps que clk_ce_in (1 fois / 8)
  signal ech_out         : signed(17 downto 0); -- �chantillon sur-�chantillonn� filtr� en sortie, 18bits sign�, valide lorsque clk_ce_out est actif


  signal data_in_ana : integer;

  signal clk_ce_in1       : boolean := false; -- clock enable en entr�e, 39.0625kHz
  signal ech_int          : signed(17 downto 0) := (others => '0'); -- sur-�chantillon interm�diaire, provenant de intfir1

  begin

 -- component instantiation
  uut1: entity work.intfir1
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in1, data_in => data_in,
      clk_ce_out => clk_ce_in, ech_out => ech_int
      );

  uut: entity work.intfir2
    port map
      (
      clk => clk, rst => rst,
      clk_ce_in => clk_ce_in, data_in => ech_int,
      clk_ce_out => clk_ce_out, ech_out => ech_out
      );


 -- clock generation
  process
    variable cpt1,cpt2,cpt3 : integer;
    begin
    clk <= '0';
    clk_ce_out <= false;
    clk_ce_in <= false;
    clk_ce_in1 <= false;
    cpt1:=0;
    cpt2:=0;
    cpt3:=0;
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
      cpt1:=cpt1+1;
      if (cpt1=40) then
        clk_ce_out <= true after 1 ns, false after 11 ns; -- 2.5MHz
        cpt1:=0;
        cpt2:=cpt2+1;
        if (cpt2=8) then
          clk_ce_in <= true after 1 ns, false after 11 ns; -- 312.5kHz
          cpt2:=0;
          cpt3:=cpt3+1;
          if (cpt3=8) then
            clk_ce_in1 <= true after 1 ns, false after 11 ns; -- 39.0625kHz
            cpt3:=0;
          end if;
        end if;
      end if;
    end loop;
  end process;

 -- signal 10kHz
  process
    variable a : real;
    begin
    a := 0.0;
    data_in <= to_signed(0,data_in'length);
    loop
      wait until clk_ce_in1 and rising_edge(clk);
      a:=a+2.0*MATH_PI*10000.0/39062.5; -- 10kHz phase en radians
      data_in <= to_signed(integer(ROUND(100000.0*SIN(a))),data_in'length);
      end loop;
    end process;


 -- main process
  process
    begin

    wait until clk'event and clk='1'; wait for 1 ns;

    wait for 395 us; -- latence fir
    wait for 2100 us; -- 21 periodes � 10kHz


    wait for 100 ns;

    assert (false) report  "Simulation ended." severity failure;

    end process;

  end architecture;
