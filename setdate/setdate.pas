{$C+}
{
  SETDATE: Sets the BIOS clock from the Retro Wifi Modem (using ATRT to
  query the NIST time. Defaults to Mountain time zone (UTC - 7), but
  the hour offset can be overridden on the command line. Minimally DST
  aware (US/Canada rules as of 2021) but doesn't account for places like
  Saskatchewan when it's standard time all year round; it suits my
  simple needs and that's good enough for me!

  V1.0 2021/??/?? initial version
  V1.1 2021/11/19 added date display when successfully set
  V1.2 2023/04/18 added retries
}
PROGRAM SetDate;

CONST
  getString = 'ATRT'; { Retro Wifi modem query NIST date/time string}
  CR = #$0D;
  LF = #$0A;
  dim : ARRAY[1..12] OF BYTE = (31,28,31,30,31,30,31,31,30,31,30,31);
  BDOSsetTime = 201;
  timeZoneOffset = 6;

TYPE
  DateBlockType = RECORD   { NovaDOS/ZRDOS date/time block }
    Julian : INTEGER;
    HourBCD : BYTE;
    MinBCD : BYTE;
    SecBCD : BYTE;
  END;

{$I MDMINRDY}
{$I OFFLINE }

{ return True if leap year: minimal implementation for 20xx }
FUNCTION LeapYear(y : INTEGER) : BOOLEAN;
BEGIN
  LeapYear := ((y MOD 4) = 0) AND (y<>100);
END;

{ convert two ASCII digits to binary number }
FUNCTION DigitsToDec(d1, d2 : CHAR) : BYTE;
BEGIN
  DigitsToDec := 10*(Ord(d1) - $30) + Ord(d2) - $30;
END;

{ convert two ASCII digits to VCD number }
FUNCTION DigitsToBcd(d1, d2 : CHAR) : BYTE;
BEGIN
  DigitsToBcd := 16*(Ord(d1) - $30) + Ord(d2) - $30;
END;

{ convert year/month/day of month to Julian date where day 1 is 1978/1/1 }
FUNCTION ToJulian(year,month,dom : INTEGER) : INTEGER;
CONST
  dim : ARRAY[1..12] OF BYTE = (31,28,31,30,31,30,31,31,30,31,30,31);
VAR
  i,julian : INTEGER;
BEGIN
  i := 0;
  julian := 8035;              { # days between 1978/1/1 and 2000/1/1 }
  WHILE i<year DO BEGIN
    julian := julian + 365;
    IF LeapYear(i) THEN
      julian := Succ(julian);
    i := Succ(i);
  END;
  i := 1;
  WHILE i<month DO BEGIN
    julian := julian + dim[i];
    IF i=2 THEN
      IF LeapYear(year) THEN
        julian := Succ(julian);
    i := Succ(i);
  END;
  ToJulian := julian + dom;
END;

{
  convert to local time using time zone and accounting for DST
  minimal implementation: doesn't account for fractional hours (hi there
  Newfoundland!) or "on standard or daylight time year round (hi there
  Saskatchewan!): US/Canada rules
}
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
    dom := Pred(dom);
    julian := Pred(julian);
    IF dom = 0 THEN BEGIN
      month := Pred(month);
      IF month = 0 THEN BEGIN
        month := 12;
        year := Pred(year);
      END;
      dom := dim[month];
    END;
  END ELSE IF hour >= 24 THEN BEGIN
    hour := hour - 24;
    dom := Succ(dom);
    julian := Succ(julian);
    IF dom > dim[month] THEN BEGIN
      month := Succ(month);
      IF month > 12 THEN BEGIN
        month := 1;
        year := Succ(year);
      END;
      dom := 1;
    END;
  END;
  ToLocal := julian;
END;

{ Connect to NIST and see if it will return the current }
{ Zulu (UTC) time. If we get a valid time string, set   }
{ the system time and return TRUE. If we get a timeout  }
{ or error, return FALSE so the main can try again if   }
{ it wants to.                                          }
FUNCTION TrySetDate(zoneOffset : INTEGER) : BOOLEAN;
CONST
  monthNames : ARRAY[1..12] OF STRING[3] = (
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  );
  dowNames : ARRAY[0..6] OF STRING[3] = (
    'Sat','Sun','Mon','Tue','Wed','Thu','Fri'
  );
VAR
  year,month,dom,hour,minute,second,timeOut,tries : INTEGER;
  code : INTEGER;
  date : DateBlockType;
  dateSet : BOOLEAN;
  ch : CHAR;
  line : STRING[255];
BEGIN
  Write(Aux, getString);
  Write(Aux, CR);
  line := '';
  timeOut := 0;
  dateSet := FALSE;
  REPEAT
    WHILE NOT dateSet AND ModemInReady DO BEGIN
      timeOut := 0;
      Read(Aux, ch);
      IF ch = CR THEN BEGIN
        { WriteLn('[',line,']'); }
        IF Length(line)=17 THEN BEGIN
          IF (line[1]>='0') AND (line[1]<='9') THEN BEGIN
            { fetch NIST data }
            year := DigitsToDec(line[1],line[2]);
            month := DigitsToDec(line[4],line[5]);
            dom := DigitsToDec(line[7],line[8]);
            hour := DigitsToDec(line[10],line[11]);
            minute := DigitsToDec(line[13],line[14]);
            second := DigitsToDec(line[16],line[17]);
            { set up NovaDOS/ZRDOS time block and set time }
            date.Julian := ToLocal(year,month,dom,hour,minute,second,zoneOffset);
            date.HourBCD := 16 * (hour DIV 10) + (hour MOD 10);
            date.MinBCD := 16 * (minute DIV 10) + (minute MOD 10);
            date.SecBCD := 16 * (second DIV 10) + (second MOD 10);
            BDOS(BDOSsetTime,Addr(date));
            dateSet := TRUE;
            { display current time }
            Write(
              dowNames[date.Julian MOD 7],' ',
              monthNames[month],'-',
              dom:2,'-20',year,' ');
            IF hour<10 THEN
              Write('0');
            Write(hour,':');
            IF minute<10 THEN
              Write('0');
            Write(minute,':');
            IF second<10 THEN
              Write('0');
            WriteLN(second);
          END;
        END ELSE IF line = 'ERROR' THEN BEGIN
          timeOut := 5000;
        END;
        line := '';
      END ELSE IF ch <> LF THEN
        line := line + ch;
    END;
    Delay(1);
    timeOut := Succ(timeOut);
  UNTIL dateSet OR (timeOut > 5000);
  TrySetDate := dateSet;
END;

VAR
  tries, zoneOffset, code : INTEGER;
  ch : CHAR;
  dateSet : BOOLEAN;

BEGIN
  IF ParamCount > 0 THEN
    Val(ParamStr(1),zoneOffset,code)
  ELSE
    zoneOffset := -7;               { default to Mountain time zone }
  dateSet := FALSE;
  tries := 0;

  IF NOT IsOffline THEN BEGIN
    WriteLN('Serial port is busy.');
    HALT;
  END;

  WHILE NOT dateSet AND (tries < 5) DO BEGIN
    dateSet := TrySetDate(zoneOffset);
    IF NOT dateSet THEN BEGIN
      tries := Succ(tries);
      Delay(3000);
    END;
  END;
  IF NOT dateSet THEN
    WriteLN('Date not set');
  WHILE ModemInReady DO BEGIN
    Read(Aux, ch);
    Delay(1);
  END;
END.
