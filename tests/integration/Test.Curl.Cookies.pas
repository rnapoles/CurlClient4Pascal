unit Test.Curl.Cookies;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestServerCookieIsReplayed;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  C.Get('/cookies/set?sid=s42&lang=pt');
  CheckEqualsStr('s42', C.GetCookie('sid'));
  R := C.Get('/echo');
  CheckJsonField(R.Text, 'cookie', 'sid=s42; lang=pt');
end;
procedure TestManualCookieIsSent;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetCookie('token', 't1').Get('/echo');
  CheckJsonField(R.Text, 'cookie', 'token=t1');
end;
procedure TestServerCanDeleteCookie;
var C: IHttpClient;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  C.Get('/cookies/set?sid=1');
  C.Get('/cookies/delete?sid');
  CheckEqualsStr('', C.GetCookie('sid'));
end;
initialization
  RegisterTest('Curl.Cookies', 'cookies set by the server are replayed', TestServerCookieIsReplayed);
  RegisterTest('Curl.Cookies', 'manually set cookie reaches the server', TestManualCookieIsSent);
  RegisterTest('Curl.Cookies', 'Max-Age=0 removes the stored cookie', TestServerCanDeleteCookie);
end.
