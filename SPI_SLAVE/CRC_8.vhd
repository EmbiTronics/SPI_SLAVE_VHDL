library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CRC_8 is
  Port 
  (
    CLK            : in    STD_LOGIC;
    Rst_Crc_module : in    STD_LOGIC := '0';
    Data 	       : in    STD_LOGIC_VECTOR (7 downto 0);
    Trigger        : in    STD_LOGIC;
    CRC_RDY        : out   STD_LOGIC;
    CRC 	       : out   STD_LOGIC_VECTOR (7 downto 0)
  );
end CRC_8;

architecture Behavioral of CRC_8 is

	type memory is array (0 to 255) of std_logic_vector(7 downto 0);
	constant crc_lut : memory := (
    x"00", x"31", x"62", x"53", x"c4", x"f5", 
	x"a6", x"97", x"b9", x"88", x"db", x"ea", 
	x"7d", x"4c", x"1f", x"2e", x"43", x"72",
	x"21", x"10", x"87", x"b6", x"e5", x"d4",
	x"fa", x"cb", x"98", x"a9", x"3e", x"0f",
	x"5c", x"6d", x"86", x"b7", x"e4", x"d5",
	x"42", x"73", x"20", x"11", x"3f", x"0e",
	x"5d", x"6c", x"fb", x"ca", x"99", x"a8",
	x"c5", x"f4", x"a7", x"96", x"01", x"30",
	x"63", x"52", x"7c", x"4d", x"1e", x"2f",
	x"b8", x"89", x"da", x"eb", x"3d", x"0c", 
	x"5f", x"6e", x"f9", x"c8", x"9b", x"aa", 
	x"84", x"b5", x"e6", x"d7", x"40", x"71",
    x"22", x"13", x"7e", x"4f", x"1c", x"2d", 
	x"ba", x"8b", x"d8", x"e9", x"c7", x"f6", 
	x"a5", x"94", x"03", x"32", x"61", x"50",
	x"bb", x"8a", x"d9", x"e8", x"7f", x"4e",
	x"1d", x"2c", x"02", x"33", x"60", x"51",
	x"c6", x"f7", x"a4", x"95", x"f8", x"c9",
	x"9a", x"ab", x"3c", x"0d", x"5e", x"6f",
	x"41", x"70", x"23", x"12", x"85", x"b4",
	x"e7", x"d6", x"7a", x"4b", x"18", x"29",
	x"be", x"8f", x"dc", x"ed", x"c3", x"f2",
	x"a1", x"90", x"07", x"36", x"65", x"54",
	x"39", x"08", x"5b", x"6a", x"fd", x"cc",
	x"9f", x"ae", x"80", x"b1", x"e2", x"d3",
    x"44", x"75", x"26", x"17", x"fc", x"cd",
	x"9e", x"af", x"38", x"09", x"5a", x"6b",
	x"45", x"74", x"27", x"16", x"81", x"b0",
	x"e3", x"d2", x"bf", x"8e", x"dd", x"ec", 
	x"7b", x"4a", x"19", x"28", x"06", x"37",
	x"64", x"55", x"c2", x"f3", x"a0", x"91",
	x"47", x"76", x"25", x"14", x"83", x"b2",
	x"e1", x"d0", x"fe", x"cf", x"9c", x"ad",
	x"3a", x"0b", x"58", x"69", x"04", x"35",
	x"66", x"57", x"c0", x"f1", x"a2", x"93",
	x"bd", x"8c", x"df", x"ee", x"79", x"48",
	x"1b", x"2a", x"c1", x"f0", x"a3", x"92",
	x"05", x"34", x"67", x"56", x"78", x"49",
    x"1a", x"2b", x"bc", x"8d", x"de", x"ef",
	x"82", x"b3", x"e0", x"d1", x"46", x"77",
	x"24", x"15", x"3b", x"0a", x"59", x"68", 
	x"ff", x"ce", x"9d", x"ac");
	
   SIGNAL sCRC          : STD_LOGIC_VECTOR (7 downto 0) := (others => '1');
   SIGNAL Index         : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
   SIGNAL Trigger_FF    : STD_LOGIC_VECTOR (1 downto 0) := (others => '0');
   
begin

CALC_CRC : process(CLK)
    TYPE StateMachine IS(CalcIndex,FindCRC);
    VARIABLE CRCSM : StateMachine := CalcIndex;
begin
	if(rising_edge(CLK)) then
		if(Rst_Crc_module = '1') then
            Index <= (others => '0');
            sCRC <= (others => '1');
            CRC_RDY <= '0';
            CRCSM := CalcIndex;
		else
            case(CRCSM) is
                when CalcIndex =>
                    CRC_RDY <= '0';
                    if(Trigger = '1') then
                        Index <= (others => '0');
                        Index <= sCRC xor Data;
                        CRCSM := FindCRC;
                    end if;               
                when FindCRC =>
                    sCRC <= crc_lut(to_integer(unsigned(Index)));
                    CRC_RDY <= '1';
                    CRCSM := CalcIndex;
            end case;
        end if;
    end if;
end process;

crc <= scrc;

end Behavioral;