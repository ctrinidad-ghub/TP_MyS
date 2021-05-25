library IEEE;
use IEEE.std_logic_1164.all;

entity lcd_controller_wrapper_tb is
end;

architecture lcd_controller_wrapper_tb_arq of lcd_controller_wrapper_tb is

    component lcd_controller_wrapper is
        port ( 
            clk, rst :IN std_logic;
            read, write : IN std_logic;
            writedata : IN std_logic_vector(31 downto 0);
            readdata : OUT std_logic_vector(31 downto 0);
            rw, rs, en  : out std_logic;
            data_out    : out std_logic_vector(7 downto 0)
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
    
    -- write data
    --data_in => to_lcd_controller(7 downto 0),
    --new_data => to_lcd_controller(8),
    --row  => to_lcd_controller(17 downto 16),
    --column => to_lcd_controller(22 downto 18),
    --new_goto => to_lcd_controller(23),
    writedata <= "00000000" & new_goto & column & row & "0000000" & new_data & data_in;
    write <= new_data or new_goto;

    -- read data
    busy <= readdata(0);
    read <= '0';

    DUT: lcd_controller_wrapper
        port map ( 
            clk => clk,
            rst => rst,
            read => read,
            write => write,
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