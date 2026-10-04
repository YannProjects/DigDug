----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.12.2025 18:56:53
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
----------------------------------------------------------------------------------


library IEEE;
library unisim;
use IEEE.STD_LOGIC_1164.ALL;
use unisim.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_core_top is
    Port ( 
        -- System clock (100 MHz)
        i_clk_main : in std_logic;
    
        -- Core reset
        i_rst_sys_n : in std_logic -- actif niveau bas
    
    )
end digdug_core_top;

architecture Behavioral of digdug_core_top is

signal clk_vga, clk_digdug, clk_uart : std_logic;
signal pll_lock : std_logic;

begin

    clock : entity work.digdug_clocks
    port map (
        i_clk_artyx7 => i_clk_main,
        o_clk_vga => clk_vga,
        o_clk_digdug => clk_digdug,
        o_clk_uart => clk_uart,
        i_rst => not i_rst_sys_n,
        o_pll_locked => pll_lock
    );
    
    hv_clocks : entity work.hv_clocks
    port map (
        clk => clk_digdug,
        -- hcnt
        -- vcnt
        -- hsync
        -- vsync
        -- csync 
        -- blankn
   );

end Behavioral;
