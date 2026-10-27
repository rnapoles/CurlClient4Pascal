unit Test.Client.CookieStoring;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestSetCookieIsStoredAndResent;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  F.AddResponseHeader('Set-Cookie', 'sid=s1; Path=/');
  C := NewHttpClient(T);
  C.Get('http://h/login');
  CheckEqualsStr('s1', C.GetCookie('sid'));
  C.Get('http://h/next');
  CheckEqualsStr('sid=s1', F.LastRequest.Headers.Get('Cookie'));
end;
procedure TestCookieFileDisablesPascalJar;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  F.AddResponseHeader('Set-Cookie', 'sid=s1; Path=/');
  C := NewHttpClient(T).SetCookieFile('cookies.txt');
  C.Get('http://h/');
  CheckEqualsInt(0, C.Cookies.Count, 'libcurl engine owns cookies');
end;
initialization
  RegisterTest('Client.CookieStoring', 'Set-Cookie is stored and re-sent', TestSetCookieIsStoredAndResent);
  RegisterTest('Client.CookieStoring', 'CookieFile leaves storage to libcurl', TestCookieFileDisablesPascalJar);
end.
