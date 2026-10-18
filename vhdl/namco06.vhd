----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.10.2026 19:25:54
-- Design Name: 
-- Module Name: namco06 - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity namco06 is
port (
    i_clk       : in std_logic; -- 6 MHz
    i_rst_n     : in std_logic;
    i_h         : in std_logic_vector(8 downto 0);
    i_edb       : in std_logic_vector(7 downto 0); -- Customs bus
    o_edb       : out std_logic_vector(7 downto 0);
    o_er_w_r_n  : out std_logic; -- Rn/W signal to custom 51xx / 53xx
    o_ecs       : out std_logic_vector(3 downto 0); -- Customs CS
    i_sel       : in std_logic; -- Control (1) / Data (0)
    i_r_w_n     : in std_logic; -- CPU R/Wn
    i_cs        : in std_logic; -- Custom 06 CS
    o_nmi_1_n   : out std_logic; -- CPU NMI1n
    i_cpu_data  : in std_logic_vector(7 downto 0); -- CPU data
    o_cpu_data  : out std_logic_vector(7 downto 0) -- CPU data
);
end namco06;

architecture Behavioral of namco06 is

signal control_reg : std_logic_vector(7 downto 0);
signal timer_stop, read_stretch : std_logic;
signal timer_counter, nmi_period : unsigned (7 downto 0);

begin
    process(i_clk)
    begin
        if (i_rst_n = '0') then
            timer_stop <= '0';
            read_stretch <= '0';
            control_reg <= (others => '0');
            timer_counter <= (others => '0');
            o_nmi_1_n <= '1';
            o_ecs <= (others => '0');
        elsif rising_edge(i_clk) then
            if i_cs = '1' then
                -- R/Wn CPU
                if i_r_w_n = '0' then
                    -- data_w (0x7000)
                    if i_sel = '0' then
                        -- Juste pour le 51XX
                        o_edb <= i_cpu_data;
                    -- ctrl_w (0x7100)
                    else
                        control_reg <= "000" & i_cpu_data(4 downto 0);
                        -- If the divider is zero, stop the timer.
                        if i_cpu_data(7 downto 5) = "000" then
                            timer_stop <= '1';
                            o_nmi_1_n <= '1';
                            o_ecs <= (others => '0');
                        else
	 	                    -- NMI is cleared immediately if this is a read.
		                    -- It will be suppressed the next clock cycle.
		                    -- Bit 4 = read/!write
                            if i_cpu_data(4) = '1' then
                                o_nmi_1_n <= '1';
                                read_stretch <= '1';
                            else
                                read_stretch <= '0';
                                timer_counter <= (others => '0');
                                -- L'horloge est à 6 MHz et le timer de NMI a 3 MHz, donc c'est le nombre de bits du registre de controle + 1
                                nmi_period <= shift_left(X"01", to_integer(unsigned(i_cpu_data(7 downto 5))) + 1);
                            end if;
                            timer_stop <= '0';
                        end if;
                    end if;
                else
                    -- data_r (0x7000)
                    if i_sel = '0' then
                        -- Port O du 51XX ou 53XX vers CPU
                        o_cpu_data <= i_edb;
                    -- ctrl_r (0x7100)
                    else
                        o_cpu_data <= control_reg;
                    end if;
                end if;
            else
                -- 64 H
                if i_h(5 downto 0) = "111111" then
                    -- Compteur NMI active ?
                    -- read_stretch supprime le cycle suivant le clear NMI
                    if timer_stop = '0' then
                        o_nmi_1_n <= '1';
                        if timer_counter < nmi_period then
                            timer_counter <= timer_counter + 1;
                        else
                            if read_stretch = '0' then
                                o_nmi_1_n <= '0';
                            end if;
                            timer_counter <= (others => '0');
                            read_stretch <= '0';                
                        end if;
                    end if;
                end if;
            end if;
       end if;
    end process;
    
    -- Le bit 5 du registre de contrôle indique un read ou un write vers le peripherique 51xx ou 53xx
    o_er_w_r_n <= control_reg(4);
    
end Behavioral;
