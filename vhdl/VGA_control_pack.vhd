----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.07.2021 22:28:45
-- Design Name: 
-- Module Name: VGA_control_pack - Behavioral
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
use ieee.std_logic_arith.all;
-- use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

Package VGA_control_pack is

constant CTRL_REG_ADDR : std_logic_vector(31 downto 0) := X"00000000";
constant STAT_REG_ADDR : std_logic_vector(31 downto 0) := X"00000004";
constant HTIM_REG_ADDR : std_logic_vector(31 downto 0) := X"00000008";
constant VTIM_REG_ADDR : std_logic_vector(31 downto 0) := X"0000000C";
constant HVLEN_REG_ADDR : std_logic_vector(31 downto 0) := X"00000010";
constant VBARa_REG_ADDR : std_logic_vector(31 downto 0) := X"00000014";
constant VBARb_REG_ADDR : std_logic_vector(31 downto 0) := X"00000018";
constant CLUT_REG_ADDR_1 : std_logic_vector(31 downto 0) := X"00000800";
constant CLUT_REG_ADDR_2 : std_logic_vector(31 downto 0) := X"00000804";

constant NUM_OF_PIXELS_PER_VGA_LINE : integer := 2*288;

end VGA_control_pack;

package body VGA_control_pack is
end;









