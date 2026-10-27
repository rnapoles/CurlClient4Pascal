unit Test.Utils.UrlEncode;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Utils;

procedure TestSpaceAndReserved;
begin
  CheckEqualsStr('a%20b%26c%3Dd', UrlEncode('a b&c=d'));
end;
procedure TestUnreservedKept;
begin
  CheckEqualsStr('AZaz09-._~', UrlEncode('AZaz09-._~'));
end;
procedure TestUnicodeIsUtf8;
begin
  CheckEqualsStr('%C3%A9', UrlEncode(#$00E9));
end;
procedure TestDecodeRoundTrip;
begin
  CheckEqualsStr('caf'+#$00E9+' & co', UrlDecode(UrlEncode('caf'+#$00E9+' & co')));
end;
procedure TestPlusAsSpaceOnlyWhenAsked;
begin
  CheckEqualsStr('a+b', UrlDecode('a+b'));
  CheckEqualsStr('a b', UrlDecode('a+b', True));
end;
initialization
  RegisterTest('Utils.UrlEncode', 'encodes space and reserved characters', TestSpaceAndReserved);
  RegisterTest('Utils.UrlEncode', 'keeps unreserved characters', TestUnreservedKept);
  RegisterTest('Utils.UrlEncode', 'encodes non-ASCII as UTF-8', TestUnicodeIsUtf8);
  RegisterTest('Utils.UrlEncode', 'decode reverses encode', TestDecodeRoundTrip);
  RegisterTest('Utils.UrlEncode', 'plus is a space only when requested', TestPlusAsSpaceOnlyWhenAsked);
end.
