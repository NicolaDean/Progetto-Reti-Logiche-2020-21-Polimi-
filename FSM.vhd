
--DEAN NICOLA 10674826 
--Matricola 911817
--PROGETTO RETI LOGICHE INGEGNERIA INFROMATICA

----------------------------------------------------------------------------------
--FSM che controlla i bit di flag del datapath------------------------------------
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity FSM is
port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end FSM;

architecture Behavioral of FSM is

 type S is (START,SIZE,STAGE1,WR0,WAIT_RAM,STAGE2,WAIT_RAM2,ELABORATE,WRITE_OUTPUT,FINISH);
                   
 signal curr_state,next_state: S;            --Sono i segnali che ideniticano lo stato corrente e prossimo
        
    component datapath
    port (
            i_clk : in std_logic;
            i_rst : in std_logic;
            i_data : in std_logic_vector(7 downto 0);
            o_address : out std_logic_vector(15 downto 0);
            o_data : out std_logic_vector (7 downto 0);
            increment : in std_logic;
            InputTrigger:in std_logic;
            RealEnd:out std_logic;
            LoadPixel : in std_logic;
             DeltaStage: in std_logic;
            InputRead : out std_logic;
            Image_end : out std_logic;
            Write: in std_logic
        );
        end component datapath;
        signal Image_end: std_logic;
        signal increment: std_logic;
        signal InputRead: std_logic;
        signal LoadPixel: std_logic;
        signal DeltaStage: std_logic;
        signal Write: std_logic;
        signal RealEnd: std_logic;
        signal InputTrigger:std_logic;
        signal InternalReset:std_logic;
        signal DatapthReset:std_logic;
        
begin
--Unifico il reset del testBanch con un reset interno necessario a resettare il datapath al termine unaffected
--i_rst è un segnale esterno controllato dal TB
--InternalReset è un segnale controllato dalla fsm 
--InternalReset si attiva una volta che finisco nello stato FINISH

UniqueReset:DatapthReset <= InternalReset or i_rst;

DataPathMap : datapath port map (
          i_clk      	=> i_clk,
          i_rst      	=> DatapthReset,
          i_data    	=> i_data,
          o_address  	=> o_address,
          o_data    	=> o_data,
          increment     => increment,
          InputTrigger  => InputTrigger,
          RealEnd       =>RealEnd,
          LoadPixel     => LoadPixel,
          DeltaStage    =>DeltaStage,
          InputRead     => InputRead,
          Image_end     => Image_end,
          Write         => Write
          
);


-- RESET E CAMBIO STATO ----------------------------------------------------------------------  
        --Quando il clock ha una fase di salita aggiorna lo stato
UPDATE: process(i_clk,i_rst)
        begin
            if i_rst = '1' then 
                curr_state <= START;
            elsif i_clk'event and i_clk='1' then  -- clock'event indica una salita o una discesa, and clock='1' specifica che ? una SALITA
                curr_state <= next_state;         -- Se il clock ? in salita allora aggiorno lo stato
            end if;       
        end process;
        
        
nxtSTATE: process(curr_state,i_start,InputRead,Image_end,RealEnd)
    begin
        next_state <= curr_state;
        case curr_state is
            when START =>   
                if( i_start = '1') then
                    next_state <= SIZE;
                 end if;
            when SIZE =>
                if(InputRead='1') then
                    next_state <= WR0;
                else
                    next_state <= STAGE1;
                end if;
            when WR0 =>
                next_state <= SIZE;
            when STAGE1 =>
               if(Image_end = '0') then
                    next_state <=WAIT_RAM;
                elsif(Image_end = '1')then
                    next_state <=STAGE2  ;
                end if;
            when WAIT_RAM =>
                    next_state <= STAGE1;
            when STAGE2 =>
                if(RealEnd='0') then
                    next_state <= WAIT_RAM2;
                else
                    next_state <= FINISH;
                end if;
            when WAIT_RAM2 =>
                next_state <= ELABORATE;
            when ELABORATE =>
                next_state <= WRITE_OUTPUT;
            when WRITE_OUTPUT =>
                next_state <= STAGE2;
             when FINISH =>
             if( i_start = '0') then
                    next_state <= START;
             end if;
        end case;
    end process;
   WriteCondition: o_we<= write and (not RealEnd);
OUTPUT:process(curr_state)
    begin
        LoadPixel <= '0';
        increment <= '0';
        Write     <= '0';
        InputTrigger<='0';
        o_en<='0';
        DeltaStage<='0';
        InternalReset<='0';
        o_done<='0';
        case curr_state is
            when START =>
                 LoadPixel <= '0';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='0';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
            when SIZE =>
                LoadPixel <= '0';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
            when WR0 =>
                LoadPixel <= '0';
                increment <= '1';
                LoadPixel <= '0';
                InputTrigger<='1';
                Write     <= '0';
                 o_en<='1';
                 DeltaStage<='0';
                 o_done<='0';
            when WAIT_RAM =>
                InputTrigger<='0';
                increment <= '1';
                LoadPixel <= '0';
                Write     <= '0';
                 o_en<='1';
                 InternalReset<='0';
                 DeltaStage<='1';
                 o_done<='0';
            when STAGE1 =>
                LoadPixel <= '1';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                 o_en<='1';
                 DeltaStage<='0';
                 InternalReset<='0';
                 o_done<='0';
            when STAGE2 =>
                LoadPixel <= '0';
                increment <= '1';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
             when WAIT_RAM2 =>
                LoadPixel <= '1';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
            when ELABORATE =>
                LoadPixel <= '0';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
            when WRITE_OUTPUT =>
                LoadPixel <= '0';
                increment <= '0';
                Write     <= '1';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='0';
                o_done<='0';
            when FINISH =>
                LoadPixel <= '0';
                increment <= '0';
                Write     <= '0';
                InputTrigger<='0';
                o_en<='1';
                DeltaStage<='0';
                InternalReset<='1';
                o_done<='1';
        end case;
    end process; 
end Behavioral;


