unit Test.Curl.VerboseLogging;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Logging, Http.Interceptors, Http.Curl.Transport;

procedure TestTraceGoesToTheLogger;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L);
  C.Get('/echo?q=1');
  CheckTrue(L.Contains('DEBUG curl: > GET /echo?q=1 HTTP/1.'), 'request line');
  CheckTrue(L.Contains('DEBUG curl: < HTTP/1.1 200'), 'status line');
  CheckTrue(L.Contains('DEBUG curl: > Host: 127.0.0.1'), 'request header');
  CheckTrue(L.Contains('DEBUG curl: < Content-Type: application/json'), 'response header');
  CheckTrue(L.Contains('DEBUG curl: * '), 'informational text');
end;
procedure TestNothingIsLoggedWithoutVerbose;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetLogger(L);
  C.Get('/echo');
  CheckEqualsInt(0, L.Count);
end;
procedure TestLoggerLevelFiltersTheTrace;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger(llInfo);
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L);
  C.Get('/echo');
  CheckEqualsInt(0, L.Count, 'trace is debug level');
end;
procedure TestBodyIsNotInTheTrace;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L);
  C.Post('/echo', 'UNIQUE-BODY-MARKER-12345');
  CheckFalse(L.Contains('UNIQUE-BODY-MARKER-12345'));
end;
procedure TestVerboseTraceOnUploadAndRedirect;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L);
  C.Get('/redirect/2');
  CheckTrue(L.Contains('< HTTP/1.1 302'), 'redirect hop visible');
  CheckTrue(L.Contains('< HTTP/1.1 200'), 'final response visible');
end;
initialization
  RegisterTest('Curl.VerboseLogging', 'libcurl trace is routed to the logger', TestTraceGoesToTheLogger);
  RegisterTest('Curl.VerboseLogging', 'no trace without Verbose', TestNothingIsLoggedWithoutVerbose);
  RegisterTest('Curl.VerboseLogging', 'logger level filters the debug trace', TestLoggerLevelFiltersTheTrace);
  RegisterTest('Curl.VerboseLogging', 'request body is not part of the trace', TestBodyIsNotInTheTrace);
  RegisterTest('Curl.VerboseLogging', 'redirect hops appear in the trace', TestVerboseTraceOnUploadAndRedirect);
end.
