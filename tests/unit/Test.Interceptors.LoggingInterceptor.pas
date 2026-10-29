unit Test.Interceptors.LoggingInterceptor;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors, Http.Logging;

procedure TestLogsRequestAndResponse;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  L := NewMemoryLogger;
  C := NewHttpClient(T).AddInterceptor(NewLoggingInterceptor(L));
  C.Get('http://h/items');
  CheckEqualsInt(2, L.Count);
  CheckEqualsStr('INFO http: --> GET http://h/items', L[0]);
  CheckContains('INFO http: <-- 200 FAKE GET http://h/items (', L[1]);
  CheckContains(' ms, 0 bytes)', L[1]);
end;
procedure TestLevelsFollowTheStatusClass;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  L := NewMemoryLogger;
  C := NewHttpClient(T).AddInterceptor(NewLoggingInterceptor(L));
  F.RespondWith(404); C.Get('http://h/a');
  F.RespondWith(503); C.Get('http://h/b');
  CheckContains('WARN http: <-- 404', L[1]);
  CheckContains('ERROR http: <-- 503', L[3]);
end;
procedure TestLogsFailures;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  F.FailWith(EHttpError, 'connection lost');
  L := NewMemoryLogger;
  C := NewHttpClient(T).AddInterceptor(NewLoggingInterceptor(L));
  try C.Get('http://h/x'); except on EHttpError do ; end;
  CheckContains('ERROR http: !!! GET http://h/x failed after ', L[1]);
  CheckContains('EHttpError: connection lost', L[1]);
end;
procedure TestUrlPasswordIsMasked;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  L := NewMemoryLogger;
  C := NewHttpClient(T).AddInterceptor(NewLoggingInterceptor(L));
  C.Get('http://ana:topsecret@h/x');
  CheckFalse(L.Contains('topsecret'));
  CheckTrue(L.Contains('ana:***@h'));
end;
procedure TestHeadersAreLoggedAndRedacted;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  F.AddResponseHeader('Set-Cookie', 'sid=zzz');
  F.AddResponseHeader('Content-Type', 'text/plain');
  L := NewMemoryLogger;
  C := NewHttpClient(T).SetBearerToken('s3cret').SetHeader('X-Trace', '7')
        .AddInterceptor(NewLoggingInterceptor(L, True));
  C.Get('http://h/x');
  CheckTrue(L.Contains('DEBUG http: > X-Trace: 7'));
  CheckTrue(L.Contains('DEBUG http: > Authorization: ***'));
  CheckTrue(L.Contains('DEBUG http: < Content-Type: text/plain'));
  CheckTrue(L.Contains('DEBUG http: < Set-Cookie: ***'));
  CheckFalse(L.Contains('s3cret'));
  CheckFalse(L.Contains('zzz'));
end;
procedure TestRedactionCanBeTurnedOff;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  L := NewMemoryLogger;
  C := NewHttpClient(T).SetBearerToken('s3cret')
        .AddInterceptor(NewLoggingInterceptor(L, True, False));
  C.Get('http://h/x');
  CheckTrue(L.Contains('Authorization: Bearer s3cret'));
end;
procedure TestHeadersStayOutAtInfoLevel;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; L: IMemoryLogger;
begin
  T := NewFakeTransport(F);
  L := NewMemoryLogger(llInfo);
  C := NewHttpClient(T).SetHeader('X-Trace', '7').AddInterceptor(NewLoggingInterceptor(L, True));
  C.Get('http://h/x');
  CheckEqualsInt(2, L.Count, 'debug header lines are filtered out');
end;
initialization
  RegisterTest('Interceptors.LoggingInterceptor', 'logs request and response lines', TestLogsRequestAndResponse);
  RegisterTest('Interceptors.LoggingInterceptor', 'level follows the status class', TestLevelsFollowTheStatusClass);
  RegisterTest('Interceptors.LoggingInterceptor', 'logs failures with the exception', TestLogsFailures);
  RegisterTest('Interceptors.LoggingInterceptor', 'masks the password in URLs', TestUrlPasswordIsMasked);
  RegisterTest('Interceptors.LoggingInterceptor', 'logs headers with secrets redacted', TestHeadersAreLoggedAndRedacted);
  RegisterTest('Interceptors.LoggingInterceptor', 'redaction can be disabled', TestRedactionCanBeTurnedOff);
  RegisterTest('Interceptors.LoggingInterceptor', 'header lines respect the logger level', TestHeadersStayOutAtInfoLevel);
end.
