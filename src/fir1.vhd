-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- premier filtre FIR pour la décimation
--
-- filtre FIR passe-bas et décimateur par 8
-- on passe de 2.5MHz à 312.5kHz avec un filtre FIR passe bas anti-repliement synthétisé avec
--   Iowa Hills FIR Filter Designer Version 7.0, freeware
--   Sampling Freq 2500000
--   Fc = 0,05 (62.5kHz)
--   Kaiser Beta 10, Window Kaiser
--   raised cosine = 1 (rectangle)
--   128 taps (=coefficients)
--   0..-0.03dB jusqu'à 25kHz et <-90dB après 140kHz (Fs/2=312.5kHz/2 => 156.25kHz pour satisfaire critère de Shannon)
--
-- Les coefficients réels sont normalisés à 2^19 et arrondi à l'entier signé le plus proche (donc 1+15bits signé).
--   Le plus petit coefficient vaut 2,66E-6 soit 11 une fois normalisé.
--   Le plus grand coefficient vaut 0.0584 soit 30652 une fois normalisé, ce qui tient sur 16bits signés.
--    (avec Excel et copiés coller ici. Iowa Hills FIR Filter Designer Version 7.0 est utilisé aussi pour vérifier que l'arrondi des coefficients
--      ne dégrade pas le filtre, en rechargeant les coefficient normalisé et arrondi)).
-- le résultat final ramené à 18bits signé.
-- Les échantillons du microphone valent 0 ou 1, considérés ici comme -1 et +1 pour supprimer l'offset de 0.5.
--   Si un échantillon PDM vaut 0, alors on soustrait le coefficient
--   Si un échantillon PDM vaut 1, alors on ajoute le coefficient
--

entity fir1 is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone

    clk_ce_in : in boolean; -- clock enable en entrée, 2.5MHz
    data_in : in std_logic; -- PDM data en entrée 0 ou 1 modulé sigma delta

    clk_ce_out : in boolean; -- clock enable decimation 2.5MHz/8 = 312.5kHz, se produit en même temps que clk_ce_in
    ech_out : out signed(17 downto 0) := (others => '0') -- echantillon décimés en sortie, 18bits signé,valide lorsque clk_ce_out est actif
    );
  end entity;

architecture rtl of fir1 is

-- FIR filter coefficients:
  type coef_mem_t is array (natural range <>) of signed(15 downto 0);
  signal coef_mem : coef_mem_t(0 to 128-1) := (
-- FIR low pass filter généré avec Iowa Hills FIR Filter Designer Version 7.0 - Freeware
-- Sampling Freq=2500000  , Fc=0.05 (62.5kHz), Num Taps=128, Kaiser Beta=10, Window Kaiser, 1,000 Rectangle 73.17kHz
-- Normalisation de coefficient à 2^19 et arrondi à l'entier le plus proche
-- (controle du filtre par rechargement des coefficient dans Iowa Hills FIR Filter Designer => pas de différence à l'oeil nu.
-- note: le filtre est symétrique, coef(0) = coef(127), coef(1) = coef(126) ... coef(63)=coef(64)
    0   => to_signed( -1      , 16),
    1   => to_signed( -3      , 16),
    2   => to_signed( -5      , 16),
    3   => to_signed( -7      , 16),
    4   => to_signed( -10     , 16),
    5   => to_signed( -13     , 16),
    6   => to_signed( -17     , 16),
    7   => to_signed( -20     , 16),
    8   => to_signed( -22     , 16),
    9   => to_signed( -23     , 16),
    10  => to_signed( -21     , 16),
    11  => to_signed( -15     , 16),
    12  => to_signed( -4      , 16),
    13  => to_signed( 13      , 16),
    14  => to_signed( 37      , 16),
    15  => to_signed( 68      , 16),
    16  => to_signed( 108     , 16),
    17  => to_signed( 154     , 16),
    18  => to_signed( 208     , 16),
    19  => to_signed( 266     , 16),
    20  => to_signed( 325     , 16),
    21  => to_signed( 383     , 16),
    22  => to_signed( 433     , 16),
    23  => to_signed( 471     , 16),
    24  => to_signed( 491     , 16),
    25  => to_signed( 484     , 16),
    26  => to_signed( 445     , 16),
    27  => to_signed( 367     , 16),
    28  => to_signed( 244     , 16),
    29  => to_signed( 72      , 16),
    30  => to_signed( -151    , 16),
    31  => to_signed( -425    , 16),
    32  => to_signed( -747    , 16),
    33  => to_signed( -1110   , 16),
    34  => to_signed( -1503   , 16),
    35  => to_signed( -1912   , 16),
    36  => to_signed( -2319   , 16),
    37  => to_signed( -2701   , 16),
    38  => to_signed( -3033   , 16),
    39  => to_signed( -3287   , 16),
    40  => to_signed( -3434   , 16),
    41  => to_signed( -3445   , 16),
    42  => to_signed( -3289   , 16),
    43  => to_signed( -2939   , 16),
    44  => to_signed( -2373   , 16),
    45  => to_signed( -1572   , 16),
    46  => to_signed( -522    , 16),
    47  => to_signed( 781     , 16),
    48  => to_signed( 2333    , 16),
    49  => to_signed( 4124    , 16),
    50  => to_signed( 6131    , 16),
    51  => to_signed( 8325    , 16),
    52  => to_signed( 10666   , 16),
    53  => to_signed( 13108   , 16),
    54  => to_signed( 15599   , 16),
    55  => to_signed( 18080   , 16),
    56  => to_signed( 20491   , 16),
    57  => to_signed( 22769   , 16),
    58  => to_signed( 24856   , 16),
    59  => to_signed( 26693   , 16),
    60  => to_signed( 28230   , 16),
    61  => to_signed( 29423   , 16),
    62  => to_signed( 30238   , 16),
    63  => to_signed( 30652   , 16),
    64  => to_signed( 30652   , 16),
    65  => to_signed( 30238   , 16),
    66  => to_signed( 29423   , 16),
    67  => to_signed( 28230   , 16),
    68  => to_signed( 26693   , 16),
    69  => to_signed( 24856   , 16),
    70  => to_signed( 22769   , 16),
    71  => to_signed( 20491   , 16),
    72  => to_signed( 18080   , 16),
    73  => to_signed( 15599   , 16),
    74  => to_signed( 13108   , 16),
    75  => to_signed( 10666   , 16),
    76  => to_signed( 8325    , 16),
    77  => to_signed( 6131    , 16),
    78  => to_signed( 4124    , 16),
    79  => to_signed( 2333    , 16),
    80  => to_signed( 781     , 16),
    81  => to_signed( -522    , 16),
    82  => to_signed( -1572   , 16),
    83  => to_signed( -2373   , 16),
    84  => to_signed( -2939   , 16),
    85  => to_signed( -3289   , 16),
    86  => to_signed( -3445   , 16),
    87  => to_signed( -3434   , 16),
    88  => to_signed( -3287   , 16),
    89  => to_signed( -3033   , 16),
    90  => to_signed( -2701   , 16),
    91  => to_signed( -2319   , 16),
    92  => to_signed( -1912   , 16),
    93  => to_signed( -1503   , 16),
    94  => to_signed( -1110   , 16),
    95  => to_signed( -747    , 16),
    96  => to_signed( -425    , 16),
    97  => to_signed( -151    , 16),
    98  => to_signed( 72      , 16),
    99  => to_signed( 244     , 16),
    100 => to_signed( 367     , 16),
    101 => to_signed( 445     , 16),
    102 => to_signed( 484     , 16),
    103 => to_signed( 491     , 16),
    104 => to_signed( 471     , 16),
    105 => to_signed( 433     , 16),
    106 => to_signed( 383     , 16),
    107 => to_signed( 325     , 16),
    108 => to_signed( 266     , 16),
    109 => to_signed( 208     , 16),
    110 => to_signed( 154     , 16),
    111 => to_signed( 108     , 16),
    112 => to_signed( 68      , 16),
    113 => to_signed( 37      , 16),
    114 => to_signed( 13      , 16),
    115 => to_signed( -4      , 16),
    116 => to_signed( -15     , 16),
    117 => to_signed( -21     , 16),
    118 => to_signed( -23     , 16),
    119 => to_signed( -22     , 16),
    120 => to_signed( -20     , 16),
    121 => to_signed( -17     , 16),
    122 => to_signed( -13     , 16),
    123 => to_signed( -10     , 16),
    124 => to_signed( -7      , 16),
    125 => to_signed( -5      , 16),
    126 => to_signed( -3      , 16),
    127 => to_signed( -1      , 16)
           );

  signal coef_out : signed(15 downto 0);
  signal coef_out_reg : signed(15 downto 0);

  -- mémoire circulaire pour garder les 128 derniers échantillons
  type data_in_mem_t is  array (natural range <>) of std_logic;
  signal data_in_mem : data_in_mem_t(0 to 128-1) :=
    (  -- preinit à 0, donc alternance de 1 / 0 (0 vaut -1, 1 vaut 1...)
    1 => '1', 3 => '1', 5 => '1', 7 => '1', 9 => '1', 11 => '1', 13 => '1', 15 => '1', 17 => '1', 19 => '1',
    21 => '1', 23 => '1', 25 => '1', 27 => '1', 29 => '1', 31 => '1', 33 => '1', 35 => '1', 37 => '1', 39 => '1',
    41 => '1', 43 => '1', 45 => '1', 47 => '1', 49 => '1', 51 => '1', 53 => '1', 55 => '1', 57 => '1', 59 => '1',
    61 => '1', 63 => '1', 65 => '1', 67 => '1', 69 => '1', 71 => '1', 73 => '1', 75 => '1', 77 => '1', 79 => '1',
    81 => '1', 83 => '1', 85 => '1', 87 => '1', 89 => '1', 91 => '1', 93 => '1', 95 => '1', 97 => '1', 99 => '1',
    101 => '1', 103 => '1', 105 => '1', 107 => '1', 109 => '1', 111 => '1', 113 => '1', 115 => '1', 117 => '1', 119 => '1',
    121 => '1', 123 => '1', 125 => '1', 127 => '1',
    others => '0'
    );

  signal data_out : std_logic;
  signal data_out_reg : std_logic;

  signal ptr_in : unsigned(6 downto 0) := (others => '0'); -- pointeur d'entrée des échantillons
  signal ptr_out : unsigned(6 downto 0) := (others => '0'); -- pointeur de calcul du filtre
  signal ptr_out_reg : unsigned(6 downto 0) := (others => '0'); -- pointeur de calcul du filtre
  signal ptr_coef : unsigned(6 downto 0) := (others => '0'); -- pointeur des coefficients
  signal ptr_coef_reg : unsigned(6 downto 0); -- pointeur des coefficients

  signal cpt : integer range 0 to 127+10; -- index machine d'état de calcul du filtre, 128 + init pipeline & normalisation / saturation résultat

  signal acc : signed(20 downto 0) := (others => '0'); -- les coef sont normalisés à 2^19, et le gain est de 2^19 (environ à cause des arrondi)
    -- on ajoute un bit de signe + 1 bit pour être sûr qu'il n'y ait pas de débordement
    -- la somme des valeurs absolues des coef vaut 663982, = 19,34bits, il faut donc 20bits+signe=21bits


  begin

  process (clk)

    begin

    if rising_edge(clk) then

      if clk_ce_in then -- memorisation des echantillons en entree
        data_in_mem(to_integer(ptr_in)) <= data_in; -- remplie la mémoire circulaire avec les échantillons en entrée
        ptr_in <= ptr_in + 1; -- incrémentation du pointeur
      end if;

      if (clk_ce_out and (cpt=0)) then -- on va démarrer le filtre décimateur. note: clk_ce_out se produit en même temps que clk_ce_in, 1 fois sur 8,
        cpt <= cpt + 1; -- 40*8 cycles = 320cycles à 100MHz. Le filtre consomme 130 sur 320 cycles environ.
        ptr_out <= ptr_in + 1;  -- démarre avec l'échantillon le plus ancien pour éviter qu'il ne soit écrasé avant qu'on l'ait utilisé...
        ptr_coef <= to_unsigned(127,ptr_coef'length); -- commence par le dernier (on pourrait aussi commence par le premier vu que le filtre est symétrique)
        acc <= (others => '0');
      end if;

      if (cpt /= 0) then -- on initialise le pipeline quand cpt<4, puis on fait tourner la machine
        cpt <= cpt + 1;
        ptr_out <= ptr_out + 1; -- etape 1 du pipeline
        ptr_coef <= ptr_coef - 1; -- on consulte les coefficiant dans l'ordre decroissant
      end if;

      if (cpt>=4) and (cpt<128+4) then -- on accumule une fois le pipeline lancé
        if data_out_reg='0' then
          acc <= acc - coef_out_reg; -- -1 * coef
        else
          acc <= acc + coef_out_reg; -- +1 * coef
          end if;
      elsif (cpt=128+4) then -- fin de la décimation, normalisation par 19-17=2bits et gestion de la potentielle saturation
        if (acc(acc'high downto 2) < -2**17) then -- saturation negative
          ech_out <= to_signed(-2**17,ech_out'length);
        elsif (acc(acc'high downto 2) > 2**17 - 1) then -- saturation positive
          ech_out <= to_signed(2**17 - 1,ech_out'length);
        else
          ech_out <= acc(17+2 downto 2); -- on met 16 bits sur les 18 de l'acumulateur
          end if;
        cpt <= 0; -- fin du FIR décimateur, prêt pour la prochaine décimation
      end if;

      ptr_out_reg <= ptr_out; -- bufferise les adresses et les data en sortie pour fréquence max ! (etape 2 du pipeline)
      data_out <= data_in_mem(to_integer(ptr_out_reg)); -- on n'est pas à un ou 2 coup d'horloge prêt et on a plein de bascules D. (etape 3 du pipeline)
      data_out_reg <= data_out; -- (etape 4 du pipeline)

      ptr_coef_reg <= ptr_coef; -- (etape 2 du pipeline des coefficiants)
      coef_out <= coef_mem(to_integer(ptr_coef_reg)); -- (etape 3 du pipeline des coefficiants)
      coef_out_reg <= coef_out; -- (etape 4 du pipeline des coefficiants)

      if rst then
          ptr_in <= (others => '0');
          cpt <= 0;
          ech_out <= to_signed(0,ech_out'length);
      end if;

    end if; -- clk
    

  end process;

  end architecture;


