unit Http.Interceptors;
{ Request/response interceptors: hooks that run around every request made by an
  IHttpClient, so cross-cutting concerns (logging, auth, timing, ...) live in
  one place instead of at each call site.

    Client := NewHttpClient
      .AddInterceptor(NewTokenProviderInterceptor(GetCurrentToken))
      .AddInterceptor(NewLoggingInterceptor(Logger))
      .AddInterceptor(Timing);                  // ITimingInterceptor

  Execution order for interceptors A, B, C (in the order they were added):

      A.BeforeRequest -> B.BeforeRequest -> C.BeforeRequest
          ... request goes over the wire ...
      C.AfterResponse -> B.AfterResponse -> A.AfterResponse      (success)
      C.OnError       -> B.OnError       -> A.OnError            (exception)

  * BeforeRequest receives the *resolved* request (absolute URL, merged client
    headers, cookies): changing its headers never touches the caller's request
    object. Exceptions raised here abort the request.
  * AfterResponse runs after cookies were stored. Exceptions raised here reach
    the caller.
  * OnError is informational: the original exception is re-raised afterwards
    and an exception raised inside OnError is swallowed.
  * Do not keep the Request/Response/Exception references after the call. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, SyncObjs, Http.Utils, Http.Headers, Http.Request, Http.Response,
  Http.Logging;

type
  IHttpInterceptor = interface
    ['{7E2A9C53-1B84-4D6F-8A30-9C5D1E7F2B68}']
    procedure BeforeRequest(const Request: IHttpRequest);
    procedure AfterResponse(const Request: IHttpRequest; const Response: IHttpResponse;
      ElapsedMs: Int64);
    procedure OnError(const Request: IHttpRequest; E: Exception; ElapsedMs: Int64);
  end;

  { Base class with empty hooks: override only what you need.

      type
        TMyInterceptor = class(THttpInterceptor)
          procedure BeforeRequest(const Request: IHttpRequest); override;
        end;
      Client.AddInterceptor(TMyInterceptor.Create);      // the client owns it }
  THttpInterceptor = class(TInterfacedObject, IHttpInterceptor)
  public
    procedure BeforeRequest(const Request: IHttpRequest); virtual;
    procedure AfterResponse(const Request: IHttpRequest; const Response: IHttpResponse;
      ElapsedMs: Int64); virtual;
    procedure OnError(const Request: IHttpRequest; E: Exception; ElapsedMs: Int64); virtual;
  end;

  THttpInterceptors = array of IHttpInterceptor;

  { Statistics collected by NewTimingInterceptor (thread-safe). }
  ITimingInterceptor = interface(IHttpInterceptor)
    ['{4F1B8D26-9A57-4E03-B6C8-2D7A5E9F1C34}']
    function RequestCount: Integer;     // finished requests (success + error)
    function ErrorCount: Integer;       // requests that raised
    function TotalMs: Int64;
    function LastMs: Int64;
    function MaxMs: Int64;
    function AverageMs: Int64;          // 0 when there are no requests
    procedure Reset;
  end;

  TTokenProvider = function: string;
  TTokenProviderMethod = function: string of object;

{ ---- ready-made interceptors (keep results in interface variables) ---- }

{ Logs "--> GET url", "<-- 200 OK ... (12 ms)" and failures. 2xx/3xx = info,
  4xx = warning, 5xx and exceptions = error. With LogHeaders the request and
  response headers are logged too (debug level); sensitive values are
  replaced by *** unless Redact is False. Category: 'http'. }
function NewLoggingInterceptor(const Logger: IHttpLogger; LogHeaders: Boolean = False;
  Redact: Boolean = True): IHttpInterceptor;

{ Adds the given headers to every request that does not already have them.
  NameValuePairs = ['X-App', 'demo', 'Accept-Language', 'en', ...] }
function NewHeadersInterceptor(const NameValuePairs: array of string): IHttpInterceptor;

{ "Authorization: Bearer <token>", unless the request already has an
  Authorization header. An empty token adds nothing. }
function NewBearerTokenInterceptor(const Token: string): IHttpInterceptor;
{ Same, but the token comes from a function called for EVERY request, which is
  where a token refresh belongs. (Separate names on purpose: overloading on
  "string" vs "function: string" would be ambiguous.) }
function NewTokenProviderInterceptor(Provider: TTokenProvider): IHttpInterceptor;
function NewTokenMethodInterceptor(Provider: TTokenProviderMethod): IHttpInterceptor;

{ Collects request counts and durations. }
function NewTimingInterceptor: ITimingInterceptor;

implementation

{ ===== THttpInterceptor ===== }

procedure THttpInterceptor.BeforeRequest(const Request: IHttpRequest);
begin
end;

procedure THttpInterceptor.AfterResponse(const Request: IHttpRequest;
  const Response: IHttpResponse; ElapsedMs: Int64);
begin
end;

procedure THttpInterceptor.OnError(const Request: IHttpRequest; E: Exception;
  ElapsedMs: Int64);
begin
end;

{ ===== logging ===== }

type
  TLoggingInterceptor = class(THttpInterceptor)
  private
    FLogger: IHttpLogger;
    FLogHeaders: Boolean;
    FRedact: Boolean;
    procedure LogHeaderBlock(const Prefix: string; Headers: THttpHeaders);
  public
    constructor Create(const ALogger: IHttpLogger; ALogHeaders, ARedact: Boolean);
    procedure BeforeRequest(const Request: IHttpRequest); override;
    procedure AfterResponse(const Request: IHttpRequest; const Response: IHttpResponse;
      ElapsedMs: Int64); override;
    procedure OnError(const Request: IHttpRequest; E: Exception; ElapsedMs: Int64); override;
  end;

constructor TLoggingInterceptor.Create(const ALogger: IHttpLogger; ALogHeaders,
  ARedact: Boolean);
begin
  inherited Create;
  FLogger := ALogger;
  FLogHeaders := ALogHeaders;
  FRedact := ARedact;
end;

procedure TLoggingInterceptor.LogHeaderBlock(const Prefix: string; Headers: THttpHeaders);
var
  I: Integer;
  V: string;
begin
  for I := 0 to Headers.Count - 1 do
  begin
    V := Headers.Values[I];
    if FRedact then V := RedactHeaderValue(Headers.Names[I], V);
    FLogger.Log(llDebug, 'http', Prefix + Headers.Names[I] + ': ' + V);
  end;
end;

function Describe(const Request: IHttpRequest; Redact: Boolean): string;
var
  U: string;
begin
  U := Request.Url;
  if Redact then U := RedactUrl(U);
  Result := HttpMethodToString(Request.Method) + ' ' + U;
end;

procedure TLoggingInterceptor.BeforeRequest(const Request: IHttpRequest);
begin
  if FLogger = nil then Exit;
  if FLogger.IsEnabled(llInfo) then
    FLogger.Log(llInfo, 'http', '--> ' + Describe(Request, FRedact));
  if FLogHeaders and FLogger.IsEnabled(llDebug) then
    LogHeaderBlock('> ', Request.Headers);
end;

procedure TLoggingInterceptor.AfterResponse(const Request: IHttpRequest;
  const Response: IHttpResponse; ElapsedMs: Int64);
var
  Level: THttpLogLevel;
  Msg: string;
begin
  if FLogger = nil then Exit;
  if Response.IsServerError then Level := llError
  else if Response.IsClientError then Level := llWarning
  else Level := llInfo;
  if FLogger.IsEnabled(Level) then
  begin
    Msg := Format('<-- %d %s %s (%d ms, %d bytes)',
      [Response.StatusCode, Response.StatusText, Describe(Request, FRedact),
       ElapsedMs, Length(Response.Body)]);
    FLogger.Log(Level, 'http', Msg);
  end;
  if FLogHeaders and FLogger.IsEnabled(llDebug) then
    LogHeaderBlock('< ', Response.Headers);
end;

procedure TLoggingInterceptor.OnError(const Request: IHttpRequest; E: Exception;
  ElapsedMs: Int64);
begin
  if FLogger = nil then Exit;
  FLogger.Log(llError, 'http', Format('!!! %s failed after %d ms: %s: %s',
    [Describe(Request, FRedact), ElapsedMs, E.ClassName, E.Message]));
end;

function NewLoggingInterceptor(const Logger: IHttpLogger; LogHeaders: Boolean;
  Redact: Boolean): IHttpInterceptor;
begin
  Result := TLoggingInterceptor.Create(Logger, LogHeaders, Redact);
end;

{ ===== static headers ===== }

type
  THeadersInterceptor = class(THttpInterceptor)
  private
    FHeaders: THttpHeaders;
  public
    constructor Create(const NameValuePairs: array of string);
    destructor Destroy; override;
    procedure BeforeRequest(const Request: IHttpRequest); override;
  end;

constructor THeadersInterceptor.Create(const NameValuePairs: array of string);
var
  I: Integer;
begin
  inherited Create;
  if Odd(Length(NameValuePairs)) then
    raise EArgumentException.Create('NewHeadersInterceptor expects name/value pairs');
  FHeaders := THttpHeaders.Create;
  I := 0;
  while I < Length(NameValuePairs) do
  begin
    FHeaders.Add(NameValuePairs[I], NameValuePairs[I + 1]);   // validates CR/LF
    Inc(I, 2);
  end;
end;

destructor THeadersInterceptor.Destroy;
begin
  FHeaders.Free;
  inherited Destroy;
end;

procedure THeadersInterceptor.BeforeRequest(const Request: IHttpRequest);
var
  I: Integer;
begin
  for I := 0 to FHeaders.Count - 1 do
    if not Request.Headers.Contains(FHeaders.Names[I]) then
      Request.Headers.Add(FHeaders.Names[I], FHeaders.Values[I]);
end;

function NewHeadersInterceptor(const NameValuePairs: array of string): IHttpInterceptor;
begin
  Result := THeadersInterceptor.Create(NameValuePairs);
end;

{ ===== bearer token ===== }

type
  TBearerInterceptor = class(THttpInterceptor)
  private
    FToken: string;
    FProvider: TTokenProvider;
    FMethodProvider: TTokenProviderMethod;
  public
    procedure BeforeRequest(const Request: IHttpRequest); override;
  end;

procedure TBearerInterceptor.BeforeRequest(const Request: IHttpRequest);
var
  Token: string;
begin
  if Request.Headers.Contains('Authorization') then Exit;   // explicit wins
  if Assigned(FMethodProvider) then Token := FMethodProvider()
  else if Assigned(FProvider) then Token := FProvider()
  else Token := FToken;
  if Token <> '' then
    Request.Headers.SetValue('Authorization', 'Bearer ' + Token);
end;

function NewBearerTokenInterceptor(const Token: string): IHttpInterceptor;
var
  B: TBearerInterceptor;
begin
  B := TBearerInterceptor.Create;
  Result := B;
  B.FToken := Token;
end;

function NewTokenProviderInterceptor(Provider: TTokenProvider): IHttpInterceptor;
var
  B: TBearerInterceptor;
begin
  B := TBearerInterceptor.Create;
  Result := B;
  B.FProvider := Provider;
end;

function NewTokenMethodInterceptor(Provider: TTokenProviderMethod): IHttpInterceptor;
var
  B: TBearerInterceptor;
begin
  B := TBearerInterceptor.Create;
  Result := B;
  B.FMethodProvider := Provider;
end;

{ ===== timing ===== }

type
  TTimingInterceptor = class(THttpInterceptor, ITimingInterceptor)
  private
    FLock: TCriticalSection;
    FCount, FErrors: Integer;
    FTotal, FLast, FMax: Int64;
    procedure Note(ElapsedMs: Int64; IsError: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AfterResponse(const Request: IHttpRequest; const Response: IHttpResponse;
      ElapsedMs: Int64); override;
    procedure OnError(const Request: IHttpRequest; E: Exception; ElapsedMs: Int64); override;
    function RequestCount: Integer;
    function ErrorCount: Integer;
    function TotalMs: Int64;
    function LastMs: Int64;
    function MaxMs: Int64;
    function AverageMs: Int64;
    procedure Reset;
  end;

constructor TTimingInterceptor.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TTimingInterceptor.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TTimingInterceptor.Note(ElapsedMs: Int64; IsError: Boolean);
begin
  FLock.Enter;
  try
    Inc(FCount);
    if IsError then Inc(FErrors);
    Inc(FTotal, ElapsedMs);
    FLast := ElapsedMs;
    if ElapsedMs > FMax then FMax := ElapsedMs;
  finally
    FLock.Leave;
  end;
end;

procedure TTimingInterceptor.AfterResponse(const Request: IHttpRequest;
  const Response: IHttpResponse; ElapsedMs: Int64);
begin
  Note(ElapsedMs, False);
end;

procedure TTimingInterceptor.OnError(const Request: IHttpRequest; E: Exception;
  ElapsedMs: Int64);
begin
  Note(ElapsedMs, True);
end;

function TTimingInterceptor.RequestCount: Integer;
begin
  FLock.Enter;
  try Result := FCount; finally FLock.Leave; end;
end;

function TTimingInterceptor.ErrorCount: Integer;
begin
  FLock.Enter;
  try Result := FErrors; finally FLock.Leave; end;
end;

function TTimingInterceptor.TotalMs: Int64;
begin
  FLock.Enter;
  try Result := FTotal; finally FLock.Leave; end;
end;

function TTimingInterceptor.LastMs: Int64;
begin
  FLock.Enter;
  try Result := FLast; finally FLock.Leave; end;
end;

function TTimingInterceptor.MaxMs: Int64;
begin
  FLock.Enter;
  try Result := FMax; finally FLock.Leave; end;
end;

function TTimingInterceptor.AverageMs: Int64;
begin
  FLock.Enter;
  try
    if FCount = 0 then Result := 0 else Result := FTotal div FCount;
  finally
    FLock.Leave;
  end;
end;

procedure TTimingInterceptor.Reset;
begin
  FLock.Enter;
  try
    FCount := 0;
    FErrors := 0;
    FTotal := 0;
    FLast := 0;
    FMax := 0;
  finally
    FLock.Leave;
  end;
end;

function NewTimingInterceptor: ITimingInterceptor;
begin
  Result := TTimingInterceptor.Create;
end;

end.
