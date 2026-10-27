unit Http.Curl.Native;
{ ===========================================================================
  LOW-LEVEL LAYER - the only place that touches raw libcurl pointers.

  Contents
    1. Global library init/cleanup
    2. Callback contexts (plain Pascal objects handed to libcurl as void*)
    3. C callbacks (global cdecl functions - never let an exception escape)
    4. TCurlSlist  - owner of a  struct curl_slist *
    5. TCurlEasy   - owner of a  CURL *  with checked setopt/getinfo/perform

  Nothing above this unit knows about libcurl.
  =========================================================================== }
{$I Http.Defines.inc}
{$POINTERMATH ON}

interface

uses
  SysUtils, Classes, libcurl, Http.Errors, Http.Utils, Http.Headers;

type
  { `long` in C is 32 bit on Windows and 64 bit on LP64 Unix. Variadic
    arguments are passed by slot size, so NativeInt is correct everywhere:
    it is 4 bytes on Win32 and 8 bytes on Win64/Linux (the callee reads the
    low 32 bits on LLP64). }
  TCurlLong = NativeInt;

  { ---- 2. callback contexts ---- }

  { Receives the response body (CURLOPT_WRITEDATA). Writes to a TStream when
    one is supplied, otherwise grows an in-memory buffer geometrically. }
  TCurlBodySink = class
  private
    FStream: TStream;
    FBuffer: TBytes;
    FUsed: NativeInt;
    FTotal: Int64;
    FMaxBytes: Int64;
    FLimitExceeded: Boolean;
  public
    constructor Create(AStream: TStream; AMaxBytes: Int64);
    function Write(Data: Pointer; Len: NativeUInt): Boolean;
    function ToBytes: TBytes;
    property LimitExceeded: Boolean read FLimitExceeded;
    property TotalBytes: Int64 read FTotal;
  end;

  { Receives response header lines (CURLOPT_HEADERDATA). A new "HTTP/" status
    line (redirect hop, 100-continue, proxy CONNECT) resets the collection so
    that it always reflects the *final* response. }
  TCurlHeaderSink = class
  private
    FHeaders: THttpHeaders;
    FHttpVersion: string;
    FStatusCode: Integer;
    FReason: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProcessLine(const Line: string);
    procedure ProcessBytes(Data: Pointer; Len: NativeUInt);
    property Headers: THttpHeaders read FHeaders;
    property HttpVersion: string read FHttpVersion;
    property StatusCode: Integer read FStatusCode;
    property Reason: string read FReason;
  end;

  { Supplies the request body (CURLOPT_READDATA / SEEKDATA). }
  TCurlBodySource = class
  private
    FData: TBytes;
    FPos: NativeInt;
  public
    constructor Create(const AData: TBytes);
    function Read(Dest: Pointer; MaxLen: NativeUInt): NativeUInt;
    function Seek(Offset: Int64; Origin: Integer): Boolean;
  end;

  { ---- 4. slist ---- }
  TCurlSlist = class
  private
    FList: Pcurl_slist;
  public
    destructor Destroy; override;
    procedure Append(const S: string);
    property Handle: Pcurl_slist read FList;
  end;

  { ---- 5. easy handle ---- }
  TCurlEasy = class
  private
    FHandle: PCURL;
    FErrorBuffer: array[0..CURL_ERROR_SIZE] of AnsiChar;
    function GetErrorDetail: string;
  public
    constructor Create;
    destructor Destroy; override;
    { setopt wrappers - each one checks the CURLcode and raises ECurlError }
    procedure SetLong(Option: CURLoption; Value: TCurlLong);
    procedure SetBool(Option: CURLoption; Value: Boolean);
    procedure SetInt64(Option: CURLoption; Value: Int64);
    procedure SetStr(Option: CURLoption; const Value: string);
    procedure SetPtr(Option: CURLoption; Value: Pointer);
    { Returns the raw code so the caller can inspect sinks before raising. }
    function PerformRaw: CURLcode;
    procedure CheckResult(Code: CURLcode; const Operation: string);
    function InfoLong(Info: CURLINFO): TCurlLong;
    function InfoInt64(Info: CURLINFO): Int64;
    function InfoStr(Info: CURLINFO): string;
    property Handle: PCURL read FHandle;
  end;

{ ---- 3. C callbacks (exposed so tests can drive them directly) ---- }
function CurlWriteCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
function CurlHeaderCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
function CurlReadCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
function CurlSeekCallback(UserData: Pointer; Offset: curl_off_t;
  Origin: Integer): Integer; cdecl;

{ ---- helpers ---- }
procedure EnsureCurlInitialized;
function CurlVersionString: string;
function CStrToString(P: Pointer): string;

implementation

var
  GInitCode: CURLcode = CURLE_OK;
  GInitialized: Boolean = False;

{ ===== 1. global init ===== }

procedure EnsureCurlInitialized;
begin
  // curl_global_init is NOT thread safe, so it runs once from this unit's
  // initialization section (single-threaded at program start).
  if GInitCode <> CURLE_OK then
    raise ECurlError.Create(Ord(GInitCode), 'curl_global_init',
      CStrToString(curl_easy_strerror(GInitCode)));
end;

function CurlVersionString: string;
begin
  Result := CStrToString(curl_version());
end;

function CStrToString(P: Pointer): string;
var
  Len: Integer;
  B: TBytes;
begin
  Result := '';
  if P = nil then Exit;
  Len := 0;
  while PByte(PByte(P) + Len)^ <> 0 do
    Inc(Len);
  if Len = 0 then Exit;
  SetLength(B, Len);
  Move(P^, B[0], Len);
  Result := BytesToString(B);
end;

{ ===== 2. contexts ===== }

constructor TCurlBodySink.Create(AStream: TStream; AMaxBytes: Int64);
begin
  inherited Create;
  FStream := AStream;
  FMaxBytes := AMaxBytes;
end;

function TCurlBodySink.Write(Data: Pointer; Len: NativeUInt): Boolean;
var
  NewCap: NativeInt;
begin
  Result := False;
  if Len = 0 then
  begin
    Result := True;
    Exit;
  end;
  if (FMaxBytes > 0) and (FTotal + Int64(Len) > FMaxBytes) then
  begin
    FLimitExceeded := True;       // returning False aborts the transfer
    Exit;
  end;
  if FStream <> nil then
    FStream.WriteBuffer(Data^, Integer(Len))
  else
  begin
    if FUsed + NativeInt(Len) > Length(FBuffer) then
    begin
      NewCap := Length(FBuffer) * 2;
      if NewCap < FUsed + NativeInt(Len) then NewCap := FUsed + NativeInt(Len);
      if NewCap < 4096 then NewCap := 4096;
      SetLength(FBuffer, NewCap);
    end;
    Move(Data^, FBuffer[FUsed], Len);
    Inc(FUsed, Len);
  end;
  Inc(FTotal, Len);
  Result := True;
end;

function TCurlBodySink.ToBytes: TBytes;
begin
  SetLength(FBuffer, FUsed);     // trim spare capacity
  Result := FBuffer;
end;

constructor TCurlHeaderSink.Create;
begin
  inherited Create;
  FHeaders := THttpHeaders.Create;
end;

destructor TCurlHeaderSink.Destroy;
begin
  FHeaders.Free;
  inherited Destroy;
end;

procedure TCurlHeaderSink.ProcessLine(const Line: string);
var
  Ver, Why: string;
  Code: Integer;
begin
  if Line = '' then Exit;                       // blank line ends a header block
  if TryParseStatusLine(Line, Ver, Code, Why) then
  begin
    FHeaders.Clear;
    FHttpVersion := Ver;
    FStatusCode := Code;
    FReason := Why;
    Exit;
  end;
  FHeaders.TryAddLine(Line);
end;

procedure TCurlHeaderSink.ProcessBytes(Data: Pointer; Len: NativeUInt);
var
  B: TBytes;
  N: NativeInt;
begin
  N := NativeInt(Len);
  // strip trailing CR/LF
  while (N > 0) and ((PByte(Data)[N - 1] = 13) or (PByte(Data)[N - 1] = 10)) do
    Dec(N);
  if N = 0 then Exit;
  SetLength(B, N);
  Move(Data^, B[0], N);
  ProcessLine(BytesToString(B));
end;

constructor TCurlBodySource.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
end;

function TCurlBodySource.Read(Dest: Pointer; MaxLen: NativeUInt): NativeUInt;
var
  Avail: NativeInt;
begin
  Avail := Length(FData) - FPos;
  if Avail <= 0 then
    Result := 0
  else
  begin
    if NativeUInt(Avail) < MaxLen then
      Result := NativeUInt(Avail)
    else
      Result := MaxLen;
    Move(FData[FPos], Dest^, Result);
    Inc(FPos, Result);
  end;
end;

function TCurlBodySource.Seek(Offset: Int64; Origin: Integer): Boolean;
var
  NewPos: Int64;
begin
  case Origin of
    0: NewPos := Offset;                          // SEEK_SET
    1: NewPos := FPos + Offset;                   // SEEK_CUR
    2: NewPos := Length(FData) + Offset;          // SEEK_END
  else
    NewPos := -1;
  end;
  Result := (NewPos >= 0) and (NewPos <= Length(FData));
  if Result then FPos := NativeInt(NewPos);
end;

{ ===== 3. C callbacks =====
  Rules followed by every callback:
    * cdecl, plain global function (no Self, no closures)
    * UserData is a TObject reference cast to Pointer by the caller
    * an exception must NEVER cross the C boundary -> catch-all, then signal
      failure to libcurl through the documented return value }

function CurlWriteCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
var
  Total: NativeUInt;
begin
  Total := Size * NItems;
  Result := 0;                         // 0 (!= Total) => CURLE_WRITE_ERROR
  try
    if UserData = nil then Exit;
    if TCurlBodySink(UserData).Write(Buffer, Total) then
      Result := Total;
  except
    Result := 0;
  end;
end;

function CurlHeaderCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
var
  Total: NativeUInt;
begin
  Total := Size * NItems;
  Result := Total;
  try
    if (UserData <> nil) and (Total > 0) then
      TCurlHeaderSink(UserData).ProcessBytes(Buffer, Total);
  except
    Result := 0;
  end;
end;

function CurlReadCallback(Buffer: Pointer; Size, NItems: NativeUInt;
  UserData: Pointer): NativeUInt; cdecl;
begin
  Result := 0;                         // 0 = end of data
  try
    if UserData <> nil then
      Result := TCurlBodySource(UserData).Read(Buffer, Size * NItems);
  except
    Result := NativeUInt(CURL_READFUNC_ABORT);
  end;
end;

function CurlSeekCallback(UserData: Pointer; Offset: curl_off_t;
  Origin: Integer): Integer; cdecl;
begin
  Result := CURL_SEEKFUNC_FAIL;
  try
    if (UserData <> nil) and TCurlBodySource(UserData).Seek(Offset, Origin) then
      Result := CURL_SEEKFUNC_OK;
  except
    Result := CURL_SEEKFUNC_FAIL;
  end;
end;

{ ===== 4. slist ===== }

destructor TCurlSlist.Destroy;
begin
  if FList <> nil then
    curl_slist_free_all(FList);        // always releases the whole chain
  inherited Destroy;
end;

procedure TCurlSlist.Append(const S: string);
var
  U: UTF8String;
  NewList: Pcurl_slist;
begin
  U := UTF8Encode(S);
  NewList := curl_slist_append(FList, PAnsiChar(U));
  if NewList = nil then
    raise ECurlError.Create(Ord(CURLE_OUT_OF_MEMORY), 'curl_slist_append',
      'out of memory');
  FList := NewList;
end;

{ ===== 5. easy handle ===== }

constructor TCurlEasy.Create;
begin
  inherited Create;
  EnsureCurlInitialized;
  FHandle := curl_easy_init();
  if FHandle = nil then
    raise ECurlError.Create(Ord(CURLE_FAILED_INIT), 'curl_easy_init',
      'curl_easy_init returned NULL');
  FErrorBuffer[0] := #0;
  SetPtr(CURLOPT_ERRORBUFFER, @FErrorBuffer[0]);
end;

destructor TCurlEasy.Destroy;
begin
  if FHandle <> nil then
    curl_easy_cleanup(FHandle);
  FHandle := nil;
  inherited Destroy;
end;

function TCurlEasy.GetErrorDetail: string;
begin
  FErrorBuffer[CURL_ERROR_SIZE] := #0;
  Result := CStrToString(@FErrorBuffer[0]);
end;

procedure TCurlEasy.CheckResult(Code: CURLcode; const Operation: string);
begin
  if Code <> CURLE_OK then
    raise ECurlError.Create(Ord(Code), Operation,
      CStrToString(curl_easy_strerror(Code)), GetErrorDetail);
end;

procedure TCurlEasy.SetLong(Option: CURLoption; Value: TCurlLong);
begin
  CheckResult(curl_easy_setopt(FHandle, Option, Value), 'curl_easy_setopt');
end;

procedure TCurlEasy.SetBool(Option: CURLoption; Value: Boolean);
begin
  if Value then SetLong(Option, 1) else SetLong(Option, 0);
end;

procedure TCurlEasy.SetInt64(Option: CURLoption; Value: Int64);
begin
  CheckResult(curl_easy_setopt(FHandle, Option, Value), 'curl_easy_setopt');
end;

procedure TCurlEasy.SetStr(Option: CURLoption; const Value: string);
var
  U: UTF8String;
begin
  U := UTF8Encode(Value);              // libcurl copies string options
  CheckResult(curl_easy_setopt(FHandle, Option, PAnsiChar(U)), 'curl_easy_setopt');
end;

procedure TCurlEasy.SetPtr(Option: CURLoption; Value: Pointer);
begin
  CheckResult(curl_easy_setopt(FHandle, Option, Value), 'curl_easy_setopt');
end;

function TCurlEasy.PerformRaw: CURLcode;
begin
  FErrorBuffer[0] := #0;
  Result := curl_easy_perform(FHandle);
end;

function TCurlEasy.InfoLong(Info: CURLINFO): TCurlLong;
var
  V: TCurlLong;
begin
  V := 0;                              // C `long` may be narrower than TCurlLong
  CheckResult(curl_easy_getinfo(FHandle, Info, @V), 'curl_easy_getinfo');
  {$IFDEF MSWINDOWS}
  Result := LongInt(V);                // LLP64: only the low 32 bits are written
  {$ELSE}
  Result := V;
  {$ENDIF}
end;

function TCurlEasy.InfoInt64(Info: CURLINFO): Int64;
var
  V: Int64;
begin
  V := 0;
  CheckResult(curl_easy_getinfo(FHandle, Info, @V), 'curl_easy_getinfo');
  Result := V;
end;

function TCurlEasy.InfoStr(Info: CURLINFO): string;
var
  P: PAnsiChar;
begin
  P := nil;
  CheckResult(curl_easy_getinfo(FHandle, Info, @P), 'curl_easy_getinfo');
  Result := CStrToString(P);           // owned by libcurl; copied immediately
end;

initialization
  GInitCode := curl_global_init(CURL_GLOBAL_DEFAULT);
  GInitialized := GInitCode = CURLE_OK;

finalization
  if GInitialized then
    curl_global_cleanup();

end.
