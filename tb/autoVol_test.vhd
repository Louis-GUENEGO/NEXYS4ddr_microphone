-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_autoVol is
end entity;

architecture tb_arch of tb_autoVol is

   signal clk  : std_logic; -- 100MHz
   signal rst  : boolean;

   signal clk_ce_in : boolean; -- clock enable en entree, 39.0625kHz
   signal ech_in : signed(17 downto 0);

   signal ech_out : signed(17 downto 0);

  begin

 -- component instantiation
autoVol : entity work.auto_vol 
    port map (
              clk => clk,
              rst => rst,
              
              clk_ce_in => clk_ce_in,
              ech_in =>ech_in,
              
              ech_out => ech_out
              );

 -- clock generation
 process
    variable cpt1 : integer;
 begin
    clk_ce_in <= false;
    cpt1:=0;
    loop
      wait for 10 ns;  -- 100MHz
      clk <= '1', '0' after 5 ns;
        cpt1:=cpt1+1;
        if (cpt1=2560) then
            cpt1:=0;
            clk_ce_in <= true after 1 ns, false after 11 ns;
        end if;
    end loop;
 end process;
 
 -- signal 10kHz
  process
    variable a : real;
    variable temps : integer;
  begin
    a := 0.0;
    temps := 0;
    ech_in <= to_signed(0,ech_in'length);
    loop
      wait until clk_ce_in and rising_edge(clk);
      a:=a+2.0*MATH_PI*100.0/39062.5; -- 1kHz phase en radians
      temps := temps + 1;
      if temps < 600 then
        ech_in <= to_signed(integer(ROUND(32768.0*SIN(a))),ech_in'length);
      elsif temps < 2900 then
        ech_in <= to_signed(integer(ROUND(10000.0*SIN(a))),ech_in'length);
      else
        ech_in <= to_signed(integer(ROUND(90000.0*SIN(a))),ech_in'length);
      end if;
    end loop;
  end process;

 -- main process
  process
    begin
    rst <= true;
    wait for 50 ns;
    rst <= false;


    wait for 150000000 ns;

    assert (false) report  "Simulation ended." severity failure;

    end process;

  end architecture;
