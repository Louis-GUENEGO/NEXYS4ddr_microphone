library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity acq_mic_111_64 is
    generic( n : integer := 6 ); -- nombre de bits du signal de sortie
    Port ( 
        CLK100MHZ  : in std_logic;
        CPU_RESETN : in std_logic;
        M_DATA : in std_logic;
        
        clk_mic_sync : in std_logic;
        clk_ech : in std_logic;
        
        ech : out signed (n-1 downto 0);
        
        PDM : out std_logic
    );
end acq_mic_111_64;

architecture rtl of acq_mic_111_64 is

    signal sig_PDM : std_logic;
    
    signal cpt_PDM : unsigned (n-1 downto 0);
    signal sig_ech : unsigned (n-1 downto 0);
    
begin

    
    process (CLK100MHZ) -- syncronisation de PDM
    begin
        if (rising_edge(CLK100MHZ)) then
            if ( clk_mic_sync = '1' ) then
                sig_PDM <= M_DATA;
            else
                sig_PDM <= sig_PDM;
            end if;
        end if;
    end process;
    
    process (CLK100MHZ) -- echantillonage de PDM
    begin
        if (rising_edge(CLK100MHZ)) then
            if ( CPU_RESETN = '0' ) then
                cpt_PDM <= TO_UNSIGNED (0,n);
                sig_ech <= TO_UNSIGNED (0,n);
            else
                if ( (clk_ech = '1') ) then
                    sig_ech <= cpt_PDM;
                    cpt_PDM <= TO_UNSIGNED (0,n);
                elsif ( clk_mic_sync = '1' ) then
                    if (M_DATA = '1') then
                        cpt_PDM <= cpt_PDM + TO_UNSIGNED (1,n);
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    PDM <= sig_PDM;
    ech <= resize ( signed(resize(sig_ech,n+1)) - to_signed(2**n/2,n+1), n) ;

end rtl;
