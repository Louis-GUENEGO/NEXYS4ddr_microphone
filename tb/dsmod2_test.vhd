--
--  dsmod2_test.vhd, rev 1.00, 22/11/2020
--  M GUENEGO
--  rev 1.00 : initial version.
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

   -- useful functions to display detailed error message with assert statement.
    -- converts a std_logic into a character
    function str(sl: std_logic) return character is
      variable c: character;
      begin
      case sl is
        when 'U' => c:= 'U'; when 'X' => c:= 'X'; when '0' => c:= '0'; when '1' => c:= '1'; when 'Z' => c:= 'Z';
        when 'W' => c:= 'W'; when 'L' => c:= 'L'; when 'H' => c:= 'H'; when '-' => c:= '-';
       end case;
      return c;
      end;
    -- converts a std_logic_vector into a string (binary base)
    function str(slv: std_logic_vector) return string is
      variable result : string (1 to slv'length);
      variable r : integer;
      begin
      r := 1;
      for i in slv'range loop
        result(r) := str(slv(i)); r := r + 1;
        end loop;
      return result;
      end;
    -- converts an unsigned into a string (binary base)
    function str(uns: unsigned) return string is
      begin return str(std_logic_vector(uns)); end;
    -- converts a boolean into a string
    function str(b: boolean) return string is
      begin if b then return "true"; else return "false"; end if; end;
    -- converts a std_logic_vector into a hex string.
    function strh(slv: std_logic_vector) return string is
      variable hexlen: integer;
      variable longslv : std_logic_vector(63 downto 0) := (others => '0');
      variable hex : string(17 downto 1);
      variable fourbit : std_logic_vector(3 downto 0);
      begin
      hexlen := (slv'length+3)/4;
      longslv(slv'length-1 downto 0) := slv;
      for i in 0 to hexlen-1 loop
        fourbit := longslv(((i*4)+3) downto (i*4));
        case fourbit is
          when "0000" => hex(i+2):='0'; when "0001" => hex(i+2):='1'; when "0010" => hex(i+2):='2'; when "0011" => hex(i+2):='3';
          when "0100" => hex(i+2):='4'; when "0101" => hex(i+2):='5'; when "0110" => hex(i+2):='6'; when "0111" => hex(i+2):='7';
          when "1000" => hex(i+2):='8'; when "1001" => hex(i+2):='9'; when "1010" => hex(i+2):='A'; when "1011" => hex(i+2):='B';
          when "1100" => hex(i+2):='C'; when "1101" => hex(i+2):='D'; when "1110" => hex(i+2):='E'; when "1111" => hex(i+2):='F';
          when "ZZZZ" => hex(i+2):='Z'; when "UUUU" => hex(i+2):='u'; when "XXXX" => hex(i+2):='x'; when "----" => hex(i+2):='-';
          when others => hex(i+2):='?';
          end case;
        end loop;
      hex(1):='h';
      return hex(hexlen+1 downto 1);
      end;
    -- converts an unsigned into a hex string.
    function strh(uns: unsigned) return string is
      begin return strh(std_logic_vector(uns)); end;
    -- converts an integer into a hex string.
    function strh(n: integer) return string is
      begin
      if (n>=0) and (n<256) then return strh(to_unsigned(n,8));
      elsif (n>=256) and (n<65536) then return strh(to_unsigned(n,16));
      else return strh(unsigned(to_signed(n,32)));
        end if;
      end;
    function strh(n: integer; l: integer) return string is -- l=number of digit
      begin return strh(unsigned(to_signed(n,l*4))); end;
    function strd(n: integer) return string is
      begin return integer'image(n); end;

  function to_std_logic(i:boolean) return std_logic is
    begin
    if i then return('1'); else return ('0'); end if;
    end;


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
