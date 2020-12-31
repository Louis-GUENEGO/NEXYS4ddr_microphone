library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- modulateur delta-sigma d'ordre 2  (voir Understanding Delta-Sigma Data Converter, Richard Schreier & Gabor C. Temes page 90)
--
--  (data_in) X(z)  18bits sign�---> + ---------(U(z))----------> 1 bit troncation ----------> Y(z) (data_out)
--                                   ^                     |     (sort soit -2^17       |
--                                   |                     |      soit +2^17            |
--                                   |                     v                            v
--                                   --- H1(z) <-(-E(z))-- + --(*-1)---------------------
--
--                                    H1(z) = z^-1 (2 - z^-1) = 2*z^-1 - z^2
--
--                                  on note d1 le registre impl�ment� par le delai z^-1
--                                    et d2 le registre apr�s le 2�me d�lai.
--                            H(z) est un delai d1, suivi d'une somme de 2 fois d1 et -d2, d2 �tant un nouveau delai apr�s d1
--
--                            les equations sont donc :
--                               u := x + 2*d1 - d2      (variable puisque pas de d�lai)
--                               y := 2^17 si u>=0 sinon -2^17 ( troncation = DAC 1bit)
--                               d1 <= u - y    (registre puisque delai)
--                               d2 <= d1       (registre puisque delai)
--
--                             pour �viter les d�bordements, on ajoute plein de bits � u, d1, d2 et y (soit 32 bits sign�s...)
--                             on pourrait aussi saturer d1 et d2.
--
--
-- E est l'erreur due � la conversion 1 bit (1 bit troncation)
--
-- usuellement, on d�crit le signal de sortie Y = U + E, U le signal d'entr�e (de la troncation) et E �tant l'erreur.
--     sur le dessin on fait U - Y , c'est donc -E en entr�e de H1(z).
--
--
-- l'�quation du circuit est U(z) = Y(z) - E(z) (suivant d�finition de E ci-dessus)
--                           U(z) = X(z) + ( H1(z) * -E(z) ) ( �quation suivant le circuit dessin�)
--                    soit Y - E = X - H1*E, Y = X + (1-H1)*E
--
--                      Y(z) = X(z) + ( 1 - H1(z) ) * E (z)
--
--   on choisit H1(z) de mani�re � minimiser l'erreur E(z) dans la bande passante,
--    donc en essayant de rejeter l'ensemble du bruit equivalent dans les haute fr�quence,
--    qui sera filtr� par le filtre analogique externe (ou par le haut-parleur)
--
--   le plus simple consiste � utiliser H1(z) = z^-1, (un simple delai).  (modulateur ordre 1)
--        ici on utilise un modulateur d'ordre 2
--


entity dsmod2 is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone

    clk_ce_in : in boolean; -- clock enable en entr�e, 2.5MHz
    data_in : in signed(17 downto 0); -- sur-�chantillon filtr� @ 2.5MHz

    data_out : out std_logic := '0' -- sortie du modulateur
    );
  end entity;

architecture rtl of dsmod2 is

  signal x : signed(17 downto 0) := (others => '0'); -- entree (buffer)
  signal d1 : signed(23 downto 0) := (others => '0'); -- sortie premier "int�grateur"
  signal d2 : signed(23 downto 0) := (others => '0'); -- sortie deuxieme integrateur

  begin

  process (clk, rst)
    variable u : signed(23 downto 0); -- signal avant la truncation 
    variable y : signed(23 downto 0); -- sortie (reconvertie en PCM)
    variable e : signed(23 downto 0); -- erreur (avant les integrateurs)
    begin

    if rising_edge(clk) then

      if clk_ce_in then

        x <= data_in;

        u := x + shift_left(d1,1) - d2;  -- x + 2*d1 - d2

        if (u>=0) then
          data_out <= '1';
          y := to_signed(2**17,y'length);
        else
          data_out <= '0';
          y := to_signed(-2**17,y'length);
        end if;

        e := u - y; -- (-e l'erreur)
        if (e>=2**21) then -- saturation positive
          d1 <= to_signed(2**21-1,d1'length);
        elsif (e<=-2**21) then -- saturation negative
          d1 <= to_signed(-2**21+1,d1'length);
        else
          d1 <= e;
        end if;
       -- d1 <= u - y;

        d2 <= d1;

      end if;


    end if; -- clk

    if rst then
      d1 <= (others => '0');
      d2 <= (others => '0');
      data_out <= '0';
    end if;
  end process;

end architecture;
