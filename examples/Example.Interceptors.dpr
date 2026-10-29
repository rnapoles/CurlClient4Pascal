program Example_Interceptors;
{ Interceptors + logging:
    - a custom interceptor (adds a correlation id to every request)
    - a bearer-token provider (called per request, so a refresh fits here)
    - a logging interceptor with a console logger (secrets are masked)
    - a timing interceptor with statistics
    - libcurl's verbose trace routed through the same logger (not stderr)
  None of the calls below needs to know about any of it.

  Usage: Example_Interceptors [baseUrl]     (default https://httpbin.org) }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Http.Errors, Http.Request, Http.Response, Http.Client, Http.Interceptors,
  Http.Logging, Http.Curl.Transport;

type
  { Derive from THttpInterceptor and override only the hooks you need. }
  TRequestIdInterceptor = class(THttpInterceptor)
  private
    FCounter: Integer;
  public
    procedure BeforeRequest(const Request: IHttpRequest); override;
  end;

procedure TRequestIdInterceptor.BeforeRequest(const Request: IHttpRequest);
begin
  Inc(FCounter);
  Request.Headers.SetValue('X-Request-Id', Format('req-%.4d', [FCounter]));
end;

{ Called for every request: fetch/refresh your real token here. }
function CurrentToken: string;
begin
  Result := 'demo-token-123';
end;

var
  BaseUrl: string;
  Logger: IHttpLogger;
  Timing: ITimingInterceptor;
  Client: IHttpClient;
begin
  if ParamCount > 0 then BaseUrl := ParamStr(1) else BaseUrl := 'https://httpbin.org';
  try
    Logger := NewConsoleLogger(llDebug);          // or NewFileLogger('http.log') ...
    Timing := NewTimingInterceptor;

    Client := NewHttpClient
      .SetBaseUrl(BaseUrl)
      .SetConnectTimeout(3000)
      .AddInterceptor(NewTokenProviderInterceptor(CurrentToken))   // 1st: Authorization
      .AddInterceptor(TRequestIdInterceptor.Create)                // 2nd: X-Request-Id
      .AddInterceptor(NewLoggingInterceptor(Logger, True))         // 3rd: sees both headers
      .AddInterceptor(Timing);

    WriteLn('--- 1. ordinary calls: logged, authenticated, timed ---');
    Client.Get('/get');
    Client.Post('/post', 'hello');
    Client.Get('/status/404');                    // a response, logged as WARN
    try
      Client.Get('http://127.0.0.1:1/');          // transport failure: OnError hooks
    except
      on E: ECurlError do
        WriteLn('caught: ', E.CurlMessage);
    end;

    WriteLn;
    WriteLn('--- 2. timing statistics ---');
    WriteLn('requests: ', Timing.RequestCount, '  errors: ', Timing.ErrorCount);
    WriteLn('total: ', Timing.TotalMs, ' ms  avg: ', Timing.AverageMs,
            ' ms  max: ', Timing.MaxMs, ' ms  last: ', Timing.LastMs, ' ms');

    WriteLn;
    WriteLn('--- 3. libcurl verbose trace through the logger (Authorization is masked) ---');
    Client.ClearInterceptors;
    Client.SetLogger(Logger).SetVerbose(True);
    Client.Get('/get');
  except
    on E: EHttpError do
    begin
      WriteLn('HTTP error: ', E.Message);
      Halt(3);
    end;
  end;
end.
