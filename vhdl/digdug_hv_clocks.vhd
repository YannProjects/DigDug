----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.04.2026
-- Design Name: 
-- Module Name: digdug_hv_clocks - Behavioral
-- Project Name: Dig dug
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- Generation des horloges H/V issues de l'implementation Gala VHDL de DAR
-- Pour l'instant je suppose que le generation d'horloge est identique à celle de PacMan
-- et donc que le custom 07 reproduit ce qu'il y a au niveau de la generaiton d'horloge PacMan
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

entity hv_sync_gen_07 is
generic (
  g_digdug_clk_gen_v1      : natural := 0;       -- v1 = Generation horloges a partir du schema original digdug
  g_digdug_clk_gen_v2      : natural := 0;       -- v2 = Generation horloges à partir de l'implementation Verilog
  g_digdug_clk_gen_v3      : natural := 1        -- v3 = Generation horloges à partir de l'implementation Pacman  
);
port(
    i_clk      : in std_logic; -- 6 MHz
    i_reset_n  : in std_logic;
    o_hcnt     : out std_logic_vector(8 downto 0);
    o_h256n    : out std_logic;
    o_vcnt     : out std_logic_vector(8 downto 0);
    o_hsync    : out std_logic;
    o_vsync    : out std_logic;
    o_vblank   : out std_logic;
    o_csync    : out std_logic; -- composite sync for TV 
    o_hblank_n : out std_logic
);
end hv_sync_gen_07;

architecture Behavioral of hv_sync_gen_07 is

signal ff0h_q, ff0h_qn, c1h_tc, c2h_tc : std_logic;
signal c1v_tc, c2v_tc, hsync, vsync, vsyncn, ff0v_q, ff0v_qn : std_logic;
signal h256n, hsyncn, hblank, hblank_n, vblank, vblank_n, h256 : std_logic;
signal hcnt : unsigned( 8 downto 0) := "010000000"; -- 80
signal vcnt : unsigned( 8 downto 0) := "011111000"; -- 0F8
signal do_hsync : boolean;


constant HBLK_START : unsigned(8 downto 0) := to_unsigned(288, 9);
constant HSYNC_START : unsigned(8 downto 0) := to_unsigned(311, 9);
constant HSYNC_END : unsigned(8 downto 0) := to_unsigned(342, 9);
constant HBLK_END : unsigned(8 downto 0) := to_unsigned(511, 9);

constant VBLK_START : unsigned(8 downto 0) := to_unsigned(223, 9);
constant VBLK_END : unsigned(8 downto 0) := to_unsigned(511, 9);
constant VSYNC_START : unsigned(8 downto 0) := to_unsigned(226, 9);
constant VSYNC_END : unsigned(8 downto 0) := to_unsigned(233, 9);

begin

g_DigDug_Clk_v1 : if g_digdug_clk_gen_v1 = 1 generate

    -- FF 1H et 1V
    FF0H : entity work.SN74LS74N
    generic map(
        tSETUP => 0 ns,     -- Setup time before clock
        tPLHCP => 0 ns,     -- Clock rising
        tPHLCP => 0 ns,     -- Clock falling
        tPLHSC => 0 ns,     -- S/C rising
        tPHLSC => 0 ns      -- S/C falling
    )
    port map (
        X_1 => i_reset_n,
        X_2 => ff0h_qn,
        X_3 => i_clk,
        X_4 => '1',
        X_5 => ff0h_q,
        X_6 => ff0h_qn,
        
        X_8  => ff0v_qn,
        X_9  => ff0v_q,
        X_10 => '1',
        X_11 => hsync,
        X_12 => ff0v_qn,
        X_13 => i_reset_n        
    );
    
    hcnt(0) <= ff0h_q;
    vcnt(0) <= ff0v_q;

    --
    -- Compteur Horizontal
    --

    C1H: entity work.SN74LS161N
    generic map(
        tPLHT => 0 ns,
        tPHLT => 0 ns,
        tPLHQ => 0 ns,
        tPHLQ => 0 ns
    )
    port map (
        X_1 => i_reset_n,
        X_2 => i_clk,
        X_3 => '0',
        X_4 => '0',
        X_5 => '0',
        X_6 => '0',
        X_7 => ff0h_q,
        X_9 => '1',
        X_10 => ff0h_q,
        X_11 => hcnt(4),
        X_12 => hcnt(3),
        X_13 => hcnt(2),
        X_14 => hcnt(1),
        X_15 => c1h_tc 
    );
    
    C2H: entity work.SN74LS161N
    generic map(
        tPLHT => 0 ns,
        tPHLT => 0 ns,
        tPLHQ => 0 ns,
        tPHLQ => 0 ns
    )
    port map (
        X_1 => i_reset_n,
        X_2 => i_clk,
        X_3 => '0',
        X_4 => '0',
        X_5 => '1',
        X_6 => '0',
        X_7 => c1h_tc,
        X_9 => not c2h_tc,
        X_10 => c1h_tc,
        X_11 => h256n,
        X_12 => hcnt(7),
        X_13 => hcnt(6),
        X_14 => hcnt(5),
        X_15 => c2h_tc 
    );

    --
    -- Compteur Vertical
    --
    
    C1V: entity work.SN74LS161N
    generic map(
        tPLHT => 0 ns,
        tPHLT => 0 ns,
        tPLHQ => 0 ns,
        tPHLQ => 0 ns
    )
    port map (
        X_1 => i_reset_n,
        X_2 => hsync,
        X_3 => '0',
        X_4 => '0',
        X_5 => '1',
        X_6 => '1',
        X_7 => ff0v_q,
        X_9 => not c2v_tc,
        X_10 => ff0v_q,
        X_11 => vcnt(4),
        X_12 => vcnt(3),
        X_13 => vcnt(2),
        X_14 => vcnt(1),
        X_15 => c1v_tc 
    );
    
    C2V: entity work.SN74LS161N
    generic map(
        tPLHT => 0 ns,
        tPHLT => 0 ns,
        tPLHQ => 0 ns,
        tPHLQ => 0 ns
    )
    port map (
        X_1 => i_reset_n,
        X_2 => hsync,
        X_3 => '1',
        X_4 => '1',
        X_5 => '1',
        X_6 => '0',
        X_7 => c1v_tc,
        X_9 => not c2v_tc,
        X_10 => c1v_tc,
        X_11 => vsyncn,
        X_12 => vcnt(7),
        X_13 => vcnt(6),
        X_14 => vcnt(5),
        X_15 => c2v_tc 
    );
    
    o_h256n <= h256n;
    o_hcnt <= std_logic_vector(hcnt);
    o_vcnt <= std_logic_vector(vcnt);
    
    --
    -- HSYNC / VSYNC
    --
    
    FF0 : entity work.SN74LS74N
    generic map(
        tSETUP => 0 ns,     -- Setup time before clock
        tPLHCP => 0 ns,     -- Clock rising
        tPHLCP => 0 ns,     -- Clock falling
        tPLHSC => 0 ns,     -- S/C rising
        tPHLSC => 0 ns      -- S/C falling
    )
    port map (
        X_1 => not h256n,
        X_2 => not(hcnt(6) and hcnt(5)),
        X_3 => hcnt(4),
        X_4 => '1',
        X_5 => hblank,
        X_6 => hblank_n,

        X_8  => hsync,
        X_9  => hsyncn,
        X_10 => hblank,
        X_11 => hcnt(4),
        X_12 => hcnt(6),
        X_13 => '1'        
    );
    
    FF1 : entity work.SN74LS74N
    generic map(
        tSETUP => 0 ns,     -- Setup time before clock
        tPLHCP => 0 ns,     -- Clock rising
        tPHLCP => 0 ns,     -- Clock falling
        tPLHSC => 0 ns,     -- S/C rising
        tPHLSC => 0 ns      -- S/C falling
    )    
    port map (
        X_1 => i_reset_n,
        X_2 => not(vcnt(7) and vcnt(6) and vcnt(5)),
        X_3 => vcnt(4),
        X_4 => '1',
        X_5 => vblank_n,
        X_6 => vblank,

        X_10 => '1',
        X_11 => '0',
        X_12 => '0',
        X_13 => '1'               
    );
    
    o_csync <= hsyncn and vsyncn;
    o_hsync <= hsync;
    o_vsync <= not vsyncn;
    o_hblank_n <= hblank_n;
    o_vblank <= vblank;
    
end generate g_DigDug_Clk_v1;

g_DigDug_Clk_v2 : if g_digdug_clk_gen_v2 = 1 generate

process(i_clk, i_reset_n)
begin
    if i_reset_n = '0' then
        hcnt <= (others => '0');
        vcnt <= (others => '0');
    elsif rising_edge(i_clk) then
        case hcnt is
            when HSYNC_END =>
                hcnt <= to_unsigned(471,9);
            when HBLK_END =>
                hcnt <= (others => '0');
                case vcnt is
                    when VSYNC_END =>
                        vcnt <= to_unsigned(483,9);
                    when VBLK_END =>
                        vcnt <= (others => '0');
                    when others =>
                        vcnt <= vcnt + 1;
                end case;
            when others =>
                hcnt <= hcnt + 1;
            end case;
    end if;
end process;

hblank <= '1' when (hcnt >= HBLK_START) and (hcnt <= HBLK_END) else '0';
hsync <= '1' when (hcnt >= HSYNC_START) and (hcnt <= HSYNC_END) else '0';
vsync <= '1' when (vcnt >= VSYNC_START) and (vcnt <= VSYNC_END) else '0';
vblank <= '1' when (vcnt >= VBLK_START) and (vcnt <= VBLK_END) else '0';

o_csync <= (not hsync) and (not vsync);
o_hsync <= hsync;
o_vsync <= vsync;
o_hblank_n <= not hblank;
o_vblank <= vblank;
o_h256n <= not hcnt(8);
o_vcnt <= std_logic_vector(vcnt);
o_hcnt <= std_logic_vector(hcnt);
    
end generate g_DigDug_Clk_v2;

g_DigDug_Clk_v3 : if g_digdug_clk_gen_v3 = 1 generate

--
-- video timing
--
p_hvcnt : process
    variable hcarry,vcarry : boolean;
    begin
        wait until rising_edge(i_clk);
        hcarry := (hcnt = "111111111");
        if hcarry then
            hcnt <= "010000000"; -- 080
        else
            hcnt <= hcnt +"1";
        end if;
        -- hcnt 8 on circuit is 256H_L
        vcarry := (vcnt = "111111111");
        if do_hsync then
            if vcarry then
                vcnt <= "011111000"; -- 0F8
            else
                vcnt <= vcnt +"1";
            end if;
        end if;
    end process;

do_hsync <= (hcnt = "010101111"); -- 0AF
vsync <= not vcnt(8);

p_sync : process
begin
    wait until rising_edge(i_clk);
    -- Timing hardware is coded differently to the real hw
    -- to avoid the use of multiple clocks. Result is identical.
    if (hcnt = "010001111") then -- 08F
        hblank <= '1';
    elsif (hcnt = "011101111") then
        hblank <= '0'; -- 0EF
    end if;

    if do_hsync then
        hsync <= '1';
    elsif (hcnt = "011001111") then -- 0CF
        hsync <= '0';
    end if;

    if do_hsync then
        if (vcnt = "111101111") then -- 1EF
            vblank <= '1';
        elsif (vcnt = "100001111") then -- 10F
            vblank <= '0';
        end if;
    end if;
end process;

o_csync <= vsync or  hsync;
o_hsync <= hsync;
o_vsync <= vsync;
o_hblank_n <= not hblank;
o_vblank <= vblank;
h256n <= hcnt(8);
h256 <= not h256n;
o_vcnt <= std_logic_vector(vcnt);
o_hcnt <= std_logic_vector(hcnt);
o_h256n <= hcnt(8);
  
end generate g_DigDug_Clk_v3;

---------------------------------------------------------------------------------
-- Galaga video horizontal/vertical and sync generator by Dar (darfpga@aol.fr)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- Compteur horizontal : 511-128+1=384 pixels (48 tiles)
-- 192 ? 255 :  64 pixels debut de ligne  (8 dont 2 derni?res tiles affich?es)
-- 256 ? 511 : 256 pixels centre de ligne (32 tiles affich?es)
-- 128 ? 191 :  64 pixels fin de ligne    (8 dont 2 premi?res tiles affich?es)

-- Compteur vertical   : 263-000+1=264 lignes (33 tiles)
-- 000 ? 015 :  16 lignes debut de trame  (2 tiles)
-- 016 ? 239 : 224 lignes centrales       (28 tiles affich?es)
-- 240 ? 263 :  24 lignes fin de trame    (3 tiles

-- Synchro horizontale : hcnt=[176 ? 204] (29 pixels)
-- Synchro verticale   : vcnt=[260 ? 003] ( 8 lignes)


-- Vient de galaga_video.vhd
-- if rising_edge(clk) then    -- clk  6MHz

--   if hcntReg = 511 then 
--     hcntReg <= to_unsigned (128,9);
--   else
--     hcntReg <= hcntReg + 1;
--   end if;

--   if hcntReg = 191 then
--     if vcntReg = 263 then
--       vcntReg <= to_unsigned(0,9);
--     else
--       vcntReg <= vcntReg + 1;
--     end if;
--   end if;

--   if    hcntReg = (175+ 0-8+8) then hsync0 <= '0'; -- 1
--   elsif hcntReg = (175+29-8+8) then	hsync0 <= '1';
--   end if;

--   if    hcntReg = (175-8+8)        then hsync1 <= '0';
--   elsif hcntReg = (175+13-8+8)     then hsync1 <= '1'; -- 11
--   elsif hcntReg = (175   +192-8+8) then hsync1 <= '0';
--   elsif hcntReg = (175+13+192-8+8) then hsync1 <= '1'; -- 11
--   end if;

--   if    hcntReg = (175-8+8)     then hsync2 <= '0';
--   elsif hcntReg = (175-28-8+8)  then hsync2 <= '1';
--   end if;

--   if     vcntReg = 252-1 then csync <= hsync1;
--   elsif  vcntReg = 253-1 then csync <= hsync1;
--   elsif  vcntReg = 254-1 then csync <= hsync1; -- and hsync2;
--   elsif  vcntReg = 255-1 then csync <= hsync2; -- not(hsync1);
--   elsif  vcntReg = 256-1 then csync <= hsync2; -- not(hsync1);
--   elsif  vcntReg = 257-1 then csync <= hsync2; -- not(hsync1) or not(hsync2);
--   elsif  vcntReg = 258-1 then csync <= hsync1;
--   elsif  vcntReg = 259-1 then csync <= hsync1;
--   elsif  vcntReg = 260-1 then csync <= hsync1;
--   else                        csync <= hsync0;
--   end if;

--   if    vcntReg = 260 then vsync <= '0';
--   elsif vcntReg = 003 then vsync <= '1';
--   end if;

--   if    hcntReg = (127+16+8) then hblank <= '1'; 
--   elsif hcntReg = (255-17+8+1) then hblank <= '0';
--   end if;

--   if    vcntReg = (240+1-1) then vblank <= '1';
--   elsif vcntReg = (015+1) then vblank <= '0';
--   end if;

--   blankn <= not (hblank or vblank); 

end architecture;