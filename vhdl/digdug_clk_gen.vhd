----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.07.2020 11:50:50
-- Design Name: 
-- Module Name: Clocks_gen - Behavioral
-- Project Name: Dig Dug
-- Target Devices: Artyx 7
-- Tool Versions: 
-- Description: Génération des horloges pour le core dig dug
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

entity digdug_clocks_gen is
    Port ( i_clk_main : in STD_LOGIC;
           o_clk_52m : out STD_LOGIC;
           o_clk_vga : out STD_LOGIC;
           o_clk_6M : out STD_LOGIC;
           o_clk_uart : out STD_LOGIC;
           i_rst : in std_logic;
           o_pll_locked : out std_logic);
end Clocks_gen;

architecture Based_on_IP of Clocks_gen is

  signal clk_sys : std_logic;
  signal J, K, Q, Qn : std_logic_vector(1 downto 0);
    
  component jkff is
    Port ( J : in STD_LOGIC;
           K : in STD_LOGIC;
           Q : out STD_LOGIC;
           Qn : out STD_LOGIC;
           CLK : in STD_LOGIC;
           CLRn : in STD_LOGIC);
  end component;

  begin
  
      -- Composant utilisé pour générer les horloges PacMan et du controlleur VGA:
      -- VGA_CLK: 25,1 MHz pour le controlleur VGA
      -- 52 MHz: dual RAM contrôleur VGA
      -- 6 MHz: PacMan core        
      clk_gen : entity work.clk_wiz_0
      port map (
          -- reset => i_rst,
          locked => o_pll_locked,
          clk_main => i_clk_main,
          clk_52m => o_clk_52m,
          clk_vga => o_clk_vga,
          clk_sys => clk_sys
      );
  
      -- 74LS107 - 8A
      sim_6M : for i in 0 to 1 generate
      begin
        inst: jkff
            port map (
                J => J(i),
                K => K(i),
                Q => Q(i),
                Qn => Qn(i),
                CLK => clk_sys, -- 18 MHz
                CLRn => not i_rst
           );
      end generate;
    
      J(0) <= Qn(1);
      K(0) <= '1';
      J(1) <= Q(0);
      K(1) <= '1';
      
      clk_6M_buffer : BUFG 
      port map (
        I => not Q(1),
        O => o_clk_6M
      );
      
      clk_6M_star_buffer : BUFG 
      port map (
        I => not Qn(0),
        O => o_clk_6M_star
      );
      
      clk_6M_star_n_buffer : BUFG 
      port map (
        I => Qn(0),
        O => o_clk_6M_star_n
      );
      
      o_clk_uart <= clk_sys;

end Based_on_IP;

