unit Test.Url.Invalid;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url, Http.Errors;

var GS: string;
procedure Parse; begin ParseUrl(GS); end;
procedure CheckInvalid(const S: string);
begin
  GS := S;
  CheckRaises(EHttpError, Parse, S);
end;
procedure TestRejectsMalformed;
begin
  CheckInvalid('http://exa mple.com/');
  CheckInvalid('http://host/pa'#10'th');
  CheckInvalid('http://host:99999/');
  CheckInvalid('http://host:abc/');
  CheckInvalid('http://host:0/');
  CheckInvalid('http://[::1/');
  CheckInvalid('http://[::1]x/');
  CheckInvalid('http://::1/');
end;
procedure TestTryParseDoesNotRaise;
var U: IUrl;
begin
  CheckFalse(TryParseUrlObject('http://host:70000/', U));
  CheckTrue(U = nil);
  CheckTrue(TryParseUrlObject('http://host:7000/', U));
  CheckEqualsInt(7000, U.Port);
end;
procedure TestEmptyPortIsAccepted;
begin
  CheckEqualsInt(0, ParseUrl('http://host:/p').Port);
end;
initialization
  RegisterTest('Url.Invalid', 'rejects malformed URLs with EHttpError', TestRejectsMalformed);
  RegisterTest('Url.Invalid', 'TryParseUrlObject returns False instead of raising', TestTryParseDoesNotRaise);
  RegisterTest('Url.Invalid', 'an empty port is accepted', TestEmptyPortIsAccepted);
end.
