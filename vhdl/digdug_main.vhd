----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.12.2025 18:42:09
-- Design Name: 
-- Module Name: digdug_main - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_main is
Port (
    i_rst_sysn      : in std_logic;
    i_clk_artyx7    : in std_logic;
    -- i_sync_bus_ab   : in std_logic_vector(15 downto 0); -- Adress bus custom 08
    -- i_sync_bus_clk  : in std_logic; -- custom 08 CLK
    -- i_sync_bus_rw_n : in std_logic; -- custom 08 R/Wn
    -- i_sync_bus_db   : in std_logic_vector(7 downto 0); -- Synced data bus custom 08
    -- o_sync_bus_db   : out std_logic_vector(7 downto 0); -- Synced data bus custom 08
    
    -- VGA
    o_hsync       : out std_logic;
    o_vsync       : out std_logic;
    o_r_vga       : out std_logic_vector(2 downto 0);
    o_g_vga       : out std_logic_vector(2 downto 0);
    o_b_vga       : out std_logic_vector(2 downto 0)
);
end digdug_main;


architecture Behavioral of digdug_main is

signal digdug_clk_3x, digdug_clk, clk_vga, pll_locked, clk_main : std_logic;
signal video_r, video_g : std_logic_vector(2 downto 0);
signal video_b : std_logic_vector(1 downto 0);
signal video_rgb : std_logic_vector(23 downto 0);
signal vga_r, vga_g, vga_b : std_logic_vector(2 downto 0);
signal core_vblk, core_hblk, blank_vga, vga_control_init_done, pixel_write : std_logic;
signal rgb_core : std_logic_vector(7 downto 0);
signal pll_locked_n, core_rst_n : std_logic;

begin

    clk_gen: entity work.clk_wiz_digdug
    port map (
      i_clk_sys => i_clk_artyx7, -- 100 MHz
      reset => not i_rst_sysn,
      o_clk_3x => digdug_clk_3x, -- 18 MHz
      o_clk_vga => clk_vga, -- 25 MHz
      o_clk_main => clk_main, -- 100 MHz
      locked => pll_locked
    );    
    
    pll_locked_n <= not pll_locked;
    
    digdug_clk_gen : entity work.digdug_clocks
    port map (
        i_rst_sysn => i_rst_sysn,
        i_clk_3x => digdug_clk_3x,
        o_clk_digdug => digdug_clk
    );  

    digdug_core : entity work.digdug_core_top
    port map (
        i_core_rst_n => core_rst_n,
        i_clk => digdug_clk,
        i_clk_3x => digdug_clk_3x,
        -- !!! Les signaux de R/Wn, CLK, data sont ceux du bus controller custom 08 !!!
        -- C'est l'interface entre les Z80 et les parties video/audio/I/O,...
        -- i_sb_clk => i_sync_bus_clk,
        i_sb_clk => '0',
        -- i_sb_ab => i_sync_bus_ab,
        i_sb_ab => (others => '0'),
        -- i_sb_rw_n => i_sync_bus_rw_n,
        i_sb_rw_n => '1',
        -- i_sb_db => i_sync_bus_db,
        i_sb_db => (others => '0'),
        -- o_sb_db => o_sync_bus_db,
        o_sb_db => open,

        o_vblank_core => core_vblk,
        o_hblank_core => core_hblk,
        o_rgb_core => rgb_core
    );
   
    -- Controlleur VGA
    u_vga_ctrl : entity work.vga_control_top
    port map ( 
        i_reset => pll_locked_n,
        i_clk => clk_main,
        i_vga_clk => clk_vga,
        i_pixel_write => digdug_clk,
    
        -- Signaux video core DigDug
        i_vblank => core_vblk,
        i_hblank => core_hblk,
        i_rgb => rgb_core,
        
        -- Signaux video VGA
        o_hsync => o_hsync,
        o_vsync => o_vsync,
        o_blank => blank_vga,
        o_r => vga_r,
        o_g => vga_g,
        o_b => vga_b,         

        o_vga_control_init_done => vga_control_init_done
    );

    video_rgb(23 downto 16) <= video_r & "00000";
    video_rgb(15 downto  8) <= video_g & "00000";
    video_rgb( 7 downto  0) <= video_b & "000000";
    
    o_r_vga <= vga_r when blank_vga = '0' else (others => '0');
    o_g_vga <= vga_g when blank_vga = '0' else (others => '0');
    o_b_vga <= vga_b when blank_vga = '0' else (others => '0');
    
    core_rst_n <= '0' when i_rst_sysn = '0' or  vga_control_init_done = '0' else '1';    

end Behavioral;
