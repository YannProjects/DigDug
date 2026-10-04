----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.04.2026
-- Design Name: 
-- Module Name: Clk generation for dig dug core - Behavioral
-- Project Name: Dig dug
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

entity digdug_clocks is
port ( i_clk_3x : in std_logic;
       i_rst_sysn : in std_logic;
       o_clk_digdug : out std_logic
);
end digdug_clocks;

architecture Behavioral of digdug_clocks is

  component jkff is
    Port ( J : in std_logic;
           K : in std_logic;
           Q : out std_logic;
           Qn : out std_logic;
           CLK : in std_logic;
           CLRn : in std_logic);
  end component;
  
  signal J, K, Q, Qn : std_logic_vector(1 downto 0);
  signal clk_3x : std_logic;

begin
    -- 74LS107 - 2R
    sim_6M : for i in 0 to 1 generate
    begin
      inst: jkff
      port map (
        J => J(i),
        K => K(i),
        Q => Q(i),
        Qn => Qn(i),
        CLK => i_clk_3x, -- 18 MHz
        CLRn => i_rst_sysn
      );
    end generate;
    
    J(0) <= Qn(1);
    K(0) <= '1';
    J(1) <= Q(0);
    K(1) <= '1';

    clk_6M_star_buffer : BUFG 
    port map (
      I => not Q(1),
      O => o_clk_digdug
    );

end Behavioral;
