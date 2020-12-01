library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity decode_amp is
    generic( n : integer := 6 ); -- nombre de bits du signal de sortie
    Port ( 
        CLK100MHZ  : in std_logic;
        CPU_RESETN : in std_logic;
        
        clk_ech : in std_logic;
        ech : in signed (n-1 downto 0);
        
        AUD_PWM : out std_logic
    );
end decode_amp;

architecture rtl of decode_amp is

    signal cpt : unsigned (n-1 downto 0);
    
    signal convert : unsigned (n-1 downto 0);
    
begin

    process(CLK100MHZ)
    begin
        if ( rising_edge (CLK100MHZ) ) then
        
            convert <= resize (unsigned( resize( signed(ech) ,n+1) + to_signed(2**n/2,n+1) ), n) ;
        
            if ( (CPU_RESETN = '0') OR (clk_ech = '1') ) then
                cpt <= to_unsigned(0,n);
            else
                cpt <= cpt + to_unsigned(1,n);
            end if;
            
            if (cpt < convert) then
                AUD_PWM <= '1';
            else
                AUD_PWM <= '0';
            end if;
        end if;
    end process;    

end rtl;
