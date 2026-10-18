----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.10.2026 22:19:50
-- Design Name: 
-- Module Name: namco51xx - Behavioral
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

entity custom53xx is
port (
    i_clk       : in std_logic; -- 2H
    i_rst_n     : in std_logic;
    i_irq_n     : in std_logic;
    o_so        : out std_logic;
    i_si        : in std_logic; -- Not used
    i_tc        : in std_logic; -- VBLANK
    o_p         : out std_logic_vector(3 downto 0);
    i_edb       : in std_logic_vector(7 downto 0);
    o_edb       : out std_logic_vector(7 downto 0);
    i_r         : in std_logic_vector(15 downto 0);
    i_k         : in std_logic_vector(3 downto 0)
);
end custom53xx;

architecture Behavioral of custom53xx is

signal cs53xx_rom_addr : std_logic_vector(10 downto 0);
signal cs53xx_rom_do : std_logic_vector(7 downto 0);

begin
    mb88_53xx : entity work.mb88
    port map(
        reset_n => i_rst_n, --Reset_n,
        clock => i_clk,
        ena => '1',

        r0_port_in  => i_r(3 downto 0),
        r1_port_in  => i_r(7 downto 4),
        r2_port_in  => i_r(11 downto 8),
        r3_port_in  => i_r(12 downto 9),
        r0_port_out => open,
        r1_port_out => open,
        r2_port_out => open,
        r3_port_out => open,
        k_port_in => i_k,
        ol_port_out => o_edb(3 downto 0),
        oh_port_out => o_edb(7 downto 4),
        p_port_out  => open,
        
        stby_n => '0',
        tc_n => '0',
        irq_n => i_irq_n,  -- CSn
        sc_in_n => '0',
        si_n => '0',
        sc_out_n => open,
        so_n => open,
        to_n => open,
         
        rom_addr  => cs53xx_rom_addr,
        rom_data  => cs53xx_rom_do
    );
    
    U53XX_ROM : entity work.dist_mem_gen_53xx
	port map (
	   a => cs53xx_rom_addr,
	   spo => cs53xx_rom_do
	);

end Behavioral;
