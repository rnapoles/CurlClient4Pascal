unit Test.Utils.UrlParts;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Utils;

procedure TestFullUrl;
var P: TUrlParts;
begin
  CheckTrue(TryParseUrl('HTTPS://User:pw@Example.com:8443/a/b?x=1#frag', P));
  CheckEqualsStr('https', P.Scheme);
  CheckEqualsStr('example.com', P.Host);
  CheckEqualsInt(8443, P.Port);
  CheckEqualsStr('/a/b', P.Path);
  CheckEqualsStr('x=1', P.Query);
end;
procedure TestDefaultPortsAndPath;
var P: TUrlParts;
begin
  CheckTrue(TryParseUrl('http://h', P));
  CheckEqualsInt(80, P.Port);
  CheckEqualsStr('/', P.Path);
  CheckTrue(TryParseUrl('https://h?q=1', P));
  CheckEqualsInt(443, P.Port);
  CheckEqualsStr('q=1', P.Query);
end;
procedure TestIpv6;
var P: TUrlParts;
begin
  CheckTrue(TryParseUrl('http://[::1]:8080/x', P));
  CheckEqualsStr('::1', P.Host);
  CheckEqualsInt(8080, P.Port);
end;
procedure TestRejectsGarbage;
var P: TUrlParts;
begin
  CheckFalse(TryParseUrl('not a url', P));
  CheckFalse(TryParseUrl('http:///path', P));
end;
initialization
  RegisterTest('Utils.UrlParts', 'parses all components', TestFullUrl);
  RegisterTest('Utils.UrlParts', 'applies default port and path', TestDefaultPortsAndPath);
  RegisterTest('Utils.UrlParts', 'parses IPv6 literal hosts', TestIpv6);
  RegisterTest('Utils.UrlParts', 'rejects malformed URLs', TestRejectsGarbage);
end.
