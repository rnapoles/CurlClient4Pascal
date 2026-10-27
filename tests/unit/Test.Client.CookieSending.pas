unit Test.Client.CookieSending;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestCookieSentAsHeader;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetCookie('sid', 'abc').SetCookie('lang', 'en');
  C.Get('http://h/');
  CheckEqualsStr('sid=abc; lang=en', F.LastRequest.Headers.Get('Cookie'));
  CheckEqualsStr('abc', C.GetCookie('sid'));
end;
procedure TestCookieNotSentToOtherDomain;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetCookie('sid', 'abc', 'example.com');
  C.Get('http://evil.test/');
  CheckFalse(F.LastRequest.Headers.Contains('Cookie'));
end;
procedure TestExplicitCookieHeaderIsExtended;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetCookie('a', '1');
  C.Execute(C.NewRequest(hmGet, 'http://h/').SetHeader('Cookie', 'z=9'));
  CheckEqualsStr('z=9; a=1', F.LastRequest.Headers.Get('Cookie'));
end;
initialization
  RegisterTest('Client.CookieSending', 'jar cookies are sent as Cookie header', TestCookieSentAsHeader);
  RegisterTest('Client.CookieSending', 'domain-bound cookie is not sent to other hosts', TestCookieNotSentToOtherDomain);
  RegisterTest('Client.CookieSending', 'explicit Cookie header is extended, not replaced', TestExplicitCookieHeaderIsExtended);
end.
