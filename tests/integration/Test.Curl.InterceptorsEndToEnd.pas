unit Test.Curl.InterceptorsEndToEnd;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Logging, Http.Interceptors, Http.Curl.Transport;

procedure TestBearerAndHeadersReachTheServer;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl)
    .AddInterceptor(NewBearerTokenInterceptor('tok-123'))
    .AddInterceptor(NewHeadersInterceptor(['X-App', 'demo']));
  R := C.Get('/echo');
  CheckJsonField(R.Text, 'authorization', 'Bearer tok-123');
  CheckJsonField(R.Text, 'x-app', 'demo');
end;
procedure TestLoggingAndTimingOverRealRequests;
var C: IHttpClient; L: IMemoryLogger; Tm: ITimingInterceptor;
begin
  L := NewMemoryLogger;
  Tm := NewTimingInterceptor;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl)
    .AddInterceptor(NewLoggingInterceptor(L)).AddInterceptor(Tm);
  C.Get('/echo');
  C.Get('/status/404');
  C.Get('/status/500');
  CheckEqualsInt(3, Tm.RequestCount);
  CheckEqualsInt(0, Tm.ErrorCount, 'HTTP error statuses are responses, not failures');
  CheckTrue(L.Contains('INFO http: <-- 200 OK GET'));
  CheckTrue(L.Contains('WARN http: <-- 404 Not Found GET'));
  CheckTrue(L.Contains('ERROR http: <-- 500 Internal Server Error GET'));
end;
procedure TestTransportFailuresReachOnError;
var C: IHttpClient; L: IMemoryLogger; Tm: ITimingInterceptor;
begin
  L := NewMemoryLogger;
  Tm := NewTimingInterceptor;
  C := NewHttpClient.SetConnectTimeout(2000)
    .AddInterceptor(NewLoggingInterceptor(L)).AddInterceptor(Tm);
  try C.Get('http://127.0.0.1:1/'); except on ECurlError do ; end;
  CheckEqualsInt(1, Tm.ErrorCount);
  CheckTrue(L.Contains('ERROR http: !!! GET http://127.0.0.1:1/ failed after'));
  CheckTrue(L.Contains('ECurlError'));
end;
procedure TestInterceptorsWorkWithUploads;
var C: IHttpClient; Tm: ITimingInterceptor; R: IHttpResponse; B: TBytes;
begin
  Tm := NewTimingInterceptor;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl)
    .AddInterceptor(NewBearerTokenInterceptor('up-tok')).AddInterceptor(Tm);
  SetLength(B, 1000);
  R := C.Execute(C.NewRequest(hmPost, '/upload').AddMultipartBytes('f', 'x.bin', B));
  CheckEqualsInt(200, R.StatusCode);
  CheckEqualsInt(1, Tm.RequestCount);
end;
initialization
  RegisterTest('Curl.InterceptorsEndToEnd', 'bearer and header interceptors reach the server', TestBearerAndHeadersReachTheServer);
  RegisterTest('Curl.InterceptorsEndToEnd', 'logging and timing over real requests', TestLoggingAndTimingOverRealRequests);
  RegisterTest('Curl.InterceptorsEndToEnd', 'transport failures reach OnError', TestTransportFailuresReachOnError);
  RegisterTest('Curl.InterceptorsEndToEnd', 'interceptors work with multipart uploads', TestInterceptorsWorkWithUploads);
end.
