library IEEE;
use IEEE.std_logic_1164.all;

entity lcd_controller_wrapper_tb is
end;

architecture lcd_controller_wrapper_tb_arq of lcd_controller_wrapper_tb is

    component lcd_controller_wrapper is
        generic (
            MODE_8_BITS  : std_logic := '1';
            LCD_COLUMNS  : std_logic_vector(4 downto 0) := "10100"; -- 20
            LCD_ROWS     : std_logic_vector(1 downto 0) := "11";    -- 4
            FREQ         : integer := 1
        );
        port ( 
            clk, rst : in std_logic;
            read, write     : in std_logic;
            address         : in std_logic_vector(1 downto 0);
            writedata       : in std_logic_vector(31 downto 0);
            readdata        : out std_logic_vector(31 downto 0);
            rw, rs, en      : out std_logic;                     --read/write, setup/data, and enable for lcd
            data_out        : out std_logic_vector(7 downto 0)   --data output to LCD
        );
    end component;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal new_data    : std_logic;
    signal new_data_d  : std_logic;
    signal data_in     : std_logic_vector(7 downto 0);
    signal busy        : std_logic;
    signal rw, rs, en  : std_logic;
    signal data_out    : std_logic_vector(7 downto 0);
    signal ena         : std_logic := '0';
    signal new_goto    : std_logic := '0';
    signal column      : std_logic_vector(4 downto 0);
    signal row         : std_logic_vector(1 downto 0);

    signal address     : std_logic_vector(1 downto 0);
    signal writedata   : std_logic_vector(31 downto 0);
    signal readdata    : std_logic_vector(31 downto 0);
    signal read        : std_logic;
    signal write       : std_logic;
begin

	rst <= '1' after 10 ns, '0' after 200 ns;
    clk <=  '1' after 10 ns when clk = '0' else
            '0' after 10 ns when clk = '1';
            -- not clk after 10 ns;
    ena <= '0' after 10 ns, '1' after 50 ns;

    -- cursor positioning
    new_goto <= '0' after 0 ns, '1' after 53000010 ns, '0' after 53000030 ns;
    column <= "00010";
    row <= "11";

    -- Avalon address
    address <=  "00" when new_data = '1' else
                "01" when new_goto = '1' else
                (others => 'Z');

    -- Avalon write operation
    writedata <= "000000000000000000000000" & data_in when new_data = '1' else
                 "0000000000000000000000000" & column & row when new_goto = '1' else
                 (others => 'Z');

    write <= new_data or new_goto;

    -- Avalon read operation
    busy <= readdata(0);
    read <= '0';

    DUT: lcd_controller_wrapper
        generic map (
            MODE_8_BITS => '0',      -- 4bits
            LCD_COLUMNS => "10100",  -- 20
            LCD_ROWS => "11",        -- 4
            FREQ => 50               -- clk = 50Mhz
        )
        port map ( 
            clk => clk,
            rst => rst,
            read => read,
            write => write,
            address => address,
            writedata => writedata,
            readdata => readdata,
            rw => rw,
            rs => rs,
            en => en,
            data_out => data_out
            );

    process(clk)
        variable char : integer range 0 to 12 := 0;
    begin
        if rst = '1' then
            new_data <= '0';
            new_data_d <= '0';
            data_in <= "00000000";
        elsif rising_edge(clk) then
            new_data_d <= new_data;
            if (busy = '0' and new_data = '0' and ena = '1'and new_data_d = '0') then
                new_data <= '1';
                if (char < 12) then
                    char := char + 1;
                end if;

                case char is
                    when 1 => data_in <= "00110001";
                    when 2 => data_in <= "00110010";
                    when 3 => data_in <= "00110011";
                    when 4 => data_in <= "00110100";
                    when 5 => data_in <= "00110101";
                    when 6 => data_in <= "00110110";
                    when 7 => data_in <= "00110111";
                    when 8 => data_in <= "00111000";
                    when 9 => data_in <= "00111001";
                    when 10 => data_in<= "01000001";
                    when 11 => data_in<= "01000010";
                    when others => new_data <= '0';
                end case;
            else
                new_data <= '0';
            end if;
        end if;
    end process;
end;