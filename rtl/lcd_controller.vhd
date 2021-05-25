---------------------------------------------------------------------
--
-- FileName: lcd_controller.vhd
--
---------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lcd_controller is
    generic (
        MODE_8_BITS  : std_logic := '1'; -- 8-bits or 4-bits
        LCD_COLUMNS  : std_logic_vector(4 downto 0) := "10100"; -- 20
        LCD_ROWS     : std_logic_vector(1 downto 0) := "11";    -- 4
        FREQ         : integer   := 1    -- system clock frequency in MHz
    );
    port (
        clk         : in std_logic;                      --system clock
        rst         : in std_logic;                      --reset
        new_data    : in std_logic;                      --new data_in valid
        data_in     : in std_logic_vector(7 downto 0);   --data
        new_goto    : in std_logic;                      --new column and row valid
        column      : in std_logic_vector(4 downto 0);   -- characters in a row
        row         : in std_logic_vector(1 downto 0);   -- row number
        busy        : out std_logic;                     --lcd controller busy
        rw, rs, en  : out std_logic;                     --read/write, setup/data, and enable for lcd
        data_out    : out std_logic_vector(7 downto 0)); --data output to LCD
end;

architecture lcd_controller_arq of lcd_controller is
    -- LCD commands
    constant LCD_CLEARDISPLAY   : std_logic_vector(7 downto 0) := "00000001";
    constant LCD_RETURNHOME     : std_logic_vector(7 downto 0) := "00000010";
    constant LCD_ENTRYMODESET   : std_logic_vector(7 downto 0) := "00000100";
    constant LCD_DISPLAYCONTROL : std_logic_vector(7 downto 0) := "00001000";
    constant LCD_CURSORSHIFT    : std_logic_vector(7 downto 0) := "00010000";
    constant LCD_FUNCTIONSET    : std_logic_vector(7 downto 0) := "00100000";
    constant LCD_SETCGRAMADDR   : std_logic_vector(7 downto 0) := "01000000";
    constant LCD_SETDDRAMADDR   : std_logic_vector(7 downto 0) := "10000000";
    
    -- flags for function set
    constant LCD_8BITMODE       : std_logic_vector(7 downto 0) := "00010000";
    constant LCD_4BITMODE       : std_logic_vector(7 downto 0) := "00000000";
    constant LCD_2LINE          : std_logic_vector(7 downto 0) := "00001000";
    constant LCD_1LINE          : std_logic_vector(7 downto 0) := "00000000";
    constant LCD_5x10DOTS       : std_logic_vector(7 downto 0) := "00000100";
    constant LCD_5x8DOTS        : std_logic_vector(7 downto 0) := "00000000";

    -- flags for display entry mode
    constant LCD_ENTRYRIGHT     : std_logic_vector(7 downto 0) := "00000000";
    constant LCD_ENTRYLEFT      : std_logic_vector(7 downto 0) := "00000010";
    constant LCD_ENTRYSHIFT     : std_logic_vector(7 downto 0) := "00000001";
    constant LCD_ENTRYNOSHIFT   : std_logic_vector(7 downto 0) := "00000000";

    -- flags for display on/off control
    constant LCD_DISPLAYON      : std_logic_vector(7 downto 0) := "00000100";
    constant LCD_DISPLAYOFF     : std_logic_vector(7 downto 0) := "00000000";
    constant LCD_CURSORON       : std_logic_vector(7 downto 0) := "00000010";
    constant LCD_CURSOROFF      : std_logic_vector(7 downto 0) := "00000000";
    constant LCD_BLINKON        : std_logic_vector(7 downto 0) := "00000001";
    constant LCD_BLINKOFF       : std_logic_vector(7 downto 0) := "00000000";

    -- LCD delay Times
    constant LCD_POWER_UP_WAIT_US   : integer := 40000 * FREQ; -- Wait for more than 40 ms after VCC rises to 2.7 V
    constant LCD_STARTUP_WAIT_1_US  : integer := 5000 * FREQ; -- Wait for more than 4.1 ms
    constant LCD_STARTUP_WAIT_2_US  : integer := 150 * FREQ; -- Wait for more than 100 μs
    constant LCD_LOW_WAIT_US        : integer := 25 * FREQ; -- 25 us
    constant LCD_HIGH_WAIT_US       : integer := 100 * FREQ; -- 100 us
    constant LCD_CMD_WAIT_US        : integer := 110 * FREQ; -- Wait time for every command 45 us
    constant LCD_CLR_DISP_WAIT_US   : integer := 3000 * FREQ; -- Clear Display 1.52 ms
    constant LCD_RET_HOME_WAIT_US   : integer := 2000 * FREQ; -- Return Home  1.52 ms
    

    component lcd_write is
        generic (
            FREQ         : integer := 1
        );
        port (
            clk         : in std_logic;
            rst         : in std_logic;
            cmd         : in std_logic;
            mode_8_bits : in std_logic;
            new_data    : in std_logic;
            data_in     : in std_logic_vector(7 downto 0);
            busy        : out std_logic;
            rw, rs, en  : out std_logic;
            data_out    : out std_logic_vector(7 downto 0)
        );
    end component;

    --state machine
    type state_t is (POWER_UP, INIT_1, INIT_2, INIT_3, FUNCTIONSET_4_BITS, FUNCTIONSET, DISPLAYCONTROL, LCD_CLEAR, ENTRYMODESET, WAITING, READY);
    signal state, next_state, save_next_state, next_save_next_state : state_t;

    signal clk_count : integer := 0;
    signal next_clk_count : integer;

    signal next_busy  : std_logic;
    signal cmd        : std_logic;
    signal new_data_i : std_logic;
    signal data_in_i  : std_logic_vector(7 downto 0);
    signal busy_i     : std_logic;
    signal busy_r     : std_logic;
    signal mode_8_bits_int : std_logic;
    signal firstCharAdress : std_logic_vector(7 downto 0);

    begin
        registros: process(clk, rst)
        begin
            if rst = '1' then
                state <= POWER_UP;
                save_next_state <= POWER_UP;
                clk_count <= 0;
                busy_r <= '0';
            elsif rising_edge(clk) then
                state <= next_state;
                if (state /= WAITING) then
                    save_next_state <= next_save_next_state;
                end if;
                clk_count <= next_clk_count;
                busy_r <= next_busy;
            end if;
        end process;

        busy <= busy_r or busy_i; -- get one extra clk
 
        mode_8_bits_int <= '1' when (next_save_next_state = POWER_UP) or
                                    (next_save_next_state = INIT_1) or
                                    (next_save_next_state = INIT_2) or
                                    (next_save_next_state = INIT_3) or
                                    (next_save_next_state = FUNCTIONSET_4_BITS) or
                                    (next_save_next_state = FUNCTIONSET) else
                                    MODE_8_BITS;
        
        firstCharAdress <= x"00" when (row = "00") else
                           x"40" when (row = "01") else
                           "000" & LCD_COLUMNS when (row = "10") else
                           x"40" or ("000" & LCD_COLUMNS);
        
        process(state, clk_count, new_data, data_in, new_goto, busy_i, save_next_state, firstCharAdress, column)
        begin
            next_state <= state;
            next_save_next_state <= save_next_state;
            next_busy <= '1';
            next_clk_count <= clk_count;
            cmd <= '0';
            new_data_i <= '0';
            data_in_i <= "00000000";

            case state is
                when POWER_UP =>
                -- Wait for more than 40 ms after VCC rises to 2.7 V
                    next_save_next_state <= INIT_1;
                    next_clk_count <= LCD_POWER_UP_WAIT_US;
                    next_busy <= '1';
                    next_state <= WAITING;
                when INIT_1 =>
                    -- Initializing by Instruction - Step 1
                    -- Function set - 8 bit mode - Wait 4.1ms
                    next_save_next_state <= INIT_2;
                    next_clk_count <= LCD_STARTUP_WAIT_1_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_FUNCTIONSET or LCD_8BITMODE;
                    next_state <= WAITING;
                when INIT_2 =>
                    -- Initializing by Instruction - Step 2
                    -- Function set - 8 bit mode - Wait 100us
                    next_save_next_state <= INIT_3;
                    next_clk_count <= LCD_STARTUP_WAIT_2_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_FUNCTIONSET or LCD_8BITMODE;
                    next_state <= WAITING;
                when INIT_3 =>
                    -- Initializing by Instruction
                    -- Function set - 8 bit mode
                    if MODE_8_BITS = '1' then
                        next_save_next_state <= FUNCTIONSET;
                    else
                        next_save_next_state <= FUNCTIONSET_4_BITS;
                    end if;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_FUNCTIONSET or LCD_8BITMODE;
                    next_state <= WAITING;
                when FUNCTIONSET_4_BITS =>
                    -- Initializing by Instruction
                    -- Exclusive for 4-bits mode
                    next_save_next_state <= FUNCTIONSET;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_FUNCTIONSET;
                    next_state <= WAITING;
                when FUNCTIONSET =>
                    -- Initializing by Instruction
                    -- Function set
                    next_save_next_state <= DISPLAYCONTROL;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    if MODE_8_BITS = '1' then
                        data_in_i <= LCD_FUNCTIONSET or LCD_8BITMODE or LCD_2LINE;
                    else
                        data_in_i <= LCD_FUNCTIONSET or LCD_4BITMODE or LCD_2LINE;
                    end if;
                    next_state <= WAITING;
                when DISPLAYCONTROL =>
                    -- Initializing by Instruction
                    -- Display on/off control
                    next_save_next_state <= LCD_CLEAR;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_DISPLAYCONTROL or LCD_DISPLAYON or LCD_CURSORON;
                    next_state <= WAITING;
                when LCD_CLEAR =>
                    -- Initializing by Instruction
                    -- LCD clear
                    next_save_next_state <= ENTRYMODESET;
                    next_clk_count <= LCD_CLR_DISP_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_CLEARDISPLAY;
                    next_state <= WAITING;
                when ENTRYMODESET =>
                    -- Initializing by Instruction
                    -- Entry mode set
                    next_save_next_state <= READY;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    next_busy <= '1';
                    cmd <= '1';
                    new_data_i <= '1';
                    data_in_i <= LCD_ENTRYMODESET or LCD_ENTRYLEFT or LCD_ENTRYNOSHIFT;
                    next_state <= WAITING;
                when READY =>
                    if (new_data = '1' or new_goto = '1') then
                        next_state <= WAITING;
                    end if;
                    next_save_next_state <= READY;
                    next_clk_count <= LCD_CMD_WAIT_US;
                    new_data_i <= new_data or new_goto;
                    if new_goto = '1' then
                        data_in_i <= (LCD_SETDDRAMADDR or std_logic_vector(unsigned(firstCharAdress) + unsigned("000" & column)));
                    else
                        data_in_i <= data_in;
                    end if;
                    if new_goto = '1' then
                        cmd <= '1';
                    else
                        cmd <= '0';
                    end if;
                    next_busy <= busy_i;
                when WAITING =>
                    next_busy <= '1';
                    if busy_i = '0' then
                        if (clk_count > 0) then
                            next_clk_count <= clk_count - 1;
                            next_state <= WAITING;
                        else
                            next_clk_count <= 0;
                            next_state <= save_next_state;
                        end if;
                    end if;
            end case;

        end process;

        u_lcd_write: lcd_write
        generic map (
            FREQ => FREQ
        )
		port map (
            clk      => clk,
            rst      => rst,
            cmd      => cmd,
            mode_8_bits => mode_8_bits_int,
            new_data => new_data_i,
            data_in  => data_in_i,
            busy     => busy_i,
            rw       => rw,
            rs       => rs,
            en       => en,
            data_out => data_out
		);
end;