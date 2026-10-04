----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.01.2023 20:44:00
-- Design Name: 
-- Module Name: ff - Behavioral
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

entity jkff is
    Port ( J : in STD_LOGIC;
           K : in STD_LOGIC;
           Q : out STD_LOGIC;
           Qn : out STD_LOGIC;
           CLK : in STD_LOGIC;
           CLRn : in STD_LOGIC);
end jkff;

architecture Behavioral of jkff is

    signal Q0 : std_logic;
    
begin
    
    p_ff : process(CLK, CLRn, J, K)
    begin
        if (CLRn = '0') then
            Q0 <= '0';
        elsif rising_edge(CLK) then
            if (J = '1') and (K='0') then
                Q0 <= '1';
            elsif (J = '0') and (K='1') then
                Q0 <= '0';
            elsif (J = '1') and (K='1') then        
                Q0 <= not Q0;
            end if;
        end if;
    end process;
    
    Q <= Q0;
    Qn <= not Q0;

end Behavioral;
