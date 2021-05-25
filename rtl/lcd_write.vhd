---------------------------------------------------------------------
--
-- FileName: lcd_write.vhd
-- 
---------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lcd_write is
    generic (
        FREQ         : integer   := 1    --system clock frequency in MHz
    );
    port (
        clk         : in std_logic;                    --system clock
        rst         : in std_logic;                    --reset
        cmd         : in std_logic;                    --cmd = 1, data = 0
        mode_8_bits : in std_logic;                    -- 8-bits or 4-bits
        new_data    : in std_logic;                    --new data_in valid
        data_in     : in std_logic_vector(7 downto 0); --data_in
        busy        : out std_logic;                   --block busy
        rw, rs, en  : out std_logic;                   --read/write, setup/data, and enable for lcd
        data_out    : out std_logic_vector(7 downto 0)
    );
end;

architecture lcd_write_arq of lcd_write is
    constant LCD_EN_PULSE_WAIT_US : integer := 25 * FREQ; -- 25us
    constant LCD_WAIT_2_US        : integer := 2 * FREQ; -- 2us

    --state machine
    type state_t is (IDLE, SEND_CMD, SEND_DATA, WAIT_EN);
    signal state, next_state : state_t;

    signal clk_count      : integer := 0;
    signal next_clk_count : integer;
    signal next_data_out  : std_logic_vector(7 downto 0);
    signal next_busy      : std_logic;
    signal next_data_cnt  : std_logic; -- Use in 4-bit mode
    signal data_cnt       : std_logic; -- Use in 4-bit mode
    signal rs_r, en_r     : std_logic;
    signal data_out_r     : std_logic_vector(7 downto 0);
    signal next_en        : std_logic;

    begin
        registros: process(clk, rst)
        begin
            if rst = '1' then
                state <= IDLE;
                clk_count <= 0;
                busy <= '0';
                rs_r <= '0';
                rw <= '0';
                en_r <= '0';
                data_out_r <= "00000000";
                data_cnt <= '0';
            elsif rising_edge(clk) then
                state <= next_state;
                clk_count <= next_clk_count;
                busy <= next_busy;
                data_cnt <= next_data_cnt;
                data_out_r <= next_data_out;
                case state is
                    when IDLE =>
                        rs_r <= '0';
                        rw <= '0';
                        en_r <= '0';
                    when SEND_CMD =>
                        rs_r <= '0';
                        rw <= '0';
                        en_r <= '0';
                    when SEND_DATA =>
                        rs_r <= '1';
                        rw <= '0';
                        en_r <= '0';
                    when WAIT_EN =>
                        en_r <= next_en;
                end case;
            end if;
        end process;

        process(state, new_data, data_in, cmd, clk_count, rs_r, en_r, data_cnt, data_out_r, mode_8_bits)
        begin
            next_data_out <= data_out_r;
            next_clk_count <= 0;
            next_busy <= '0';
            next_state <= state;
            next_data_cnt <= data_cnt;
            next_en <= en_r;

            case state is
                when IDLE =>
                    --next_data_out <= "00000000";
                    if (new_data = '1') then
                        next_data_out <= data_in;
                        next_busy <= '1';
                        next_data_cnt <= '0';
                        if cmd = '1' then
                            next_state <= SEND_CMD;
                        else
                            next_state <= SEND_DATA;
                        end if;
                    end if;
                when SEND_CMD =>
                    next_state <= WAIT_EN;
                    next_busy  <= '1';
                when SEND_DATA =>
                    next_state <= WAIT_EN;
                    next_busy  <= '1';
                when WAIT_EN =>
                    next_busy  <= '1';
                    if (clk_count < (LCD_EN_PULSE_WAIT_US)) then
                        next_clk_count <= clk_count + 1;
                        next_en <= '1';
                    elsif (clk_count < (LCD_EN_PULSE_WAIT_US+LCD_WAIT_2_US)) then
                            -- Add 2 us to meet "Address hold time", between en -> rs 
                            next_clk_count <= clk_count + 1;
                            next_en <= '0';
                    elsif (clk_count < (2 * LCD_EN_PULSE_WAIT_US) and (mode_8_bits = '0' and data_cnt = '0')) then
                        next_clk_count <= clk_count + 1;
                        next_en <= '0';
                    else
                        if (mode_8_bits = '0' and data_cnt = '0') then
                            next_data_cnt <= '1';
                            next_clk_count <= 0;
                            if rs_r = '0' then
                                next_state <= SEND_CMD;
                            else
                                next_state <= SEND_DATA;
                            end if;
                            next_busy  <= '1';
                            next_data_out <= data_out_r(3 downto 0) & data_out_r(3 downto 0);
                        else 
                            next_data_cnt <= '0';
                            next_clk_count <= 0;
                            next_state <= IDLE;
                            next_busy  <= '0';
                        end if;
                    end if;
            end case;
        end process;

        rs <= rs_r;
        en <= en_r;
        data_out <= data_out_r;
end;