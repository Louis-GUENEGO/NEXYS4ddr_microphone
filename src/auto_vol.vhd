library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity auto_vol is
  port(clk  : in std_logic; -- 100MHz
       rst  : in boolean;

       clk_ce_in : in boolean; -- clock enable en entree, 39.0625kHz
       ech_in : in signed(17 downto 0);

       ech_out : out signed(17 downto 0)
      );
end entity;

architecture rtl of auto_vol is

    signal ech_in_reg : signed(17 downto 0);
    signal ech_out_reg : signed(17 downto 0);

    signal gain : signed (17 downto 0);
    signal gain_reg : signed (17 downto 0);
    signal max : signed (17 downto 0); -- maximum

    constant n : integer := 32; -- décrémentation du max à chaque coup d'horloge

begin

process (clk)
begin
    if ( rising_edge(clk) ) then
        if (rst) then
            gain <= to_signed(1024,gain'length);
            max <= to_signed(0,max'length);
            ech_out_reg <= to_signed(0,ech_out_reg'length);
        elsif (clk_ce_in) then
            if (ech_out_reg >= 0) then -- detection du maximum avec ech_out_reg positif
                if (max < ech_out_reg) then
                    max <= ech_out_reg;
                else
                    max <= max - n;
                end if;
            else -- detection du maximum avec ech_out_reg negatif
                if ( max < (- ech_out_reg)) then
                    max <= (- ech_out_reg);
                else
                    max <= max - n;
                end if;
            end if;
            
            
            -- calcul gain
            if (max < TO_SIGNED(2**15,gain'length)) then
                    gain <= gain + to_signed(4,gain'length);--resize ("0000" & gain(17 downto 4),gain'length);
                elsif (max > TO_SIGNED(2**15,gain'length)) then
                    gain <= gain - to_signed(4,gain'length);--resize ("0000" & gain(17 downto 4),gain'length);
            end if;

            if (gain < to_signed(1024,gain_reg'length)) then --saturation négative
                gain_reg <= to_signed(1024,gain_reg'length);
            elsif (gain > to_signed(32767,gain_reg'length)) then --saturation positive
                gain_reg <= to_signed(32767,gain_reg'length);
            else
                gain_reg <= gain;             
            end if;
            
        end if;       
    
        ech_out_reg <= resize ((ech_in_reg * gain_reg), 28) (27 downto 10)  ; -- application du gain
        
        ech_in_reg <= ech_in; -- bufferisation de l'entree
        ech_out <= ech_out_reg; -- bufferisation de la sortie
        
    end if;--clk
end process;

end architecture;
