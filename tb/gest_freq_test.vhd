--
--  gest_freq_test.vhd, rev 1.00, 15/11/2020
--  rev 1.00 : version initiale.
--
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
  signal clk_gain         : boolean;

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

 -- instanciation du composant � tester
  uut: entity work.gest_freq
    port map
      (
      clk => clk, rst => rst,
      clk_mic_pin => clk_mic_pin,
      clk_mic => clk_mic, clk_int => clk_int, clk_ech => clk_ech,
      clk_gain => clk_gain
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
