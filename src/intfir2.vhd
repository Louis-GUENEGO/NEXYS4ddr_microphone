--
--  intfir2.vhd, rev 1.00, 20/11/2020
--
--  rev 1.00 : version initiale.
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- surechantilloneur / filtre x8
--
-- 1) le signal est surechantillonn� par un facteur x8 (on ajoute 7 echantillons � 0 interm�diaire)
-- 2) on filtre (FIR passe bas) de mani�re � reconstruire le signal sur�chantillon� parfaitement, en supprimant
--      la r�p�tition de spectre du au sur�chantillonnage
--
-- Le filtre FIR passe-bas comporte 128-8 = 120 �chantillons, de mani�re � ce que la m�moire circulaire contienne 16 �chantillons
--  (c'est plus facile pour les pointeurs circulaire, pas besoin de tester le d�bordement)
--
-- Comme 7/8 �chantillons valent 0, on peut ne faire qu'une multiplication toute les 8 (le r�sultat des autres vaut 0 �videmment)
--
-- Dans l m�moire circulaire, on ne stocke que 1ech/8 soit 16 au total, (les autres valent 0, pas besoin de les stocker)
--
-- On produit � chaque insertion d'un nouvel �chantillon dans la m�moire circulaire 8 sur �chantillons filtr�s en sortie
--   en faisant 120 multiplications coef*ech. (15 par sur-e�chantillon)
--
-- Ici on parcourt le filtre � partir de l'�chantillon le + r�cent (on sur-�chantillonne, les 8 sur-�chantillons doivent �tre produit avant le prochain ech)
--  On incr�mente les indices des �chantillons (et donc des coef)
--  On produit d'abord le sur-�chantillon le plus ancien (le n-7) jusqu'au plus r�cent. Le plus r�cent utilise l'�chantillon le plus r�cent (ici 15),
--  donc les autres commencent un peu avant et donc vont utiliser en premier l'�chantillon n-1 (ici 14)
--    (rappel: les sur-�chantillons � 0 ne sont pas calcul�s ni stock�s, ils sont virtuels...)
--
--   ech   15 . . . . . . . 14 . . . . . . . 13 . . . . . . . 12 .  (...)   . 1 . . . . . . 0 . . . . . . .  (les . sont les 0 ins�r�s virtuellement)
--     (le + recent)                                                                (le + ancien)
--  (ici on indique les coef � utuliser pour chaque sur �chantillon filtr�)
--  sef-7                  0 1  2 3 4         9               17             105           113     118 119 -
--  sef-6                0 1 2  3 4          10               18             106           114     119  -  -
--
--  sef-1     0 1 2 3 4 5 6  7               15               23             111           119 - - - - - - -
--  sef-0   0 1 2 3 4 5 6 7  8               16               24             112       119  -  - - - - - - -
--
-- On voit que le calcul des sur-�chantillons filtr�s -7 � -1 d�marre � l'�chantillon 14 (ech-1) et vont jusqu'� l'�chantillon 0
--   tandis que le sur-�chantillon filtr� le plus r�cente (0) d�marre � l'�chantillon 15 (ech-0) et va jusqu'� l'�chantillon 1.
--
-- On voit que si l'on avait pris un filtre avec 128 coefficients (le m�me que fir1), alors il aurait fallu faire une m�moire circulaire sur 17
-- �chantillons, mais alors les pointeurs sont moins faciles � g�rer (le retour � 0 n'est pas simple alors qu'il l'est avec une puissance de 2)
--
-- On vise un multiplieur 18x18 sign�, donc des nombres jusqu'� +/-2^17-1
--  C'est le cas des �chantillons en entr�e, est aussi des coefficients gr�ce � une normalisation ad�quate (2^21)
--  les sur-echantillons filtr�s ont n�anmoins besoin d'un facteur x8, puisqu'on a �tal� la puissance sur tout le spectre puis filtr�, ce qui
--  enl�ve 7/8 de la puissance en coupant toutes les r�plications de spectre.
--
--
-- Au final le calcul de chaque sur-�chantillon prend 15 cycles + la latence de mise en route du pipeline, (6-7 clock) et on n'utilise
--   qu'un seul multiplieur cabl� (block DSP48) et un seul accumulateur.
--
-- filtre FIR passe-bas et d�cimateur par 8
-- il doit parfaitement couper apr�s 312.5kHz/2 et �tre plat gain=0dB de 0 � 10kHz environ
--   Iowa Hills FIR Filter Designer Version 7.0, freeware
--   Sampling Freq 2500000
--   Fc = 0,05 (62.5kHz)
--   Kaiser Beta 10, Window Kaiser, Rectangle 1,000
--   120 taps (=coefficients)
--   0..-0.03dB jusqu'� 20kHz et <-90dB apr�s 150kHz
--
--

entity intfir2 is
  port (
    clk  : in std_logic; -- 100MHz
    rst  : in boolean; -- reset synchrone � la lib�ration, asynchrone � l'assertion

    clk_ce_in : in boolean; -- clock enable en entr�e, 312.5kHz
    data_in : in signed(17 downto 0); -- echantillon interm�diaire, provenant de fir1

    clk_ce_out : in boolean; -- clock enable oversampling 312.5*8 = 2.5MkHz, se produit en m�me temps que clk_ce_in (1 fois / 8)
    ech_out : out signed(17 downto 0) := (others => '0') -- �chantillon sur-�chantillonn� filtr� en sortie, 18bits sign�, valide lorsque clk_ce_out est actif
    );
  end entity;

architecture rtl of intfir2 is

-- FIR filter coefficients:
  type coef_mem_t is  array (natural range <>) of signed(17 downto 0);
  signal coef_mem : coef_mem_t(0 to 128-1) := (  -- on n'utilise que 248 coef, mais taille � 256 pour �viter les erreurs en simultation sur index >= 248
-- FIR low pass filter g�n�r� avec Iowa Hills FIR Filter Designer Version 7.0 - Freeware
--   Sampling Freq=2500000  , Fc=0.05 (62.5kHz), Num Taps=120, Kaiser Beta=10, Window Kaiser, 1,000 Rectangle 73.85kHz
--   Normalisation de coefficient � 2^21 et arrondi � l'entier le plus proche (max abs=123750 = 16.92bits => tient sur 17+1 = 18bits sign�s)
--   (controle du filtre par rechargement des coefficient dans Iowa Hills FIR Filter Designer => pas de diff�rence � l'oeil nu.
-- note: le filtre est sym�trique, coef(0) = coef(119), coef(1) = coef(118) ... coef(59)=coef(60)
    0   => to_signed( -8     , 18),
    1   => to_signed( -14    , 18),
    2   => to_signed( -21    , 18),
    3   => to_signed( -29    , 18),
    4   => to_signed( -37    , 18),
    5   => to_signed( -43    , 18),
    6   => to_signed( -44    , 18),
    7   => to_signed( -38    , 18),
    8   => to_signed( -22    , 18),
    9   => to_signed( 9      , 18),
    10  => to_signed( 59     , 18),
    11  => to_signed( 131    , 18),
    12  => to_signed( 228    , 18),
    13  => to_signed( 351    , 18),
    14  => to_signed( 500    , 18),
    15  => to_signed( 671    , 18),
    16  => to_signed( 858    , 18),
    17  => to_signed( 1051   , 18),
    18  => to_signed( 1235   , 18),
    19  => to_signed( 1393   , 18),
    20  => to_signed( 1503   , 18),
    21  => to_signed( 1541   , 18),
    22  => to_signed( 1480   , 18),
    23  => to_signed( 1293   , 18),
    24  => to_signed( 955    , 18),
    25  => to_signed( 445    , 18),
    26  => to_signed( -255   , 18),
    27  => to_signed( -1152  , 18),
    28  => to_signed( -2243  , 18),
    29  => to_signed( -3512  , 18),
    30  => to_signed( -4927  , 18),
    31  => to_signed( -6443  , 18),
    32  => to_signed( -7994  , 18),
    33  => to_signed( -9500  , 18),
    34  => to_signed( -10865 , 18),
    35  => to_signed( -11979 , 18),
    36  => to_signed( -12724 , 18),
    37  => to_signed( -12975 , 18),
    38  => to_signed( -12607 , 18),
    39  => to_signed( -11500 , 18),
    40  => to_signed( -9545  , 18),
    41  => to_signed( -6651  , 18),
    42  => to_signed( -2753  , 18),
    43  => to_signed( 2187   , 18),
    44  => to_signed( 8173   , 18),
    45  => to_signed( 15168  , 18),
    46  => to_signed( 23100  , 18),
    47  => to_signed( 31852  , 18),
    48  => to_signed( 41272  , 18),
    49  => to_signed( 51171  , 18),
    50  => to_signed( 61330  , 18),
    51  => to_signed( 71506  , 18),
    52  => to_signed( 81442  , 18),
    53  => to_signed( 90872  , 18),
    54  => to_signed( 99538  , 18),
    55  => to_signed( 107191 , 18),
    56  => to_signed( 113609 , 18),
    57  => to_signed( 118601 , 18),
    58  => to_signed( 122016 , 18),
    59  => to_signed( 123750 , 18),
    60  => to_signed( 123750 , 18),
    61  => to_signed( 122016 , 18),
    62  => to_signed( 118601 , 18),
    63  => to_signed( 113609 , 18),
    64  => to_signed( 107191 , 18),
    65  => to_signed( 99538  , 18),
    66  => to_signed( 90872  , 18),
    67  => to_signed( 81442  , 18),
    68  => to_signed( 71506  , 18),
    69  => to_signed( 61330  , 18),
    70  => to_signed( 51171  , 18),
    71  => to_signed( 41272  , 18),
    72  => to_signed( 31852  , 18),
    73  => to_signed( 23100  , 18),
    74  => to_signed( 15168  , 18),
    75  => to_signed( 8173   , 18),
    76  => to_signed( 2187   , 18),
    77  => to_signed( -2753  , 18),
    78  => to_signed( -6651  , 18),
    79  => to_signed( -9545  , 18),
    80  => to_signed( -11500 , 18),
    81  => to_signed( -12607 , 18),
    82  => to_signed( -12975 , 18),
    83  => to_signed( -12724 , 18),
    84  => to_signed( -11979 , 18),
    85  => to_signed( -10865 , 18),
    86  => to_signed( -9500  , 18),
    87  => to_signed( -7994  , 18),
    88  => to_signed( -6443  , 18),
    89  => to_signed( -4927  , 18),
    90  => to_signed( -3512  , 18),
    91  => to_signed( -2243  , 18),
    92  => to_signed( -1152  , 18),
    93  => to_signed( -255   , 18),
    94  => to_signed( 445    , 18),
    95  => to_signed( 955    , 18),
    96  => to_signed( 1293   , 18),
    97  => to_signed( 1480   , 18),
    98  => to_signed( 1541   , 18),
    99  => to_signed( 1503   , 18),
    100 => to_signed( 1393   , 18),
    101 => to_signed( 1235   , 18),
    102 => to_signed( 1051   , 18),
    103 => to_signed( 858    , 18),
    104 => to_signed( 671    , 18),
    105 => to_signed( 500    , 18),
    106 => to_signed( 351    , 18),
    107 => to_signed( 228    , 18),
    108 => to_signed( 131    , 18),
    109 => to_signed( 59     , 18),
    110 => to_signed( 9      , 18),
    111 => to_signed( -22    , 18),
    112 => to_signed( -38    , 18),
    113 => to_signed( -44    , 18),
    114 => to_signed( -43    , 18),
    115 => to_signed( -37    , 18),
    116 => to_signed( -29    , 18),
    117 => to_signed( -21    , 18),
    118 => to_signed( -14    , 18),
    119 => to_signed( -8     , 18),
    others => to_signed( 0   , 18) -- �vite les erreur d'index >=120
           );

  signal coef_out : signed(17 downto 0);
  signal coef_out_reg : signed(17 downto 0);

  -- m�moire circulaire pour garder les 32 derniers �chantillons
  type data_in_mem_t is  array (natural range <>) of signed(17 downto 0);
  signal data_in_mem : data_in_mem_t(0 to 16-1) := ( others => to_signed(0,18) ); -- preinit � 0
  signal data_out : signed(17 downto 0);
  signal data_out_reg : signed(17 downto 0);

  signal ptr_in : unsigned(3 downto 0) := (others => '0'); -- pointeur d'entr�e des �chantillons
  signal ptr_out : unsigned(3 downto 0) := (others => '0'); -- pointeur de calcul du filtres
  signal ptr_out_save : unsigned(3 downto 0) := (others => '0');
  signal ptr_out_last : unsigned(3 downto 0) := (others => '0');
  signal ptr_out_reg : unsigned(3 downto 0) := (others => '0'); -- pointeur de calcul du filtres
  signal ptr_coef : unsigned(6 downto 0) := (others => '0'); -- pointeur des coefficients
  signal ptr_coef_reg : unsigned(6 downto 0) := (others => '0'); -- pointeur des coefficients

  signal cpt : integer range 0 to 16+10 := 0; -- index machine d'�tat de calcul du filtre, 128 + init pipeline & normalisation / saturation r�sultat
  signal cpt_surech : integer range 0 to 7 := 7; -- compte les sur�chantillons produits � chque cycle de sortie

  signal acc : signed(19+17 downto 0) := (others => '0'); -- les coef sont normalis�s � 2^21, les echantillons � 2^17, on accumule 32x
    -- la somme des valeurs absolues des coef vaut 2608724, = 21.32bits, on ne peut donc pas d�passer 22+17+1 (signe) bits
    -- plus pr�cisement , comme on n'utilise qu'1 coef sur 8, on cherche dans excel (intfir2.xls) le max des valeur absolues
    --   de chacune des s�quences de coef en en prenant 1/8.  C'est 333251, soit 18.353 bits, , on ne peut donc pas d�passer 19+17+1 (signe) bits

  signal mul_data_coef : signed(18+18-1 downto 0);  -- sortie du multiplieur 18x18 bits sign�s
  signal mul_data_coef_reg : signed(18+18-1 downto 0);


  begin

  process (clk, rst)

    begin

    if rising_edge(clk) then

      if clk_ce_in then
        data_in_mem(to_integer(ptr_in)) <= data_in; -- remplie la m�moire circulaire avec les �chantillons en entr�e
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

        if clk_ce_in then -- d�marre le surechantillonneur note: clk_ce_in se produit en m�me temps que clk_ce_out, 1 fois sur 8,
          ptr_out <= ptr_in - 1;  -- ech-1 (ptr_in n'a pas encore �t� incr�ment�)
          ptr_out_save <= ptr_in - 1;
          ptr_out_last <= ptr_in; -- ech pour le dernier
          ptr_coef <= to_unsigned(1,ptr_coef'length);
          cpt_surech <= 1;
        elsif (cpt_surech>0) then
          ptr_out <= ptr_out_save;  -- ech-1
          ptr_coef <= to_unsigned(cpt_surech,ptr_coef'length); -- commence par le dernier (on pourrait aussi commence par le premier vu que le filtre est sym�trique)
        else -- cpt_surech=0 (dernier sur echantillon, en commencant par l'�chantillon le plus r�cent)
          ptr_out <= ptr_out_last;  -- ech pour le dernier
          ptr_coef <= to_unsigned(0,ptr_coef'length); -- commence par le dernier (on pourrait aussi commence par le premier vu que le filtre est sym�trique)
          end if;

        end if;

      if (cpt>=6) and (cpt<15+6) then -- on accumule une fois le pipeline lanc�
        acc <= acc + mul_data_coef_reg; -- accumulateur
      elsif (cpt=15+6) then -- fin de la d�cimation, normalisation par 21-3 (coef filtre normalis� par 2^21, mais surechantillonnage par 8
        if (acc(acc'high downto 21-3) < -2**17) then  -- en ajoutant des z�ro => perte d'amplitude d'1 facteur 8 apr�s filtrage
          ech_out <= to_signed(-2**17,ech_out'length);
        elsif (acc(acc'high downto 21-3) > 2**17 - 1) then
          ech_out <= to_signed(2**17 - 1,ech_out'length);
        else
          ech_out <= acc(17+21-3 downto 21-3);
          end if;
        if (cpt_surech<7) then cpt_surech <= cpt_surech + 1; else cpt_surech <= 0; end if;
        cpt <= 0; -- fin de ce surechantillon, pr�t pour le suivant
        end if;

      ptr_out_reg <= ptr_out; -- bufferise les adresses et les data en sortie pour fr�quence max !
      data_out <= data_in_mem(to_integer(ptr_out_reg)); -- on n'est pas � un ou 2 coup d'horloge pr�t et on a plein de bascules D.
      data_out_reg <= data_out;

      ptr_coef_reg <= ptr_coef;
      coef_out <= coef_mem(to_integer(ptr_coef_reg));
      coef_out_reg <= coef_out;

      mul_data_coef <= data_out_reg * coef_out_reg; -- multiplieur 18x18 sign�
      mul_data_coef_reg <= mul_data_coef; -- buffer pour vitesse max

      end if; -- clk

    if rst then
      ptr_in <= (others => '0');
      cpt <= 0;
      ech_out <= to_signed(0,ech_out'length);
      end if;

    end process;

  end architecture;


