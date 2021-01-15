-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TOP_ENTITY is
    port (
      CLK100MHZ  : in std_logic;
      CPU_RESETN : in std_logic;

      SW : in std_logic_vector (15 downto 0);
      LED : out std_logic_vector (15 downto 0);

      M_CLK   : out std_logic;
      M_DATA  : in std_logic;
      M_LRSEL : out std_logic;

      AUD_PWM : out std_logic;
      AUD_SD  : out std_logic
      );
end entity;

architecture rtl of TOP_ENTITY is

    signal clk  : std_logic;

    signal rsts : unsigned(3 downto 0) := (others => '0');
    signal rst : boolean;
    signal rst2 : boolean;
    signal rst_buf  : boolean;
    
    signal clk_mic : boolean; -- 2.5MHz
    signal clk_int : boolean; -- 312.5kHz
    signal clk_ech : boolean; -- 39.0625kHz

    signal data_mic : std_logic := '0';
    signal dac_out : std_logic;
    signal audio_out : std_logic := '0';
    signal LED_audio_out : std_logic := '0';
    signal LED_auto_vol : std_logic := '0';
    signal LED_reverb : std_logic := '0';    
    signal SW0ss, SW0s : std_logic := '0'; -- synchro
    signal SW15ss, SW15s : std_logic := '0'; -- synchro
    signal SW14ss, SW14s : std_logic := '0'; -- synchro

    signal ech_0 : signed (17 downto 0);
    signal ech_1 : signed (17 downto 0);
    signal ech_2 : signed (17 downto 0);
    signal ech_3 : signed (17 downto 0);
    
    signal ech_fin : signed (17 downto 0);

    

begin

  clk <= CLK100MHZ;

  process(clk)
    begin  -- reset synchrone. rsts démarre à 0000 à la mise sous tension
    if rising_edge(clk) then
      rsts <= rsts(rsts'high-1 downto 0) & CPU_RESETN;
      rst_buf <= (rsts(rsts'high)='0');
      rst <= rst_buf;
    end if;
  end process;

  gf: entity work.gest_freq
    port map
      (
      clk => clk, rst => rst,
      clk_mic_pin => M_CLK,
      clk_mic => clk_mic,
      clk_int => clk_int,
      clk_ech => clk_ech
      );

  process(clk)
    begin
    if rising_edge(clk) then
      if clk_mic then
        data_mic <= M_DATA;
      end if;
    end if;
  end process;


  M_LRSEL <= '0'; -- sélectionne micro left
  acq_mic : entity work.acq_mic -- module d'acquisition du micro
    port map
      (
      clk  => clk,
      rst => rst,

      clk_mic => clk_mic, -- 2.5 MHz
      data_mic => data_mic,
      clk_int => clk_int, -- 312.5 kHz
      clk_ech => clk_ech, -- 39062.5 Hz
      
      ech_out => ech_0
      );

  
  -- début traitement du signal ech_0 (18bits 39062.5kHz)

  autoVol : entity work.auto_vol 
    port map (
              clk => clk,
              rst => rst,
              
              clk_ce_in => clk_ech,
              ech_in => ech_0,
              
              ech_out => ech_1
              );
    process (clk) -- on choisi le volumme automatique avec SW(15)
    begin
    if (rising_edge(clk)) then
    SW15ss <= SW15s; SW15s <= SW(15); -- synchro
      if clk_ech then
        if SW15ss='1' then
          ech_2 <= ech_1;
          LED_auto_vol <= '1';
        else
          ech_2 <= ech_0;
          LED_auto_vol <= '0';
        end if;
      end if;
      LED(15) <= LED_auto_vol;
    end if;
    end process;
    

    
    
    reverb : entity work.reverb
        port map (
          CLK100MHZ => clk,
          CPU_RESETN => rst,
          clk_ech => clk_ech,
          ech_in => ech_2,
          ech_out => ech_3
          );   
    process (clk) -- on choisi la reverb on ou off avec SW(14)
    begin
    if (rising_edge(clk)) then
    SW14ss <= SW14s; SW14s <= SW(14); -- synchro
      if clk_ech then
        if SW14ss='1' then
          ech_fin <= ech_3;
          LED_reverb <= '1';
        else
          ech_fin <= ech_2;
          LED_reverb <= '0';
        end if;
      end if;
      LED(14) <= LED_reverb;
    end if;
    end process;
    
  -- fin du traitement du signal (18bits 39062.5kHz), début de la modulation

  se1: entity work.mod_out -- module modulation du signal
    port map
      (
      clk => clk,
      rst => rst,
      clk_ech => clk_ech,
      ech_in => ech_fin,
      clk_int => clk_int,
      clk_mic => clk_mic,
      PDM_out => dac_out
      );

  -- ampli audio, on choisi soit le micro soit le signal modulé selon SW(0)
  AUD_SD <= '1';
  process(clk)
    begin
    if rising_edge(clk) then
      SW0ss <= SW0s; SW0s <= SW(0); -- synchro
      if clk_mic then
        if SW0ss='1' then
          audio_out <= dac_out;
          LED_audio_out <= '1';
        else
          audio_out <= data_mic;
          LED_audio_out <= '0';
        end if;
        AUD_PWM <= audio_out; -- bascule D dans IO
        LED(0) <= LED_audio_out;
      end if;
    end if;
  end process;

end architecture;
