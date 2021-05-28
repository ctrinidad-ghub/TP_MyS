library IEEE;
use IEEE.std_logic_1164.all;

entity lcd_controller_wrapper is
    generic (
        MODE_8_BITS  : std_logic := '1';
        LCD_COLUMNS  : std_logic_vector(4 downto 0) := "10100"; -- 20
        LCD_ROWS     : std_logic_vector(1 downto 0) := "11";    -- 4
        FREQ         : integer := 1
    );
    port ( 
        clk, rst        : in std_logic;
        -- Avalon bus
        read, write     : in std_logic;
        address         : in std_logic_vector(1 downto 0);
        writedata       : in std_logic_vector(31 downto 0);
        readdata        : out std_logic_vector(31 downto 0);
        -- LCD outputs
        rw, rs, en      : out std_logic;                     --read/write, setup/data, and enable for lcd
        data_out        : out std_logic_vector(7 downto 0)   --data output to LCD
    );
end lcd_controller_wrapper;

architecture lcd_controller_wrapper_arq of lcd_controller_wrapper is
    signal new_data    : std_logic;
    signal data_in     : std_logic_vector(7 downto 0);
    signal new_goto    : std_logic := '0';
    signal column      : std_logic_vector(4 downto 0);
    signal row         : std_logic_vector(1 downto 0);
    signal busy        : std_logic;

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
begin

    write_data: process(clk, rst)
    begin
        if rst = '1' then
            new_data <= '0';
            data_in <= "00000000";
            new_goto <= '0';
            column <= "00000";
            row  <= "00";
        elsif rising_edge(clk) then
            new_data <= '0';
            data_in <= "00000000";
            new_goto <= '0';
            column <= "00000";
            row  <= "00";

            if (write = '1') then
                if (address = "00") then
                    new_data <= '1';
                    data_in <= writedata(7 downto 0);
                elsif (address = "01") then
                    new_goto <= '1';
                    column <= writedata(6 downto 2);
                    row  <= writedata(1 downto 0);
                end if;
            end if;
        end if;
    end process;

    u_lcd_controller: lcd_controller
    generic map (
        MODE_8_BITS => MODE_8_BITS,
        LCD_COLUMNS => LCD_COLUMNS,
        LCD_ROWS => LCD_ROWS,
        FREQ => FREQ
    )
    port map (
        clk => clk,
        rst => rst,
        new_data => new_data,
        data_in => data_in,
        new_goto => new_goto,
        column => column,
        row  => row,
        busy => busy,
        rw => rw,
        rs => rs,
        en => en,
        data_out => data_out
    );

    readdata <= "0000000000000000000000000000000" & busy when read = '1' and address = "10" else
                (others => '0');
end lcd_controller_wrapper_arq;