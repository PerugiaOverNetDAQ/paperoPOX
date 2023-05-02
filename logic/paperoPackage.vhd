--!@file paperoPackage.vhd
--!@brief Constants, components declarations, and functions
--!@author Matteo D'Antonio, matteo.dantonio@studenti.unipg.it
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.basic_package.all;

--Mainly, for register initialization
use work.FOOTpackage.all;

--!@copydoc paperoPackage.vhd
package paperoPackage is
  -- Constants -----------------------------------------------------------------
  constant cREG_WIDTH      : natural := 32;  --!Register width
  constant cHPS_REGISTERS  : natural := 16;  --!Number of HPS-RW, FPGA-R registers
  constant cFPGA_REGISTERS : natural := 16;  --!Number of HPS-R, FPGA-RW registers
  constant cREGISTERS      : natural := cHPS_REGISTERS + cFPGA_REGISTERS;  --!Total number of registers

  constant cHPS_REG_ADDR  : natural := ceil_log2(cHPS_REGISTERS);  --!Register address width
  constant cFPGA_REG_ADDR : natural := ceil_log2(cFPGA_REGISTERS);  --!Register address width

  constant cFDI_WIDTH     : natural := 32;  --!Width of FDI FIFO
  constant cFDI_DEPTH     : natural := 4096;  --!Number of words in the FDI FIFO
  constant cLENCONV_DEPTH : natural := 16;  --!Number of words in the length converter FIFO

  --Housekeeping reader
  constant cF2H_HK_SOP    : std_logic_vector(31 downto 0) := x"55AADEAD";  --!Start of Packet for the FPGA-2-HPS FSM
  constant cF2H_HK_HDR    : std_logic_vector(31 downto 0) := x"4EADE500";  --!Fixed Header for the FPGA-2-HPS FSM
  constant cF2H_HK_EOP    : std_logic_vector(31 downto 0) := x"600DF00D";  --!End of Packet for the FPGA-2-HPS FSM
  constant cF2H_HK_PERIOD : natural                       := 50000000;  --!Period for internal counter to read HKs; max: 2^32 (85 s)
  constant cF2H_AFULL     : natural                       := 949;  --!Almost full threshold for the HK FIFO: 1021 - (6 + 32*2) - 2
  constant cFastF2H_AFULL : natural                       := 4085;  --!Almost full threshold for the data FIFO

  --Trigger types
  constant cTRG_PHYS_INT  : std_logic_vector(15 downto 0) := x"0001";  --!Physics trigger (from internal counter)
  constant cTRG_PHYS_EXT  : std_logic_vector(15 downto 0) := x"0002";  --!Physics trigger (from external pin)
  constant cTRG_CALIB_INT : std_logic_vector(15 downto 0) := x"0004";  --!Calibration trigger (internal)
  constant cTRG_CALIB_EXT : std_logic_vector(15 downto 0) := x"0008";  --!Calibration trigger (external)

  -- Types ---------------------------------------------------------------------
  constant rGOTO_STATE     : natural := 0;
  constant rUNITS_EN       : natural := 1;
  constant rTRIGBUSY_LOGIC : natural := 2;
  constant rDET_ID         : natural := 3;
  constant rPKT_LEN        : natural := 4;
  constant rFE_CLK_PARAM   : natural := 5;
  constant rADC_CLK_PARAM  : natural := 6;
  constant rMSD_PARAM      : natural := 7;
  constant rBUSYADC_PARAM  : natural := 8;
  --!Register array HPS-RW, FPGA-R
  type tHpsRegArray is array (0 to cHPS_REGISTERS-1) of
    std_logic_vector(cREG_WIDTH-1 downto 0);
    constant cHPS_REG_NULL : tHpsRegArray := (
      x"00000000", x"00000001", x"02faf080", x"000000FF",
      x"0000028A", cFE_CLK_DUTY & cFE_CLK_DIV, cADC_CLK_DUTY & cADC_CLK_DIV , cCFG_PLANE & cTRG2HOLD,
      cBUSY_LEN & cADC_DELAY, x"00000000", x"00000000", x"00000000",
      x"00000000", x"00000000", x"00000000", x"00000000"
      );                                  --!Null vector for HPS register array

  constant rGW_VER           : natural := 0;
  constant rINT_TS_MSB       : natural := 1;
  constant rINT_TS_LSB       : natural := 2;
  constant rEXT_TS_MSB       : natural := 3;
  constant rEXT_TS_LSB       : natural := 4;
  constant rWARNING          : natural := 5;
  constant rBUSY             : natural := 6;
  constant rEXT_TRG_COUNT    : natural := 7;
  constant rINT_TRG_COUNT    : natural := 8;
  constant rFDI_FIFO_NUMWORD : natural := 9;
  constant rPIUMONE          : natural := 15;
  --!Register array HPS-R, FPGA-RW
  type tFpgaRegArray is array (0 to cFPGA_REGISTERS-1) of
    std_logic_vector(cREG_WIDTH-1 downto 0);
  constant cFPGA_REG_NULL : tFpgaRegArray := (
    x"a0a0a0a0", x"00000000", x"00000000", x"00000000",
    x"00000000", x"00000000", x"00000000", x"00000000",
    x"00000000", x"00000000", x"00000000", x"00000000",
    x"00000000", x"00000000", x"00000000", x"c1a0c1a0"
    );                                  --!Null vector for FPGA register array

  --!Complete Registers array
  type tRegArray is array (0 to cREGISTERS-1) of
    std_logic_vector(cREG_WIDTH-1 downto 0);

  --!Registers interface
  type tRegIntf is record
    reg  : std_logic_vector(cREG_WIDTH-1 downto 0);  --!Content to be written
    addr : std_logic_vector(cHPS_REG_ADDR-1 downto 0);  --!Address to be updated
    we   : std_logic;                   --!Write enable
  end record tRegIntf;

  --!FPGA Registers interface
  type tFpgaRegIntf is record
    regs : tFpgaRegArray;               --!FPGA registers
    we   : std_logic_vector(cFPGA_REGISTERS-1 downto 0);  --!Write enable vector
  end record tFpgaRegIntf;

  --!Control interface for a generic block: input signals
  type tControlIn is record
    en    : std_logic;                  --!Enable
    start : std_logic;                  --!Start
  end record tControlIn;

  --!Control interface for a generic block: output signals
  type tControlOut is record
    busy  : std_logic;                  --!Busy flag
    error : std_logic;                  --!Error flag
    reset : std_logic;                  --!Resetting flag
    compl : std_logic;                  --!completion of task
  end record tControlOut;

  --!CRC32 interface (do not use it as port)
  type tCrc32 is record
    rst  : std_logic;
    en   : std_logic;                      --!Write enable
    data : std_logic_vector(31 downto 0);  --!Input data
    crc  : std_logic_vector(31 downto 0);  --!CRC32 out
  end record tCrc32;

  --!Input signals of a typical FIFO memory of 32 bit
  type tFifo32In is record
    data : std_logic_vector(31 downto 0);  --!Input data port
    rd   : std_logic;                      --!Read request
    wr   : std_logic;                      --!Write request
  end record tFifo32In;

  --!Output signals of a typical FIFO memory of 32 bit
  type tFifo32Out is record
    q      : std_logic_vector(31 downto 0);  --!Output data port
    aEmpty : std_logic;                      --!Almost empty
    empty  : std_logic;                      --!Empty
    aFull  : std_logic;                      --!Almost full
    full   : std_logic;                      --!Full
  end record tFifo32Out;

  --!Input signals of a typical FIFO memory of cFDI_WIDTH bit
  type tFifoFdiIn is record
    data : std_logic_vector(cFDI_WIDTH-1 downto 0);  --!Input data port
    rd   : std_logic;                                --!Read request
    wr   : std_logic;                                --!Write request
  end record tFifoFdiIn;

  --!Output signals of a typical FIFO memory of cFDI_WIDTH bit
  type tFifoFdiOut is record
    q      : std_logic_vector(cFDI_WIDTH-1 downto 0);  --!Output data port
    aEmpty : std_logic;                                --!Almost empty
    empty  : std_logic;                                --!Empty
    aFull  : std_logic;                                --!Almost full
    full   : std_logic;                                --!Full
  end record tFifoFdiOut;

  --!Metadata for the F2H Fast TX
  type tF2hMetadata is record
    pktLen  : std_logic_vector(31 downto 0);  --!Packet Length: Number of 32-bit payload words + 10
    trigNum : std_logic_vector(31 downto 0);  --!Trigger Counter
    detId   : std_logic_vector(15 downto 0);  --!Detector ID
    trigId  : std_logic_vector(15 downto 0);  --!Trigger ID
    intTime : std_logic_vector(63 downto 0);  --!Internal Timestamp
    extTime : std_logic_vector(63 downto 0);  --!External Timestamp
  end record tF2hMetadata;

  --!Input signals of FIFO memory of HPS/FPGA interface
  type tFifoCsrIn is record
    data    : std_logic_vector(31 downto 0);  --!Input data port
    rd      : std_logic;                      --!Read request
    wr      : std_logic;                      --!Write request
    csrAddr : std_logic_vector(2 downto 0);   --!CSR Address
    csrData : std_logic_vector(31 downto 0);  --!CSR Input Data
    csrRd   : std_logic;                      --!CSR Read Enable
    csrWr   : std_logic;                      --!CSR Write Enable
  end record tFifoCsrIn;

  --!Output signals of FIFO memory of HPS/FPGA interface
  type tFifoCsrOut is record
    q       : std_logic_vector(31 downto 0);  --!Output data port
    aEmpty  : std_logic;                      --!Almost empty
    empty   : std_logic;                      --!Empty
    aFull   : std_logic;                      --!Almost full
    full    : std_logic;                      --!Full
    csrQ    : std_logic_vector(31 downto 0);  --!CSR Data Out
  end record tFifoCsrOut;

  -- Components ----------------------------------------------------------------
  
  --!@copydoc Config_Receiver.vhd
  component Config_Receiver is
    port(
      CR_CLK_in               : in  std_logic;
      CR_RST_in               : in  std_logic;
      CR_FIFO_WAIT_REQUEST_in : in  std_logic;
      CR_DATA_in              : in  std_logic_vector(31 downto 0);
      CR_FWV_in               : in  std_logic_vector(31 downto 0);
      CR_FIFO_READ_EN_out     : out std_logic;
      CR_DATA_out             : out std_logic_vector(31 downto 0);
      CR_ADDRESS_out          : out std_logic_vector(15 downto 0);
      CR_DATA_VALID_out       : out std_logic;
      CR_WARNING_out          : out std_logic_vector(2 downto 0)
      );
  end component;

  --!@copydoc WR_Timer.vhd
  component WR_Timer is
    port(
      iCLK        : in  std_logic;
      iRST        : in  std_logic;
      iSTART      : in  std_logic;
      iSTANDBY    : in  std_logic;
      iLEN        : in  std_logic_vector(31 downto 0);
      oWRT        : out std_logic;
      oEND_COUNT  : out std_logic
      );
  end component;

  --!@copydoc registerArray.vhd
  component registerArray is
    port (
      iCLK       : in  std_logic;
      iRST       : in  std_logic;
      iCNT       : in  tControlIn;
      oCNT       : out tControlOut;
      --Register array
      oREG_ARRAY : out tRegArray;
      iHPS_REG   : in  tRegIntf;
      iFPGA_REG  : in  tFpgaRegIntf
      );
  end component;

  --!@copydoc hkReader.vhd
  component hkReader is
    generic(
      pFIFO_WIDTH : natural;
      pPARITY     : string;
      pGW_VER     : std_logic_vector(31 downto 0)
      );
    port (
      iCLK        : in  std_logic;
      iRST        : in  std_logic;
      iCNT        : in  tControlIn;
      oCNT        : out tControlOut;
      iINT_START  : in  std_logic;
      --Register array
      iREG_ARRAY  : in  tRegArray;
      --Output FIFO interface
      oFIFO_DATA  : out std_logic_vector(pFIFO_WIDTH-1 downto 0);
      oFIFO_WR    : out std_logic;
      iFIFO_AFULL : in  std_logic
      );
  end component;

  --!@copydoc HPS_intf.vhd
  component HPS_intf is
    generic (
      pGW_VER : std_logic_vector(31 downto 0)
      );
    port (
      --# {{clocks|Clock}}
      iCLK                : in  std_logic;
      --# {{resets|Reset}}
      iRST                : in  std_logic;
      iRST_REG            : in  std_logic;
      --# {{ConfigRX | ConfigRX}}
      oCR_WARNING         : out std_logic_vector(2 downto 0);
      --# {{HKReader|HKReader}}
      iHK_RDR_CNT         : in  tControlIn;
      iHK_RDR_INT_START   : in  std_logic;
      --# {{F2HFast|F2HFast}}
      iF2HFAST_CNT        : in  tControlIn;
      oF2HFAST_MD_RD      : out std_logic;
      iF2HFAST_MD_EMPTY   : in  std_logic;
      iF2HFAST_METADATA   : in  tF2hMetadata;
      oF2HFAST_BUSY       : out std_logic;
      oF2HFAST_WARNING    : out std_logic;
      --# {{RegArray|RegArray}}
      iREG_ARRAY          : in  tRegArray;
      oREG_CONFIG_RX      : out tRegIntf;
      --# {{FdiFifo|FdiFifo}}
      iFDI_FIFO           : in  tFifo32Out;
      oFDI_FIFO_RD        : out std_logic;
      --# {{H2F_FIFO|H2F_FIFO}}
      iFIFO_H2F_EMPTY     : in  std_logic;
      iFIFO_H2F_DATA      : in  std_logic_vector(31 downto 0);
      oFIFO_H2F_RE        : out std_logic;
      --# {{F2H_FIFO|F2H_FIFO}}
      iFIFO_F2H_AFULL     : in  std_logic;
      oFIFO_F2H_WE        : out std_logic;
      oFIFO_F2H_DATA      : out std_logic_vector(31 downto 0);
      --# {{F2H_FastFIFO|F2H_FastFIFO}}
      iFIFO_F2HFAST_AFULL : in  std_logic;
      oFIFO_F2HFAST_WE    : out std_logic;
      oFIFO_F2HFAST_DATA  : out std_logic_vector(31 downto 0)  --!F2H Fast q
      );
  end component;

  --!@copydoc Test_Unit.vhd
  component Test_Unit is
    port(
      iCLK            : in  std_logic;
      iRST            : in  std_logic;
      iEN             : in  std_logic;
      iSETTING_CONFIG : in  std_logic_vector(1 downto 0);
      iSETTING_LENGTH : in  std_logic_vector(31 downto 0);
      iTRIG           : in  std_logic;
      oDATA           : out std_logic_vector(31 downto 0);
      oDATA_VALID     : out std_logic;
      oTEST_BUSY      : out std_logic
      );
  end component;

  --!@copydoc FastData_Transmitter.vhd
  component FastData_Transmitter is
    generic(
      pGW_VER : std_logic_vector(31 downto 0)
      );
    port(
      iCLK         : in  std_logic;
      iRST         : in  std_logic;
      iEN          : in  std_logic;
      oMETADATA_RD : out std_logic;
      iMETADATA_EMPTY : in  std_logic;
      iMETADATA    : in  tF2hMetadata;
      iFIFO_DATA   : in  std_logic_vector(31 downto 0);
      iFIFO_EMPTY  : in  std_logic;
      iFIFO_AEMPTY : in  std_logic;
      oFIFO_RE     : out std_logic;
      oFIFO_DATA   : out std_logic_vector(31 downto 0);
      iFIFO_AFULL  : in  std_logic;
      oFIFO_WE     : out std_logic;
      oBUSY        : out std_logic;
      oWARNING     : out std_logic
      );
  end component;

  --!@copydoc trigBusyLogic.vhd
  component trigBusyLogic is
    port (
      iCLK            : in  std_logic;
      iRST            : in  std_logic;
      iRST_COUNTERS   : in  std_logic;
      iCFG            : in  std_logic_vector(31 downto 0);
      iEXT_TRIG       : in  std_logic;
      iBUSIES_AND     : in  std_logic_vector(7 downto 0);
      iBUSIES_OR      : in  std_logic_vector(7 downto 0);
      oTRIG           : out std_logic;
      oTRIG_ID        : out std_logic_vector(15 downto 0);
      oTRIG_COUNT     : out std_logic_vector(31 downto 0);
      oEXT_TRIG_COUNT : out std_logic_vector(31 downto 0);
      oINT_TRIG_COUNT : out std_logic_vector(31 downto 0);
      oTRIG_WHEN_BUSY : out std_logic_vector(7 downto 0);
      oBUSY           : out std_logic
      );
  end component;

  --!@copydoc TdaqModule.vhd
  component TdaqModule is
    generic (
      pFDI_WIDTH : natural;
      pFDI_DEPTH : natural;
      pGW_VER    : std_logic_vector(31 downto 0)
      );
    port (
      iCLK                : in  std_logic;
      --# {{RegArray|RegArray}}
      iRST                : in  std_logic;
      iRST_COUNT          : in  std_logic;
      iRST_REG            : in  std_logic;
      oREG_ARRAY          : out tRegArray;
      iINT_TS             : in  std_logic_vector(63 downto 0);
      iEXT_TS             : in  std_logic_vector(63 downto 0);
      --# {{TrigBusy|TrigBusy}}
      iEXT_TRIG           : in  std_logic;
      oTRIG               : out std_logic;
      oBUSY               : out std_logic;
      iTRG_BUSIES_AND     : in  std_logic_vector(7 downto 0);
      iTRG_BUSIES_OR      : in  std_logic_vector(7 downto 0);
      --# {{FastDATA-Detector interface|FastDATA-Detector interface}}
      iFASTDATA_DATA      : in  std_logic_vector(cREG_WIDTH-1 downto 0);
      iFASTDATA_WE        : in  std_logic;
      oFASTDATA_AFULL     : out std_logic;
      --# {{H2F_FIFO|H2F_FIFO}}
      iFIFO_H2F_EMPTY     : in  std_logic;
      iFIFO_H2F_DATA      : in  std_logic_vector(31 downto 0);
      oFIFO_H2F_RE        : out std_logic;
      --# {{F2H_FIFO|F2H_FIFO}}
      iFIFO_F2H_AFULL     : in  std_logic;
      oFIFO_F2H_WE        : out std_logic;
      oFIFO_F2H_DATA      : out std_logic_vector(31 downto 0);
      --# {{F2H_FastFIFO|F2H_FastFIFO}}
      iFIFO_F2HFAST_AFULL : in  std_logic;
      oFIFO_F2HFAST_WE    : out std_logic;
      oFIFO_F2HFAST_DATA  : out std_logic_vector(31 downto 0)
      );
  end component;

  --!@copydoc metaDataFifo.vhd
  component metaDataFifo is
    generic (
      pFIFOs : natural;
      pWIDTH : natural
    );
    port (
      iCLK      : in  std_logic;
      iRST      : in  std_logic;
      oERR      : out std_logic;
      iRD       : in  std_logic;
      iWR       : in  std_logic;
      oEMPTY    : out std_logic;
      iMETADATA : in  tF2hMetadata;
      oMETADATA : out tF2hMetadata
    );
  end component;

  --!@copydoc DetectorInterface.vhd
  component DetectorInterface is
    port (
      iCLK            : in  std_logic;
      iRST            : in  std_logic;
      --# {{Controls|Controls}}
      iEN             : in  std_logic;
      iTRIG           : in  std_logic;
      oCNT            : out tControlIntfOut;
      iMSD_CONFIG     : in  msd_config;
      --# {{Detector 0|Detector 0}}
      oFE0            : out tFpga2FeIntf;
      oADC0           : out tFpga2AdcIntf;
      --# {{Detector 1|Detector 1}}
      oFE1            : out tFpga2FeIntf;
      oADC1           : out tFpga2AdcIntf;
      --# {{ADCs Inputs|ADCs Inputs}}
      iMULTI_ADC      : in  tMultiAdc2FpgaIntf;
      --# {{FastDATA Interface|FastDATA Interface}}
      oFASTDATA_DATA  : out std_logic_vector(cREG_WIDTH-1 downto 0);
      oFASTDATA_WE    : out std_logic;
      iFASTDATA_AFULL : in  std_logic
      );
  end component;

  --!@copydoc priorityEncoder.vhd
  component priorityEncoder is
    generic (
      pFIFOWIDTH : natural;
      pFIFODEPTH : natural
      );
    port (
      iCLK            : in  std_logic;
      iRST            : in  std_logic;
      --# {{MULTI_FIFO Interface|MULTI_FIFO Interface}}
      iMULTI_FIFO     : in  tMultiAdcFifoOut;
      oMULTI_FIFO     : out tMultiAdcFifoIn;
      --# {{FastDATA Interface|FastDATA Interface}}
      oFASTDATA_DATA  : out std_logic_vector(pFIFOWIDTH-1 downto 0);
      oFASTDATA_WE    : out std_logic;
      iFASTDATA_AFULL : in  std_logic
      );
  end component;

end paperoPackage;
