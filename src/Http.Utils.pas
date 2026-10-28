unit Http.Utils;
{ Pure Pascal helpers: no libcurl dependency. }
{$I Http.Defines.inc}

interface

uses
  SysUtils;

type
  THttpStringArray = array of string;

  TUrlParts = record
    Scheme: string;   // lower-case, e.g. 'https'
    Host: string;     // lower-case, without brackets/userinfo
    Port: Integer;    // explicit port or scheme default (0 if unknown)
    Path: string;     // always starts with '/'
    Query: string;    // without '?'
  end;

{ ASCII-only (locale independent) case handling }
function AsciiLower(const S: string): string;
function AsciiSameText(const A, B: string): Boolean;

{ String <-> bytes (UTF-8) }
function StringToBytes(const S: string): TBytes;
function BytesToString(const B: TBytes): string;
function Latin1ToString(const B: TBytes): string;

{ Encoding }
function UrlEncode(const S: string): string;
function UrlDecode(const S: string; PlusAsSpace: Boolean = False): string;
function Base64Encode(const Data: TBytes): string;
function Base64EncodeString(const S: string): string;

{ URL helpers }
function TryParseUrl(const Url: string; out Parts: TUrlParts): Boolean;
function CombineUrl(const BaseUrl, Relative: string): string;
function AppendQueryParam(const Url, Name, Value: string): string;

{ Directory for temporary files, always WITH a trailing path delimiter.
  Portable replacement for FPC's GetTempDir (which Delphi lacks). }
function GetTempDirectory: string;

{ HTTP parsing }
function TryParseStatusLine(const Line: string; out HttpVersion: string;
  out Code: Integer; out Reason: string): Boolean;
function TryParseHttpDate(const S: string; out UtcValue: TDateTime): Boolean;
function NowUtc: TDateTime;
{ MIME type from a file name's extension; 'application/octet-stream' if unknown. }
function GuessContentType(const FileName: string): string;
function ParseIntDef(const S: string; DefaultValue: Integer): Integer;

implementation

uses
  {$IFDEF FPC}DateUtils{$ELSE}System.DateUtils, System.IOUtils{$ENDIF};

const
  HexChars = '0123456789ABCDEF';
  B64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  MonthNames: array[1..12] of string =
    ('jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec');

function ParseIntDef(const S: string; DefaultValue: Integer): Integer;
var
  I: Integer;
  Acc: Int64;
  Neg: Boolean;
begin
  Result := DefaultValue;
  I := 1;
  Neg := False;
  if (S <> '') and ((S[1] = '-') or (S[1] = '+')) then
  begin
    Neg := S[1] = '-';
    Inc(I);
  end;
  if I > Length(S) then Exit;
  Acc := 0;
  while I <= Length(S) do
  begin
    if (S[I] < '0') or (S[I] > '9') then Exit;
    Acc := Acc * 10 + (Ord(S[I]) - Ord('0'));
    if Acc > High(Integer) then Exit;
    Inc(I);
  end;
  if Neg then Acc := -Acc;
  Result := Integer(Acc);
end;

function AsciiLower(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Result[I] := Char(Ord(Result[I]) + 32);
end;

function AsciiSameText(const A, B: string): Boolean;
begin
  Result := (Length(A) = Length(B)) and (AsciiLower(A) = AsciiLower(B));
end;

function StringToBytes(const S: string): TBytes;
var
  U: RawByteString;
begin
  // NOTE: UTF8Encode is used instead of TEncoding.UTF8, whose UnicodeString
  // overloads misbehave in FPC 3.2.2.
  U := UTF8Encode(S);
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[0], Length(U));
end;

function BytesToString(const B: TBytes): string;
var
  U: RawByteString;
begin
  if Length(B) = 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(U, Length(B));
  Move(B[0], U[1], Length(B));
  SetCodePage(U, CP_UTF8, False);
  {$IFDEF FPC}
  Result := UTF8Decode(U);
  {$ELSE}
  Result := UTF8ToString(U);
  {$ENDIF}
end;

function Latin1ToString(const B: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(B));
  for I := 0 to High(B) do
    Result[I + 1] := Char(B[I]);
end;

function IsUnreserved(C: Byte): Boolean;
begin
  Result := ((C >= Ord('A')) and (C <= Ord('Z'))) or
            ((C >= Ord('a')) and (C <= Ord('z'))) or
            ((C >= Ord('0')) and (C <= Ord('9'))) or
            (C = Ord('-')) or (C = Ord('.')) or (C = Ord('_')) or (C = Ord('~'));
end;

function UrlEncode(const S: string): string;
var
  B: TBytes;
  I, N: Integer;
begin
  B := StringToBytes(S);
  SetLength(Result, Length(B) * 3);
  N := 0;
  for I := 0 to High(B) do
    if IsUnreserved(B[I]) then
    begin
      Inc(N);
      Result[N] := Char(B[I]);
    end
    else
    begin
      Result[N + 1] := '%';
      Result[N + 2] := HexChars[(B[I] shr 4) + 1];
      Result[N + 3] := HexChars[(B[I] and $0F) + 1];
      Inc(N, 3);
    end;
  SetLength(Result, N);
end;

function HexVal(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function UrlDecode(const S: string; PlusAsSpace: Boolean): string;
var
  B, Lit: TBytes;
  I, N, H, L: Integer;
begin
  SetLength(B, Length(S) * 4); // worst case: every char is a 4-byte sequence
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I + 2 <= Length(S)) then
    begin
      H := HexVal(S[I + 1]);
      L := HexVal(S[I + 2]);
      if (H >= 0) and (L >= 0) then
      begin
        B[N] := Byte(H * 16 + L);
        Inc(N);
        Inc(I, 3);
        Continue;
      end;
    end;
    if PlusAsSpace and (S[I] = '+') then
    begin
      B[N] := 32;
      Inc(N);
    end
    else if Ord(S[I]) < 128 then
    begin
      B[N] := Byte(Ord(S[I]));
      Inc(N);
    end
    else
    begin
      Lit := StringToBytes(S[I]); // literal non-ASCII char: keep as UTF-8
      if Length(Lit) > 0 then
        Move(Lit[0], B[N], Length(Lit));
      Inc(N, Length(Lit));
    end;
    Inc(I);
  end;
  SetLength(B, N);
  Result := BytesToString(B);
end;

function Base64Encode(const Data: TBytes): string;
var
  I, N, Len: Integer;
  A, B, C: Byte;
begin
  Len := Length(Data);
  SetLength(Result, ((Len + 2) div 3) * 4);
  N := 0;
  I := 0;
  while I < Len do
  begin
    A := Data[I];
    if I + 1 < Len then B := Data[I + 1] else B := 0;
    if I + 2 < Len then C := Data[I + 2] else C := 0;
    Result[N + 1] := B64Chars[(A shr 2) + 1];
    Result[N + 2] := B64Chars[(((A and 3) shl 4) or (B shr 4)) + 1];
    if I + 1 < Len then
      Result[N + 3] := B64Chars[(((B and 15) shl 2) or (C shr 6)) + 1]
    else
      Result[N + 3] := '=';
    if I + 2 < Len then
      Result[N + 4] := B64Chars[(C and 63) + 1]
    else
      Result[N + 4] := '=';
    Inc(N, 4);
    Inc(I, 3);
  end;
end;

function Base64EncodeString(const S: string): string;
begin
  Result := Base64Encode(StringToBytes(S));
end;

function TryParseUrl(const Url: string; out Parts: TUrlParts): Boolean;
var
  P, E, At, Colon: Integer;
  Rest, Auth, HostPort: string;
begin
  Result := False;
  Parts.Scheme := '';
  Parts.Host := '';
  Parts.Port := 0;
  Parts.Path := '/';
  Parts.Query := '';

  P := Pos('://', Url);
  if P < 2 then Exit;
  Parts.Scheme := AsciiLower(Copy(Url, 1, P - 1));
  Rest := Copy(Url, P + 3, MaxInt);

  P := Pos('#', Rest);               // drop fragment
  if P > 0 then Rest := Copy(Rest, 1, P - 1);

  E := 1;
  while (E <= Length(Rest)) and (Rest[E] <> '/') and (Rest[E] <> '?') do Inc(E);
  Auth := Copy(Rest, 1, E - 1);
  Rest := Copy(Rest, E, MaxInt);

  P := Pos('?', Rest);
  if P > 0 then
  begin
    Parts.Query := Copy(Rest, P + 1, MaxInt);
    Rest := Copy(Rest, 1, P - 1);
  end;
  if Rest <> '' then Parts.Path := Rest;

  At := 0;
  for P := Length(Auth) downto 1 do
    if Auth[P] = '@' then
    begin
      At := P;
      Break;
    end;
  HostPort := Copy(Auth, At + 1, MaxInt);

  Colon := 0;
  if (HostPort <> '') and (HostPort[1] = '[') then
  begin
    E := Pos(']', HostPort);
    if E = 0 then Exit;
    Parts.Host := Copy(HostPort, 2, E - 2);
    HostPort := Copy(HostPort, E + 1, MaxInt);   // ":8080" or ""
    if (HostPort <> '') and (HostPort[1] = ':') then Colon := 1;
  end
  else
  begin
    P := Pos(':', HostPort);
    if P > 0 then
    begin
      Parts.Host := Copy(HostPort, 1, P - 1);
      HostPort := Copy(HostPort, P, MaxInt);     // ":8080"
      Colon := 1;
    end
    else
      Parts.Host := HostPort;
  end;
  Parts.Host := AsciiLower(Parts.Host);
  if Parts.Host = '' then Exit;

  if Parts.Scheme = 'http' then
    Parts.Port := 80
  else if Parts.Scheme = 'https' then
    Parts.Port := 443;
  if (Colon > 0) and (Length(HostPort) > 1) then
    Parts.Port := ParseIntDef(Copy(HostPort, 2, MaxInt), Parts.Port);
  Result := True;
end;

function CombineUrl(const BaseUrl, Relative: string): string;
var
  B, R: string;
begin
  if (BaseUrl = '') or (Pos('://', Relative) > 0) then
  begin
    Result := Relative;
    Exit;
  end;
  B := BaseUrl;
  while (B <> '') and (B[Length(B)] = '/') do
    SetLength(B, Length(B) - 1);
  R := Relative;
  if (R <> '') and ((R[1] = '?') or (R[1] = '#')) then
  begin
    Result := B + R;
    Exit;
  end;
  while (R <> '') and (R[1] = '/') do
    Delete(R, 1, 1);
  if R = '' then
    Result := B
  else
    Result := B + '/' + R;
end;

function AppendQueryParam(const Url, Name, Value: string): string;
var
  Sep: string;
begin
  if Pos('?', Url) = 0 then
    Sep := '?'
  else if (Url[Length(Url)] = '?') or (Url[Length(Url)] = '&') then
    Sep := ''
  else
    Sep := '&';
  Result := Url + Sep + UrlEncode(Name) + '=' + UrlEncode(Value);
end;

function TryParseStatusLine(const Line: string; out HttpVersion: string;
  out Code: Integer; out Reason: string): Boolean;
var
  S: string;
  P: Integer;
begin
  Result := False;
  HttpVersion := '';
  Code := 0;
  Reason := '';
  if Copy(Line, 1, 5) <> 'HTTP/' then Exit;
  S := Copy(Line, 6, MaxInt);
  P := Pos(' ', S);
  if P = 0 then Exit;
  HttpVersion := Copy(S, 1, P - 1);
  S := Trim(Copy(S, P + 1, MaxInt));
  P := Pos(' ', S);
  if P = 0 then
    Code := ParseIntDef(S, 0)           // HTTP/2 has no reason phrase
  else
  begin
    Code := ParseIntDef(Copy(S, 1, P - 1), 0);
    Reason := Trim(Copy(S, P + 1, MaxInt));
  end;
  Result := Code > 0;
end;

{ Parses "Sun, 06 Nov 1994 08:49:37 GMT" and the dashed cookie variant
  "Sunday, 06-Nov-94 08:49:37 GMT". Result is UTC. }
function TryParseHttpDate(const S: string; out UtcValue: TDateTime): Boolean;
var
  Tokens: array of string;
  Cur, T: string;
  I, M, Day, Mon, Year, H, Mi, Sec, P1, P2: Integer;
begin
  Result := False;
  UtcValue := 0;
  SetLength(Tokens, 0);
  Cur := '';
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = ' ') or (S[I] = ',') or (S[I] = '-') then
    begin
      if Cur <> '' then
      begin
        SetLength(Tokens, Length(Tokens) + 1);
        Tokens[High(Tokens)] := Cur;
        Cur := '';
      end;
    end
    else
      Cur := Cur + S[I];

  Day := 0; Mon := 0; Year := 0; H := -1; Mi := -1; Sec := -1;
  for I := 0 to High(Tokens) do
  begin
    T := Tokens[I];
    if Pos(':', T) > 0 then
    begin
      P1 := Pos(':', T);
      P2 := Pos(':', Copy(T, P1 + 1, MaxInt));
      if P2 = 0 then Exit;
      P2 := P2 + P1;
      H := ParseIntDef(Copy(T, 1, P1 - 1), -1);
      Mi := ParseIntDef(Copy(T, P1 + 1, P2 - P1 - 1), -1);
      Sec := ParseIntDef(Copy(T, P2 + 1, MaxInt), -1);
    end
    else if (Mon = 0) and (Length(T) >= 3) and (ParseIntDef(T, -1) < 0) then
    begin
      for M := 1 to 12 do
        if AsciiLower(Copy(T, 1, 3)) = MonthNames[M] then
        begin
          Mon := M;
          Break;
        end;
    end
    else if (Day = 0) and (Mon = 0) and (ParseIntDef(T, -1) > 0) then
      Day := ParseIntDef(T, 0)
    else if (Day > 0) and (Mon > 0) and (Year = 0) and (ParseIntDef(T, -1) >= 0) then
    begin
      Year := ParseIntDef(T, 0);
      if Length(T) <= 2 then
      begin
        if Year < 70 then Inc(Year, 2000) else Inc(Year, 1900);
      end;
    end;
  end;
  if (Day < 1) or (Day > 31) or (Mon = 0) or (Year = 0) or
     (H < 0) or (H > 23) or (Mi < 0) or (Mi > 59) or (Sec < 0) or (Sec > 59) then
    Exit;
  try
    UtcValue := EncodeDate(Year, Mon, Day) + EncodeTime(H, Mi, Sec, 0);
    Result := True;
  except
    on EConvertError do
      Result := False;
  end;
end;

function GuessContentType(const FileName: string): string;
const
  Known: array[0..27, 0..1] of string = (
    ('txt', 'text/plain'), ('csv', 'text/csv'), ('html', 'text/html'),
    ('htm', 'text/html'), ('css', 'text/css'), ('js', 'text/javascript'),
    ('json', 'application/json'), ('xml', 'application/xml'),
    ('pdf', 'application/pdf'), ('zip', 'application/zip'),
    ('gz', 'application/gzip'), ('tar', 'application/x-tar'),
    ('png', 'image/png'), ('jpg', 'image/jpeg'), ('jpeg', 'image/jpeg'),
    ('gif', 'image/gif'), ('bmp', 'image/bmp'), ('webp', 'image/webp'),
    ('svg', 'image/svg+xml'), ('ico', 'image/x-icon'),
    ('mp3', 'audio/mpeg'), ('wav', 'audio/wav'), ('mp4', 'video/mp4'),
    ('doc', 'application/msword'),
    ('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
    ('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    ('md', 'text/markdown'), ('log', 'text/plain'));
var
  Ext: string;
  I: Integer;
begin
  Ext := AsciiLower(ExtractFileExt(FileName));
  if (Ext <> '') and (Ext[1] = '.') then Delete(Ext, 1, 1);
  for I := Low(Known) to High(Known) do
    if Known[I, 0] = Ext then
    begin
      Result := Known[I, 1];
      Exit;
    end;
  Result := 'application/octet-stream';
end;

function GetTempDirectory: string;
begin
  {$IFDEF FPC}
  Result := GetTempDir;                 // SysUtils (FPC)
  {$ELSE}
  Result := TPath.GetTempPath;          // System.IOUtils (Delphi)
  {$ENDIF}
  if Result = '' then
    Result := GetCurrentDir;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function NowUtc: TDateTime;
begin
  {$IFDEF FPC}
  Result := LocalTimeToUniversal(Now);
  {$ELSE}
  Result := TTimeZone.Local.ToUniversalTime(Now);
  {$ENDIF}
end;

end.
