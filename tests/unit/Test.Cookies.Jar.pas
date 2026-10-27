unit Test.Cookies.Jar;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Cookies;

procedure TestSetGetRemove;
var J: THttpCookieJar;
begin
  J := THttpCookieJar.Create;
  try
    J.SetCookie('sid', 'abc');
    CheckEqualsStr('abc', J.Get('sid'));
    J.SetCookie('sid', 'def');
    CheckEqualsInt(1, J.Count);
    CheckEqualsStr('def', J.Get('sid'));
    CheckEqualsInt(1, J.Remove('sid'));
    CheckFalse(J.Contains('sid'));
  finally J.Free; end;
end;
procedure TestAssignCopies;
var A, B: THttpCookieJar;
begin
  A := THttpCookieJar.Create; B := THttpCookieJar.Create;
  try
    A.SetCookie('a', '1');
    B.Assign(A); A.Clear;
    CheckEqualsStr('1', B.Get('a'));
  finally A.Free; B.Free; end;
end;
initialization
  RegisterTest('Cookies.Jar', 'set, replace, get and remove', TestSetGetRemove);
  RegisterTest('Cookies.Jar', 'Assign copies the content', TestAssignCopies);
end.
