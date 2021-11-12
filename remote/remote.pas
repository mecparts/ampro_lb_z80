PROGRAM Remote;

CONST
  CR = ^M;

TYPE
  ModemSetupType = ARRAY [0..3] OF BYTE;
  String80 = STRING[80];

VAR
  modemSetup : ModemSetupType;

{$I MDMINRDY}
{$I OFFLINE }

PROCEDURE Purge;
VAR
  timeout : INTEGER;
  c : CHAR;
BEGIN
  timeout := 500;
  REPEAT
    IF ModemInReady THEN BEGIN
      Read(Aux,c);
      timeout := 100;
    END ELSE BEGIN
      Delay(1);
      timeOut := Pred(timeout);
    END;
  UNTIL timeOut < 0;
END;

FUNCTION BaudIndex(baud : INTEGER) : BYTE;
BEGIN
  CASE baud OF
    300: BaudIndex := 1;
    450: BaudIndex := 2;
    600: BaudIndex := 3;
    710: BaudIndex := 4;
    1200: BaudIndex := 5;
    2400: BaudIndex := 6;
    4800: BaudIndex := 7;
    9600: BaudIndex := 8;
    ELSE BEGIN
      WriteLn(baud,' baud is unsupported');
      Halt;
    END;
  END;
END;

PROCEDURE SetTTY(baud: INTEGER);
CONST
  BIOSioinit = 18; { Ampro extended BIOS call to init I/O system }
  Mspeed = $3C;
  CTCA1 = 3;       { Offset of CTC count for channel 1 }
  SIOBR4 = 21;     { Offset of SIO channel B divisor register }
  CtcCount : ARRAY[1..8] OF BYTE = (208,139,208,176,104,52,26,13);
  SioDivisor : ARRAY[1..8] OF BYTE = ($80,$80,$40,$40,$40,$40,$40,$40);
VAR
  ioTable : INTEGER;
  index : BYTE;
BEGIN
  index := BaudIndex(baud);
  WriteLn(Aux,'AT$SB=',baud);
  Purge;
  ioTable := Mem[2] SHL 8 OR $40;
  Mem[ioTable+CTCA1] := CtcCount[index];
  Mem[ioTable+SIOBR4] := (Mem[ioTable+SIOBR4] AND $0F) OR SioDivisor[index];
  Bios(BIOSioinit);
  Mem[Mspeed] := index;
END;

CONST
  quietStr = 'ATE0Q1';
  attnStr = '+++';
  hangupStr = 'ATH';
  activeStr = 'ATE1Q0';
  IObyte = $0003;

BEGIN
  IF (Mem[IObyte] AND $03) = 0 THEN BEGIN
    Mem[IObyte] := Mem[IObyte] OR $01;
    Delay(1100);
    Write(Aux,attnStr);
    Delay(1100);
    Purge;
    Write(Aux, CR);
    Purge;
    Write(Aux, activeStr, CR);
    Purge;
    Write(Aux, hangupStr, CR);
    Purge;
  END ELSE BEGIN
    IF NOT IsOffline THEN BEGIN
      WriteLN('Serial port is busy.');
      HALT;
    END;
    SetTTY(9600);
    Write(Aux, quietStr, CR);
    Purge;
    Mem[IObyte] := (Mem[IObyte] AND $FC);
  END;
END.
