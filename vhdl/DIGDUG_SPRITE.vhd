--------------------------------------------
-- FPGA DigDug (Sprite part)
--
-- Copyright (c) 2017 MiSTer-X
-- Converted from Verilog to VHDL
-- Fichier convertit de Verilog à VHDL par IA ChatGPT pour essayer de comprendre 
-- le fonctionnement du module Sprite de DigDug.
--------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DIGDUG_SPRITE is
    port (
        RCLK        : in  STD_LOGIC;  -- Rendering Clock
        VCLK        : in  STD_LOGIC;  -- Video Dot Clock
        VCLKx2      : in  STD_LOGIC;  -- Video Dot Clockx2
        
        POSH        : in  STD_LOGIC_VECTOR(8 downto 0);
        POSV        : in  STD_LOGIC_VECTOR(8 downto 0);
        
        SPATCL      : out STD_LOGIC;
        SPATAD      : out STD_LOGIC_VECTOR(6 downto 0);
        SPATDT      : in  STD_LOGIC_VECTOR(23 downto 0);
        
        SPCOL       : out STD_LOGIC_VECTOR(4 downto 0);
        
        V_FLIP      : in  STD_LOGIC;
        
        ROMCL       : in  STD_LOGIC;  -- Downloaded ROM image
        ROMAD       : in  STD_LOGIC_VECTOR(15 downto 0);
        ROMDT       : in  STD_LOGIC_VECTOR(7 downto 0);
        ROMEN       : in  STD_LOGIC
    );
end DIGDUG_SPRITE;

architecture RTL of DIGDUG_SPRITE is

    -- Internal signals
    signal PH           : STD_LOGIC_VECTOR(8 downto 0);
    signal PV           : STD_LOGIC_VECTOR(8 downto 0);
    signal TY           : STD_LOGIC_VECTOR(8 downto 0);
    
    signal PHASE        : STD_LOGIC_VECTOR(3 downto 0);
    signal SIDE         : STD_LOGIC;
    
    signal ADR          : STD_LOGIC_VECTOR(7 downto 0);
    signal ATR0         : STD_LOGIC_VECTOR(23 downto 0);
    signal ATR1         : STD_LOGIC_VECTOR(23 downto 0);
    
    signal WXP          : STD_LOGIC_VECTOR(8 downto 0);
    signal WCN          : STD_LOGIC_VECTOR(8 downto 0);
    
    -- Control signals
    signal SZ           : STD_LOGIC;
    signal SS           : STD_LOGIC_VECTOR(8 downto 0);
    signal SC           : STD_LOGIC_VECTOR(5 downto 0);
    signal SX           : STD_LOGIC_VECTOR(8 downto 0);
    signal SY           : STD_LOGIC_VECTOR(8 downto 0);
    signal SU           : STD_LOGIC_VECTOR(8 downto 0);
    signal SV           : STD_LOGIC_VECTOR(8 downto 0);
    signal SM           : STD_LOGIC_VECTOR(7 downto 0);
    signal SL           : STD_LOGIC_VECTOR(7 downto 0);
    signal SN           : STD_LOGIC_VECTOR(7 downto 0);
    signal SD           : STD_LOGIC;
    
    signal ABORT        : STD_LOGIC;
    signal STANDBY      : STD_LOGIC;
    signal ATRTAIL      : STD_LOGIC;
    signal DRAWING      : STD_LOGIC;
    
    signal WSX          : STD_LOGIC_VECTOR(8 downto 0);
    
    -- ROM chip signals
    signal CHRD         : STD_LOGIC_VECTOR(7 downto 0);
    signal PIX          : STD_LOGIC_VECTOR(7 downto 0);
    
    -- CLUT signals
    signal WDT          : STD_LOGIC_VECTOR(7 downto 0);
    
    -- LBUF signals
    signal LBOUT        : STD_LOGIC_VECTOR(4 downto 0);
    signal POSH_READ    : STD_LOGIC_VECTOR(8 downto 0);
    
    signal radr0        : STD_LOGIC_VECTOR(9 downto 0);
    signal radr1        : STD_LOGIC_VECTOR(9 downto 0);
    signal radr_changed : STD_LOGIC;

begin

    -- Position calculations
    PH <= std_logic_vector(unsigned(POSH) + 1);
    PV <= std_logic_vector(unsigned'("0" & POSV) + 2) when V_FLIP = '0'
          else std_logic_vector(to_unsigned(221, 9) - unsigned(POSV));
    
    -- Attribute decoding
    SZ <= ATR0(7);
    SS <= std_logic_vector(to_unsigned(32, 9)) when SZ = '1'
          else std_logic_vector(to_unsigned(16, 9));
    SC <= ATR1(5 downto 0);
    SX <= std_logic_vector(unsigned(ATR1(15 downto 8) & '0') - 39);
    SY <= std_logic_vector(to_unsigned(256, 9) - unsigned(TY));
    
    -- XOR flip operations
    SU <= std_logic_vector(unsigned(SS) - unsigned(WCN)) xor (8 downto 0 => ATR0(16));
    SV <= std_logic_vector(unsigned(PV) - unsigned(SY)) xor (8 downto 0 => ATR0(17));
    
    -- Sprite code selection
    SM <= ATR0(7 downto 0);
    SL <= (SM(7) or SM(5)) & (SM(6) or SM(4)) & SM(3 downto 0) & SV(4) & SU(4);
    SN <= SL when SZ = '1' else SM;
    
    -- Visibility check
    SD <= ATR1(17) or ((PV < SY) and (SY < 496)) or (PV >= (SY + SS));
    
    -- TY calculation
    TY <= std_logic_vector(unsigned(ATR0(15 downto 8)) + 16) when SZ = '1'
          else ATR0(15 downto 8) & "00000000";
    TY <= std_logic_vector((unsigned(ATR0(15 downto 8) & "00000000") + to_unsigned(30, 9)));
    
    -- Control signal generation
    ABORT <= '1' when PH = std_logic_vector(to_unsigned(288, 9)) else '0';
    STANDBY <= '0' when PH = std_logic_vector(to_unsigned(289, 9)) else '1';
    ATRTAIL <= ADR(7);
    DRAWING <= '1' when WCN /= std_logic_vector(to_unsigned(1, 9)) else '0';
    
    SPATCL <= not RCLK;
    SPATAD <= ADR(6 downto 0);
    
    WSX <= '0' & std_logic_vector(unsigned(SX(7 downto 0)) + 256) when SX(7 downto 0) < 16
           else '0' & SX(7 downto 0);
    
    -- Main state machine
    process(RCLK)
    begin
        if rising_edge(RCLK) then
            if ABORT = '1' then
                PHASE <= (others => '0');
                WCN <= (others => '0');
            else
                case PHASE is
                    when "0000" =>
                        SIDE <= PV(0);
                        ADR <= (others => '0');
                        WCN <= (others => '0');
                        if STANDBY = '1' then
                            PHASE <= PHASE;  -- LOOP
                        else
                            PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                        end if;
                    
                    when "0001" =>
                        if ATRTAIL = '1' then
                            PHASE <= "0001";  -- NXTA
                        else
                            PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                        end if;
                    
                    when "0010" =>
                        ATR0 <= SPATDT;
                        ADR <= std_logic_vector(unsigned(ADR) + 1);
                        PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                    
                    when "0011" =>
                        ATR1 <= SPATDT;
                        ADR <= std_logic_vector(unsigned(ADR) + 1);
                        PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                    
                    when "0100" =>
                        WXP <= WSX;
                        WCN <= SS;
                        if SD = '1' then
                            PHASE <= "0001";  -- NXTA
                        else
                            PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                        end if;
                    
                    when "0101" =>
                        -- CLUT Read
                        PHASE <= std_logic_vector(unsigned(PHASE) + 1);  -- NEXT
                    
                    when "0110" =>
                        -- LBUF Write
                        WXP <= std_logic_vector(unsigned(WXP) + 1);
                        WCN <= std_logic_vector(unsigned(WCN) - 1);
                        if DRAWING = '1' then
                            PHASE <= "0101";
                        else
                            PHASE <= "0001";  -- NXTA
                        end if;
                    
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
    
    -- ROM Chip read (character data)
    process(RCLK, ROMCL)
    begin
        if ROMCL = '1' then
            CHRD <= (others => '0');
        elsif rising_edge(RCLK) then
            if PHASE = "0101" and ROMEN = '1' and ROMAD(15 downto 14) = "01" then
                CHRD <= ROMDT;
            end if;
        end if;
    end process;
    
    -- Pixel shift
    PIX <= CHRD sll to_integer(unsigned(SU(1 downto 0)));
    
    -- CLUT read (Color Lookup Table)
    process(RCLK, ROMCL)
    begin
        if ROMCL = '1' then
            WDT <= (others => '0');
        elsif rising_edge(RCLK) then
            if PHASE = "0101" and ROMEN = '1' and ROMAD(15 downto 8) = x"D9" then
                WDT <= ROMDT;
            end if;
        end if;
    end process;
    
    -- LBUF line buffer (simplified - external module in real design)
    POSH_READ <= std_logic_vector(to_unsigned(287, 9) - unsigned(PH)) when V_FLIP = '1'
                 else PH;
    
    LBOUT <= "1" & WDT(3 downto 0) when (PHASE = "0110" and (PIX(7) = '1' or PIX(3) = '1'))
             else "0" & WDT(3 downto 0);
    
    -- Read address registers
    radr_changed <= '1' when radr0 /= radr1 else '0';
    
    process(VCLK)
    begin
        if rising_edge(VCLK) then
            radr0 <= not SIDE & POSH_READ;
        end if;
    end process;
    
    process(VCLK)
    begin
        if falling_edge(VCLK) then
            if radr_changed = '1' then
                SPCOL <= LBOUT;
            end if;
            radr1 <= radr0;
        end if;
    end process;

end RTL;
