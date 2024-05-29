library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- THE SPI SLAVE MODULE SUPPORT ONLY SPI MODE 0 (CPOL=0, CPHA=0)!!!

entity SPI_SLAVE is
    Generic (
        WORD_SIZE : natural := 16 -- size of transfer word in bits, must be power of two
    );
    Port (
        CLK      : in  std_logic;
        -- SPI SLAVE INTERFACE
        SCLK     : in  std_logic;
        CS_N     : in  std_logic;
        MOSI     : in  std_logic;
        MISO     : out std_logic;
        
        -- MOTOR CONTROL
        hallsensor1A, hallsensor1B, hallsensor2A, hallsensor2B, sensor0, sensor1 : in STD_LOGIC;
        IN1A, IN2A, IN1B, IN2B : out STD_LOGIC;
        ENA, ENB : out STD_LOGIC
        

    );
end entity;

architecture RTL of SPI_SLAVE is

    constant BIT_CNT_WIDTH : natural := natural(ceil(log2(real(WORD_SIZE))));

    signal sclk_meta          : std_logic;
    signal cs_n_meta          : std_logic;
    signal mosi_meta          : std_logic;
    signal sclk_reg           : std_logic;
    signal cs_n_reg           : std_logic;
    signal mosi_reg           : std_logic;
    signal spi_clk_reg        : std_logic;
    signal spi_clk_redge_en   : std_logic;
    signal spi_clk_fedge_en   : std_logic;
    signal bit_cnt            : unsigned(BIT_CNT_WIDTH-1 downto 0);
    signal bit_cnt_max        : std_logic;
    signal last_bit_en        : std_logic;
    signal load_data_en       : std_logic;
    signal data_shreg         : std_logic_vector(WORD_SIZE-1 downto 0);
    signal data_to_use        : std_logic_vector(WORD_SIZE-1 downto 0);
    signal slave_ready        : std_logic;
    signal shreg_busy         : std_logic;
    signal rx_data_vld        : std_logic;
    signal DIN                : std_logic_vector(WORD_SIZE-1 downto 0); -- data for transmission to SPI master
    signal DIN_VLD            : std_logic; -- when DIN_VLD = 1, data for transmission are valid
    signal DIN_RDY            : std_logic; -- when DIN_RDY = 1, SPI slave is ready to accept valid data for transmission
    signal DOUT               : std_logic_vector(WORD_SIZE-1 downto 0); -- received data from SPI master
    signal DOUT_VLD           : std_logic;  -- when DOUT_VLD = 1, received data are valid
    signal RST                : std_logic :='1';

    -- PWM variables and so on 
    constant PWM_PERIOD : integer := 1000000;
    signal pwm_counter: integer range 0 to PWM_PERIOD - 1 := 0;
    
    signal total_pulse_counter_pan: integer range -179 to 179 := 0;
    signal total_pulse_counter_tilt: integer range 0 to 269 := 0;
    signal pulse_counter_tilt_vector : std_logic_vector(8 downto 0);
    signal pulse_counter_pan_vector : std_logic_vector(6 downto 0);
    signal counter: integer := 0;
    signal duty_cycle: integer range 0 to PWM_PERIOD -1 := 450000;
    signal duty_cycleA: integer range 0 to PWM_PERIOD -1 := 200000;
    signal pwm_output : std_logic := '0';
    signal pwm_outputA : std_logic := '0';
    signal saved_tilt : integer := 0;
    signal saved_pan : integer := 0;
    
    
begin

process(hallsensor2B)
begin
    if rising_edge(hallsensor2B) then
        if hallsensor2B = hallsensor2A then
            if total_pulse_counter_tilt < 269 then
                total_pulse_counter_tilt <= total_pulse_counter_tilt + 1;
            else
                total_pulse_counter_tilt <= 0;  -- Reset to 0 if it exceeds 269
            end if;
        else
            if total_pulse_counter_tilt > 0 then
                total_pulse_counter_tilt <= total_pulse_counter_tilt - 1;
            else
                total_pulse_counter_tilt <= 269;  -- Reset to 269 if it goes below 0
            end if;
        end if;
        pulse_counter_tilt_vector <= std_logic_vector(TO_UNSIGNED(total_pulse_counter_tilt, pulse_counter_tilt_vector'length));
    end if;
end process;

process(hallsensor1B)
begin
        if rising_edge(hallsensor1B) then
            if hallsensor1B > hallsensor1A then
                total_pulse_counter_pan <= total_pulse_counter_pan + 1;
            else
                total_pulse_counter_pan <= total_pulse_counter_pan - 1; 
            end if;
        pulse_counter_pan_vector <= std_logic_vector(TO_UNSIGNED(total_pulse_counter_pan, pulse_counter_pan_vector'length));
        end if;
end process;


    -- -------------------------------------------------------------------------
    --  INPUT SYNCHRONIZATION REGISTERS
    -- -------------------------------------------------------------------------


    -- Synchronization registers to eliminate possible metastability.
    sync_ffs_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            sclk_meta <= SCLK;
            cs_n_meta <= CS_N;
            mosi_meta <= MOSI;
            sclk_reg  <= sclk_meta;
            cs_n_reg  <= cs_n_meta;
            mosi_reg  <= mosi_meta;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  SPI CLOCK REGISTER
    -- -------------------------------------------------------------------------

    -- The SPI clock register is necessary for clock edge detection.
    spi_clk_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                spi_clk_reg <= '0';
            else
                spi_clk_reg <= sclk_reg;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  SPI CLOCK EDGES FLAGS
    -- -------------------------------------------------------------------------

    -- Falling edge is detect when sclk_reg=0 and spi_clk_reg=1.
    spi_clk_fedge_en <= not sclk_reg and spi_clk_reg;
    -- Rising edge is detect when sclk_reg=1 and spi_clk_reg=0.
    spi_clk_redge_en <= sclk_reg and not spi_clk_reg;

    -- -------------------------------------------------------------------------
    --  RECEIVED BITS COUNTER
    -- -------------------------------------------------------------------------

    -- The counter counts received bits from the master. Counter is enabled when
    -- falling edge of SPI clock is detected and not asserted cs_n_reg.
    bit_cnt_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                bit_cnt <= (others => '0');
            elsif (spi_clk_fedge_en = '1' and cs_n_reg = '0') then
                if (bit_cnt_max = '1') then
                    bit_cnt <= (others => '0');
                else
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- The flag of maximal value of the bit counter.
    bit_cnt_max <= '1' when (bit_cnt = WORD_SIZE-1) else '0';

    -- -------------------------------------------------------------------------
    --  LAST BIT FLAG REGISTER
    -- -------------------------------------------------------------------------

    -- The flag of last bit of received byte is only registered the flag of
    -- maximal value of the bit counter.
    last_bit_en_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                last_bit_en <= '0';
            else
                last_bit_en <= bit_cnt_max;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  RECEIVED DATA VALID FLAG
    -- -------------------------------------------------------------------------

    -- Received data from master are valid when falling edge of SPI clock is
    -- detected and the last bit of received byte is detected.
    rx_data_vld <= spi_clk_fedge_en and last_bit_en;

    -- -------------------------------------------------------------------------
    --  SHIFT REGISTER BUSY FLAG REGISTER
    -- -------------------------------------------------------------------------

    -- Data shift register is busy until it sends all input data to SPI master.
    shreg_busy_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                shreg_busy <= '0';
            else
                if (DIN_VLD = '1' and (cs_n_reg = '1' or rx_data_vld = '1')) then
                    shreg_busy <= '1';
                elsif (rx_data_vld = '1') then
                    shreg_busy <= '0';
                else
                    shreg_busy <= shreg_busy;
                end if;
            end if;
        end if;
    end process;

    -- The SPI slave is ready for accept new input data when cs_n_reg is assert and
    -- shift register not busy or when received data are valid.
    slave_ready <= (cs_n_reg and not shreg_busy) or rx_data_vld;
    
    -- The new input data is loaded into the shift register when the SPI slave
    -- is ready and input data are valid.
    load_data_en <= slave_ready and DIN_VLD;
    
data_into_reg_p : process (CLK)
begin
if (rising_edge(CLK)) then
 if (spi_clk_redge_en = '1' and cs_n_reg = '0') then
  data_to_use <= data_to_use(WORD_SIZE-2 downto 0) & mosi_reg;
 end if;
end if;
end process;
    -- -------------------------------------------------------------------------
    --  DATA SHIFT REGISTER
    -- -------------------------------------------------------------------------

    -- The shift register holds data for sending to master, capture and store
    -- incoming data from master.
data_shreg_p : process (CLK)
begin
    if (rising_edge(CLK)) then
        if (load_data_en = '1') then
            data_shreg <= DIN;  -- Load entire word from DIN if valid and ready
        elsif (spi_clk_redge_en = '1' and cs_n_reg = '0') then
            data_shreg <= data_shreg(WORD_SIZE-2 downto 0) & mosi_reg;  -- Shift in the MOSI bit on rising edge
        end if;
    end if;
end process;

PWM : process(CLK)
    begin
     if rising_edge(CLK) then -- This is for the motor B tilt
        pwm_counter <= pwm_counter + 1;
        if pwm_counter < duty_cycle then
            pwm_output <= '1';
        else
            pwm_output <= '0';
        end if;
        -- This one for motor A pan
        if pwm_counter < duty_cycleA then
            pwm_outputA <= '1';
        else
            pwm_outputA <= '0';
        end if;
    end if;
end process;



check_data_p : process(CLK)
begin
    if rising_edge(CLK) then  -- Corrected to include the clock signal
        case data_to_use is
            when x"0004" =>
                if sensor0 = '1' then
                    if total_pulse_counter_tilt < 135 then
                        ENB <= '1';
                        IN1B <= '0';
                        IN2B <= pwm_output;
                    else
                        ENB <= '1';
                        IN1B <= pwm_output;
                        IN2B <= '0';
                    end if;
                else
                    ENB <= '0';
                    IN1B <= '0'; 
                    IN2B <= '0'; 
                    if sensor1 = '1' then
                        if total_pulse_counter_pan > 0 then
                            ENA <= '1';
                            IN1A <= pwm_outputA; 
                            IN2A <= '0'; 
                        else
                            ENA <= '1';
                            IN1A <= '0'; 
                            IN2A <= pwm_outputA; 
                        end if;
                    end if;
                end if;
                
            when x"0005" =>
                ENA <= '0';
                IN1A <= '0'; 
                IN2A <= '0'; 
                ENB <= '1';
                IN1B <= pwm_output; 
                IN2B <= '0'; 
                
            when x"0007" =>
                ENB <= '0';
                IN1B <= '0'; 
                IN2B <= '0'; 
                ENA <= '1';
                IN1A <= pwm_outputA; 
                IN2A <= '0'; 
                
            when x"0009" =>
                ENB <= '0';
                IN1B <= '0'; 
                IN2B <= '0'; 
                ENA <= '1';
                IN1A <= '0'; 
                IN2A <= pwm_outputA; 
                
            when x"0011" =>
                ENA <= '0';
                IN1A <= '0'; 
                IN2A <= '0'; 
                ENB <= '1';
                IN1B <= '0'; 
                IN2B <= pwm_output; 
                
            when x"0006" =>
                ENB <= '0';
                IN1B <= '0';
                IN2B <= '0';
                ENA <= '0';
                IN1A <= '0';
                IN2A <= '0';
                saved_pan <= total_pulse_counter_pan;
                saved_tilt <= total_pulse_counter_tilt; 
                
            when x"0003" =>
                if total_pulse_counter_tilt > saved_tilt then
                    ENB <= '1';
                    IN1B <= '0';
                    IN2B <= pwm_output;
                elsif total_pulse_counter_tilt = saved_tilt then
                    ENB <= '0';
                    IN1B <= '0';
                    IN2B <= '0';
                    if total_pulse_counter_pan > saved_pan then
                        ENA <= '1';
                        IN1A <= pwm_outputA; 
                        IN2A <= '0'; 
                    elsif total_pulse_counter_pan = saved_pan then
                        ENA <= '0';
                        IN1A <= '0'; 
                        IN2A <= '0'; 
                    else 
                        ENB <= '0';
                        IN1B <= '0';
                        IN2B <= '0';
                        ENA <= '1';
                        IN1A <= '0'; 
                        IN2A <= pwm_outputA;
                    end if; 
                else
                    ENB <= '1';
                    IN1B <= pwm_output;
                    IN2B <= '0';
                end if;
            
            when x"0008" =>
                ENB <= '0';
                IN1B <= '0';
                IN2B <= '0';
                
                ENA <= '0';
                IN1A <= '0';
                IN2A <= '0';
                
            when others =>
                ENB <= '0';
                IN1B <= '0';
                IN2B <= '0';
                
                ENA <= '0';
                IN1A <= '0';
                IN2A <= '0';
        end case;
    end if;   
end process;

    -- -------------------------------------------------------------------------
    --  MISO REGISTER
    -- -------------------------------------------------------------------------

    -- The output MISO register ensures that the bits are transmit to the master
    -- when is not assert cs_n_reg and falling edge of SPI clock is detected.
miso_p : process (CLK)
begin
        if (rising_edge(CLK)) then
            if (load_data_en = '1') then
                MISO <= DIN(WORD_SIZE-1);
            elsif (spi_clk_fedge_en = '1' and cs_n_reg = '0') then
                MISO <= data_shreg(WORD_SIZE-1);
            end if;
        end if;
end process;

    
    reset_init_p : process (CLK)
begin
 if (rising_edge(CLK)) then
  if spi_clk_reg = '0' and bit_cnt = (bit_cnt'range => '0') and last_bit_en = '0' and shreg_busy = '0' then
      RST <= '0';
     end if;
    end if;
end process;

    -- -------------------------------------------------------------------------
    --  ASSIGNING OUTPUT SIGNALS
    -- -------------------------------------------------------------------------
    
    DIN <= pulse_counter_tilt_vector & pulse_counter_pan_vector;
    DIN_VLD <= '1';  -- Set DIN_VLD to indicate that the data in DIN is valid
    DIN_RDY  <= slave_ready;
    DOUT     <= data_shreg;
    DOUT_VLD <= rx_data_vld;

end architecture;
