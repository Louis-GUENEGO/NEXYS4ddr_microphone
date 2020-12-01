--
--  gest_freq.vhd, rev 1.00, 15/11/2020
--
--  rev 1.00 : version initiale.
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- g�n�ration des horloges
--
-- en interne, on n'utilise qu'une seule horloge � 100MHz, les sous-fr�quences utilisent les "clock enable" des bascules D
--   cela simplifie la gestion des synchronisation des horloges/signaux en limitant le nombre d'horloge � 1
--
-- clk               \_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�\_/�
--
-- clk_mic_pin       ______/�������\_______/�������\_______/�������\_______/�������\_  ( /40 en r�alit�)
-- clk_mic           ____/�\_____________/�\_____________/�\_____________/�\_________  (pour �chantillonnage DATA1 au front montant de clk_mig_pin)
--                      ---^            ---^                                           ( point d'�chantillonnage)
-- clk_int           ____/�\_____________________________/�\_________________________  ( /8 en r�alit� )
-- clk_ech           ____________________________________/�\_________________________  ( /64 en r�alit� )


entity gest_freq is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone � la lib�ration, asynchrone � l'assertion

    clk_mic_pin  : out std_logic := '0';  -- 2.5MHz ( /40 )

    clk_mic  : out boolean; -- top � 2.5MHz ( /40 )
    clk_int : out boolean; -- top � 312.5kHz  ( /8 )
    clk_ech  : out boolean  -- top � 39.0625kHz ( /8 )
    );
  end entity;

architecture rtl of gest_freq is


  -- integer avec �tendue limit�e: rend plus lisible l'�criture du code,
  --   le compilateur en d�duit automatiquement le nombre de bit n�cessaire
  --   la v�rification par le simulateur est plus stricte.
  signal cpt_clk_mic : integer range 0 to 39 := 0; -- 100MHz => 2.5MHz (/40)
  signal cpt_clk_int : integer range 0 to 7 := 0; -- 2.5MHz => 312.5kHz (/8)
  signal cpt_clk_ech : integer range 0 to 39 := 0; -- 312.5kHz => 39.0625kHz (/8)

  signal clk_mic_pin1 : std_logic := '0'; -- retard clk_mic d'un coup d'horloge, permet de mettre la bascule D finale dans l'IO
   -- et permet de bien �chantillon� le signal d'entr�e au front montant de clk_pin (pas 1 coup d'horloge = 10ns apr�s)


  begin

  process (clk, rst)

    begin

    if rising_edge(clk) then

      if (cpt_clk_mic = 39) then -- /40
        cpt_clk_mic <= 0;
      else
        cpt_clk_mic <= cpt_clk_mic + 1;
        end if;

      if (cpt_clk_mic < 20) then  -- rapport cyclique 50%
        clk_mic_pin1 <= '1';
      else
        clk_mic_pin1 <= '0';
        end if;
      clk_mic_pin <= clk_mic_pin1; -- Bascule D dans IO et synchro avec clk_mic interne


      clk_mic <= false;
      clk_int <= false;
      clk_ech <= false;

      if (cpt_clk_mic = 0) then

        clk_mic <= true;

        if (cpt_clk_int = 7) then -- /8
          cpt_clk_int <= 0;
        else
          cpt_clk_int <= cpt_clk_int + 1;
          end if;

        if (cpt_clk_int = 0)  then

          clk_int <= true;

          if (cpt_clk_ech = 7)  then -- /8
            cpt_clk_ech <= 0;
          else
            cpt_clk_ech <= cpt_clk_ech + 1;
            end if;

          if (cpt_clk_ech = 0)  then -- /8
            clk_ech <= true;
            end if;

          end if;

        end if;

      end if; -- clk

    if rst then
      cpt_clk_mic <= 0;
      cpt_clk_int <= 0;
      cpt_clk_ech <= 0;
      clk_mic_pin1 <= '0';
      end if;

    end process;

  end architecture;
