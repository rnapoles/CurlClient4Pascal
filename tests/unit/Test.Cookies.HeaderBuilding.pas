unit Test.Cookies.HeaderBuilding;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Cookies;

procedure TestJoinsMatchingCookies;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.SetCookie('a', '1'); J.SetCookie('b', '2');
    CheckEqualsStr('a=1; b=2', J.BuildCookieHeader('http://h/x'));
  finally J.Free; end;
end;
procedure TestDomainScoping;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.SetCookie('a', '1', 'example.com');
    CheckEqualsStr('a=1', J.BuildCookieHeader('http://example.com/'));
    CheckEqualsStr('a=1', J.BuildCookieHeader('http://api.example.com/'));
    CheckEqualsStr('', J.BuildCookieHeader('http://notexample.com/'));
    CheckEqualsStr('', J.BuildCookieHeader('http://evil.org/'));
  finally J.Free; end;
end;
procedure TestPathScoping;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.SetCookie('a', '1', '', '/api');
    CheckEqualsStr('a=1', J.BuildCookieHeader('http://h/api'));
    CheckEqualsStr('a=1', J.BuildCookieHeader('http://h/api/v1'));
    CheckEqualsStr('', J.BuildCookieHeader('http://h/apix'));
    CheckEqualsStr('', J.BuildCookieHeader('http://h/other'));
  finally J.Free; end;
end;
procedure TestSecureOnlyOverHttps;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.SetCookie('a', '1', '', '/', True);
    CheckEqualsStr('', J.BuildCookieHeader('http://h/'));
    CheckEqualsStr('a=1', J.BuildCookieHeader('https://h/'));
  finally J.Free; end;
end;
initialization
  RegisterTest('Cookies.HeaderBuilding', 'joins cookies with semicolons', TestJoinsMatchingCookies);
  RegisterTest('Cookies.HeaderBuilding', 'respects Domain scoping', TestDomainScoping);
  RegisterTest('Cookies.HeaderBuilding', 'respects Path scoping', TestPathScoping);
  RegisterTest('Cookies.HeaderBuilding', 'Secure cookies only go over https', TestSecureOnlyOverHttps);
end.
