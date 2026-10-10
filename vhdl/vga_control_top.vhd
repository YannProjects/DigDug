----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.07.2021 10:42:27
-- Design Name: 
-- Module Name: vga_control_top - Behavioral
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
-- Composant charge de l'initialisation du controller VGA et de l'interface entre l'affichage 
-- issu du core du jeu et le controller VGA OpenCore
-- Principe:
-- On ecrit les donnees video du jeu dans une RAM sur 8 (3 bits de R, G, 2 bits de bleu) bits avec l'horloge i_sys_clk
-- L'adresse d'ecriture est resette si i_vsync = 1 (synchro trame)
-- Le controller VGA utilise une resolution de 640 x 480
-- La RAM video est lue par le controller VGA avec l'horloge i_clk_52m
-- Les bits sont dupliques pour doubler la longueur de ligne pour (288 * 2 =  576 pixels < 640)
-- A chaque Hsync controller VGA, on revient au debut de la ligne 1 fois sur 2 pour doubler l'affichage vertical (224 * 2 = 448 lignes < 480)

library ieee;
library work;
use ieee.std_logic_1164.ALL;
-- use ieee.std_logic_arith.all;
-- use ieee.std_logic_unsigned.all;
-- use ieee.numeric_std.shift_left;
use ieee.numeric_std.all;
use work.VGA_control_pack.all;

library UNISIM;
use UNISIM.VComponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_control_top is
    Port ( 
        i_reset : in STD_LOGIC;
        i_clk : in std_logic;
        i_vga_clk : in std_logic; -- 25.18750 Mhz
        i_pixel_write : in std_logic;

        i_vblank : in std_logic; -- VSYNC core
        i_hblank : in std_logic; -- Video BLANK core
        i_rgb : in std_logic_vector(7 downto 0); -- RGB core
        
        o_hsync : out std_logic; -- HSYNC output from controller VGA (vers connecteur VGA)
        o_vsync : out std_logic; -- VSYNC output from controller VGA (vers connecteur VGA)
        o_csync : out std_logic; -- CSYNC output from controller VGA (vers connecteur VGA)
        o_blank : out std_logic; -- BLANK output from controller VGA (vers connecteur VGA)
        o_r : out std_logic_vector(2 downto 0); -- R controller VGA
        o_g : out std_logic_vector(2 downto 0); -- G controller VGA
        o_b : out std_logic_vector(2 downto 0); -- B controller VGA                

        o_vga_control_init_done : out std_logic
    );
end vga_control_top;

architecture Behavioral of vga_control_top is

    -- Controller VGA Opencores
    component vga_enh_top is
	port(
		wb_clk_i   : in std_logic;                         -- wishbone clock input
		wb_rst_i   : in std_logic;                         -- synchronous active high reset
		rst_i  : in std_logic;                  -- asynchronous active low reset
		wb_inta_o  : out std_logic;                        -- interrupt request output

		-- slave signals
		wbs_adr_i : in std_logic_vector(11 downto 0);          -- addressbus input (only 32bit databus accesses supported)
		wbs_dat_i : in std_logic_vector(31 downto 0);  -- Slave databus output
		wbs_dat_o : out std_logic_vector(31 downto 0); -- Slave databus input
		wbs_sel_i : in std_logic_vector(3 downto 0);   -- byte select inputs
		wbs_we_i  : in std_logic;                      -- write enabel input
		wbs_stb_i : in std_logic;                      -- vga strobe/select input
		wbs_cyc_i : in std_logic;                      -- valid bus cycle input
		wbs_ack_o : out std_logic;                     -- bus cycle acknowledge output
		wbs_rty_o : out std_logic;                     -- bus cycle retry output
		wbs_err_o : out std_logic;                     -- bus cycle error output
		
		-- master signals
		wbm_adr_o : out std_logic_vector(31 downto 0);              -- addressbus output
		wbm_dat_i : in std_logic_vector(31 downto 0);      -- Master databus input
		wbm_sel_o : out std_logic_vector(3 downto 0);       -- byte select outputs
		wbm_we_o  : out std_logic;                           -- write enable output
		wbm_stb_o : out std_logic;                          -- strobe output
		wbm_cyc_o : out std_logic;                          -- valid bus cycle output
		wbm_cti_o : out std_logic_vector(2 downto 0);       -- cycle type bus
		wbm_bte_o : out std_logic_vector(1 downto 0);       -- burst type extensions
		wbm_ack_i : in std_logic;                           -- bus cycle acknowledge input
		wbm_err_i : in std_logic;                           -- bus cycle error input

		-- VGA signals
		clk_p_i     : in std_logic;                            -- pixel clock
		clk_p_o     : out std_logic;                            -- pixel clock
		hsync_pad_o : out std_logic;                          -- horizontal sync
		vsync_pad_o : out std_logic;                          -- vertical sync
		csync_pad_o : out std_logic;                          -- composite sync
		blank_pad_o : out std_logic;                          -- blanking signal
		r_pad_o,g_pad_o,b_pad_o : out std_logic_vector(7 downto 0)        -- RGB color signals
	);
    end component vga_enh_top;
    
	-- Memoire dual port de taille 224 x 288 x  x 8 bits
    component blk_mem_gen_video_ram is
    port (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- Core write side
        clkb : IN STD_LOGIC;
        addrb : IN STD_LOGIC_VECTOR(14 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) -- VGA core read side
    );
    end component; 

	type states is (wait_init, chk_stop, gen_cycle, wait_for_ack, idle);
	type vector_type is 
    record
        adr   : std_logic_vector(31 downto 0); -- wishbone address output
        dat   : std_logic_vector(31 downto 0); -- wishbone data output (write) or input compare value (read)
        stop  : std_logic;                     -- last field, stop wishbone activities
    end record;
    
    type vector_list is array(0 to 29) of vector_type;

	-- signal declarations
	signal state : states;
	signal icnt, init_timer : natural := 0;
	signal vga_controller_ok : std_logic;
	signal video_mem_addr : unsigned(15 downto 0); -- Adresse bitmap video cote core
	signal video_dpram_vga_core_addr_l : std_logic_vector(31 downto 0);
	signal video_dpram_vga_core_addr : std_logic_vector(14 downto 0);
	signal video_mem_data : std_logic_vector(7 downto 0); -- Data video cote core
	signal video_mem_vga_core_data : std_logic_vector(15 downto 0);
	
    -- wishbone host
	signal s_cyc_o, s_we_o : std_logic;
	signal s_adr_o                  : std_logic_vector(31 downto 0);
	signal s_dat_o                  : std_logic_vector(31 downto 0);
	signal s_sel_o                  : std_logic_vector(3 downto 0);
	signal s_ack_i                  : std_logic;
	signal s_stb_vga_o : std_logic;
	
    -- vga master
	signal vga_adr                  : std_logic_vector(31 downto 0);
	signal vga_addr_even_line_start        : unsigned(31 downto 0);
	signal vga_frame_offset                : unsigned(31 downto 0);
	signal vga_odd_line : std_logic;
	signal vga_dat                         : std_logic_vector(31 downto 0);
	signal vga_stb, vga_cyc, vga_ack       : std_logic;
	
    signal hsync_vga, vsync_vga, pixel_wr_0 : std_logic;
    
    signal r_vgac, g_vgac, b_vgac: std_logic_vector(7 downto 0);
        
    -- attribute ASYNC_REG : string;
	
	shared variable vectors : vector_list :=
    (
        -- Mode Resolution Refresh Pulse Back porch Active time Front porch Line Total
        --              rate  MHz       usec    pix     pix     pix     pix     pix
        -- QVGA 320x240 60 Hz
        -- VGA 640x480  60 Hz 25.175    3.81    96      45      646     13      800        <<<===
        -- VGA 640x480  72 Hz 31.5      1.27    40      125     646     21      832
        -- SVGA 800x600 56 Hz 36        2       72      125     806     21      1024
        -- SVGA 800x600 60 Hz 40        3.2     128     85      806     37      1056
        -- SVGA 800x600 72 Hz 50        2.4     120     61      806     53      1040

        -- program vga controller
        (VBARa_REG_ADDR,x"00000000", '0'), --   program video base address 0 register (VBARa)
        (VBARb_REG_ADDR,x"00100000", '0'), --   program video base address 0 register (VBARb). Pas utilis�
        -- Pour le cas de DKong, le mode choisit et une r�solution de 512 x 448 avec un affichage de:
        -- Thsync : 96 pixels
        -- Thgdel (back porch) : 60 pixels
        -- Thgate : 512 pixels
        -- Front porch = 800 - (96+60+576) = 68 pixels
        (HTIM_REG_ADDR,x"5F3B023F", '0'), -- program horizontal timing register ((256*2)*(288*2))
        
        -- Vertical timings
        -- QVGA 320x240 60 Hz
        -- VGA 640x480 60 Hz 31.78 63 2 953 30 15382 484 285 9 16683 525        <<<===
        -- VGA 640x480 72 Hz 26.41 79 3 686 26 12782 484 184 7 13735 520
        -- SVGA 800x600 56 Hz 28.44 56 1 568 20 17177 604 -1* 17775 625
        -- SVGA 800x600 60 Hz 26.40 106 4 554 21 15945 604 -1* 16579 628
        -- SVGA 800x600 72 Hz 20.80 125 6 436 21 12563 604 728 35 13853 AIE_NOC_M_AXI
        --
        -- Pour les lignes, il y a en tout 600 lignes
        -- => Sync pulse = 2 lignes
        -- => active time = 448 lignes (2 x 224)
        -- => back porch = 30
        -- => front porch = 600 - (2+30+448) = 120 lignes
        (VTIM_REG_ADDR,x"013801BF", '0'), --   program vertical timing register
        (HVLEN_REG_ADDR,x"031F020B", '0'), --   program horizontal/vertical length register (800 x 525).
        
        -- Table de conversion des niveaux RGB en sortie des ROMs 2E/2F sour la forme de 3 bits rouge,
        -- 3 bits vers, 2 bits bleus sous forme  d'un index dans la table de LUT vers des valeurs equivalentes
        -- RGB mais sur 24 bits.
        -- e.g.: R = 7 (b111), V = 7 (b111), B = 0 (b00), donne l'index 11111100 = 0xFC => x 4 (alignement sur 32 bits) + 0x800 (offset LUTE0) = 0xBF0 
        -- => Valeur RGB 24 bits = 0x00E0E000
        (X"00000800", x"00000000", '0'),
        (X"00000810", x"00920000", '0'),
        (X"0000081C", x"00FF0000", '0'),
        (X"00000828", x"00492400", '0'),
        (X"00000834", x"00B62400", '0'),
        (X"00000850", x"00924900", '0'),
        (X"00000878", x"00DB6D00", '0'),
        (X"0000087C", x"00FF6D00", '0'),
        (X"000008A0", x"0000B600", '0'),
        (X"000008BC", x"00FFB600", '0'),
        (X"000008D8", x"00DBDB00", '0'),
        (X"00000948", x"00494955", '0'),
        (X"00000968", x"00496D55", '0'),
        (X"0000096C", x"006D6D55", '0'),
        (X"00000994", x"00B69255", '0'),
        (X"00000A00", x"000000AA", '0'),
        (X"00000A10", x"009200AA", '0'),
        (X"00000A90", x"009292AA", '0'),
        (X"00000B40", x"000049FF", '0'),
        (X"00000B60", x"00006DFF", '0'),
        (X"00000B7C", x"00FF6DFF", '0'),
        (X"00000BA0", x"0000B6FF", '0'),
        (X"00000BD8", x"00DBDBFF", '0'),
        (CTRL_REG_ADDR, x"00000901", '0'), --   program control register (VEN=1 (video enabled), PC=1 (pseudo-color), CD=11 (32 bits))                                                
        -- end list
        (x"00000000",x"00000000", '1')  -- stop testbench
    );
    
    constant DIGDUG_LINE_RESOLUTION : unsigned := X"0000090"; -- 144 = 288 / 2

begin
    -- Partie destinee a configurer le controlleur VGA
    -- Une fois le controlleur initialise, on met VGA_CONTROL_INIT_DONE = 1 
    -- ce qui permettra de demarrer les autres composants (Z80, ULA,...).
    
	process(i_clk, i_reset)
	begin
        if (i_reset = '1') then
            state <= chk_stop;
            icnt <= 0;
            s_cyc_o <= '0';
            s_stb_vga_o <= '0';
            s_adr_o <= X"FFFFFFFF";
            s_dat_o <= (others => 'X');
            s_we_o  <= 'X';
            s_sel_o <= (others => 'X');
            vga_controller_ok <= '0';
            init_timer <= 0;
            
        elsif falling_edge(i_clk) then    
              case state is
                when wait_init =>
                    init_timer <= init_timer + 1;
                    if init_timer = 500 then
                        state <= chk_stop;
                    end if;
                when chk_stop =>
                    s_cyc_o <= '0';
                    s_stb_vga_o <= 'X';
                    s_adr_o <= (others => 'X');
                    s_dat_o <= (others => 'X');
                    s_we_o  <= 'X';
                    s_sel_o <= (others => 'X');
                    if (vectors(icnt).stop = '0') then
                        state <= gen_cycle;
                    else
                        state <= idle;
                    end if;
               when gen_cycle =>
                    s_cyc_o <= '1';
                    s_stb_vga_o <= '1';
                    s_adr_o <= vectors(icnt).adr;
                    s_dat_o <= vectors(icnt).dat;
                    s_we_o <= '1';
                    s_sel_o <= "1111";
                    state <= wait_for_ack;
               when wait_for_ack =>
                    if s_ack_i = '1' then
                        state <= chk_stop;
                        icnt <= icnt + 1;
                    end if;
               when idle =>
                    s_stb_vga_o <= '0';
                    s_cyc_o <= '0';
                    s_we_o  <= '0';
                    vga_controller_ok <= '1';
               end case;
        end if;
    end process;
    
    -- PortA : Cote ecriture (8 bits)
    -- PortB : Cote lecture (16 bits)
    u1: blk_mem_gen_video_ram port map (
        clka => i_clk,
        wea(0) => i_pixel_write,
        addra => std_logic_vector(video_mem_addr),
        dina => video_mem_data,

        clkb => i_clk, -- Read side
        addrb => video_dpram_vga_core_addr,
        doutb => video_mem_vga_core_data
    );
        
    process(i_clk)
    begin
        -- Reset ou top trame venant du core
        if ((i_reset = '1') or (i_vblank = '1')) then
            video_mem_addr <= (others => '0');
        elsif rising_edge(i_clk) then
            -- Detection front montant i_pixel_write. A remplacer par quelque chose d'autre base sur i_clk_52m ?
            pixel_wr_0 <= i_pixel_write;
            if ((pixel_wr_0 = '1') and (i_pixel_write = '0')) then
                if (i_hblank = '0') then
                    video_mem_addr <= video_mem_addr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Rouge : 3 bits, Vert : 3 bits, Bleu : 2 bits => 8 bits dans la DPRAM
    video_mem_data <= i_rgb;
	
    -- Detection ligne paires/impaires pour le doublement des lignes
    -- L'image VGA est configuree en 288*2 horizontalement et 224*2 verticalement.
    -- Le controlleur VGA lit 4 pixels par 4 pixels. On lit 2 pixels dans la DPRAM et ils sont dupliques pour retourner 4 pixels au controlleur VGA
    -- Principe:
    -- Les adresses controlleur VGA vont de N a N + 575
    -- Les adresses DPRAM VGA vont de M a M + 143 (144 * 4 = 576)
    -- L'adresse RAM controlleur VGA est divisee par 4 et on soustrait 0x90 un ligne sur deux pour revenir au debut de la ligne
    -- precedente pour dupliquer les lignes.
    -- vga_adr_o: Adresse cote controlleur VGA
    -- vga_odd_line: indique les lignes paires ou impaires par rapport a l'adresse controlleur VGA
    -- vga_addr_even_line_start: Adresse de debut de la ligne controlleur VGA / 4
    -- Exemples:
    -- Adresse controlleur VGA: (les adresses sont incrementees 4 par 4 et retournent 32 bits)
    -- Ligne 0: 0x000 ... 0x23F
    -- Ligne 1: 0x240 ... 0x47F
    -- Ligne 2: 0x480 ... 0x6BF
    -- Ligne 3: 0x6C0 ... 0x8FF
    -- Ligne 4: 0x900 ... 0xB3F
    -- Ligne 5: 0xB40 ... 0xD7F
    -- ...
    -- Adresse DPRAM : (les adresses sont incrementees 1 par 1 et retournent 16 bits)
    -- Ligne 0: 0x000 ... 0x08F ([0x0..0x23F] / 4 - vga_frame_offset (0x00)
    -- Ligne 1: 0x000 ... 0x08F ([0x240..0x47F] / 4 - vga_frame_offset (0x90))
    -- Ligne 2: 0x090 ... 0x11F  ([0x480..0x6BF] / 4  - vga_frame_offset (0x90))
    -- Ligne 3: 0x090 ... 0x11F  ([0x6C0..0x8FF] / 4  - vga_frame_offset (0x120))
    -- Ligne 4: 0x120 ... 0x1AF  ([0x900..0xB3F] / 4  - vga_frame_offset (0x120))
    -- Ligne 4: 0x120 ... 0x1AF  ([0xB40..0xD7F] / 4  - vga_frame_offset (0x1B0))
    -- ...
	process(i_clk, i_reset)
    begin
        if (i_reset = '1' or vga_adr = X"00000000") then
            vga_frame_offset <= (others => '0');
            vga_addr_even_line_start <= (others => '0');
            vga_odd_line <= '0';
        elsif rising_edge(i_clk) then
            if unsigned("00" & vga_adr(31 downto 2)) - vga_addr_even_line_start >= DIGDUG_LINE_RESOLUTION then
                vga_odd_line <= not vga_odd_line;
                vga_addr_even_line_start <= unsigned("00" & vga_adr(31 downto 2));
                if vga_odd_line = '0' then
                    vga_frame_offset <= vga_frame_offset + DIGDUG_LINE_RESOLUTION;
                end if;
            end if;
        end if;
    end process;
    
    video_dpram_vga_core_addr_l <= std_logic_vector(unsigned("00" & vga_adr(31 downto 2)) - vga_frame_offset);
    video_dpram_vga_core_addr <= video_dpram_vga_core_addr_l(14 downto 0);
    -- La DPRAM retourne 2 pixels sur 8 bits qui sont dupliques et retournes au controlleur VGA.
    vga_dat <=  video_mem_vga_core_data(7 downto 0) & video_mem_vga_core_data(7 downto 0) & video_mem_vga_core_data(15 downto 8) & video_mem_vga_core_data(15 downto 8);
    
    o_vga_control_init_done <= vga_controller_ok;

	--
	-- hookup vga + clut core
	--
	-- Controleur VGA s'interfacant avec le U3 (vid_mem)
	u2: vga_enh_top port map (
        wb_clk_i => not i_clk, wb_rst_i => '0', rst_i => not i_reset,
        
        wbs_adr_i => s_adr_o(11 downto 0), wbs_dat_i => s_dat_o, 
        wbs_sel_i => s_sel_o, wbs_we_i => s_we_o, wbs_stb_i => s_stb_vga_o,
		wbs_cyc_i => s_cyc_o, wbs_ack_o => s_ack_i,
		
		wbm_adr_o => vga_adr, wbm_dat_i => vga_dat, wbm_stb_o => vga_stb,
		wbm_cyc_o => vga_cyc, wbm_ack_i => vga_ack, wbm_err_i => '0',
		
		clk_p_i => i_vga_clk, hsync_pad_o => hsync_vga, vsync_pad_o => vsync_vga, csync_pad_o => o_csync, blank_pad_o => o_blank,
		r_pad_o => r_vgac, g_pad_o => g_vgac, b_pad_o => b_vgac	
	);    
    
    -- Acquittement immediat
    vga_ack <= '1' when (vga_cyc = '1') and (vga_stb = '1') else '0'; 
 
    o_hsync <= hsync_vga;
    o_vsync <= vsync_vga;
    o_r <= r_vgac(7 downto 5); 
    o_g <= g_vgac(7 downto 5);
    o_b <= b_vgac(7 downto 5);
    
end architecture Behavioral;
