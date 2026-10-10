----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.04.2026 22:43:46
-- Design Name: 
-- Module Name: digdug_core_top - Behavioral
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
-- 
-- Dig Dug:
-- -------
-- MAIN CPU:
-- 
-- Address          Dir Data     Name      Description
-- ---------------- --- -------- --------- -----------------------
-- 0000xxxxxxxxxxxx R   xxxxxxxx ROM 0     program ROM 0x0000 - 0x0FFF
-- 0001xxxxxxxxxxxx R   xxxxxxxx ROM 1     program ROM 0x1000 - 0x1FFF
-- 0010xxxxxxxxxxxx R   xxxxxxxx ROM 2     program ROM 0x2000 - 0x2FFF
-- 0011xxxxxxxxxxxx R   xxxxxxxx ROM 3     program ROM 0x3000 - 0x3FFF
-- the rest of the memory map is common to the other CPUs
-- 
-- SUB CPU:
-- 
-- Address          Dir Data     Name      Description
-- ---------------- --- -------- --------- -----------------------
-- 0000xxxxxxxxxxxx R   xxxxxxxx ROM 4     program ROM
-- 0001xxxxxxxxxxxx R   xxxxxxxx ROM 5     program ROM
-- 0010------------              n.c.
-- 0011------------              n.c.
-- the rest of the memory map is common to the other CPUs
-- 
-- SOUND CPU:
-- 
-- Address          Dir Data     Name      Description
-- ---------------- --- -------- --------- -----------------------
-- 0000xxxxxxxxxxxx R   xxxxxxxx ROM 6     program ROM
-- 0001xxxxxxxxxxxx R   xxxxxxxx ROM 7     program ROM (optional, not used)
-- 0010------------              n.c.
-- 0011------------              n.c.
-- the rest of the memory map is common to the other CPUs
-- 
-- COMMON:
-- 
-- Address          Dir Data     Name      Description
-- ---------------- --- -------- --------- -----------------------
-- 01000-----------              n.c.
-- 01001-----------              n.c.
-- 01010-----------              n.c.
-- 01011-----------              n.c.
-- 01100-----------              n.c.
-- 01101-----00----   W ----xxxx AUDIO 0   \ sound control registers
-- 01101-----01----   W ----xxxx AUDIO 1   /
-- 01101-----10-000   W -------x IRQ1      main CPU irq enable/acknowledge
-- 01101-----10-001   W -------x IRQ2      sub CPU irq enable/acknowledge
-- 01101-----10-010   W -------x NMION     sound CPU nmi enable
-- 01101-----10-011   W -------x RESET     reset sub and sound CPU, and 5xXX chips on CPU board
-- 01101-----10-100   W -------x n.c.
-- 01101-----10-101   W -------x MOD 0     \
-- 01101-----10-110   W -------x MOD 1     | to custom 53XX
-- 01101-----10-111   W -------x MOD 2     /
-- 01101-----11----   W -------- WDDIS     watchdog reset
-- 01110--0-------- R/W xxxxxxxx I/O       custom 06XX data
-- 01110--1-------- R/W xxxxxxxx I/O       custom 06XX control
-- 01111-----------              n.c.
-- 10000xxxxxxxxxxx R/W xxxxxxxx RAM 0     tilemap RAM + work RAM
-- 10001-xxxxxxxxxx R/W xxxxxxxx OBJRAM    work RAM
-- 10001-111xxxxxxx R/W xxxxxxxx           portion holding sprite registers (sprite number and color)
-- 10010-xxxxxxxxxx R/W xxxxxxxx POSRAM    work RAM 0x8900 - 0x89FF
-- 10010-111xxxxxxx R/W xxxxxxxx           portion holding sprite registers (x and y)
-- 10011-xxxxxxxxxx R/W xxxxxxxx FLPRAM    work RAM
-- 10011-111xxxxxxx R/W xxxxxxxx           portion holding sprite registers (flip)
-- 10100--------000   W -------x           \ background ROM (114) bank select
-- 10100--------001   W -------x           /
-- 10100--------010   W -------x           tilemap color select (low or high 4 bits of tilemap RAM)
-- 10100--------011   W -------x           background enable
-- 10100--------100   W -------x           \ background color lookup PROM (112) bank select
-- 10100--------101   W -------x           /
-- 10100--------110   W -------x n.c.
-- 10100--------111   W -------x FLIP      flip screen
-- 10101-----------              n.c.
-- 10110-----------              n.c.
-- 10111----0xxxxxx   W xxxxxxxx EAROM     non volatile memory address latch and data write
-- 10111----0------ R   xxxxxxxx EAROM     non volatile memory read
-- 10111----1------   W ----xxxx EAROM     non volatile memory control
-- 
-- 
-- 
-- | TILEMAP + Work RAM     0x8000-0x87FF
--                              0x8000-0x83FF => tile num
--                              0x8400-0x87FF => tile color
-- | OBJRAM                 0x8800-0x8BFF
-- | POSRAM                 0x9000-0x93FF
-- | FLPRAM                 0x9800-0x9BFF
-- 
-- ----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_core_top is
    port (
        -- System clock
        i_clk                    : in std_logic; -- 6 MHz
        i_clk_3x                 : in std_logic; -- 18 MHz
        i_core_rst_n             : in std_logic;
        
        o_hblank_core            : out std_logic;
        o_vblank_core            : out std_logic;
        o_rgb_core               : out std_logic_vector(7 downto 0)
    );
end digdug_core_top;

architecture Behavioral of digdug_core_top is

signal h256_n, h256, hsync, hsync_n, vsync_n, hflip_star, vflip_star : std_logic;
signal flip_0, flip_1, flip_2, vset_n, shift_load_n, mobj_on : std_logic;  
signal vblank, csync, hblk_n, flip, cmpblk, hblank : std_logic;
signal hpos_1_star_n, h256_star_n, hsyncsp : std_logic;
signal pod, bgram_out, sptile_num, final_rgb : std_logic_vector(7 downto 0);
signal hpos, vpos : std_logic_vector(8 downto 0);
signal pa_addr, vram_addr : std_logic_vector(10 downto 0);
signal spvcnt : unsigned(4 downto 0);
signal mobj, pf, final_color_sel, final_color : std_logic_vector(3 downto 0);
signal final_color_reg : std_logic_vector(5 downto 0);
signal msc, psc : std_logic_vector(1 downto 0);

begin

    hv_clocks: entity work.hv_sync_gen_07
    port map (  
        i_clk => i_clk,
        i_reset_n => i_core_rst_n,
        o_hcnt => hpos,
        o_h256n => h256_n,
        o_vcnt => vpos,
        o_hsync => hsync,
        o_vsync => vsync_n,
        o_vblank => vblank,
        o_csync => csync, 
        o_hblank_n => hblk_n
    );
    
    vram_addr_gen: entity work.digdug_vram_addresser
    port map (
        i_h => hpos,
        i_h256n => h256_n,
        i_flip => flip,
        i_v => vpos,
        o_ab => vram_addr
    );
    
    -- When 2H is low, the CPU controls the bus.
    -- Le bus (pa) utilise pour adresser la RAM est partage entre le CPU.
    -- Le signal vram_addr_ab est l'adresse generee par le custom IC VRAM adresser (5S)
    -- Cycle utilise par le CPU pour acceder a la RAM
    pa_addr <= (others => '0') when hpos(1) = '0' else vram_addr;

    h256 <= not h256_n;
    
    playfield_gen: entity work.digdug_pf_gen
    port map (
        i_clk => i_clk,
        i_reset_n => i_core_rst_n,
        -- BG Ram tiles
        i_pa => pa_addr,
        i_dbin => (others => '0'),
        o_dbout => bgram_out,
        o_pod => pod,
        o_flip => flip,
        o_pf => pf,
        i_hpos => hpos,
        i_vpos => vpos,
        i_ram0_csn => '1',
        i_br_wn => '1',
        i_portn => '1',
        -- Vient a priori des 2 bits de poids faible du registre a decalage 5D PSC0/PSC1 (TBC)
        i_psc => psc
    );
    
    sprites_gen : entity work.digdug_sprite_gen
    port map (
        i_rst_n => i_core_rst_n,
        i_sprite_gen_clk => i_clk,
        i_clk_3x => i_clk_3x,
        i_ab => (others => '0'),
        i_h => hpos,
        i_256h => h256,
        i_v => vpos,
        i_msc => msc,
        i_flip => '0',
        i_hsync_n => hsync_n,
        i_br_w_n => '1',
        o_mobj => mobj,
        -- o_db => 
        o_spvcnt => spvcnt,
        o_sptile_num => sptile_num,
        o_hflip_star => hflip_star,
        o_vflip_star => vflip_star,
        o_flip_0 => flip_0,
        o_flip_1 => flip_1,
        o_flip_2 => flip_2,
        o_vset_n => vset_n
    );
    
    hsync_n <= not hsync;
    o_hblank_core <= hblank;
    o_vblank_core <= vblank;
    
    color_control : entity work.digdug_color_controller
    port map (
        i_rst_n => i_core_rst_n,
        i_clk => i_clk,
        i_shift_load_n => shift_load_n,
        i_flip => '0',
        i_flip_0 => flip_0,
        i_flip_1 => flip_1,
        i_flip_2 => flip_2,
        i_hflip_star => hflip_star,
        i_vflip_star => vflip_star,
        i_spvcnt => spvcnt,
        i_sptile_num => sptile_num,
        i_tile_bg_data => pod,
        i_vset_n => vset_n,
        o_msc => msc,
        o_psc => psc
    ); 
    
    -------------------------------
    -- Video color output
    -------------------------------
    -- CMPBLK
    U6HJ : process(i_clk)
	begin
        if vblank = '1' then
            cmpblk <= '1';
		elsif rising_edge(i_clk) then
            -- Rising edge 8H
			if hpos(2 downto 0) = "111" then
                 cmpblk <= not hblk_n;
            end if;
        end if;
    end process;
    
    HBLK_SYNC : process(i_clk)
	begin
        if rising_edge(i_clk) then
            -- Rising edge 8H
			if hpos(2 downto 0) = "111" then
                 hblank <= not hblk_n;
            end if;
        end if;
    end process;
    
    H256_SYNC : process(i_clk)
	begin
        if rising_edge(i_clk) then
            -- Rising edge 8H
			if hpos(2 downto 0) = "111" then
                 h256_star_n <= h256_n;
            end if;
        end if;
    end process;    
    
    -- U1HJ
    mobj_on <= '0' when mobj="1111" else '1';
    final_color_sel <= pf when mobj_on = '0' else mobj;
    final_color <= final_color_sel when cmpblk = '0' else "1111";    
    
    U1NP : process(i_clk, i_core_rst_n)
	begin
        if (i_core_rst_n = '0') then
            final_color_reg <= (others => '0');
        elsif falling_edge(i_clk) then
            final_color_reg <= hpos(1) & mobj_on & final_color;
        end if;
    end process;
    
    -- U1B
    hpos_1_star_n <= not (hpos(1) and final_color_reg(5));
    
    -- 136007.113 1H/J 
	U1R : entity work.dist_mem_gen_1R
	port map (
	   a => final_color_reg(4 downto 0),
	   spo => final_rgb
	);
	
	o_rgb_core <= final_rgb;
    
    -- U4R : Reload shift register
    shift_load_n <= not (hpos(0) and hpos(1));

end Behavioral;