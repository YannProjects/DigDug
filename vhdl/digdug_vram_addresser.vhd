----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.04.2026 12:07:02
-- Design Name: 
-- Module Name: digdug_vram_addresser - Behavioral
-- Project Name: DIGDUG
-- Target Devices: Xilinx Artyx 7
-- Tool Versions: 
-- Description: Generation adresses VRAM en supposant que c'est la meme chose que le VRAM addresse PacMan...
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digdug_vram_addresser is
generic (
  vram_addresser_v1      : natural := 0;       -- v1 = Generation horloges a partir de la version Verilog
  vram_addresser_v2      : natural := 1        -- v2 = Generation horloges à partir de l'implementation Pacman
);
port(
    i_h      : in std_logic_vector(8 downto 0);
    i_h256n  : in std_logic;
    i_flip   : in std_logic;
    i_v      : in std_logic_vector(8 downto 0);
    o_ab     : out std_logic_vector(10 downto 0)
);
end digdug_vram_addresser;

architecture Behavioral of digdug_vram_addresser is

  -- Pour la version Pacman du vram addresser
  signal f      : std_logic_vector(7 downto 3);
  signal hp, vp : std_logic_vector(7 downto 3);
  signal sel    : std_logic;
  signal y157   : std_logic_vector(11 downto 0);
  signal ab_pm  : std_logic_vector(11 downto 0);

  
  signal ph, pv_offset, pv : unsigned(8 downto 0);
  signal scol, srow : unsigned(5 downto 0);
  signal ab : unsigned(9 downto 0);

begin

    -- Version issue de l'implementation DigDug Verilog
    g_vram_addresser_v1 : if vram_addresser_v1 = 1 generate
        -- Version issue de la version Verilog de DigDug
        ph <= (286 - unsigned(i_h)) when i_flip = '1' else unsigned(i_h) + 1;
        pv_offset <= "000000001" when (ph >= 504) else "000000000";
        pv <= (223 - unsigned(i_v)) when i_flip = '1' else unsigned(i_v) + pv_offset;
        
        scol <= ph(8 downto 3) - "00010";
        srow <= pv(8 downto 3) + "00010";
        
        ab <= scol(4 downto 0) & srow(4 downto 0) when scol(5) = '1' else srow(4 downto 0) & scol(4 downto 0);
        o_ab <= '0' & std_logic_vector(ab);  
    end generate g_vram_addresser_v1;
    
    -- Version issue de PacMan
    g_vram_addresser_v2 : if vram_addresser_v2 = 1 generate
        f  <= (others => i_flip);
        vp <= i_v(7 downto 3) xor f;
        hp <= i_h(7 downto 3) xor f;
        
        sel <= not ( (i_h(5) xor i_h(4)) or (i_h(5) xor i_h(6)) );
        
        p_y157 : process(sel, i_h, hp, vp)
        begin
            if (sel = '1') then
              y157 <= '0' & i_h(2) & hp(6) & hp(6) & hp(6) & hp(6) & hp(3) & std_logic_vector(vp(7 downto 3));
              -- y157 <= '0' & '0' & hp(6) & hp(6) & hp(6) & hp(6) & hp(3) & std_logic_vector(vp(7 downto 3));
            else
              y157 <= "11111111" & i_h(6 downto 4) & i_h(2);
            end if;
        end process;
        
        ab_pm <= y157 when i_h256n = '0' else  '0' & i_h(2) & vp(7 downto 3) & hp(7 downto 3);      
        o_ab <= ab_pm(10 downto 0);
        
    end generate g_vram_addresser_v2;    

    -- Version issue de la version VHDL de Galaga
    -- bgtile_addr <= 	"10000" & hcnt(1) & vcnt(7 downto 3) & hcnt(7 downto 3)                                when (hcnt(8)='1' and flip_h='0') else
    --                         "10000" & hcnt(1) & hcnt(4) & hcnt(4) & hcnt(4) & hcnt(4) & hcnt(3) & vcnt(7 downto 3) when (hcnt(8)='0' and flip_h='0') else
    --                         "10000" & hcnt(1) & not( vcnt(7 downto 3) & hcnt(7 downto 3))                          when (hcnt(8)='1' and flip_h='1') else
    --                         "10000" & hcnt(1) & not( hcnt(4) & hcnt(4) & hcnt(4) & hcnt(4) & hcnt(3) & vcnt(7 downto 3));
    -- o_ab <= i_h(1) & i_v(7 downto 3) & i_h(7 downto 3) when (i_h256n='0' and i_flip='0') else
    --         i_h(1) & i_h(4) & i_h(4) & i_h(4) & i_h(4) & i_h(3) & i_v(7 downto 3) when (i_h256n='1' and i_flip='0') else
    --         i_h(1) & not( i_v(7 downto 3) & i_h(7 downto 3)) when (i_h256n='0' and i_flip='1') else
    --         i_h(1) & not( i_h(4) & i_h(4) & i_h(4) & i_h(4) & i_h(3) & i_v(7 downto 3));

    -- Version issue du VRAM addresser PacMan
    -- f  <= (others => i_flip);
    -- vp <= i_v(7 downto 3) xor f;
    -- hp <= i_h(7 downto 3) xor f;
    
    -- sel <= not ( (i_h(5) xor i_h(4)) or (i_h(5) xor i_h(6)) );
    
    -- y157 <= i_h(2) & hp(6) & hp(6) & hp(6) & hp(6) & hp(3) & vp(7 downto 3) when sel = '1' else
    --         "1111111" & i_h(6 downto 4) & i_h(2);
    
    -- o_ab <= i_h(2) & vp(7 downto 3) & hp(7 downto 3) when (i_h256n = '1') else
    --         y157;
    
end Behavioral;
