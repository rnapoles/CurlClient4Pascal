unit Http.Logging;
{ Pluggable logging for the HTTP client (pure Pascal, no libcurl dependency).

    IHttpLogger  the one-method contract the library logs through
    THttpLogger  base class: level filtering + serialised writes; derive from
                 it (override WriteLine) for your own sinks
    factories    NewConsoleLogger, NewFileLogger, NewMemoryLogger, NewProcLogger

  Typical use
    Client := NewHttpClient
      .SetLogger(NewConsoleLogger(llDebug))    // routes libcurl's verbose trace
      .SetVerbose(True)
      .AddInterceptor(NewLoggingInterceptor(Logger));   // see Http.Interceptors

  Categories used by the library: 'curl' (libcurl verbose trace) and 'http'
  (request/response log lines from the logging interceptor).

  Secrets: header values of Authorization, Proxy-Authorization, Cookie,
  Set-Cookie, X-Api-Key and X-Auth-Token, and the password in URLs, are
  replaced by *** by the helpers below, which the library applies by default. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Http.Utils;

type
  THttpLogLevel = (llDebug, llInfo, llWarning, llError);

  IHttpLogger = interface
    ['{3C8D5A12-6E47-4B9A-A1F0-8D2E7C4B9F63}']
    procedure Log(Level: THttpLogLevel; const Category, Msg: string);
    { Cheap pre-check so callers can skip building expensive messages. }
    function IsEnabled(Level: THttpLogLevel): Boolean;
  end;

  { Base class for loggers. Log() filters by MinLevel and calls WriteLine
    under a lock, so descendants need not be thread-safe. }
  THttpLogger = class(TInterfacedObject, IHttpLogger)
  private
    FLock: TCriticalSection;
    FMinLevel: THttpLogLevel;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); virtual; abstract;
  public
    constructor Create(AMinLevel: THttpLogLevel = llDebug);
    destructor Destroy; override;
    procedure Log(Level: THttpLogLevel; const Category, Msg: string);
    function IsEnabled(Level: THttpLogLevel): Boolean;
    property MinLevel: THttpLogLevel read FMinLevel write FMinLevel;
  end;

  { In-memory logger, mainly for tests. }
  IMemoryLogger = interface(IHttpLogger)
    ['{0B6E1F94-2A3D-4C58-9D77-5E8A3F1C2B40}']
    function Count: Integer;
    function GetLine(Index: Integer): string;
    function Text: string;
    procedure Clear;
    { True if any logged line contains Needle. }
    function Contains(const Needle: string): Boolean;
    property Lines[Index: Integer]: string read GetLine; default;
  end;

  THttpLogProc = procedure(Level: THttpLogLevel; const Category, Msg: string);

{ ---- factories (always keep results in interface variables) ---- }
{ Timestamped lines on stdout (or stderr). }
function NewConsoleLogger(AMinLevel: THttpLogLevel = llInfo; ToStdErr: Boolean = False): IHttpLogger;
{ Appends timestamped lines to FileName (created if missing). }
function NewFileLogger(const FileName: string; AMinLevel: THttpLogLevel = llInfo): IHttpLogger;
{ Collects "LEVEL category: message" lines (no timestamp). }
function NewMemoryLogger(AMinLevel: THttpLogLevel = llDebug): IMemoryLogger;
{ Forwards every accepted message to a plain procedure. }
function NewProcLogger(AProc: THttpLogProc; AMinLevel: THttpLogLevel = llDebug): IHttpLogger;

{ ---- formatting & redaction helpers ---- }
function LogLevelName(Level: THttpLogLevel): string;
function IsSensitiveHeader(const Name: string): Boolean;
{ 'Bearer abc' -> '***' when Name is sensitive, otherwise Value unchanged. }
function RedactHeaderValue(const Name, Value: string): string;
{ 'Authorization: Bearer abc' -> 'Authorization: ***' (other lines unchanged). }
function RedactHeaderLine(const Line: string): string;
{ 'http://ana:pw@h/x' -> 'http://ana:***@h/x'. }
function RedactUrl(const Url: string): string;

implementation

const
  LevelNames: array[THttpLogLevel] of string = ('DEBUG', 'INFO ', 'WARN ', 'ERROR');
  SensitiveHeaders: array[0..5] of string =
    ('authorization', 'proxy-authorization', 'cookie', 'set-cookie',
     'x-api-key', 'x-auth-token');

function LogLevelName(Level: THttpLogLevel): string;
begin
  Result := LevelNames[Level];
end;

function IsSensitiveHeader(const Name: string): Boolean;
var
  I: Integer;
  N: string;
begin
  N := AsciiLower(Trim(Name));
  for I := Low(SensitiveHeaders) to High(SensitiveHeaders) do
    if SensitiveHeaders[I] = N then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function RedactHeaderValue(const Name, Value: string): string;
begin
  if IsSensitiveHeader(Name) and (Value <> '') then
    Result := '***'
  else
    Result := Value;
end;

function RedactHeaderLine(const Line: string): string;
var
  P: Integer;
begin
  Result := Line;
  P := Pos(':', Line);
  if (P > 1) and IsSensitiveHeader(Copy(Line, 1, P - 1)) then
    Result := Copy(Line, 1, P) + ' ***';
end;

function RedactUrl(const Url: string): string;
var
  P, AuthEnd, At, Colon: Integer;
begin
  Result := Url;
  P := Pos('://', Url);
  if P = 0 then Exit;
  AuthEnd := P + 3;
  while (AuthEnd <= Length(Url)) and (Url[AuthEnd] <> '/') and (Url[AuthEnd] <> '?') and
        (Url[AuthEnd] <> '#') do
    Inc(AuthEnd);
  At := 0;
  for P := AuthEnd - 1 downto Pos('://', Url) + 3 do
    if Url[P] = '@' then
    begin
      At := P;
      Break;
    end;
  if At = 0 then Exit;
  Colon := 0;
  for P := Pos('://', Url) + 3 to At - 1 do
    if Url[P] = ':' then
    begin
      Colon := P;
      Break;
    end;
  if Colon = 0 then Exit;                       // user only, no password
  Result := Copy(Url, 1, Colon) + '***' + Copy(Url, At, MaxInt);
end;

{ ===== THttpLogger ===== }

constructor THttpLogger.Create(AMinLevel: THttpLogLevel);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FMinLevel := AMinLevel;
end;

destructor THttpLogger.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function THttpLogger.IsEnabled(Level: THttpLogLevel): Boolean;
begin
  Result := Ord(Level) >= Ord(FMinLevel);
end;

procedure THttpLogger.Log(Level: THttpLogLevel; const Category, Msg: string);
begin
  if not IsEnabled(Level) then Exit;
  FLock.Enter;
  try
    try
      WriteLine(Level, Category, Msg);
    except
      // logging must never break an HTTP request
    end;
  finally
    FLock.Leave;
  end;
end;

function Stamp: string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
end;

function FormatLine(Level: THttpLogLevel; const Category, Msg: string): string;
begin
  Result := Stamp + ' [' + LevelNames[Level] + '] ' + Category + ': ' + Msg;
end;

{ ===== concrete loggers (implementation only) ===== }

type
  TConsoleLogger = class(THttpLogger)
  private
    FToStdErr: Boolean;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  public
    constructor Create(AMinLevel: THttpLogLevel; AToStdErr: Boolean);
  end;

  TFileLogger = class(THttpLogger)
  private
    FFileName: string;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  public
    constructor Create(const AFileName: string; AMinLevel: THttpLogLevel);
  end;

  TMemoryLogger = class(THttpLogger, IMemoryLogger)
  private
    FLines: TStringList;
    FReadLock: TCriticalSection;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  public
    constructor Create(AMinLevel: THttpLogLevel);
    destructor Destroy; override;
    function Count: Integer;
    function GetLine(Index: Integer): string;
    function Text: string;
    procedure Clear;
    function Contains(const Needle: string): Boolean;
  end;

  TProcLogger = class(THttpLogger)
  private
    FProc: THttpLogProc;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  public
    constructor Create(AProc: THttpLogProc; AMinLevel: THttpLogLevel);
  end;

constructor TConsoleLogger.Create(AMinLevel: THttpLogLevel; AToStdErr: Boolean);
begin
  inherited Create(AMinLevel);
  FToStdErr := AToStdErr;
end;

procedure TConsoleLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
begin
  if FToStdErr then
    WriteLn(ErrOutput, FormatLine(Level, Category, Msg))
  else
    WriteLn(FormatLine(Level, Category, Msg));
end;

constructor TFileLogger.Create(const AFileName: string; AMinLevel: THttpLogLevel);
begin
  inherited Create(AMinLevel);
  FFileName := AFileName;
end;

procedure TFileLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
var
  F: TFileStream;
  B: TBytes;
  Mode: Word;
begin
  // open-append-close per line: slower, but robust against crashes and rotation
  if FileExists(FFileName) then Mode := fmOpenReadWrite or fmShareDenyNone
  else Mode := fmCreate;
  F := TFileStream.Create(FFileName, Mode);
  try
    F.Seek(0, soEnd);
    B := StringToBytes(FormatLine(Level, Category, Msg) + sLineBreak);
    if Length(B) > 0 then F.WriteBuffer(B[0], Length(B));
  finally
    F.Free;
  end;
end;

constructor TMemoryLogger.Create(AMinLevel: THttpLogLevel);
begin
  inherited Create(AMinLevel);
  FLines := TStringList.Create;
  FReadLock := TCriticalSection.Create;
end;

destructor TMemoryLogger.Destroy;
begin
  FReadLock.Free;
  FLines.Free;
  inherited Destroy;
end;

procedure TMemoryLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
begin
  FReadLock.Enter;
  try
    FLines.Add(Trim(LevelNames[Level]) + ' ' + Category + ': ' + Msg);
  finally
    FReadLock.Leave;
  end;
end;

function TMemoryLogger.Count: Integer;
begin
  FReadLock.Enter;
  try
    Result := FLines.Count;
  finally
    FReadLock.Leave;
  end;
end;

function TMemoryLogger.GetLine(Index: Integer): string;
begin
  FReadLock.Enter;
  try
    Result := FLines[Index];
  finally
    FReadLock.Leave;
  end;
end;

function TMemoryLogger.Text: string;
begin
  FReadLock.Enter;
  try
    Result := FLines.Text;
  finally
    FReadLock.Leave;
  end;
end;

procedure TMemoryLogger.Clear;
begin
  FReadLock.Enter;
  try
    FLines.Clear;
  finally
    FReadLock.Leave;
  end;
end;

function TMemoryLogger.Contains(const Needle: string): Boolean;
begin
  Result := Pos(Needle, Text) > 0;
end;

constructor TProcLogger.Create(AProc: THttpLogProc; AMinLevel: THttpLogLevel);
begin
  inherited Create(AMinLevel);
  FProc := AProc;
end;

procedure TProcLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
begin
  if Assigned(FProc) then FProc(Level, Category, Msg);
end;

function NewConsoleLogger(AMinLevel: THttpLogLevel; ToStdErr: Boolean): IHttpLogger;
begin
  Result := TConsoleLogger.Create(AMinLevel, ToStdErr);
end;

function NewFileLogger(const FileName: string; AMinLevel: THttpLogLevel): IHttpLogger;
begin
  Result := TFileLogger.Create(FileName, AMinLevel);
end;

function NewMemoryLogger(AMinLevel: THttpLogLevel): IMemoryLogger;
begin
  Result := TMemoryLogger.Create(AMinLevel);
end;

function NewProcLogger(AProc: THttpLogProc; AMinLevel: THttpLogLevel): IHttpLogger;
begin
  Result := TProcLogger.Create(AProc, AMinLevel);
end;

end.
