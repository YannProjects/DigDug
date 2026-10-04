----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.06.2026 23:00:23
-- Design Name: 
-- Module Name: digdug_color_controller - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_color_controller is
port (
    i_rst_n : in std_logic;
    i_clk : in std_logic; -- 6 MHz
    i_shift_load_n : in std_logic;
    i_flip : in std_logic;
    i_flip_0 : in std_logic;
    i_flip_1 : in std_logic;
    i_flip_2 : in std_logic;
    i_hflip_star : in std_logic;
    i_vflip_star : in std_logic;
    i_spvcnt : in unsigned(4 downto 0);
    i_sptile_num : in std_logic_vector(7 downto 0); -- PD0..7
    i_tile_bg_data : in std_logic_vector(7 downto 0); -- POD0..7
    i_vset_n : in std_logic;
    o_msc : out std_logic_vector(1 downto 0);
    o_psc : out std_logic_vector(1 downto 0)
);
end digdug_color_controller;

architecture Behavioral of digdug_color_controller is

signal sprite_data_1, sprite_data_2 : std_logic_vector(3 downto 0);
signal spgraphx_do_1, spgraphx_do_2, spgraphx_do_3, spgraphx_do_4, spgraphx_do, sprite_data, sptile_num : std_logic_vector(7 downto 0);
signal spflips, spgraphx_addr : std_logic_vector(13 downto 0);
signal spflip_2V, spflip_2H : std_logic_vector(1 downto 0);
signal spflip_H, spflip_V, vset_n_0, vset_n_1 : std_logic;

begin

    -- U7C/8C U7AB/8AB (ROM graphique sprites)
    -- 136007 X16
    U8C : entity work.dist_mem_gen_u8c
    port map (
        a => spgraphx_addr(13 downto 8) & spgraphx_addr(5 downto 0),
        spo => spgraphx_do_1
    );

    -- 136007 X17
    U7C : entity work.dist_mem_gen_u7c
    port map (
        a => spgraphx_addr(13 downto 8) & spgraphx_addr(5 downto 0),
        spo => spgraphx_do_2
    );

    -- 136007 X18
    U8AB : entity work.dist_mem_gen_u8ab
    port map (
        a => spgraphx_addr(11 downto 0),
        spo => spgraphx_do_3
    );

    -- 136007 X19
    U7AB : entity work.dist_mem_gen_u7ab
    port map (
        a => spgraphx_addr(11 downto 0),
        spo => spgraphx_do_4
    );
    
    -- U9B
    U9B : process(i_clk)
    begin
        if rising_edge(i_clk) then
            vset_n_1 <= i_vset_n;
            vset_n_0 <= vset_n_1;
            -- Rising edge VSETn 
            if (vset_n_1 = '0') and (vset_n_0 = '1') then
                sptile_num <= i_sptile_num;
            end if;
        end if;
    end process;
        
    -- U8/9A
    with sptile_num(7 downto 6) select
    spgraphx_do <= spgraphx_do_1 when "00",
                    spgraphx_do_2 when "01",
                    spgraphx_do_3 when "10",
                    spgraphx_do_4 when "11",
                    X"FF" when others;
    
    sprite_data_1 <= spgraphx_do(7 downto 4) when i_hflip_star = '0' else
                 spgraphx_do(4) & spgraphx_do(5) & spgraphx_do(6) & spgraphx_do(7);
    sprite_data_2 <= spgraphx_do(3 downto 0) when i_hflip_star = '0' else
                 spgraphx_do(0) & spgraphx_do(1) & spgraphx_do(2) & spgraphx_do(3);
    sprite_data <= sprite_data_1 & sprite_data_2;
    
    -- U5D custom 02
    U5D: entity work.digdug_custom02
    port map (
        i_clr_n => i_rst_n,
        i_clk => i_clk,
        i_flip => i_flip,
        i_data0 => sprite_data,
        i_data1 => i_tile_bg_data,
        o_Q00 => o_msc(0),
        o_Q01 => o_msc(1),
        o_Q10 => o_psc(0),
        o_Q11 => o_psc(1),
        i_mode => '0',
        s_l_n => i_shift_load_n,
        LDEn => '0'
    );
        
    -- Equivalences sur le schema DigDug vs Galaga:
    -- HFLIP* => spdata(0)
    -- FLIP => FLIP
    -- FLIP 0/1/2 => 4H* / 8H* / 16H*
    -- U5B
    -- Sur le schema je ne retrouve pas les XOR qui generent les signaux 1/2/4/8/16V*
    -- J'ai reproduit ce que j'ai trouvé dans le schema Galaga et l'implementation RTL Dar
    spflip_H <= i_hflip_star xor i_flip;
    spflip_2H <= spflip_H & spflip_H;
    spflip_V <= i_vflip_star;
    spflip_2V <= spflip_V & spflip_V;
    
    -- U4B et le circuit qui manque sur le schema pour générer 1V*/2V*/4V*/8V*/16V* (récupéré
    -- du schéma de Galaga et de l'implementation RTL Dar)
    spflips <= "000000" & spflip_V & spflip_H & spflip_V & spflip_2H & spflip_2V & spflip_V;
    
    -- Adresse U8C/U7C U8A/B U7A/B (ROM graphique des sprites)
    spgraphx_addr <= (sptile_num(5 downto 0) & i_spvcnt(4) & i_flip_2 & i_spvcnt(3) & i_flip_1 & i_flip_0 & std_logic_vector(i_spvcnt(2 downto 0))) xor spflips;

end Behavioral;
