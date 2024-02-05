library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPI_Slave is
    Generic ( width: natural := 40
              );
    Port ( 
           CLK                    : in  STD_LOGIC;
           SCLK                   : in  STD_LOGIC;
           CPOL                   : in  STD_LOGIC;
           CPHA                   : in  STD_LOGIC;
           SS                     : in  STD_LOGIC; 
           MOSI                   : in  STD_LOGIC;
           MISO                   : out  STD_LOGIC;
           Dout                   : out  STD_LOGIC_VECTOR (width-1 downto 0);
           Ready                  : out STD_LOGIC; 
           TxnEnd                 : out STD_LOGIC; 
           mode_out               : out STD_LOGIC_vector(1 downto 0) := (others => '0'); 
           CRC8_OUT               : out STD_LOGIC_vector(7 downto 0) := (others => '0'); 
           RECV_CRC_out           : out STD_LOGIC_vector(7 downto 0) := (others => '0'); 
           TxData_CRC_out         : out STD_LOGIC_vector(31 downto 0) := (others => '0'); 
           RxData_OUT             : out STD_LOGIC_vector(31 downto 0) := (others => '0'); 
           CRC8_RDY_OUT           : out STD_LOGIC := '0'; 
           CRC_Comp_out           : out STD_LOGIC := '0'; 
           Ready_out              : out STD_LOGIC := '0'
--           TX_DATA     : in STD_LOGIC_vector(31 downto 0) := (others => '0') 
--           TX_DATA_rdy     : in STD_LOGIC := '0' 
           );
end SPI_Slave;

architecture Behavioral of SPI_Slave is

type StateMachine_CRC_Calc is(WaitForTrigger, CopyData, CalculateCRC, WaitForComplete);
signal CRCSM : StateMachine_CRC_Calc := WaitForTrigger;

type StateMachine_input_processing is(WaitForTrigger, ProcessInput, ProcessBurst,WaitForNextBurst, CalculateCRC, WaitForComplete);
signal INPUTSM : StateMachine_input_processing := WaitForTrigger;

--mode = b"00" -> CPOL=0/CPHA=0
--mode = b"01" -> CPOL=0/CPHA=1
--mode = b"10" -> CPOL=1/CPHA=0
--mode = b"11" -> CPOL=1/CPHA=1

constant   mode            : std_logic_vector(1 downto 0) := b"00";  
signal   buffer1            : std_logic_vector(31 downto 0) := x"0000000A";  
signal   buffer2            : std_logic_vector(31 downto 0) := x"00000014";  
signal   buffer3            : std_logic_vector(31 downto 0) := x"0000001E";  
signal   buffer4            : std_logic_vector(31 downto 0) := x"00000028";  
signal   buffer5            : std_logic_vector(31 downto 0) := x"00000032";  
signal   buffer6            : std_logic_vector(31 downto 0) := x"0000003C";  
signal   buffer7            : std_logic_vector(31 downto 0) := x"00000046";  
signal   buffer8            : std_logic_vector(31 downto 0) := x"00000050";  
signal   buffer9            : std_logic_vector(31 downto 0) := x"0000005A";  
signal   buffer10           : std_logic_vector(31 downto 0) := x"00000064";  
signal   RX_CRC_CORRUPTED   : std_logic_vector(31 downto 0) := x"000000C8";  
constant MinPacktetLen      : integer                       := 8;
constant TxnEndType         : STD_LOGIC_VECTOR(7 downto 0) := X"FF";
signal   doutsr             : STD_LOGIC_VECTOR (width-1 downto 0);
signal   responseData       : STD_LOGIC_VECTOR(width-1 downto 0) := (others => '0');
signal   response           : STD_LOGIC_VECTOR(width-1 downto 0) := (others => '0');
signal   responserdy        : STD_LOGIC := '0';
signal   burst              : STD_LOGIC := '0';
signal   burst_count        : unsigned(7 downto 0) := x"01";
---crc8---
    signal Rst_Crc_module     : std_logic                                := '0';
    signal Trigger_To_CRC     : std_logic                                := '0';
    signal Data_To_CRC        : std_logic_vector(7 downto 0)             := (others => '0');
    signal RECV_CRC              : std_logic_vector(7 downto 0)           := (others => '0');
    signal CALC_CRC              : std_logic_vector(7 downto 0)           := (others => '0');
    signal CRC_8              : std_logic_vector(7 downto 0)           := (others => '0');
    signal CRC8_RDY           : std_logic                               := '0';
    signal TriggerCRC_Calc    : std_logic                                := '0';
    signal TriggerTXCRC_Calc    : std_logic                                := '0';
    signal Calc_CRC_FF        : std_logic_vector(1 downto 0)              := (others => '0');
    signal Calc_TX_CRC_FF        : std_logic_vector(1 downto 0)              := (others => '0');
    signal CRC_Comp           : std_logic                                := '0';
    signal TxData_CRC         : std_logic_vector(31 downto 0)  := (others => '0');
    signal CRC_DATA              : std_logic_vector(31 downto 0)         := (others => '0');
    signal CounterForCRCGen   : unsigned(4 downto 0)                      := (others => '0');
    constant CRC_BYTES_COUNT    : integer := 4;
    signal SS_META : std_logic := '0';
    signal SS_SYNC : std_logic := '0';
    signal SS_ff        : std_logic_vector(1 downto 0)              := (others => '0');
    signal CRC_Comp_ff        : std_logic_vector(1 downto 0)              := (others => '0');
    signal RxData        : std_logic_vector(31 downto 0)              := (others => '0');
    signal TxData        : std_logic_vector(31 downto 0)              := (others => '0');

begin
mode_out <= mode;

process(CLK)
begin
    if(rising_edge(CLK)) then
        CRC_Comp_ff(0) <= CRC_Comp;                                                     
        CRC_Comp_ff(1) <= CRC_Comp_ff(0);
        case(INPUTSM) is
            when WaitForTrigger =>
                if(CRC_Comp_ff(0) = '1' and CRC_Comp_ff(1) = '0') then              -- OVER HERE WE DETECT THE CRC_COMP PULSE TO START PROCESSING THE RECIEVED MOSI DATA.
                    if(RECV_CRC = CALC_CRC) then                                    -- IF THE CRC MATCHES WE MOVE TO PROCESSINPUT STATE.
                        RxData <= doutsr(39 downto 8);
                        INPUTSM <= ProcessInput;
                    else                                                            -- IF CRC MATCH FAILS WE SEND THE CRC_CORRUPTED RESPONSE BACK TO THE MASTER.
                        TxData <= RX_CRC_CORRUPTED;
                        INPUTSM <= CalculateCRC;
                    end if;                       
                end if;
                responserdy <= '0';
            when ProcessInput =>                                                    -- IN THIS STATE WE CHECK THE REQUEST DATA FROM MASTER AND ASSIG N THE RELEVANT REPONSE.
                if(unsigned(RxData) = 1) then
                    TxData <= buffer1;
                elsif(unsigned(RxData) = 2) then
                    TxData <= buffer2;
                elsif(unsigned(RxData) = 3) then
                    TxData <= buffer3;
                elsif(unsigned(RxData) = 4) then
                    TxData <= buffer4;
                elsif(unsigned(RxData) = 5) then
                    TxData <= buffer5;
                elsif(unsigned(RxData) = 6) then
                    TxData <= buffer6;
                elsif(unsigned(RxData) = 7) then
                    TxData <= buffer7;
                elsif(unsigned(RxData) = 8) then
                    TxData <= buffer8;
                elsif(unsigned(RxData) = 9) then
                    TxData <= buffer9;
                elsif(unsigned(RxData) = 10) then
                    TxData <= buffer10;
                elsif(unsigned(RxData) = 11) then                                   -- IF WE RECIEVE THE REQUEST FOR BURST DATA THEN WE MOVE TO PROCESSBURST STATE.
                    burst <= '1';
                    INPUTSM <= ProcessBurst;
                else
                    TxData <= (others => '1');
                end if;
                if(unsigned(RxData) /= 11) then
                    INPUTSM <= CalculateCRC;                                        -- AND MOVE ONTO CALCULATECRC STATE.
                end if;
            when ProcessBurst =>                                                    -- IN THIS STATE WE ONE BY ONE ASSIGN THE BURST DATA BUFFER BY BUFFER BY INCREMENTING THE BURST COUNT EVERYTIME A BUFFER OS ASSIGNED.
                if(burst_count = 1) then
                    TxData <= buffer1;
                elsif(burst_count = 2) then
                    TxData <= buffer2;
                elsif(burst_count = 3) then
                    TxData <= buffer3;
                elsif(burst_count = 4) then
                    TxData <= buffer4;
                elsif(burst_count = 5) then
                    TxData <= buffer5;
                elsif(burst_count = 6) then
                    TxData <= buffer6;
                elsif(burst_count = 7) then
                    TxData <= buffer7;
                elsif(burst_count = 8) then
                    TxData <= buffer8;
                elsif(burst_count = 9) then
                    TxData <= buffer9;
                elsif(burst_count = 10) then
                    TxData <= buffer10;
                end if;
                burst_count <= burst_count + 1;
                INPUTSM <= CalculateCRC;                                            -- AND WE MOVE TO CALCULATECRC MODULE TO CALCUTAE THE CRC OF THE RESPONSE DATA.
            when CalculateCRC => 
                TriggerTXCRC_Calc <= not TriggerTXCRC_Calc;
                INPUTSM <= WaitForComplete;
            when WaitForComplete =>                                                         -- IN THIS STATE WE WAIT FOR THE CRC TO COMPLETE. ONCE CRC IS COMPLETED WE ATTACH THE CALCUATED CRC OF THE RESPONSE DATA WITH THE CRC AND TRIGGER THE MISO PROCESS TO START TRANSMITTING THE REPONSE DATA.
                if(CRC_Comp_ff(0) = '1' and CRC_Comp_ff(1) = '0' and burst = '0') then
                    response <= TxData & CALC_CRC;
                    responserdy <= '1';
                    INPUTSM <= WaitForTrigger;
                elsif((CRC_Comp_ff(0) = '1' and CRC_Comp_ff(1) = '0')) then                 -- IF WE ARE I N BURST MODE THE WE MOVE TO WAIT FOR NEXTBURST STATE.
                    response <= TxData & CALC_CRC;
                    responserdy <= '1';
                    INPUTSM <= WaitForNextBurst;
                end if;
            when WaitForNextBurst => 
                responserdy <= '0';
                if(burst_count > 10) then                                               -- WE CHECK IF THE BURST COUNT HAS REACHED 10 THEN WE GO TO WAIT FOR TRIGGER STATE ELSE WE WAIT FOR THE SS LINE TO GET FREE BEFORE PREPARING THE REPONSE DATA FOR THE NEXT BUFFER.
                    burst <= '0';
                    burst_count <= x"01";
                    INPUTSM <= WaitForTrigger;                  
                elsif(SS_ff(0) = '1' and SS_ff(1) = '0') then
                    INPUTSM <= ProcessBurst;
                end if;
        end case;
    end if;
end process;

RxData_OUT <= RxData;
CRC_Comp_out <= CRC_Comp;


  process (responserdy,SCLK)   
  begin
     if (responserdy='1') then                                                      -- IN THIS PROCESS WE CHECK FOR REPONSERDY SIGNAL. WHEN WE RECIEVE THAT SIGNAL WE ASSIGN THE REPONSE TO THE REPONSE DATA BUFFER WHICH IS TRANSMISTTED OVER MISO LINE ONCE THE SCLK IS RECIEVED.
        -- Register Data
        Ready <= '1';                                                               -- ONCE RESPONSE DATA IS READY WE RAISE THE READY SIGNAL WHICH IS CONNECTED WITH THE MASTER TO INDICATE IT THAT THE SLAVE RESPONSE DATA IS READY. THE MASTER UPON RECIEVING THIS SIGNAL STARTS THE TRANSACTION THE RECIEVE DATA BACK FROM SLAVE.
        Dout <= response;
        responseData <= response;
     elsif(mode = b"00" or mode = b"11") then
        if(rising_edge(SCLK)) then                                                  -- PROCESS TO TRANSMIT MISO DATA. RISING EDGE DETECTED TO SAMPLE DATA WHEN CPOL=0/CPHA=0 OR CPOL=1/CPHA=1. MSB FIRST.
            responseData <= responseData(responseData'left-1 downto 0) & '0';
            Ready <= '0';
        end if;
     elsif (mode = b"01" or mode = b"10") then
        if(falling_edge(SCLK)) then                                                 -- PROCESS TO TRANSMIT MISO DATA. RISING EDGE DETECTED TO SAMPLE DATA WHEN CPOL=0/CPHA=1 OR CPOL=1/CPHA=0  MSB FIRST. 
            responseData <= responseData(responseData'left-1 downto 0) & '0';
            Ready <= '0';
        end if;
     end if;
  end process;

  MISO <= responseData(responseData'left) when SS='0' else 'Z';                     -- OVER HERE WE ASSIGN THE REPONSE DATA TO MISO LINE BIT BY BIT.

-- -------------------------------------------------------------------------
-- HANDLES MOSI
-- -------------------------------------------------------------------------
  process (SCLK)   
  begin
     if (mode = b"00" or mode = b"11") then
        if(rising_edge(SCLK)) then                                 -- PROCESS TO GATHER MOSI DATA ON SCLK. RISING EDGE DETECTED TO SAMPLE DATA WHEN CPOL=0/CPHA=0 OR CPOL=1/CPHA=1. MSB FIRST.
            doutsr <= doutsr(doutsr'left-1 downto 0) & MOSI;
        end if;
     elsif (mode = b"01" or mode = b"10") then
        if(falling_edge(SCLK)) then                                -- PROCESS TO GATHER MOSI DATA ON SCLK. RISING EDGE DETECTED TO SAMPLE DATA WHEN CPOL=0/CPHA=1 OR CPOL=1/CPHA=0  MSB FIRST.                          
            doutsr <= doutsr(doutsr'left-1 downto 0) & MOSI;
        end if;
     end if;
  end process;
  
  process(CLK)
  begin
    if(rising_edge(CLK)) then                                       -- PROCESS TO SYNC THE SS LINE ON THE INTERNAL CLOCK. THEN DETECT THE RISING EDGE OF SS WHICH INDICATES THAT THE MOSI TRANSACTION HAS COMPLETED.
        SS_META <= SS;                                              -- ONCE THE TRANSACTION IS COMPLETE WE TOGGLE A VARIABLE TO INDICATE THE CRC CALCULATION MODULE TO START CALCULATING THE CRC OF THE DATA RECIEVED ON THE MOSI LINE.
        SS_SYNC <= SS_META; 
        
        SS_ff(0) <= SS_SYNC;
        SS_ff(1) <= SS_ff(0);
        if(SS_ff(0) = '1' and SS_ff(1) = '0' and burst = '0') then
            TriggerCRC_Calc <= not TriggerCRC_Calc;
        end if;
    end if;
  end process;
  
   HandleCRC_Generation : process (CLK)
    begin
        if (rising_edge(CLK)) then
            Calc_CRC_FF(0) <= TriggerCRC_Calc;                      -- RECIEVE THE MOSI DATA COMPLETION TRIGGER.
            Calc_CRC_FF(1) <= Calc_CRC_FF(0);
            
            Calc_TX_CRC_FF(0) <= TriggerTXCRC_Calc;                 -- RECIEVE THE RESPONSE DATA RDY TRIGGER.
            Calc_TX_CRC_FF(1) <= Calc_TX_CRC_FF(0);
            case(CRCSM) is
                when WaitForTrigger =>                              -- BY DEAFAULT THE CRC STATEMACHINE IS IN WAIT STATE.
                CRC_Comp <= '0';
                if ((Calc_CRC_FF(0) xor Calc_CRC_FF(1)) = '1') then -- UPON RECIEVING THIS TRIGGER WE START CALCULATING THE CRC OF THE RECIEVED MOSI DATA.
                    TxData_CRC     <= doutsr(39 downto 8);
                    RECV_CRC <= doutsr(7 downto 0);
                    Rst_Crc_module <= '0';
                    CRCSM          <= CopyData;
                elsif((Calc_TX_CRC_FF(0) xor Calc_TX_CRC_FF(1)) = '1') then  -- UPON RECIEVING THIS TRIGGER WE START CALCULATING THE CRC OF THE RESPONSE DATA.
                    TxData_CRC     <= TxData;
                    Rst_Crc_module <= '0';
                    CRCSM          <= CopyData;
                else
                    Rst_Crc_module <= '1';
                end if;
                when CopyData =>                                                -- IN THIS STATE WE START GIVING THE DATA TO THE CRC MODULE BYTE BY BYTE TO CALCULATE CUMALATIVE CRC.
                if (CounterForCRCGen < CRC_BYTES_COUNT) then                    -- ONCE A BYTE IS ASSIGNED WE GO TO  CALCULATE CRC MODULE.
                    Data_To_CRC      <= TxData_CRC(31 downto 24);
                    TxData_CRC       <= TxData_CRC(23 downto 0) & x"00";
                    CounterForCRCGen <= CounterForCRCGen + 1;
                    CRCSM            <= CalculateCRC;
                else                                                            -- WE CHECK IF ALL 4 BYTES CRC HAS BEEN COMPLETED WE TRIGGER THE CRC_COMP VARIABLE TO INDICATE TO OTHER PROCESS TAHT THE ENTIRE CRC HAS BEEN CALCULATED.
                    CRC_Comp         <= '1';                                    -- AND THEN WE JUMP BACK TO WAIT FOR TRIGGER STATE.
                    CALC_CRC         <= CRC_8;
                    CRCSM            <= WaitForTrigger;
                    CounterForCRCGen <= (others => '0');
                end if;
                when CalculateCRC =>                                            -- THIS STATE TRIGGER THE CRC MODULE TO CALCULATE THE CRC OF THE BYTE PROVIDED TO IT IN THE PREVIOUS STATE.
                Trigger_To_CRC <= '1';
                CRCSM          <= WaitForComplete;
                when WaitForComplete =>                                         -- IN THIS STARTE WE WAIT FOR THE CRC MODULE TO COMPLETE CALCULATING THE CRC OF THE LAST BYTE.
                Trigger_To_CRC <= '0';
                if (CRC8_RDY = '1') then                                        -- ONCE WE RECIEVE THE COMPLETION TRIGGER FROM THE CRC MODULE WE GO BACK TO COPY DATA STATE TO CHECK IF ANY MORE BYTES ARE LEFT. IN OUR CASE WE ARE TO CALCULATE THE CRC OF 4 BYTES.
                    CRCSM <= CopyData;
                end if;
            end case;
        end if;
    end process;
  
  CRC8_GEN : entity work.CRC_8
    port map
    (
        CLK            => CLK,
        Rst_Crc_module => Rst_Crc_module,
        Data           => Data_To_CRC,
        Trigger        => Trigger_To_CRC,
        CRC_RDY        => CRC8_RDY,
        CRC            => CRC_8
    );
    
    CRC8_RDY_OUT <= CRC8_RDY;
    CRC8_OUT <= CRC_8;
    RECV_CRC_out <= RECV_CRC;
    TxData_CRC_out <= TxData_CRC;

end Behavioral;