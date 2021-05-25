library IEEE;
use IEEE.std_logic_1164.all;

entity lcd_controller_wrapper is
    port ( clk, rst : in std_logic;
    read, write     : in std_logic;
    writedata       : in std_logic_vector(31 downto 0);
    readdata        : out std_logic_vector(31 downto 0);
    rw, rs, en      : out std_logic;                     --read/write, setup/data, and enable for lcd
    data_out        : out std_logic_vector(7 downto 0)); --data output to LCD
end lcd_controller_wrapper;

architecture lcd_controller_wrapper_arq of lcd_controller_wrapper is
    signal to_lcd_controller : std_logic_vector(31 downto 0);
    --signal from_lcd_controller : std_logic_vector(11 downto 0);
    signal busy              : std_logic;

	component lcd_controller is
        generic (
            MODE_8_BITS  : std_logic := '1';
            LCD_COLUMNS  : std_logic_vector(4 downto 0) := "10100"; -- 20
            LCD_ROWS     : std_logic_vector(1 downto 0) := "11";    -- 4
            FREQ         : integer := 1
        );
        port (
            clk         : in std_logic;
            rst         : in std_logic;
            new_data    : in std_logic;
            data_in     : in std_logic_vector(7 downto 0);
            new_goto    : in std_logic;
            column      : in std_logic_vector(4 downto 0);
            row         : in std_logic_vector(1 downto 0);
            busy        : out std_logic;
            rw, rs, en  : out std_logic;
            data_out    : out std_logic_vector(7 downto 0)
        );
	end component;
BEGIN

    write_data: process(clk, rst)
    begin
        if rst = '1' then
            to_lcd_controller <= "00000000000000000000000000000000";
        elsif rising_edge(clk) then
            to_lcd_controller <= "00000000000000000000000000000000";
            if (write = '1') then
                to_lcd_controller <= writedata;
            end if;
        end if;
    end process;

    u_lcd_controller: lcd_controller
    generic map (
        MODE_8_BITS => '0',      -- 4bits
        LCD_COLUMNS => "10100",  -- 20
        LCD_ROWS => "11",        -- 4
        FREQ => 50               -- clk = 50Mhz
    )
    port map (
        clk => clk,
        rst => rst,
        new_data => to_lcd_controller(8),
        data_in => to_lcd_controller(7 downto 0),
        new_goto => to_lcd_controller(23),
        column => to_lcd_controller(22 downto 18),
        row  => to_lcd_controller(17 downto 16),
        busy => busy,
        rw => rw,
        rs => rs,
        en => en,
        data_out => data_out
    );

    --readdata <= "000000000000000" & from_lcd_controller; 16..0
    readdata <= "0000000000000000000000000000000" & busy;
END lcd_controller_wrapper_arq;