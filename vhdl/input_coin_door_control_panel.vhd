----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.10.2026 23:03:19
-- Design Name: 
-- Module Name: input_coin_door_control_panel - Behavioral
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

entity input_coin_door_control_panel is
port (
    i_clk         : in std_logic; -- 6 MHz
    i_reset_n     : in std_logic;
    i_hpos        : in std_logic_vector(8 downto 0);
    i_vblk        : in std_logic;
    i_mod         : in std_logic_vector(2 downto 0);
    i_ctrl_data   : in std_logic; -- Control / Data 06xx
    i_cpu_r_w_n   : in std_logic; -- CPU R/Wn
    i_db          : in std_logic_vector(7 downto 0);
    o_db          : out std_logic_vector(7 downto 0);
    o_nmi_1       : out std_logic;
    i_ioen        : in std_logic; -- CLK => 2H
    i_controls    : in std_logic_vector(15 downto 0); -- Up/Down/Right/Left/Coin/...
    i_dip_sw_1    : in std_logic_vector(6 downto 0);
    i_dip_sw_2    : in std_logic_vector(7 downto 0);
    i_cocktail    : in std_logic;
    o_coin_lock   : out std_logic;
    o_led_1       : out std_logic;
    o_led_2       : out std_logic;
    o_coin_cntr_1 : out std_logic;
    o_coin_cntr_2 : out std_logic
);
end input_coin_door_control_panel;

architecture Behavioral of input_coin_door_control_panel is

signal io_controller_r_n_w : std_logic;
signal controllers_cs, led_coins : std_logic_vector(3 downto 0);
signal io_controller_K, controllers_outputs, cus51_output, cus53_output : std_logic_vector(7 downto 0);

begin

    -- Namco 5xxx/5xxx controller
    U2E : entity work.namco06
    port map(
        i_clk => i_clk, -- 6 MHz
        i_rst_n => i_reset_n,
        i_h => i_hpos, -- Utilise pour détecter le front montant 64H qui est normalement l'horloge utilisee pour le custom 06xx
        i_edb => controllers_outputs,
        o_edb => io_controller_K, -- K port Namco 51xx
        o_ecs => controllers_cs,
        o_er_w_r_n => io_controller_r_n_w, 
        i_sel => i_ctrl_data, -- Control (1) / Data (0)
        i_r_w_n => i_cpu_r_w_n,
        i_cs => i_hpos(7), -- 128H
        o_nmi_1_n => o_nmi_1,
        i_cpu_data => i_db,
        o_cpu_data => o_db
    );

    -- Namco 51xx Coin I/O controller
    U1_2E : entity work.custom51xx
    port map(
        i_clk => i_ioen,
        i_rst_n => i_reset_n,
        i_irq_n => controllers_cs(1),
        o_so => o_coin_lock,
        i_si => '0',
        i_tc => i_vblk, -- VBLANK
        o_p => led_coins, -- Port des LEDs . coin control
        i_edb => (others => '0'), -- Pas utilise (seulement en sortie) ?
        o_edb => cus51_output,
        i_r => i_controls,
        i_k => io_controller_r_n_w & io_controller_K(2 downto 0)
    );
     
    -- Namco 53xx Steering controller
    U1_2C : entity work.custom53xx
    port map(
        i_clk => i_ioen,
        i_rst_n => i_reset_n,
        i_irq_n => controllers_cs(0),
        o_so => open,
        i_si => '0',
        i_tc => '0', -- Pas utilise
        o_p => open, -- Port des LEDs . coin control
        i_edb => (others => '0'), -- Pas utilise (seulement en sortie) ?
        o_edb => cus53_output,
        i_r => i_dip_sw_1 & i_cocktail & i_dip_sw_2,
        i_k => i_mod & '0'
     );
     
     o_led_1 <= led_coins(0);
     o_led_2 <= led_coins(1);
     o_coin_cntr_1 <= led_coins(2);
     o_coin_cntr_2 <= led_coins(3);
     
     process(controllers_cs, cus51_output, cus53_output)
     begin
         case controllers_cs is
            when "1110" => 
                controllers_outputs <= cus53_output;
            when "1101" =>
                controllers_outputs <= cus51_output;
            when others => 
                controllers_outputs <= (others => '1');
         end case;
     end process;

end Behavioral;
