
----------------------------------------------------------------------------------
--DataPath che controlla i bit di flag del datapath------------------------------------
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity datapath is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_data : out std_logic_vector (7 downto 0);
        increment : in std_logic;
        InputTrigger:in std_logic;
        RealEnd:out std_logic;
        LoadPixel: in std_logic;
        DeltaStage: in std_logic;
        InputRead : out std_logic;
        Image_end : out std_logic;
        Write: in std_logic
        
    );
end datapath;

architecture Behavioral of datapath is
signal REGaddressR      : STD_LOGIC_VECTOR(15 downto 0); --Read address
signal REGaddressW      : STD_LOGIC_VECTOR(15 downto 0); --Write addres

signal ColRegister      : STD_LOGIC_VECTOR(7 downto 0); --Max 128 (7bit)
signal RowRegister      : STD_LOGIC_VECTOR(7 downto 0); --Max 128 (7bit)

signal CurrentPixel     : STD_LOGIC_VECTOR(7 downto 0);
signal CurrentMax       : STD_LOGIC_VECTOR(7 downto 0);
signal CurrentMin       : STD_LOGIC_VECTOR(7 downto 0);
signal LoadMax          : STD_LOGIC;
signal LoadMin          : STD_LOGIC;

signal sum: STD_LOGIC_VECTOR(15 downto 0);      
signal LoadDelta        : STD_LOGIC;
signal DeltaReg         : STD_LOGIC_VECTOR(8 downto 0);       

signal Log              : STD_LOGIC_VECTOR(3 downto 0);   
signal ShiftIn          : STD_LOGIC_VECTOR(7 downto 0);
signal NewPixel         : STD_LOGIC_VECTOR(15 downto 0);

signal R_end: STD_LOGIC;
signal C_end: STD_LOGIC;

signal subR      : STD_LOGIC_VECTOR(7 downto 0); --Max 128 (7bit)
signal subC      : STD_LOGIC_VECTOR(7 downto 0); --Max 128 (7bit)
signal Par       : STD_LOGIC_VECTOR(7 downto 0); --Max 128 (7bit)

signal ColTrig : STD_LOGIC;
signal RowTrig : STD_LOGIC;

signal fine: std_logic;
signal end_input: std_logic;
begin

--Calcola preventivamente il prossimo indirizzo      
    sum <= REGaddressR + "0000000000000001";                    --Incremento registro adress
    
--Determina quando teoricamente ho terminato la lettura delle dimensioni
    end_input<= '1' when REGaddressR <= "00000001" else '0';    --Sale a 1 quando leggo i registri contenenti l'input
  
--Si triggerano Quando finisco di contare righe o colonne(sono attivi solo una volta che ho letto la dimensione dell'immagine)  
    R_end <= '1' when RowRegister = subR  and end_input = '0' else '0';
    C_end <= '1' when ColRegister = subC  and end_input = '0' else '0';
    
    Image_end<=fine ;
    InputRead<=end_input;
            
--Seleziono quale contatore (fra righe o colonne) � attivo al momento
--Ogni volta che finisco le colonne attivo il contatore di righe per poi tornare a quello di colonne nel prossimo stato
 SubSelector:
    with C_end select
        Par <= subC + "00000001" when '0',
               subR + "00000001" when '1',
               "00000000" when others;
             
--Contatore in 2 stati, 
--ogni volta che il contatore di colonne raggiunge "ColRegister" triggera il contatore delle righe (C_end)
--ogni volta che il contatore di righe raggiunge "RowRegister"  R_end sale ad alto (ed interrompe eventuali process)
--R_end permette il passaggio Stage1->Stage2 (tramite il flag Fine) oppure Stage2->Finish (tramite il flag RealEnd)
ColSub: process(i_clk,i_rst,R_end,C_end)     
        begin
              if(i_rst = '1') then
                       subC <= "00000001";
                       subR <= "00000000";
               elsif i_clk'event and i_clk = '0' then                                  --Quando il clock sale
                    if(increment = '1' and end_input ='0') then                                           --Controllo flag "increment"
                        if(R_end = '1') then
                            subC<= "00000001";
                            subR<= "00000000";
                        elsif(C_end = '1')then
                            subC<= "00000001";
                            subR<= par;
                        else
                            subR<= subR;
                            subC <= par;
                        end if;
                    end if;
               end if;        
        end process;

                                                                                            
--Indica QUando finisce Stage1 e quando inizia Stage2 tramite il Flag "fine"
EndStage1:   process(i_clk,i_rst,R_end)
             begin
             if(i_rst = '1') then
                       fine<='0';
               elsif i_clk'event and i_clk = '1' then                                  --Quando il clock sale
                     --FINE E' UN PROBLEMA
                   if(R_end = '1' and DeltaStage ='1') then
                        fine<='1';
                   end if;
                end if;
             end process;
 
DimFlags:            
    ColTrig <= '1' when REGaddressR = "0000000000000000" and InputTrigger = '1' else '0';   
    RowTrig <= '1' when REGaddressR = "0000000000000001" and InputTrigger = '1' else '0';         
--Lettura di dimensione di Colonna
InputReadCol:  process(i_clk,ColTrig)
            begin
            if i_clk'event and i_clk = '0' then 
                if InputTrigger = '1' and ColTrig = '1' then
                     ColRegister <= i_data; 
                end if;
            end if;  
            end process;
--Lettura della dimensione di Riga
InputReadRow:  process(i_clk,RowTrig)
            begin
            if i_clk'event and i_clk = '0' then 
                if InputTrigger = '1' and RowTrig = '1' then
                     RowRegister <= i_data; 
                end if;
            end if;  
            end process;
            
--Ad ogni clock in fase di discesa, se mi trovo in uno stato dell FSM di incremento allora eseguo un "ADRESS++"
--Se mi trovo in Stage1 W address sar� uguale a R address
--Se mi trovo in Stage2 W address si incrementa in maniera "indipendente"
--Ogni volta che l'immagine giunge a termine il Raddress Viene resettato a "2"
Contatore:  process(i_clk,i_rst,increment)
            begin
                if(i_rst = '1') then
                       REGaddressR<= "0000000000000000";
                       REGaddressW<= "1111111111111111";
               elsif i_clk'event and i_clk = '0' then                                  --Quando il clock sale
                    if(increment = '1') then                                           --Controllo flag "increment"
                       REGaddressR <= sum;   --Aggiorno RegAddress
                       if(fine = '1') then
                            REGaddressW<=REGaddressW+"0000000000000001";
                       else
                            REGaddressW<=sum;
                       end if;
                    end if;
                    if(R_end = '1') then
                        REGaddressW<=REGaddressW;
                        REGaddressR<= "0000000000000010";--Ritorno al primo pixel
                    end if;
               end if;
              
            end process;

--Se reset Resetta il valore iniziale di Oaddress 
--In base allo stato dell FSM in cui mi trovo scego se assegnare W/R address ad oaddress  
UpdateAddr: process(REGaddressR,write,i_rst)
            begin
            if(i_rst = '1') then
                o_address  <= "0000000000000000";
            elsif(write = '1') then
                o_address   <= REGaddressW;
            else
                o_address   <= REGaddressR;
            end if;
            end process;
 

    

--Ogni volta che il Clock scende, o che cambiano i dati verifica se � necessario caricare un nuovo pixel (tramite flag LoadPixel)   
INPUTDat:  process(i_clk,REGaddressR,i_data,LoadPixel)
            begin
                if i_clk'event and i_clk = '0' then                                  --Quando il clock sale
                    if(increment = '0' and LoadPixel = '1') then 
                        CurrentPixel <= i_data;  
                    end if;
                end if;
                
            end process;         
--Controllo se il Massimo/Minimo corrente � ancora massimo o minimo rispetto al nuovo pixel
FlagMinMax:
    LoadMax <= '1' when (CurrentMax < CurrentPixel) and DeltaStage='1' else '0';
    LoadMin <= '1' when (CurrentMin > CurrentPixel) and DeltaStage='1' else '0';
   
Delta:    
    DeltaReg <= (CurrentMax - CurrentMin) + "000000001";--Controllo DELTYAAA NON VAAA
--Carico i registri CurrentMax e CurrentMin ma solo quando necessario(STAGE1) e setto il vlore inizile in caso di reset
MaxMin:process(LoadMax,LoadMin,i_rst)
    begin
     if(i_rst = '1') then
              CurrentMax <=  "00000000";
              CurrentMin <=  "11111111";
      else  
      --(R_end = '0') then                  <---MODIFICA FATTA
            if  falling_edge(LoadMax) then  
                CurrentMax <= CurrentPixel;
            end if;
            
            if falling_edge(LoadMin) then  
                CurrentMin <= CurrentPixel;
            end if;
        end if;
            
    end process;
    
    
--Esegue l'operazione 8-Log(Delta+1) utilizzando un controllo a soglia degli 8 possibili risultati
Logaritmo: process(i_clk)
begin
    if i_clk'event and i_clk = '0' then                                  --Quando il clock sale
         if (DeltaReg = "000000001") then                                               --(1,1)
            Log <= "1000";
         end if;
         if (DeltaReg = "000000010")and (DeltaReg < "00000011") then                 -- (2,3)
            Log <= "0111";
         end if;
         if (DeltaReg > "000000100")  and (DeltaReg < "00000111")then                -- (4,7)
            Log <= "0110";
         end if;
         if (DeltaReg > "000001000")  and (DeltaReg < "00001111")then                -- (8,15)
           Log <= "0101";
         end if;
         if (DeltaReg > "000010000")  and (DeltaReg < "000011111")then               -- (16,31)
             Log <= "0100";
         end if;
         if (DeltaReg > "000100000")  and (DeltaReg < "000111111")then               -- (32,63)
            Log <= "0011";
         end if;
         if (DeltaReg > "001000000")  and (DeltaReg < "001111111")then                -- (64,127)
            Log <= "0010";
         end if;
         if (DeltaReg > "010000000")  and (DeltaReg < "011111111")then                -- (128,255)
            Log <= "0001";
         end if;
         if (DeltaReg >= "100000000")then                                              -- (256,256)
            Log <= "0000";
         end if;
     end if;  
   end process;

CalcoloIngressoShift:   ShiftIn<= CurrentPixel - CurrentMin;         
--Esegue uno shift senza perdita di informazione, shiftando un registro a 8 bit (SHIFTIN) in un registro a 16bit(NewPixel)             
SHIFT: process(ShiftIn)
        begin
        --if LoadNewPixel then
            NewPixel <="0000000000000000";
            case Log is 
                when "0000" =>
                    NewPixel(7 downto 0) <= ShiftIn;              
                when "0001" =>
                    NewPixel(8 downto 1) <= ShiftIn;
                when "0010" =>
                   NewPixel(9 downto 2) <= ShiftIn;
                when "0011"=>
                    NewPixel(10 downto 3) <= ShiftIn;
                when "0100"=>
                    NewPixel(11 downto 4) <= ShiftIn;
                when "0101" =>
                     NewPixel(12 downto 5) <= ShiftIn;
                when "0110" =>
                     NewPixel(13 downto 6) <= ShiftIn;
                when "0111" =>
                     NewPixel(14 downto 7) <= ShiftIn;
                when others  => NewPixel(15 downto 8) <= ShiftIn;
            end case;
                
        end process;
        
-- Write Mode si occupa di Scrivere NewPixel nella ram controllando con appositi flag se ci� si pu� fare oppure � un "false trigger" del process
--Oltre alla scrittura si occupa pure di verificare se l'immagine di input � terminata e in caso alza un segnale di Flag (RealEnd)
WriteMode:process(Write,i_rst)
          begin
                if(i_rst ='1') then
                        RealEnd<='0';
                elsif rising_edge(Write)  then
                    if( R_end = '0') then
                        if(NewPixel > "0000000011111111")then
                              o_data <="11111111";
                        else 
                            o_data <= NewPixel(7 downto 0);
                        end if;
                     else
--                        o_data <="00000000";  <---MODIFICA FATTA
                        RealEnd<='1';
                     end if;
                end if;
          end process;
end Behavioral;
