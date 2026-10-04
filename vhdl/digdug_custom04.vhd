----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.06.2026 18:12:45
-- Design Name: 
-- Module Name: digdug_custom04 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Impementation du chip custom 04 utilise dans Dig Dug
-- basé sur l'implementation rtl_dat DigDug en VHDL
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_custom04 is
port (
    i_rst_n          : in std_logic;
    i_clk            : in std_logic; -- 18 MHz
    i_ab             : in std_logic_vector(6 downto 0);
    i_match_n        : in std_logic;
    i_hpos           : in std_logic_vector(8 downto 0);
    i_256h           : in std_logic;
    i_size           : in std_logic;
    o_mora           : out std_logic_vector(6 downto 0);
    o_vset_n         : out std_logic;
    o_hset_n         : out std_logic;
    o_obj            : out std_logic;
    o_flip           : out std_logic_vector(2 downto 0)
);
end digdug_custom04;

architecture Behavioral of digdug_custom04 is

type states is (IDLE, ABORT, GET_SPRITE_DATA, WAIT_FOR_NEXT_CYCLE, WAIT_CYCLE_END, WAIT_FOR_FILL_LINE_BUFFER, FILL_LINE_BUFFER);

signal sprite_state : states;
signal slot : unsigned(2 downto 0) := (others => '0');
signal sprite_size, cpu_access_n, cpu_access_t1_n, cpu_access_t2_n : std_logic;
signal sprite_num : unsigned(5 downto 0);
signal sphcnt, flipcnt : unsigned(4 downto 0);
signal hset_n, vset_n, hset_n_filtered : std_logic;

-- !!! A verifier !!!
constant PH_ABORT : unsigned(8 downto 0) := to_unsigned(191, 9);

begin

    -- Le fonctionnement du custom 04 est issu de l'implementation VHDL Gala (rtl DAR)
    -- mais adaptee à une horloge 1H (6 MHz).
    -- Detection taille des sprites
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if hset_n = '0' then
                if i_size = '1' then
                    sprite_size <= '1';
                 else
                    sprite_size <= '0';
                 end if;
            end if;
        end if;
    end process;
        
    -- VSET sur la premiere periode de 2H (filtre avec les etats de la machine d'etat)
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_hpos(1 downto 0) = "01" then
                vset_n <= '0';
            else
                vset_n <= '1';
            end if;
        end if;
    end process;

    -- HSET sur la seconde periode de 2H (filtre avec les etats de la machine d'etat)
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_hpos(1 downto 0) = "10" then
                hset_n <= '0';
            else
                hset_n <= '1';
            end if;
        end if;
    end process;
    
    process (i_clk)
    begin
        -- !!! Zone de fin de ligne horizontale => A verifier !!!
        -- if i_h = std_logic_vector(STANDBY_PH) then
        -- Debut du traitement des sprites quand HSYNCn = 0 ???
        if i_rst_n = '0' or (i_hpos = std_logic_vector(PH_ABORT) and (i_256h = '1')) then
            sprite_num <= (others => '0');
            sprite_state <= IDLE;
        elsif rising_edge(i_clk) then     
            case sprite_state is
               when IDLE =>
                    -- La partie sprite a acces quand 2H=1, les CPUs quand 2H=0
                    if i_hpos(1) = '1' then
                        -- Line match
                        if i_match_n = '0' then
                             sprite_state <= WAIT_FOR_NEXT_CYCLE;
                        else
                            -- Fin de l'affichage des sprites (64 sprites) ???
                            if sprite_num = X"3F" then
                                sprite_state <= WAIT_CYCLE_END;
                            else
                                sprite_num <= sprite_num + 1;			
                            end if;		
                        end if;	                    
                    end if;
               
               when WAIT_FOR_NEXT_CYCLE =>
                    if i_hpos(1 downto 0) = "01" then
                        sprite_state <= GET_SPRITE_DATA;        
                    end if;

               when GET_SPRITE_DATA =>
                    if i_hpos(1 downto 0) = "11" then
                        sprite_state  <= WAIT_FOR_FILL_LINE_BUFFER;
                        -- Flip counter est utilise pour anticiper la mise à jour de o_flip
                        -- et tenir compte du decalage du rechargement du registre a decalage custom02
                        flipcnt <= (others => '0');
                    end if;
               
               -- Attente d'un cycle (2H) supplementaire pour tenir compte du decalage
               -- du rechargement du registre a decalage custom02
               when WAIT_FOR_FILL_LINE_BUFFER =>
                    flipcnt <= flipcnt + 1;
                    if i_hpos(1 downto 0) = "11" then 
                        sprite_state  <= FILL_LINE_BUFFER;
                        sphcnt <= (others => '0');
                    end if;                    

               when FILL_LINE_BUFFER =>
                    sphcnt <= sphcnt + 1;
                    flipcnt <= flipcnt + 1;
                    -- Fin du traitement des sprites ou sprite suivant
                    if 	((sphcnt = "01111" and sprite_size = '0') or   -- size H x 1  -- fixed Dar : 04/11/2017
                        (sphcnt = "11111" and sprite_size = '1')) then -- size H x 2  -- fixed Dar : 04/11/2017 
                        if sprite_num = "111111" then
                            sprite_state <= WAIT_CYCLE_END;
                        else
                            sprite_num <= sprite_num + 1;
                            sprite_state <= IDLE;
                        end if;
                    end if;
            
               when WAIT_CYCLE_END =>
               when others =>
             
            end case;
        end if;
    end process;

    -- Le bit de poids faible sprite_state(0) permet d'acceder soit au numero du sprite (@n) soit a la couleur (@n+1)
    o_mora <= (std_logic_vector(sprite_num) & not hset_n_filtered) when i_hpos(1) = '1' else i_ab;
    -- Ecriture dans les line buffer
    o_obj <= '1' when (sprite_state = FILL_LINE_BUFFER) else '0';
    
    -- Lors d'une premiere periode 2H, on recupere l'ID du sprite et le numero de ligne
    o_vset_n <= vset_n when sprite_state = GET_SPRITE_DATA else '1';
    -- Lors de la seconde periode 2H, on recupere la couleur du sprite et le numero de colonne
    hset_n_filtered <= hset_n when sprite_state = WAIT_FOR_FILL_LINE_BUFFER else '1';
    o_hset_n <= hset_n_filtered;
    -- FLIP0/1/2 sur le schema DigDug et 4H*/8H*/16H* sur le schema Galaga
    o_flip <= std_logic_vector(flipcnt(4 downto 2));

end Behavioral;
