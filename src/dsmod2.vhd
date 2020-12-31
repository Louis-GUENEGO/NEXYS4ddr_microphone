library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- modulateur delta-sigma d'ordre 2  (voir Understanding Delta-Sigma Data Converter, Richard Schreier & Gabor C. Temes page 90)
--
--  (data_in) X(z)  18bits signé---> + ---------(U(z))----------> 1 bit troncation ----------> Y(z) (data_out)
--                                   ^                     |     (sort soit -2^17       |
--                                   |                     |      soit +2^17            |
--                                   |                     v                            v
--                                   --- H1(z) <-(-E(z))-- + --(*-1)---------------------
--
--                                    H1(z) = z^-1 (2 - z^-1) = 2*z^-1 - z^2
--
--                                  on note d1 le registre implémenté par le delai z^-1
--                                    et d2 le registre après le 2ème délai.
--                            H(z) est un delai d1, suivi d'une somme de 2 fois d1 et -d2, d2 étant un nouveau delai après d1
--
--                            les equations sont donc :
--                               u := x + 2*d1 - d2      (variable puisque pas de délai)
--                               y := 2^17 si u>=0 sinon -2^17 ( troncation = DAC 1bit)
--                               d1 <= u - y    (registre puisque delai)
--                               d2 <= d1       (registre puisque delai)
--
--                             pour éviter les débordements, on ajoute plein de bits à u, d1, d2 et y (soit 32 bits signés...)
--                             on pourrait aussi saturer d1 et d2.
--
--
-- E est l'erreur due à la conversion 1 bit (1 bit troncation)
--
-- usuellement, on décrit le signal de sortie Y = U + E, U le signal d'entrée (de la troncation) et E étant l'erreur.
--     sur le dessin on fait U - Y , c'est donc -E en entrée de H1(z).
--
--
-- l'équation du circuit est U(z) = Y(z) - E(z) (suivant définition de E ci-dessus)
--                           U(z) = X(z) + ( H1(z) * -E(z) ) ( équation suivant le circuit dessiné)
--                    soit Y - E = X - H1*E, Y = X + (1-H1)*E
--
--                      Y(z) = X(z) + ( 1 - H1(z) ) * E (z)
--
--   on choisit H1(z) de manière à minimiser l'erreur E(z) dans la bande passante,
--    donc en essayant de rejeter l'ensemble du bruit equivalent dans les haute fréquence,
--    qui sera filtré par le filtre analogique externe (ou par le haut-parleur)
--
--   le plus simple consiste à utiliser H1(z) = z^-1, (un simple delai).  (modulateur ordre 1)
--        ici on utilise un modulateur d'ordre 2
--


entity dsmod2 is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone

    clk_ce_in : in boolean; -- clock enable en entrée, 2.5MHz
    data_in : in signed(17 downto 0); -- sur-échantillon filtré @ 2.5MHz

    data_out : out std_logic := '0' -- sortie du modulateur
    );
  end entity;

architecture rtl of dsmod2 is

  signal x : signed(17 downto 0) := (others => '0'); -- entree (buffer)
  signal d1 : signed(23 downto 0) := (others => '0'); -- sortie premier "intégrateur"
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
