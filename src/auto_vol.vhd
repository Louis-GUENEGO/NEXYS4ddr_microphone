library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity auto_vol is
  port(clk  : in std_logic; -- 100MHz
       rst  : in boolean;

       clk_ce_in : in boolean; -- clock enable en entrÃ©e, 39.0625kHz
       ech_in : in signed(17 downto 0);

       ech_out : out signed(17 downto 0) := (others => '0')
      );
end entity;

architecture rtl of auto_vol is

    signal ech_in_reg : signed(17 downto 0);
    signal ech_out_reg : signed(17 downto 0);

    signal gain : signed (17 downto 0); -- de 1 a 10
    signal max : signed (17 downto 0); -- maximum

    constant n : integer := 3; -- décrémentation du max à chaque coup d'horloge

begin

    process (clk)
    begin
      if ( rising_edge(clk) ) then
        if (clk_ce_in) then
        
            if (ech_in_reg >= 0) then -- detection du maximum
              if (max < ech_in_reg) then
                  max <= ech_in_reg;
              else
                  if (max >= 0) then -- on decremente le max si on n'a pas d'echantillons superieur
                    max <= max - n;
                  else
                    max <= max + n;
                  end if;
              end if;
            else
              if (max > ech_in_reg) then
                  max <= ech_in_reg;
              else
                  if (max >= 0) then
                    max <= max - n;
                  else
                    max <= max + n;
                  end if;
              end if;
            end if;
    
    
            if (max >= 0) then -- calcul du gain a appliquer
                gain <=  TO_SIGNED(2**16 -1,gain'length) / max;
            else
                gain <= TO_SIGNED(2**16 -1,gain'length) / (- max);
            end if;
    
            if (gain = 0) then -- effet saturation du gain
                gain <= resize (to_signed(1, gain'length), gain'length );
            elsif (gain > 10) then
                gain <= resize (to_signed(10, gain'length), gain'length );
            end if;
    
    
            ech_out_reg <= resize (ech_in_reg * gain, ech_out_reg'length)  ; -- application du gain
    
    
            ech_in_reg <= ech_in; -- bufferisation de l'entree
            ech_out <= ech_out_reg; -- bufferisation de la sortie
          end if;
      end if;
    end process;

end architecture;
