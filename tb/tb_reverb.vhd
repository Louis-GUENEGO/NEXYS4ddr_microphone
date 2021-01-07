library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_reverb is
end entity;

architecture tb_arch of tb_reverb is

   signal CLK100MHZ  : std_logic; -- 100MHz
   signal CPU_RESETN  : boolean;

   signal clk_ech : boolean; -- clock enable en entree, 39.0625kHz
   signal ech_in : signed(17 downto 0);
   signal ech_out : signed(17 downto 0);

  begin

 -- component instantiation
autoVol : entity work.reverb 
    port map (
              CLK100MHZ => CLK100MHZ,
              CPU_RESETN => CPU_RESETN,
              
              clk_ech => clk_ech,
              ech_in =>ech_in,
              
              ech_out => ech_out
              );

 -- clock generation
 process
    variable cpt1 : integer;
 begin
    clk_ech <= false;
    cpt1:=0;
    loop
      wait for 10 ns;  -- 100MHz
      CLK100MHZ <= '1', '0' after 5 ns;
        cpt1:=cpt1+1;
        if (cpt1=2560) then
            cpt1:=0;
            clk_ech <= true after 1 ns, false after 11 ns;
        end if;
    end loop;
 end process;
 
 -- signal 10kHz
  process
    variable a : real;
    variable b : real;
    variable temps : integer;
  begin
    a := 0.0;
    b := 0.0;
    temps := 0;
    ech_in <= to_signed(0,ech_in'length);
    loop
      wait until clk_ech and rising_edge(CLK100MHZ);
      a:=a+2.0*MATH_PI*100.0/39062.5; -- 100Hz phase en radians
      b:=b+2.0*MATH_PI*250.0/39062.5; -- 1kHz phase en radians
      temps := temps + 1;
      if temps < 3000 then
        ech_in <= to_signed( integer( ROUND( 30000.0*SIN(a) + 30000.0*SIN(b) ) ),ech_in'length);
      else
        ech_in <= to_signed(integer(ROUND(131000.0*SIN(a))),ech_in'length);
      end if;
    end loop;
  end process;

 -- main process
  process
    begin
    CPU_RESETN <= true;
    wait for 50 ns;
    CPU_RESETN <= false;


    wait for 100000000 ns;

    assert (false) report  "Simulation ended." severity failure;

    end process;

  end architecture;
