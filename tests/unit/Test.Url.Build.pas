unit Test.Url.Build;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url;

procedure TestRoundTripOfCanonicalUrl;
const S = 'https://ana:pw@example.com:8443/a/b?x=1&y=two%20words#top';
begin
  CheckEqualsStr(S, ParseUrl(S).Build);
end;
procedure TestEditPartsThenBuild;
var U: IUrl;
begin
  U := ParseUrl('http://old.test/p?a=1#f');
  U.Scheme := 'HTTPS';
  U.Host := 'new.test';
  U.Port := 9000;
  U.Path := '/v2/items';
  U.Query.SetValue('a', 'x y');
  U.Query.Add('page', '2');
  U.Fragment := '';
  CheckEqualsStr('https://new.test:9000/v2/items?a=x%20y&page=2', U.Build);
end;
procedure TestRelativeAndFileUrlsRoundTrip;
begin
  CheckEqualsStr('/a/b?x=1', ParseUrl('/a/b?x=1').Build);
  CheckEqualsStr('//cdn.test/lib.js', ParseUrl('//cdn.test/lib.js').Build);
  CheckEqualsStr('file:///etc/hosts', ParseUrl('file:///etc/hosts').Build);
  CheckEqualsStr('mailto:ana@example.com', ParseUrl('mailto:ana@example.com').Build);
end;
procedure TestIpv6IsBracketedAgain;
begin
  CheckEqualsStr('http://[::1]:8080/', ParseUrl('http://[::1]:8080/').Build);
end;
procedure TestQueryNormalisation;
begin
  CheckEqualsStr('http://h/?a=b%20c&flag=', ParseUrl('http://h/?a=b+c&flag').Build);
end;
procedure TestBuildAddsMissingSlash;
var U: IUrl;
begin
  U := ParseUrl('http://h');
  U.Path := 'docs';
  CheckEqualsStr('http://h/docs', U.Build);
end;
procedure TestBadPortSetterRejected;
var U: IUrl; Raised: Boolean;
begin
  U := ParseUrl('http://h/');
  Raised := False;
  try U.Port := 70000; except on E: Exception do Raised := True; end;
  CheckTrue(Raised);
end;
initialization
  RegisterTest('Url.Build', 'canonical URL survives a round trip', TestRoundTripOfCanonicalUrl);
  RegisterTest('Url.Build', 'edited parts are re-assembled', TestEditPartsThenBuild);
  RegisterTest('Url.Build', 'relative, network-path, file and mailto URLs', TestRelativeAndFileUrlsRoundTrip);
  RegisterTest('Url.Build', 'IPv6 hosts get their brackets back', TestIpv6IsBracketedAgain);
  RegisterTest('Url.Build', 'query is re-encoded canonically', TestQueryNormalisation);
  RegisterTest('Url.Build', 'adds the slash between host and a relative path', TestBuildAddsMissingSlash);
  RegisterTest('Url.Build', 'Port setter validates its range', TestBadPortSetterRejected);
end.
