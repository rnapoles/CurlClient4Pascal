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
  SysUtils, Classes, libcurl, Http.Errors, Http.Utils, Http.Headers, Http.Logging;

type
  TCurlEasy = class;

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

  { Receives libcurl's verbose trace (CURLOPT_DEBUGDATA) and forwards it to an
    IHttpLogger instead of stderr. Informational text ('* '), request headers
    ('> ') and response headers ('< ') are logged line by line at debug level,
    category 'curl'. Body data is NOT logged (can be huge or binary). With
    Redact set, values of sensitive headers (Authorization, Cookie, ...) are
    replaced by ***. }
  TCurlDebugSink = class
  private
    FLogger: IHttpLogger;
    FRedact: Boolean;
  public
    constructor Create(const ALogger: IHttpLogger; ARedact: Boolean);
    procedure Process(InfoType: Integer; Data: Pointer; Size: NativeUInt);
  end;

  { Supplies upload data (CURLOPT_READDATA / SEEKDATA, or a MIME part):
    either an in-memory buffer or a TStream, read from its position at
    creation time to its end. }
  TCurlBodySource = class
  private
    FData: TBytes;
    FStream: TStream;
    FOwnsStream: Boolean;
    FStart: Int64;
    FSize: Int64;
    FPos: Int64;
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AStream: TStream; AOwnsStream: Boolean); overload;
    destructor Destroy; override;
    function Read(Dest: Pointer; MaxLen: NativeUInt): NativeUInt;
    function Seek(Offset: Int64; Origin: Integer): Boolean;
    property Size: Int64 read FSize;
  end;

  { Owns a  curl_mime *  (multipart/form-data) plus every file stream that
    feeds its parts. Create AFTER the easy handle, free BEFORE it. }
  TCurlMime = class
  private
    FMime: Pcurl_mime;
    FSources: array of TCurlBodySource;
    function NewPart(const Name: string): Pcurl_mimepart;
    procedure SetPartStr(Part: Pcurl_mimepart; Kind: Integer; const Value: string);
    procedure AddSource(const Name, FileName, ContentType: string; Source: TCurlBodySource);
  public
    constructor Create(Easy: TCurlEasy);
    destructor Destroy; override;
    procedure AddField(const Name, Value: string);
    procedure AddFile(const Name, FilePath, FileName, ContentType: string);
    procedure AddBytes(const Name, FileName: string; const Data: TBytes;
      const ContentType: string);
    { AStream is NOT owned: its position is restored when the mime is freed. }
    procedure AddStream(const Name, FileName: string; AStream: TStream;
      const ContentType: string);
    property Handle: Pcurl_mime read FMime;
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
    { Like SetLong but returns the raw CURLcode instead of raising, for options
      whose support depends on how libcurl was built. }
    function TrySetLong(Option: CURLoption; Value: TCurlLong): CURLcode;
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
{ curl_debug_callback; InfoType is a curl_infotype (0 text, 1 header in, 2 header out). }
function CurlDebugCallback(Handle: Pointer; InfoType: Integer; Data: Pointer;
  Size: NativeUInt; UserData: Pointer): Integer; cdecl;

{ ---- helpers ---- }
procedure EnsureCurlInitialized;
procedure CurlCheck(Code: CURLcode; const Operation: string);
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

constructor TCurlDebugSink.Create(const ALogger: IHttpLogger; ARedact: Boolean);
begin
  inherited Create;
  FLogger := ALogger;
  FRedact := ARedact;
end;

procedure TCurlDebugSink.Process(InfoType: Integer; Data: Pointer; Size: NativeUInt);
const
  INFO_TEXT = 0;
  INFO_HEADER_IN = 1;
  INFO_HEADER_OUT = 2;
var
  Prefix, Text, Line: string;
  B: TBytes;
  Start, I: Integer;
begin
  if (FLogger = nil) or (Size = 0) or not FLogger.IsEnabled(llDebug) then Exit;
  case InfoType of
    INFO_TEXT:       Prefix := '* ';
    INFO_HEADER_IN:  Prefix := '< ';
    INFO_HEADER_OUT: Prefix := '> ';
  else
    Exit;                              // data / TLS payload: not logged
  end;
  SetLength(B, Size);
  Move(Data^, B[0], Size);
  Text := BytesToString(B);
  Start := 1;
  for I := 1 to Length(Text) + 1 do
    if (I > Length(Text)) or (Text[I] = #10) then
    begin
      Line := Copy(Text, Start, I - Start);
      Start := I + 1;
      while (Line <> '') and (Line[Length(Line)] = #13) do
        SetLength(Line, Length(Line) - 1);
      if Line = '' then Continue;      // blank line that ends a header block
      if FRedact and (InfoType <> INFO_TEXT) then Line := RedactHeaderLine(Line);
      FLogger.Log(llDebug, 'curl', Prefix + Line);
    end;
end;

constructor TCurlBodySource.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FSize := Length(AData);
end;

constructor TCurlBodySource.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
  FStart := AStream.Position;
  FSize := AStream.Size - FStart;
end;

destructor TCurlBodySource.Destroy;
begin
  if FStream <> nil then
  begin
    if FOwnsStream then
      FStream.Free
    else
      try
        FStream.Position := FStart;   // leave a caller-owned stream where we found it
      except
        // a stream that cannot seek back is simply left as is
      end;
  end;
  inherited Destroy;
end;

function TCurlBodySource.Read(Dest: Pointer; MaxLen: NativeUInt): NativeUInt;
var
  Avail: Int64;
  Want: Integer;
begin
  Avail := FSize - FPos;
  if Avail <= 0 then
  begin
    Result := 0;
    Exit;
  end;
  if Int64(MaxLen) < Avail then Avail := Int64(MaxLen);
  if Avail > 1048576 then Avail := 1048576;      // cap a single chunk
  Want := Integer(Avail);
  if FStream <> nil then
    Result := NativeUInt(FStream.Read(Dest^, Want))
  else
  begin
    Move(FData[FPos], Dest^, Want);
    Result := NativeUInt(Want);
  end;
  Inc(FPos, Result);
end;

function TCurlBodySource.Seek(Offset: Int64; Origin: Integer): Boolean;
var
  NewPos: Int64;
begin
  case Origin of
    0: NewPos := Offset;                          // SEEK_SET
    1: NewPos := FPos + Offset;                   // SEEK_CUR
    2: NewPos := FSize + Offset;                  // SEEK_END
  else
    NewPos := -1;
  end;
  Result := (NewPos >= 0) and (NewPos <= FSize);
  if Result then
  begin
    if FStream <> nil then FStream.Position := FStart + NewPos;
    FPos := NewPos;
  end;
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

function CurlDebugCallback(Handle: Pointer; InfoType: Integer; Data: Pointer;
  Size: NativeUInt; UserData: Pointer): Integer; cdecl;
begin
  Result := 0;                         // the return value is ignored by libcurl
  try
    if UserData <> nil then
      TCurlDebugSink(UserData).Process(InfoType, Data, Size);
  except
    // never let an exception cross the C boundary
  end;
end;

{ ===== 4a. multipart (MIME) ===== }

procedure CurlCheck(Code: CURLcode; const Operation: string);
begin
  if Code <> CURLE_OK then
    raise ECurlError.Create(Ord(Code), Operation,
      CStrToString(curl_easy_strerror(Code)));
end;

constructor TCurlMime.Create(Easy: TCurlEasy);
begin
  inherited Create;
  FMime := curl_mime_init(Easy.Handle);
  if FMime = nil then
    raise ECurlError.Create(Ord(CURLE_OUT_OF_MEMORY), 'curl_mime_init', 'out of memory');
end;

destructor TCurlMime.Destroy;
var
  I: Integer;
begin
  if FMime <> nil then
    curl_mime_free(FMime);               // stops all callbacks into the sources
  for I := 0 to High(FSources) do
    FSources[I].Free;                    // closes the file streams
  inherited Destroy;
end;

function TCurlMime.NewPart(const Name: string): Pcurl_mimepart;
var
  U: UTF8String;
begin
  Result := curl_mime_addpart(FMime);
  if Result = nil then
    raise ECurlError.Create(Ord(CURLE_OUT_OF_MEMORY), 'curl_mime_addpart', 'out of memory');
  U := UTF8Encode(Name);
  CurlCheck(curl_mime_name(Result, PUTF8Char(PAnsiChar(U))), 'curl_mime_name');
end;

{ Kind: 0 = filename, 1 = mime type }
procedure TCurlMime.SetPartStr(Part: Pcurl_mimepart; Kind: Integer; const Value: string);
var
  U: UTF8String;
begin
  U := UTF8Encode(Value);
  if Kind = 0 then
    CurlCheck(curl_mime_filename(Part, PUTF8Char(PAnsiChar(U))), 'curl_mime_filename')
  else
    CurlCheck(curl_mime_type(Part, PUTF8Char(PAnsiChar(U))), 'curl_mime_type');
end;

procedure TCurlMime.AddField(const Name, Value: string);
var
  Part: Pcurl_mimepart;
  U: UTF8String;
begin
  Part := NewPart(Name);
  U := UTF8Encode(Value);                // curl_mime_data copies the bytes
  if Length(U) = 0 then
    CurlCheck(curl_mime_data(Part, PUTF8Char(PAnsiChar('')), 0), 'curl_mime_data')
  else
    CurlCheck(curl_mime_data(Part, PUTF8Char(PAnsiChar(U)), Length(U)), 'curl_mime_data');
end;

procedure TCurlMime.AddBytes(const Name, FileName: string; const Data: TBytes;
  const ContentType: string);
var
  Part: Pcurl_mimepart;
  Dummy: Byte;
begin
  Part := NewPart(Name);
  Dummy := 0;
  if Length(Data) = 0 then
    CurlCheck(curl_mime_data(Part, PUTF8Char(@Dummy), 0), 'curl_mime_data')
  else
    CurlCheck(curl_mime_data(Part, PUTF8Char(@Data[0]), Length(Data)), 'curl_mime_data');
  if FileName <> '' then SetPartStr(Part, 0, FileName);
  if ContentType <> '' then SetPartStr(Part, 1, ContentType);
end;

procedure TCurlMime.AddSource(const Name, FileName, ContentType: string;
  Source: TCurlBodySource);
var
  Part: Pcurl_mimepart;
begin
  SetLength(FSources, Length(FSources) + 1);
  FSources[High(FSources)] := Source;      // owned from here on
  Part := NewPart(Name);
  CurlCheck(curl_mime_data_cb(Part, Source.Size,
    curl_read_callback(@CurlReadCallback), curl_seek_callback(@CurlSeekCallback),
    nil, Pointer(Source)), 'curl_mime_data_cb');
  if FileName <> '' then SetPartStr(Part, 0, FileName);
  if ContentType <> '' then SetPartStr(Part, 1, ContentType);
end;

procedure TCurlMime.AddFile(const Name, FilePath, FileName, ContentType: string);
var
  Stream: TFileStream;
begin
  // The file is read through a Pascal stream (full Unicode path support on
  // Windows) and fed to libcurl chunk by chunk: memory use stays constant.
  try
    Stream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  except
    on E: EStreamError do
      raise EHttpError.CreateFmt('Cannot open upload file "%s": %s', [FilePath, E.Message]);
  end;
  AddSource(Name, FileName, ContentType, TCurlBodySource.Create(Stream, True));
end;

procedure TCurlMime.AddStream(const Name, FileName: string; AStream: TStream;
  const ContentType: string);
begin
  AddSource(Name, FileName, ContentType, TCurlBodySource.Create(AStream, False));
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

function TCurlEasy.TrySetLong(Option: CURLoption; Value: TCurlLong): CURLcode;
begin
  Result := curl_easy_setopt(FHandle, Option, Value);
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
