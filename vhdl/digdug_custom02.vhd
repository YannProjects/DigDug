----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.06.2026 20:18:30
-- Design Name: 
-- Module Name: digdug_custom02 - Behavioral
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

entity digdug_custom02 is
port (
    i_clr_n : in std_logic; -- Reset
    i_clk : in std_logic; -- 6 MHz
    i_flip : in std_logic; -- Normal / Reverse
    i_data0 : in std_logic_vector(7 downto 0); -- D0..7
    i_data1 : in std_logic_vector(7 downto 0); -- D10..17
    o_Q00 : out std_logic;
    o_Q01 : out std_logic;
    o_Q10 : out std_logic;
    o_Q11 : out std_logic;
    i_mode : in std_logic; -- 0 : 4 bits mode, 1 : 8 bits mode. Seul le mode 0 est utilise pour DigDug
    s_l_n : in std_logic; -- SHIFT / LOADn
    LDEn : in std_logic -- Load enable (pas utilise par DigDug
);
end digdug_custom02;

architecture Behavioral of digdug_custom02 is

    signal r0 : std_logic_vector(7 downto 0);
    signal r1 : std_logic_vector(7 downto 0);

begin
    process(i_clk, i_clr_n)
    begin
        if i_clr_n = '0' then
            r0 <= (others => '0');
            r1 <= (others => '0');
        elsif rising_edge(i_clk) then
            if s_l_n = '0' then
                -- LOAD PARALLÈLE
                r0 <= i_data0;
                r1 <= i_data1;
            else
                -- SHIFT
                if i_flip = '0' then
                    -- SHIFT LEFT
                    r0 <= r0(6 downto 0) & '0';
                    r1 <= r1(6 downto 0) & '0';
                else
                    -- SHIFT RIGHT
                    r0 <= '0' & r0(7 downto 1);
                    r1 <= '0' & r1(7 downto 1);
                end if;
            end if;
        end if;
    end process;

    -- SORTIES : bit shifté selon le sens
    o_Q00 <= r0(3) when i_flip = '0' else r0(0);
    o_Q01 <= r0(7) when i_flip = '0' else r0(4);

    o_Q10 <= r1(3) when i_flip = '0' else r1(0);
    o_Q11 <= r1(7) when i_flip = '0' else r1(4);

end Behavioral;