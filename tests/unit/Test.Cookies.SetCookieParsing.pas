unit Test.Cookies.SetCookieParsing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Cookies;

procedure TestStoresHostOnlyCookie;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    CheckTrue(J.StoreFromSetCookie('http://h.test/a/b', 'sid=xyz; HttpOnly'));
    CheckEqualsStr('sid=xyz', J.BuildCookieHeader('http://h.test/a/c'));
    CheckEqualsStr('', J.BuildCookieHeader('http://sub.h.test/a/c'), 'host-only');
    CheckEqualsStr('', J.BuildCookieHeader('http://h.test/other'), 'default path is /a');
  finally J.Free; end;
end;
procedure TestDomainAttributeWidens;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    CheckTrue(J.StoreFromSetCookie('http://a.example.com/', 't=1; Domain=.example.com; Path=/'));
    CheckEqualsStr('t=1', J.BuildCookieHeader('http://b.example.com/'));
  finally J.Free; end;
end;
procedure TestRejectsForeignDomain;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    CheckFalse(J.StoreFromSetCookie('http://a.example.com/', 't=1; Domain=evil.com'));
    CheckEqualsInt(0, J.Count);
  finally J.Free; end;
end;
procedure TestMaxAgeZeroDeletes;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.StoreFromSetCookie('http://h/', 'a=1; Path=/');
    J.StoreFromSetCookie('http://h/', 'a=; Max-Age=0; Path=/');
    CheckEqualsInt(0, J.Count);
  finally J.Free; end;
end;
procedure TestPastExpiresDeletes;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.StoreFromSetCookie('http://h/', 'a=1; Path=/');
    J.StoreFromSetCookie('http://h/', 'a=; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/');
    CheckEqualsInt(0, J.Count);
  finally J.Free; end;
end;
initialization
  RegisterTest('Cookies.SetCookieParsing', 'stores a host-only cookie with default path', TestStoresHostOnlyCookie);
  RegisterTest('Cookies.SetCookieParsing', 'Domain attribute widens the scope', TestDomainAttributeWidens);
  RegisterTest('Cookies.SetCookieParsing', 'rejects cookies for foreign domains', TestRejectsForeignDomain);
  RegisterTest('Cookies.SetCookieParsing', 'Max-Age=0 deletes the cookie', TestMaxAgeZeroDeletes);
  RegisterTest('Cookies.SetCookieParsing', 'past Expires deletes the cookie', TestPastExpiresDeletes);
end.
