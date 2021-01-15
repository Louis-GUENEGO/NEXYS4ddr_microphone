-- GUENEGO Louis
-- ENSEIRB-MATMECA, Electronique 2A, 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- surechantilloneur / filtre x8
--
-- 1) le signal est surechantillonné par un facteur x8 (on ajoute 7 echantillons à 0 intermédiaire)
-- 2) on filtre (FIR passe bas) de manière à reconstruire le signal suréchantilloné parfaitement, en supprimant
--      la répétition de spectre due au suréchantillonnage
--
-- Le filtre FIR passe-bas comporte 256-8 = 248 échantillons, de manière à ce que la mémoire circulaire contienne 32 échantillons
--  (c'est plus facile pour les pointeurs circulaire, pas besoin de tester le débordement)
--
-- Comme 7/8 échantillons valent 0, on peut ne faire qu'une multiplication toute les 8 (le résultat des autres vaut 0 évidemment)
--
-- Dans l mémoire circulaire, on ne stocke que 1ech/8 soit 32 au total, (les autres valent 0, pas besoin de les stocker)
--
-- On produit à chaque insertion d'un nouvel échantillon dans la mémoire circulaire 8 sur échantillons filtrés en sortie
--   en faisant 248 multiplications coef*ech. (31 par sur-échantillon)
--
-- Ici on parcourt le filtre à partir de l'échantillon le + récent (on sur-échantillonne, les 8 sur-échantillons doivent être produit avant le prochain ech)
--  On incrémente les indices des échantillons (et donc des coef)
--  On produit d'abord le sur-échantillon le plus ancien (le n-7) jusqu'au plus récent. Le plus récent utilise l'échantillon le plus récent (ici 31),
--  donc les autres commencent un peu avant et donc vont utiliser en premier l'échantillon n-1 (ici 30)
--    (rappel: les sur-échantillons à 0 ne sont pas calculés ni stockés, ils sont virtuels...)
--
--   ech   31 . . . . . . . 30 . . . . . . . 29 . . . . . . . 28 .  (...)   . 1 . . . . . . 0 . . . . . . .  (les . sont les 0 insérés virtuellement)
--     (le + recent)                                                                (le + ancien)
--  (ici on indique les coef à utuliser pour chaque sur échantillon filtré)
--  sef-7                  0 1  2 3 4         9               17             233           241     246 247 -
--  sef-6                0 1 2  3 4          10               18             234           242     247  -  -
--
--  sef-1     0 1 2 3 4 5 6  7               15               23             239           247 - - - - - - -
--  sef-0   0 1 2 3 4 5 6 7  8               16               24             240       247  -  - - - - - - -
--
-- On voit que le calcul des sur-échantillons filtrés -7 à -1 démarre à l'échantillon 30 (ech-1) et vont jusqu'à l'échantillon 0
--   tandis que le sur-échantillon filtré le plus récente (0) démarre à l'échantillon 31 (ech-0) et va jusqu'à l'échantillon 1.
--
-- On voit que si l'on avait pris un filtre avec 256 coefficients (le même que fir1), alors il aurait fallu faire une mémoire circulaire sur 33
-- échantillons, mais alors les pointeurs sont moins faciles à gérer (le retour à 0 n'est pas simple alors qu'il l'est avec une puissance de 2)
--
-- On vise un multiplieur 18x18 signé, donc des nombres jusqu'à +/-2^17-1
--  C'est le cas des échantillons en entrée, est aussi des coefficients grâce à une normalisation adéquate (2^20)
--  les sur-echantillons filtrés ont néanmoins besoin d'un facteur x8, puisqu'on a étalé la puissance sur tout le spectre puis filtré, ce qui
--  enlève 7/8 de la puissance en coupant toutes les réplications de spectre.
--
--
-- Au final le calcul de chaque sur-échantillon prend 31 cycles + la latence de mise en route du pipeline, (6-7 clock) et on n'utilise
--   qu'un seul multiplieur cablé (block DSP48) et un seul accumulateur.
--
-- filtre FIR passe-bas et décimateur par 8
-- il doit parfaitement couper après 39.0625kHz/2 et être plat gain=0dB de 0 à 10kHz environ
--   Iowa Hills FIR Filter Designer Version 7.0, freeware
--   Sampling Freq 312500
--   Fc = 0,09 (14.06kHz)
--   Kaiser Beta 10, Window Kaiser, Rectangle 1,000
--   248 taps (=coefficients)
--   0..-0.03dB jusqu'à 11.75kHz et <-90dB après 19.5kHz
--
--

entity intfir1 is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone

    clk_ce_in : in boolean; -- clock enable en entrée, 39.0625kHz
    data_in : in signed(17 downto 0); -- echantillon intermédiaire, provenant de fir1

    clk_ce_out : in boolean; -- clock enable oversampling 39.0625*8 = 312.5kHz, se produit en même temps que clk_ce_in (1 fois / 8)
    ech_out : out signed(17 downto 0) := (others => '0') -- échantillon sur-échantillonné filtré en sortie, 18bits signé, valide lorsque clk_ce_out est actif
    );
  end entity;

architecture rtl of intfir1 is

-- FIR filter coefficients:
  type coef_mem_t is  array (natural range <>) of signed(17 downto 0);
  signal coef_mem : coef_mem_t(0 to 256-1) := (  -- on n'utilise que 248 coef, mais taille à 256 pour éviter les erreurs en simultation sur index >= 248
-- FIR low pass filter généré avec Iowa Hills FIR Filter Designer Version 7.0 - Freeware
--   Sampling Freq=312500  , Fc=0.09 (14.06kHz), Num Taps=248, Kaiser Beta=10, Window Kaiser, 1,000 Rectangle 14.06kHz
--   Normalisation de coefficient à 2^20 et arrondi à l'entier le plus proche (max abs=98670 = 16.6bit => tient sur 17+1 = 18bits signés)
--   (controle du filtre par rechargement des coefficient dans Iowa Hills FIR Filter Designer => pas de différence à l'oeil nu.
-- note: le filtre est symétrique, coef(0) = coef(247), coef(1) = coef(245) ... coef(123)=coef(124)
    0   => to_signed( -1     , 18),
    1   => to_signed( -2     , 18),
    2   => to_signed( -3     , 18),
    3   => to_signed( -3     , 18),
    4   => to_signed( -3     , 18),
    5   => to_signed( -3     , 18),
    6   => to_signed( -2     , 18),
    7   => to_signed( 0      , 18),
    8   => to_signed( 3      , 18),
    9   => to_signed( 6      , 18),
    10  => to_signed( 10     , 18),
    11  => to_signed( 14     , 18),
    12  => to_signed( 18     , 18),
    13  => to_signed( 20     , 18),
    14  => to_signed( 21     , 18),
    15  => to_signed( 19     , 18),
    16  => to_signed( 15     , 18),
    17  => to_signed( 7      , 18),
    18  => to_signed( -4     , 18),
    19  => to_signed( -18    , 18),
    20  => to_signed( -33    , 18),
    21  => to_signed( -49    , 18),
    22  => to_signed( -63    , 18),
    23  => to_signed( -73    , 18),
    24  => to_signed( -77    , 18),
    25  => to_signed( -74    , 18),
    26  => to_signed( -61    , 18),
    27  => to_signed( -39    , 18),
    28  => to_signed( -8     , 18),
    29  => to_signed( 31     , 18),
    30  => to_signed( 75     , 18),
    31  => to_signed( 120    , 18),
    32  => to_signed( 161    , 18),
    33  => to_signed( 194    , 18),
    34  => to_signed( 212    , 18),
    35  => to_signed( 211    , 18),
    36  => to_signed( 188    , 18),
    37  => to_signed( 141    , 18),
    38  => to_signed( 71     , 18),
    39  => to_signed( -19    , 18),
    40  => to_signed( -123   , 18),
    41  => to_signed( -232   , 18),
    42  => to_signed( -336   , 18),
    43  => to_signed( -423   , 18),
    44  => to_signed( -481   , 18),
    45  => to_signed( -500   , 18),
    46  => to_signed( -471   , 18),
    47  => to_signed( -390   , 18),
    48  => to_signed( -258   , 18),
    49  => to_signed( -79    , 18),
    50  => to_signed( 133    , 18),
    51  => to_signed( 364    , 18),
    52  => to_signed( 592    , 18),
    53  => to_signed( 794    , 18),
    54  => to_signed( 946    , 18),
    55  => to_signed( 1026   , 18),
    56  => to_signed( 1015   , 18),
    57  => to_signed( 904    , 18),
    58  => to_signed( 689    , 18),
    59  => to_signed( 378    , 18),
    60  => to_signed( -10    , 18),
    61  => to_signed( -447   , 18),
    62  => to_signed( -896   , 18),
    63  => to_signed( -1314  , 18),
    64  => to_signed( -1657  , 18),
    65  => to_signed( -1882  , 18),
    66  => to_signed( -1952  , 18),
    67  => to_signed( -1842  , 18),
    68  => to_signed( -1542  , 18),
    69  => to_signed( -1057  , 18),
    70  => to_signed( -415   , 18),
    71  => to_signed( 341    , 18),
    72  => to_signed( 1151   , 18),
    73  => to_signed( 1943   , 18),
    74  => to_signed( 2639   , 18),
    75  => to_signed( 3160   , 18),
    76  => to_signed( 3438   , 18),
    77  => to_signed( 3418   , 18),
    78  => to_signed( 3071   , 18),
    79  => to_signed( 2395   , 18),
    80  => to_signed( 1417   , 18),
    81  => to_signed( 199    , 18),
    82  => to_signed( -1169  , 18),
    83  => to_signed( -2572  , 18),
    84  => to_signed( -3882  , 18),
    85  => to_signed( -4964  , 18),
    86  => to_signed( -5690  , 18),
    87  => to_signed( -5956  , 18),
    88  => to_signed( -5687  , 18),
    89  => to_signed( -4852  , 18),
    90  => to_signed( -3468  , 18),
    91  => to_signed( -1607  , 18),
    92  => to_signed( 606    , 18),
    93  => to_signed( 3002   , 18),
    94  => to_signed( 5377   , 18),
    95  => to_signed( 7507   , 18),
    96  => to_signed( 9164   , 18),
    97  => to_signed( 10143  , 18),
    98  => to_signed( 10274  , 18),
    99  => to_signed( 9448   , 18),
    100 => to_signed( 7628   , 18),
    101 => to_signed( 4865   , 18),
    102 => to_signed( 1298   , 18),
    103 => to_signed( -2847  , 18),
    104 => to_signed( -7262  , 18),
    105 => to_signed( -11582 , 18),
    106 => to_signed( -15399 , 18),
    107 => to_signed( -18298 , 18),
    108 => to_signed( -19880 , 18),
    109 => to_signed( -19798 , 18),
    110 => to_signed( -17786 , 18),
    111 => to_signed( -13684 , 18),
    112 => to_signed( -7456  , 18),
    113 => to_signed( 797    , 18),
    114 => to_signed( 10838  , 18),
    115 => to_signed( 22299  , 18),
    116 => to_signed( 34701  , 18),
    117 => to_signed( 47479  , 18),
    118 => to_signed( 60016  , 18),
    119 => to_signed( 71680  , 18),
    120 => to_signed( 81866  , 18),
    121 => to_signed( 90031  , 18),
    122 => to_signed( 95736  , 18),
    123 => to_signed( 98670  , 18),
    124 => to_signed( 98670  , 18),
    125 => to_signed( 95736  , 18),
    126 => to_signed( 90031  , 18),
    127 => to_signed( 81866  , 18),
    128 => to_signed( 71680  , 18),
    129 => to_signed( 60016  , 18),
    130 => to_signed( 47479  , 18),
    131 => to_signed( 34701  , 18),
    132 => to_signed( 22299  , 18),
    133 => to_signed( 10838  , 18),
    134 => to_signed( 797    , 18),
    135 => to_signed( -7456  , 18),
    136 => to_signed( -13684 , 18),
    137 => to_signed( -17786 , 18),
    138 => to_signed( -19798 , 18),
    139 => to_signed( -19880 , 18),
    140 => to_signed( -18298 , 18),
    141 => to_signed( -15399 , 18),
    142 => to_signed( -11582 , 18),
    143 => to_signed( -7262  , 18),
    144 => to_signed( -2847  , 18),
    145 => to_signed( 1298   , 18),
    146 => to_signed( 4865   , 18),
    147 => to_signed( 7628   , 18),
    148 => to_signed( 9448   , 18),
    149 => to_signed( 10274  , 18),
    150 => to_signed( 10143  , 18),
    151 => to_signed( 9164   , 18),
    152 => to_signed( 7507   , 18),
    153 => to_signed( 5377   , 18),
    154 => to_signed( 3002   , 18),
    155 => to_signed( 606    , 18),
    156 => to_signed( -1607  , 18),
    157 => to_signed( -3468  , 18),
    158 => to_signed( -4852  , 18),
    159 => to_signed( -5687  , 18),
    160 => to_signed( -5956  , 18),
    161 => to_signed( -5690  , 18),
    162 => to_signed( -4964  , 18),
    163 => to_signed( -3882  , 18),
    164 => to_signed( -2572  , 18),
    165 => to_signed( -1169  , 18),
    166 => to_signed( 199    , 18),
    167 => to_signed( 1417   , 18),
    168 => to_signed( 2395   , 18),
    169 => to_signed( 3071   , 18),
    170 => to_signed( 3418   , 18),
    171 => to_signed( 3438   , 18),
    172 => to_signed( 3160   , 18),
    173 => to_signed( 2639   , 18),
    174 => to_signed( 1943   , 18),
    175 => to_signed( 1151   , 18),
    176 => to_signed( 341    , 18),
    177 => to_signed( -415   , 18),
    178 => to_signed( -1057  , 18),
    179 => to_signed( -1542  , 18),
    180 => to_signed( -1842  , 18),
    181 => to_signed( -1952  , 18),
    182 => to_signed( -1882  , 18),
    183 => to_signed( -1657  , 18),
    184 => to_signed( -1314  , 18),
    185 => to_signed( -896   , 18),
    186 => to_signed( -447   , 18),
    187 => to_signed( -10    , 18),
    188 => to_signed( 378    , 18),
    189 => to_signed( 689    , 18),
    190 => to_signed( 904    , 18),
    191 => to_signed( 1015   , 18),
    192 => to_signed( 1026   , 18),
    193 => to_signed( 946    , 18),
    194 => to_signed( 794    , 18),
    195 => to_signed( 592    , 18),
    196 => to_signed( 364    , 18),
    197 => to_signed( 133    , 18),
    198 => to_signed( -79    , 18),
    199 => to_signed( -258   , 18),
    200 => to_signed( -390   , 18),
    201 => to_signed( -471   , 18),
    202 => to_signed( -500   , 18),
    203 => to_signed( -481   , 18),
    204 => to_signed( -423   , 18),
    205 => to_signed( -336   , 18),
    206 => to_signed( -232   , 18),
    207 => to_signed( -123   , 18),
    208 => to_signed( -19    , 18),
    209 => to_signed( 71     , 18),
    210 => to_signed( 141    , 18),
    211 => to_signed( 188    , 18),
    212 => to_signed( 211    , 18),
    213 => to_signed( 212    , 18),
    214 => to_signed( 194    , 18),
    215 => to_signed( 161    , 18),
    216 => to_signed( 120    , 18),
    217 => to_signed( 75     , 18),
    218 => to_signed( 31     , 18),
    219 => to_signed( -8     , 18),
    220 => to_signed( -39    , 18),
    221 => to_signed( -61    , 18),
    222 => to_signed( -74    , 18),
    223 => to_signed( -77    , 18),
    224 => to_signed( -73    , 18),
    225 => to_signed( -63    , 18),
    226 => to_signed( -49    , 18),
    227 => to_signed( -33    , 18),
    228 => to_signed( -18    , 18),
    229 => to_signed( -4     , 18),
    230 => to_signed( 7      , 18),
    231 => to_signed( 15     , 18),
    232 => to_signed( 19     , 18),
    233 => to_signed( 21     , 18),
    234 => to_signed( 20     , 18),
    235 => to_signed( 18     , 18),
    236 => to_signed( 14     , 18),
    237 => to_signed( 10     , 18),
    238 => to_signed( 6      , 18),
    239 => to_signed( 3      , 18),
    240 => to_signed( 0      , 18),
    241 => to_signed( -2     , 18),
    242 => to_signed( -3     , 18),
    243 => to_signed( -3     , 18),
    244 => to_signed( -3     , 18),
    245 => to_signed( -3     , 18),
    246 => to_signed( -2     , 18),
    247 => to_signed( -1     , 18),
    others => to_signed( 0   , 18) -- évite les erreur d'index >=248
           );

  signal coef_out : signed(17 downto 0);
  signal coef_out_reg : signed(17 downto 0);

  -- mémoire circulaire pour garder les 32 derniers échantillons
  type data_in_mem_t is  array (natural range <>) of signed(17 downto 0);
  signal data_in_mem : data_in_mem_t(0 to 32-1) := ( others => to_signed(0,18) ); -- preinit à 0
  signal data_out : signed(17 downto 0);
  signal data_out_reg : signed(17 downto 0);

  signal ptr_in : unsigned(4 downto 0) := (others => '0'); -- pointeur d'entrée des échantillons
  signal ptr_out : unsigned(4 downto 0) := (others => '0'); -- pointeur de calcul du filtres
  signal ptr_out_save : unsigned(4 downto 0) := (others => '0');
  signal ptr_out_last : unsigned(4 downto 0) := (others => '0');
  signal ptr_out_reg : unsigned(4 downto 0) := (others => '0'); -- pointeur de calcul du filtres
  signal ptr_coef : unsigned(7 downto 0) := (others => '0'); -- pointeur des coefficients
  signal ptr_coef_reg : unsigned(7 downto 0); -- pointeur des coefficients

  signal cpt : integer range 0 to 32+10 := 0; -- index machine d'état de calcul du filtre, 128 + init pipeline & normalisation / saturation résultat
  signal cpt_surech : integer range 0 to 7 := 7; -- compte les suréchantillons produits à chque cycle de sortie

  signal acc : signed(18+17 downto 0) := (others => '0'); -- les coef sont normalisés à 2^20, les echantillons à 2^17, on accumule 32x
    -- la somme des valeurs absolues des coef vaut 1824350, = 20,8bits, on ne peut donc pas dépasser 21+17+1 (signe) bits
    -- plus précisement , comme on n'utilise qu'1 coef sur 8, on cherche dans excel (intfir1.xls) le max des valeur absolues
    --   de chacune des séquences de coef en en prenant 1/8.  C'est 232356, soit 17,83 bits, , on ne peut donc pas dépasser 18+17+1 (signe) bits

  signal mul_data_coef : signed(18+18-1 downto 0);  -- sortie du multiplieur
  signal mul_data_coef_reg : signed(18+18-1 downto 0);


  begin

  process (clk)

    begin

    if rising_edge(clk) then

      if clk_ce_in then
        data_in_mem(to_integer(ptr_in)) <= data_in; -- remplie la mémoire circulaire avec les échantillons en entrée
        ptr_in <= ptr_in + 1; -- auto wrapping
      end if;

      if (cpt /= 0) then -- le filtre tourne 8 fois par clk_ce_out
        cpt <= cpt + 1;
        ptr_out <= ptr_out - 1; -- auto wrapping
        ptr_coef <= ptr_coef + 8;
      end if;

      if clk_ce_out then
        cpt <= 1;
        acc <= (others => '0');

        if clk_ce_in then -- démarre le surechantillonneur note: clk_ce_in se produit en même temps que clk_ce_out, 1 fois sur 8,
          ptr_out <= ptr_in - 1;  -- ech-1 (ptr_in n'a pas encore été incrémenté)
          ptr_out_save <= ptr_in - 1;
          ptr_out_last <= ptr_in; -- ech pour le dernier
          ptr_coef <= to_unsigned(1,ptr_coef'length);
          cpt_surech <= 1;
        elsif (cpt_surech>0) then
          ptr_out <= ptr_out_save;  -- ech-1
          ptr_coef <= to_unsigned(cpt_surech,ptr_coef'length); -- commence par le dernier (on pourrait aussi commence par le premier vu que le filtre est symétrique)
        else -- cpt_surech=0 (dernier sur echantillon, en commencant par l'échantillon le plus récent)
          ptr_out <= ptr_out_last;  -- ech pour le dernier
          ptr_coef <= to_unsigned(0,ptr_coef'length); -- commence par le dernier (on pourrait aussi commence par le premier vu que le filtre est symétrique)
        end if;

      end if;

      if (cpt>=6) and (cpt<31+6) then -- on accumule une fois le pipeline lancé
        acc <= acc + mul_data_coef_reg; -- accumulateur
      elsif (cpt=31+6) then -- fin de la décimation, normalisation par 20-3 (coef filtre normalisé par 2^20, mais surechantillonnage par 8
        if (acc(acc'high downto 20-3) < -2**17) then  -- en ajoutant des zéro => perte d'amplitude d'1 facteur 8 après filtrage
          ech_out <= to_signed(-2**17,ech_out'length);
        elsif (acc(acc'high downto 20-3) > 2**17 - 1) then
          ech_out <= to_signed(2**17 - 1,ech_out'length);
        else
          ech_out <= acc(17+20-3 downto 20-3);
        end if;
        if (cpt_surech<7) then cpt_surech <= cpt_surech + 1; else cpt_surech <= 0; end if; -- incrementation du compteur de surechantillonage
        cpt <= 0; -- fin de ce surechantillon, prêt pour le suivant
      end if;

      ptr_out_reg <= ptr_out; -- bufferise les adresses et les data en sortie pour fréquence max !
      data_out <= data_in_mem(to_integer(ptr_out_reg)); -- on n'est pas à un ou 2 coup d'horloge prêt et on a plein de bascules D.
      data_out_reg <= data_out;

      ptr_coef_reg <= ptr_coef;
      coef_out <= coef_mem(to_integer(ptr_coef_reg));
      coef_out_reg <= coef_out;

      mul_data_coef <= data_out_reg * coef_out_reg; -- multiplier 18x18 signé
      mul_data_coef_reg <= mul_data_coef; -- buffer pour vitesse max

      if rst then
        ptr_in <= (others => '0');
        cpt <= 0;
        ech_out <= to_signed(0,ech_out'length);
      end if;

    end if; -- clk
    
  end process;

end architecture;


