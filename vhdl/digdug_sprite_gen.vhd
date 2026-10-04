----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.05.2026 12:27:00
-- Design Name: 
-- Module Name: digdug_sprite_gen - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- Module utilise pour la generation des sprites de DigDug
-- Base sur l'implementation des sprite DAR (C:\Users\yannv\Documents\Projets_HW\DigDug\vhdl_galaga_rev_0_3_2018_05_06\rtl_dar\galaga.vhd)
-- car je n'ai pas trouvé de documentation sur le chip custom 04
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-- ID sprite : spriteram[offs];
-- Color sprite : spriteram[offs+1]
--
-- Sprite Y : spriteram_2[offs]
-- Sprite X : spriteram_2[offs+1];
-- 
-- Sprite FLIPX : (spriteram_3[offs] & 0x01);
-- Sprite FLIPY : (spriteram_3[offs] & 0x02) >> 1;
--
-- Sprite size : sprite & 0x80;
--
-- 0x8B80 - 0x8BFF : 64 sprites tile num, tile color.     Debut RAM OBJRAM : 0x8800 + 0x380
-- 0x9380 - 0x93FF : 64 sprites pos v, pos h lsb.         Debut RAM POSRAM : 0x9000 + 0x380
-- 0x9B80 - 0x9BFF : 64 sprites 2xH, 2xV, flip H, flip V. Debut RAM FLPRAM : 0x9800 + 0x380
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_sprite_gen is
port (
    i_rst_n          : in std_logic;
    i_sprite_gen_clk : in std_logic; -- 6 MHz
    i_clk_3x         : in std_logic; -- 18 MHz
    i_ab             : in std_logic_vector(15 downto 0);
    i_h              : in std_logic_vector(8 downto 0);
    i_256h           : in std_logic;
    i_v              : in std_logic_vector(8 downto 0);
    i_msc            : in std_logic_vector(1 downto 0);
    i_flip           : in std_logic;
    i_hsync_n        : in std_logic;
    i_br_w_n         : in std_logic;
    o_mobj           : out std_logic_vector(3 downto 0);
    o_db             : out std_logic_vector(7 downto 0); -- Read CPU
    o_spvcnt         : out unsigned(4 downto 0);
    o_sptile_num     : out std_logic_vector(7 downto 0);
    o_hflip_star     : out std_logic;
    o_vflip_star     : out std_logic;
    o_flip_0         : out std_logic;
    o_flip_1         : out std_logic;
    o_flip_2         : out std_logic;
    o_vset_n         : out std_logic
);

end digdug_sprite_gen;


--- SPRITES MACHINE ---
-----------------------

architecture Behavioral of digdug_sprite_gen is

signal sptile_color : std_logic_vector(5 downto 0);
signal flip : std_logic_vector(2 downto 0);
signal objram_di, posram_di, objram_do, posram_do, flpram_di, flpram_do : std_logic_vector(7 downto 0);
signal sprite_line : unsigned(7 downto 0);
signal spram1_do, spram2_do : std_logic_vector(3 downto 0);
signal spram1_addr, spram2_addr : unsigned(8 downto 0);
signal spram1_addr_std, spram2_addr_std : std_logic_vector(8 downto 0);
signal mora_cus_04 : std_logic_vector(6 downto 0);
signal mora : std_logic_vector(9 downto 0);
signal spdata : std_logic_vector(3 downto 0);
signal mux_4M_a, mux_4M_b, mux_4M_out, spram1_di, spram2_di, u4g_do : std_logic_vector(3 downto 0);
signal spram1_we, spram2_we : std_logic;
signal match_n, ram0_n, picen, posen, flipen, port_n : std_logic;
signal objram_n, flpram_n, posram_n, earom_n : std_logic;
signal vset_n, hset_n, obj, line_buffer_wr : std_logic;

-- Fin de remplissage du line buffer
-- Limite fixée pour arrêter l'ecriture dans le buffer de ligne
-- Sans ça les premiers octets etaient reecrits en fin de cycle "FILL_LINE_BUFFER"  
constant END_OF_LINE_BUFFER : unsigned(8 downto 0) := to_unsigned(288, 9);

begin

    -- U3C/D U4P
    sprite_line <= unsigned(posram_do) + unsigned(i_v(7 downto 0));
    -- U3P / U5E
    -- Le bit 7 du sprite représente sa taille
    match_n <= not ((objram_do(7) or sprite_line(4)) and sprite_line(5) and sprite_line(6) and sprite_line(7)); 
       
    -- U10N/P U7H
    ram0_n <= '0' when i_ab(15 downto 11) = "10000" else '1';
    picen <= '0' when i_ab(15 downto 11) = "10001" else '1';
    posen <= '0' when i_ab(15 downto 11) = "10010" else '1';
    flipen <= '0' when i_ab(15 downto 11) = "10011" else '1';
    port_n <= '0' when i_ab(15 downto 11) = "10100" else '1';
    earom_n <= '0' when i_ab(15 downto 11) = "10111" else '1';
    
    objram_n <= picen when i_h(1) = '1' else '1';
    flpram_n <= flipen when i_h(1) = '1' else '1';
    posram_n <= posen when i_h(1) = '1' else '1';
    
    -- CPU read
    o_db <= objram_do when objram_n = '0' and i_br_w_n = '1' else
            posram_do when posram_n = '0' and i_br_w_n = '1' else
            flpram_do when flpram_n = '0' and i_br_w_n = '1';
    
    mora <= "111" & mora_cus_04 when i_h(1) = '1' else i_ab(9 downto 7) & mora_cus_04;

    -- VSETn. Registre absent du schema de DigDug ???
    process (i_sprite_gen_clk)
    begin
        if rising_edge(i_sprite_gen_clk) then
            if vset_n = '0' then
                -- U9B ?
                o_sptile_num <= objram_do(7 downto 0);
                -- spdata: bit0 => flip_x, bit1 => flip_y
                spdata <= flpram_do(3 downto 0);
                -- Equivalent 1V*,2V*,4V*,8V*,16V*   
                o_spvcnt <= sprite_line(4 downto 0);
            end if;
        end if;
    end process;
      
    -- U4D (HSETn)
    U4D : process (i_sprite_gen_clk)
    begin
        if rising_edge(i_sprite_gen_clk) then
            if hset_n = '0' then
                sptile_color <= objram_do(5 downto 0);
            end if;
        end if;
    end process;

    -- Custom 04
    U9K : entity work.digdug_custom04
    port map (
        i_rst_n => i_rst_n,
        i_clk => i_sprite_gen_clk, -- 6 MHz
        i_ab => i_ab(6 downto 0),
        i_match_n => match_n,
        i_256h => i_256h,
        i_hpos => i_h,
        i_size => objram_do(7),
        o_mora => mora_cus_04, 
        o_vset_n => vset_n,
        o_hset_n => hset_n,
        o_obj => obj,
        o_flip => flip
    );
    
    o_flip_0 <= flip(0);
    o_flip_1 <= flip(1);
    o_flip_2 <= flip(2);
    o_vset_n <= vset_n;
    
    o_hflip_star <= spdata(0);
    o_vflip_star <= spdata(1);
    
    -- U3F/3H
    -- Remarques pour U3FH et U4FN
    -- Le compteur original du schema digdug est sur 8 bits donc, 256 pixel
    -- Celui dans l'implementation Verilog et celui du schma Gala sont sur 9 bits.
    -- Le problème c'est au'avec 256 pixel de buffer ligne et une resolution de 288 pixels,
    -- certains pixel de sprites n'etaient pas affiches. C'est peut-etre parce que l'affichage
    -- des sprites est cense commencer à partir du pixel 16 et finir en 256 ???
    -- Je n'ai pas reussi à decaler l'affichage des pixel de 16 pixels. J'ai prefere agrandir
    -- la taille du buffer ligne de 256 a 512 pixels et aussi limiter l'ecriture dans le buffer
    -- ligne au minimum (END_OF_LINE_BUFFER).    
    U3FH : process (i_sprite_gen_clk)
    begin
        if (i_rst_n = '0' or i_hsync_n = '0') then
            spram1_addr <= (others => '0');
        elsif rising_edge(i_sprite_gen_clk) then
            -- Compteur reload 1V
            if (hset_n = '0' and i_v(0) = '0') then
                spram1_addr <= unsigned('0' & posram_do);
            elsif spram1_addr < END_OF_LINE_BUFFER then
                spram1_addr <= spram1_addr + 1;
            end if;
        end if;
    end process;
    
    -- U4F/4N
    U4FN : process (i_sprite_gen_clk)
    begin
        if (i_rst_n = '0' or i_hsync_n = '0') then
            spram2_addr <= (others => '0');
        elsif rising_edge(i_sprite_gen_clk) then 
            -- Compteur reload 1V
            if (hset_n = '0' and i_v(0) = '1') then
                spram2_addr <= unsigned('0' & posram_do);
            elsif spram2_addr < END_OF_LINE_BUFFER then
                spram2_addr <= spram2_addr + 1;
            end if;
        end if;
    end process;
    
    spram1_di <= u4g_do when (i_v(0) = '0') else "1111";
    spram2_di <= u4g_do when (i_v(0) = '1') else "1111";
    
    line_buffer_wr <= not (not (u4g_do(0) and u4g_do(1) and u4g_do(2) and u4g_do(3)) and obj and i_hsync_n); 
    mux_4M_a <= line_buffer_wr & i_sprite_gen_clk & '0' & i_256h;
    mux_4M_b <= i_sprite_gen_clk & line_buffer_wr & i_256h & '0';
    mux_4m_out <= mux_4M_a when i_v(0) = '0' else mux_4M_b;
    -- Ecriture sur niveau haut
    spram1_we <= not mux_4m_out(3);
    spram2_we <= not mux_4m_out(2);
    
    -- U2H/J
    U2HJ : process(i_sprite_gen_clk)
    begin
        if rising_edge(i_sprite_gen_clk) then
            if (i_v(0) = '0') then
                o_mobj <= spram2_do;
            else
                o_mobj <= spram1_do;
            end if;
        end if;
    end process;
    
    -- ROMs
    -- U4G (Palette sprites)
    U4G : entity work.dist_mem_gen_u4g
    port map (
        a => sptile_color & i_msc,
        spo => u4g_do
    );
    
    -- RAMS
    -- working/sprite register OBJRAM 0x8800-0x8BFF / 0x8C00-0x8FFF
    U9EJ : entity work.blk_mem_gen_objram
    port map (
        clka => i_clk_3x,
        addra => mora,
        -- dina => objram_di,
        dina => "00000000",
        douta => objram_do,
        wea(0) => not(i_br_w_n or objram_n)
    );
    
    -- working/sprite register POSRAM 0x9000-0x93FF / 0x9400-0x97FF
    U9FG : entity work.blk_mem_gen_posram
    port map (
        clka => i_clk_3x,
        addra => mora,
        dina => posram_di,
        douta => posram_do,
        wea(0) => not(i_br_w_n or posram_n)
    );
    
    -- working/sprite register FLPRAM 0x9800-0x9BFF / 0x9C00-0x9FFF
    U9HJ : entity work.blk_mem_gen_flpram
    port map (
        clka => i_clk_3x,
        addra => mora,
        dina => flpram_di,
        douta => flpram_do,
        wea(0) => not(i_br_w_n or flpram_n)
    );
    
    -- U3G
    -- Line buffer 1 (V_1 = '0')
    U3G : entity work.blk_mem_gen_spram_1
    port map (
        clka => i_clk_3x,
        addra => spram1_addr_std,
        dina => spram1_di,
        douta => spram1_do,
        wea(0) => spram1_we
    );
        
    spram1_addr_std <= std_logic_vector(spram1_addr);
    
    -- U3G
    -- Line buffer 1 (V_1 = '1')
    U4J : entity work.blk_mem_gen_spram_2
    port map (
        clka => i_clk_3x,
        addra => spram2_addr_std,
        dina => spram2_di,
        douta => spram2_do,
        wea(0) => spram2_we
    );
    
    spram2_addr_std <= std_logic_vector(spram2_addr);

end Behavioral;
