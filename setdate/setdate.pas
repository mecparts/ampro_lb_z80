{$C+}
{
  SETDATE: Sets the BIOS clock from the Retro Wifi Modem (using ATRT to
  query the NIST time. Defaults to Mountain time zone (UTC - 7), but
  the hour offset can be overridden on the command line. Minimally DST
  aware (US/Canada rules as of 2021) but doesn't account for places like
  Saskatchewan when it's standard time all year round; it suits my
  simple needs and that's good enough for me!

  V1.0 2021/??/?? initial version
}
PROGRAM SetDate;

CONST
  getString = 'ATRT';
  CR = #$0D;
  LF = #$0A;
  dim : ARRAY[1..12] OF BYTE = (31,28,31,30,31,30,31,31,30,31,30,31);
  BDOSsetTime = 201;
  timeZoneOffset = 6;

TYPE
  DateBlockType = RECORD
    Julian : INTEGER;
    HourBCD : BYTE;
    MinBCD : BYTE;
    SecBCD : BYTE;
  END;

{$I MDMINRDY}
{$I OFFLINE }

FUNCTION LeapYear(y : INTEGER) : BOOLEAN;
BEGIN
  LeapYear := ((y MOD 4) = 0) AND (y<>100);
END;

FUNCTION DigitsToDec(d1, d2 : CHAR) : BYTE;
BEGIN
  DigitsToDec := 10*(Ord(d1) - $30) + Ord(d2) - $30;
END;

FUNCTION DigitsToBcd(d1, d2 : CHAR) : BYTE;
BEGIN
  DigitsToBcd := 16*(Ord(d1) - $30) + Ord(d2) - $30;
END;

FUNCTION ToJulian(year,month,dom : INTEGER) : INTEGER;
CONST
  dim : ARRAY[1..12] OF BYTE = (31,28,31,30,31,30,31,31,30,31,30,31);
VAR
  i,julian : INTEGER;
BEGIN
  i := 0;
  julian := 8035;
  WHILE i<year DO BEGIN
    julian := julian + 365;
    IF LeapYear(i) THEN
      julian := julian + 1;
    i := i + 1;
  END;
  i := 1;
  WHILE i<month DO BEGIN
    julian := julian + dim[i];
    IF i=2 THEN
      IF LeapYear(year) THEN
        julian := julian + 1;
    i := i + 1;
  END;
  ToJulian := julian + dom;
END;

FUNCTION ToLocal(VAR year,month,dom,hour,minute,second,zoneOffset : INTEGER) : INTEGER;
CONST
  dim : ARRAY[1..12] OF BYTE = (31,28,31,30,31,30,31,31,30,31,30,31);
  Sunday: ARRAY[0..6] OF BYTE = (1,7,6,5,4,3,2);

VAR
  dow,julian,dstOffset,firstOfMonth,firstSunday,secondSunday : INTEGER;

BEGIN
  julian := ToJulian(year,month,dom);
  firstOfMonth := (julian - dom) MOD 7;
  firstSunday := Sunday[firstOfMonth];
  secondSunday := firstSunday + 7;
  dow := (julian-1) MOD 7; { 0=Sun, 1=Mon,... 6=Sat }
  IF ((month = 3) AND (dom=secondSunday) AND (hour>=-zoneOffset+2))
    OR ((month = 3) AND (dom>secondSunday))
    OR ((month > 3) AND (month<11))
    OR ((month = 11) AND (dom<firstSunday)
    OR ((month = 11) AND (dom=firstSunday) AND (hour<-zoneOffset+1))) THEN BEGIN
    { Daylight Saving }
    dstOffset := 1;
  END ELSE BEGIN
    { Standard time }
    dstOffset := 0;
  END;
  hour := hour + zoneoffset + dstOffset;
  IF hour < 0 THEN BEGIN
    hour := hour + 24;
    dom := dom - 1;
    julian := julian - 1;
    IF dom = 0 THEN BEGIN
      month := month - 1;
      IF month = 0 THEN BEGIN
        month := 12;
        year := year - 1;
      END;
      dom := dim[month];
    END;
  END ELSE IF hour >= 24 THEN BEGIN
    hour := hour - 24;
    dom := dom + 1;
    julian := julian + 1;
    IF dom > dim[month] THEN BEGIN
      month := month + 1;
      IF month > 12 THEN BEGIN
        month := 1;
        year := year + 1;
      END;
      dom := 1;
    END;
  END;
  ToLocal := julian;
END;

VAR
  year,month,dom,hour,minute,second,timeOut : INTEGER;
  zoneOffset,code : INTEGER;
  date : DateBlockType;
  ch : CHAR;
  line : STRING[255];
  dateSet : BOOLEAN;

BEGIN
  IF ParamCount > 0 THEN
    Val(ParamStr(1),zoneOffset,code)
  ELSE
    zoneOffset := -7;
  line := '';
  dateSet := FALSE;
  timeOut := 0;

  IF NOT IsOffline THEN BEGIN
    WriteLN('Serial port is busy.');
    HALT;
  END;

  Write(Aux, getString);
  Write(Aux, CR);

  REPEAT
    WHILE ModemInReady DO BEGIN
      timeOut := 0;
      Read(Aux, ch);
      IF ch = CR THEN BEGIN
        IF Length(line)=17 THEN BEGIN
          IF (line[1]>='0') AND (line[1]<='9') THEN BEGIN
            year := DigitsToDec(line[1],line[2]);
            month := DigitsToDec(line[4],line[5]);
            dom := DigitsToDec(line[7],line[8]);
            hour := DigitsToDec(line[10],line[11]);
            minute := DigitsToDec(line[13],line[14]);
            second := DigitsToDec(line[16],line[17]);
            date.Julian := ToLocal(year,month,dom,hour,minute,second,zoneOffset);
            date.HourBCD := 16 * (hour DIV 10) + (hour MOD 10);
            date.MinBCD := 16 * (minute DIV 10) + (minute MOD 10);
            date.SecBCD := 16 * (second DIV 10) + (second MOD 10);
            BDOS(BDOSsetTime,Addr(date));
            dateSet := TRUE;
          END;
        END;
        line := '';
      END ELSE IF ch <> LF THEN
        line := line + ch;
    END;
    Delay(1);
    timeOut := Succ(timeOut);
  UNTIL dateSet OR (timeOut > 5000);

  WHILE ModemInReady DO BEGIN
    Read(Aux, ch);
    Delay(1);
  END;
END.

