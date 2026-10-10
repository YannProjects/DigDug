----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.04.2026 13:34:43
-- Design Name: 
-- Module Name: digdug_pf_gen - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

-- Namco vs Atari ROM names and locations
-- --------------------------------------
-- The Namco version is composed of two boards, while the Atari version is
-- single board. There are two revisions of the Atari version.
-- 
-- Location  ID        Location  Location  ID
--                     (type 1)  (type 2)
-- --------  ----      --------  --------  ----------
-- CPU 3P    DD1-1     6L        2C/D      136007-101
-- CPU 3M    DD1-2     6M        2E        136007-102
-- CPU 2M    DD1-3     6N/P      2B/C      136007-103
-- CPU 2L    DD1-4     6R        2A        136007-104
-- CPU 3F    DD1-5     6C        2P        136007-105
-- CPU 3J    DD1-6     6D        2N        136007-106
-- CPU 2C    DD1-7     5L        2K/L      136007-107
-- CPU 5N    [bpr]     2K/L      10A       136007-109
-- CPU 7N    [bpr]     2P        11A       136007-110
-- 
-- VID 2C    DD1-9     8R        5K        136007-108 *
-- VID 1C    [bpr]     4G        8F        136007-111 *
-- VID 2N    [bpr]     10K/L     4N        136007-112 *
-- VID 5N    [bpr]     1R        8L        136007-113
-- VID 2D    DD1-10    9N        4J        136007-114 *
-- VID 5C    DD1-11    10C/D     4F        136007-115 *
-- VID 5F    DD1-12    7A/B      5B        136007-119 *
-- VID 5H    DD1-13    8A/B      5A        136007-118 *
-- VID 5J    DD1-14    7C        5C        136007-117 *
-- VID 5K    DD1-15    8C        5D        136007-116 *

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_pf_gen is
port(
    i_clk      : in std_logic; -- 6 MHz
    i_reset_n  : in std_logic;
    -- BG Ram tiles
    i_pa       : in std_logic_vector(10 downto 0);
    i_dbin     : in std_logic_vector(7 downto 0);
    o_dbout    : out std_logic_vector(7 downto 0);
    o_pod      : out std_logic_vector(7 downto 0);
    o_flip     : out std_logic;
    o_pf       : out std_logic_vector(3 downto 0);
    i_hpos     : in std_logic_vector(8 downto 0);
    i_vpos     : in std_logic_vector(8 downto 0);
    i_ram0_csn : in std_logic;
    i_br_wn    : in std_logic;
    i_portn    : in std_logic;
    i_psc      : in std_logic_vector(1 downto 0) -- A priori issu des 2 bits de poids faible du registre a decalage 5D PSC0/PSC1
);
    
end digdug_pf_gen;

architecture Behavioral of digdug_pf_gen is

signal fg_color_mode, bg_cutoff, flip : std_logic;
signal bg_color_bank, bg_select : std_logic_vector(1 downto 0);
signal q_10lm, pf_10kl, q_10r : std_logic_vector(3 downto 0);
signal Q_5MN, shift_reg_8n : std_logic_vector(7 downto 0);
signal bg_data, q_10mn, q_9r, dout_8r, dout_9M : std_logic_vector(7 downto 0);

begin

    -- MAME:
	-- " The hardware has two ways to pick the color, either straight from the
	-- bottom 4 bits of the character code, or from the top 4 bits through a
	-- formula. The former method isnot used by Dig Dug and seems kind of
	-- useless (I don't know what use they were thinking of when they added
	-- it), anyway here it is reproduced faithfully."
	-- Les 4 bits de poids fors contiennent l'index de la tile et les 4 bits de poids faibles
	-- l'index de la couleur ?
    -- 9M - RAM0: tilemap RAM (bottom half of RAM 0 + work RAM (top half for RAM 0)
    u_ram0_9M: entity work.blk_mem_gen_bgram
    port map (
        clka => i_clk,
        addra => i_pa,
        dina => i_dbin,
        douta => dout_9M,
        wea(0) => not i_br_wn
    );
    
    o_dbout <= dout_9M;
    
    U5MN : process(i_clk, i_reset_n)
	begin
        if i_reset_n = '0' then
            Q_5MN <= (others => '0');
		elsif rising_edge(i_clk) then
			if i_portn = '0' then
				case i_pa(2 downto 0) is
					when "000" => Q_5MN(0) <= i_dbin(0);
					when "001" => Q_5MN(1) <= i_dbin(0);
					when "010" => Q_5MN(2) <= i_dbin(0);
					when "011" => Q_5MN(3) <= i_dbin(0);
					when "100" => Q_5MN(4) <= i_dbin(0);
					when "101" => Q_5MN(5) <= i_dbin(0);
					when "111" => Q_5MN(7) <= i_dbin(0);
					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	-- Les noms viennent du core MiSTER DIGDUG en Verilog
	-- bg_select <= Q_5MN(1 downto 0);
	bg_select <= "01";
	-- fg_color_mode <= Q_5MN(2);
	fg_color_mode <= '1';
	-- bg_cutoff <= Q_5MN(3);
	bg_cutoff <= '0'; -- BG desactive pour test
	bg_color_bank <= Q_5MN(5 downto 4);
    flip <= Q_5MN(7);
    o_flip <= flip;
	
	-- MAME:
	-- " when the background is "disabled", it is actually still drawn, but using
	--  a color code that makes all pixels black. There are pullups setting the
	--  code to 0xf, but also solder pads that optionally connect the lines with
	--  tilemap RAM, therefore allowing to pick some bits of the color code from
	--  the top 4 bits of alpha code. This feature is not used by Dig Dug. "
	-- Cette partie implémente une image de fond sur laquelle viennent se superposer les tiles ?	
	-- DD1-10 - 136007-114
	U9N : entity work.dist_mem_gen_9N
	port map (
	   a => bg_select & i_pa(9 downto 0),
	   spo => bg_data -- Background data
	);
	
	-- U10R
	U10R : process(i_clk)
	begin
	   if rising_edge(i_clk) then
	       -- FALLING edge 4H (le 74LS298 est actif sur front descendant)
	       if i_hpos(2 downto 0) = "111" then
               if (bg_cutoff = '0') then 
                   q_10r <= bg_data(7 downto 4);
               else
                   q_10r <= (others => '1');
               end if;
           end if;
	   end if;
    end process;
	
	-- U10M/N
   -- MAME:
   -- when the background is "disabled", it is actually still drawn, but using
   -- a color code that makes all pixels black. There are pullups setting the
   -- code to 0xf, but also solder pads that optionally connect the lines with
   -- tilemap RAM, therefore allowing to pick some bits of the color code from
   -- the top 4 bits of alpha code. This feature is not used by Dig Dug."
   -- Correspond au 10LM. Soit on selection les 4 bits de poids faibles du code couleur avec Q_5MN(2)
   -- soit un autre ensemble de 4 bits qui doit correspondre a ce que parle le commentaire de MAME
   -- Mais, c'est apparemment pas utilise et seuls les 4 bits de poids faibles sont utilises.
	U10MN : process(i_clk)
	begin
        if rising_edge(i_clk) then
            -- Rising edge 4H
            if i_hpos(2 downto 0) = "011" then
                q_10mn <= bg_data;
            end if;
        end if;
    end process;

    -- DD1-11 - 136007-115
	U10CD : entity work.dist_mem_gen_10cd
	port map (
	   a => q_10mn & ((i_hpos(2) & i_vpos(2 downto 0)) xor (flip & flip & flip & flip)),
	   spo => o_pod
	);
	
	-- 9R
	U9R: process(i_clk)
	begin
        if rising_edge(i_clk) then
            -- Rising edge 4H
            if i_hpos(2 downto 0) = "011" then
                q_9r <= dout_9M;
            end if;
        end if;
    end process;
	   
    -- [bpr] 10K/L 136007-112
    -- ROM pour la couleur du fond
	U10KL : entity work.dist_mem_gen_10kl
	port map (
	   a => bg_color_bank & q_10r & i_psc,
	   spo => pf_10kl
	);
	
	
	-- MAME:
	-- The hardware has two character sets, one normal and one x-flipped. When
	-- screen is flipped, character y flip is done by the hardware inverting the
	-- timing signals, while x flip is done by selecting the 2nd character set.
	-- We reproduce this here, but since the tilemap system automatically flips
	-- characters when screen is flipped, we have to flip them back."
	-- La selection de la 2eme banque de caracteres est faite par le signal fli (A10)
	-- Les 3 bits de poids faibles correspondent a l'index de la ligne dans la tile
	-- Les 7 bits suivant à l'index de la tile
	-- Le dernier bit a la selection de la banque de tile
    -- DD1-9 8R 136007-108
	U8R : entity work.dist_mem_gen_8r
	port map (
	   a => flip & q_9r(6 downto 0) & (i_vpos(2 downto 0) xor (flip & flip & flip)),
	   spo => dout_8r
	);

    -- Registre a decalage permettant de valider la couleur:
    -- Si la sortie d'un pixel de tile est a 1, on valide sa couleur avec shift_reg_8n(7)
    -- Si la sortie d'un pixel de tile est a 0, on prend la couleur du fond
    -- Chaque pixel de la tile est donc associe a un code couleur sur 4 bits issu des 4 bits de poids
    -- faibles de la tile.
	-- 8N
	U8N: process(i_clk, i_reset_n)
    begin
        if i_reset_n = '0' then
            shift_reg_8n <= (others => '0');
        elsif rising_edge(i_clk) then
            -- Rechargement registre a decalage falling edge 4H
            if i_hpos(2 downto 0)= "111" then
                shift_reg_8n <= dout_8r(0) & dout_8r(1) & dout_8r(2) & dout_8r(3) & dout_8r(4) & dout_8r(5) & dout_8r(6) & dout_8r(7);
            else
                shift_reg_8n <= shift_reg_8n(6 downto 0) & '0';
            end if;
        end if;
    end process;
    
	-- U10L/M
	U10LM : process(i_clk)
	begin
	   if rising_edge(i_clk) then
	       -- FALLING edge 4H (le 74LS298 est actif sur front descendant)
	       if i_hpos(2 downto 0) = "111" then
	           -- Dans DigDug c'est le mode de couleur 1 qui est utilise qui ajoute une conversion
	           -- en utilisant les bits de poids forts de la tile:
	           --      q_9r   |    q_10lm   
	           -- 0000 => 0x0 | 0000 => 0x0 => Noir
               -- 0001 => 0x1 | 0010 => 0x2 => Blanc
               -- 0010 => 0x2 | 0010 => 0x2 => Blanc
               -- 0011 => 0x3 | 0010 => 0x2 => Blanc
               -- 0100 => 0x4 | 0100 => 0x4 => Vert
               -- 0101 => 0x5 | 0110 => 0x6 => Jaune
               -- 0110 => 0x6 | 0110 => 0x6 => Jaune
               -- 0111 => 0x7 | 0110 => 0x6 => Jaune
               -- 1000 => 0x8 | 1000 => 0x8 => Bleu
               -- 1001 => 0x9 | 1010 => 0xA => Rouge
               -- 1010 => 0xA | 1010 => 0xA => Rouge
               -- 1011 => 0xB | 1010 => 0xA => Rouge
               -- 1100 => 0xC | 1100 => 0xC => Gris
               -- 1101 => 0xD | 1110 => 0xE => Marron
               -- 1110 => 0xE | 1110 => 0xE => Marron
               -- 1111 => 0xF | 1110 => 0xE => Marron 
               if (fg_color_mode = '0') then 
                   q_10lm <= dout_9M(3 downto 0);
               else
                   q_10lm <= q_9r(7) & q_9r(6) & (q_9r(4) or q_9r(5)) & '0';
               end if;
           end if;
	   end if;
    end process;
    
    o_pf <= pf_10kl when shift_reg_8n(7) = '0' else q_10lm;

end Behavioral;