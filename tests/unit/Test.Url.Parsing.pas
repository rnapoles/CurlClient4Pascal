unit Test.Url.Parsing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url;

procedure TestAllComponents;
var U: IUrl;
begin
  U := ParseUrl('HTTPS://ana:s3cret@Example.com:8443/a/b.html?x=1&y=two#top');
  CheckEqualsStr('https', U.Scheme, 'scheme is lower-cased');
  CheckEqualsStr('ana', U.User);
  CheckEqualsStr('s3cret', U.Password);
  CheckEqualsStr('Example.com', U.Host);
  CheckEqualsInt(8443, U.Port);
  CheckEqualsStr('/a/b.html', U.Path);
  CheckEqualsStr('x=1&y=two', U.RawQuery);
  CheckEqualsStr('top', U.Fragment);
  CheckTrue(U.IsAbsolute);
end;
procedure TestMinimalUrlAndDefaultPorts;
var U: IUrl;
begin
  U := ParseUrl('http://example.com');
  CheckEqualsStr('example.com', U.Host);
  CheckEqualsInt(0, U.Port, 'no explicit port');
  CheckEqualsInt(80, U.EffectivePort);
  CheckEqualsStr('', U.Path);
  CheckEqualsInt(443, ParseUrl('https://h/').EffectivePort);
  CheckEqualsInt(0, ParseUrl('nosuchscheme://h/').EffectivePort);
end;
procedure TestUserWithoutPassword;
var U: IUrl;
begin
  U := ParseUrl('ftp://bob@files.test/pub');
  CheckEqualsStr('bob', U.User);
  CheckEqualsStr('', U.Password);
  CheckEqualsStr('files.test', U.Host);
end;
procedure TestIpv6Host;
var U: IUrl;
begin
  U := ParseUrl('http://[2001:db8::1]:8080/x');
  CheckEqualsStr('2001:db8::1', U.Host, 'brackets removed');
  CheckEqualsInt(8080, U.Port);
  CheckEqualsStr('[2001:db8::1]:8080', U.Authority);
end;
procedure TestRelativeReferences;
var U: IUrl;
begin
  U := ParseUrl('/api/v1/items?id=7#frag');
  CheckEqualsStr('', U.Scheme);
  CheckEqualsStr('', U.Host);
  CheckEqualsStr('/api/v1/items', U.Path);
  CheckEqualsStr('7', U.Query.Get('id'));
  CheckFalse(U.IsAbsolute);
  U := ParseUrl('//cdn.test/lib.js');
  CheckEqualsStr('cdn.test', U.Host);
  CheckEqualsStr('/lib.js', U.Path);
  U := ParseUrl('docs/readme.txt');
  CheckEqualsStr('docs/readme.txt', U.Path);
end;
procedure TestSchemeWithoutAuthority;
var U: IUrl;
begin
  U := ParseUrl('mailto:ana@example.com');
  CheckEqualsStr('mailto', U.Scheme);
  CheckEqualsStr('ana@example.com', U.Path);
  CheckEqualsStr('', U.Host);
end;
procedure TestEmptyString;
var U: IUrl;
begin
  U := ParseUrl('');
  CheckEqualsStr('', U.Path);
  CheckEqualsInt(0, U.Query.Count);
end;
initialization
  RegisterTest('Url.Parsing', 'splits every component', TestAllComponents);
  RegisterTest('Url.Parsing', 'minimal URL and default ports', TestMinimalUrlAndDefaultPorts);
  RegisterTest('Url.Parsing', 'user without password', TestUserWithoutPassword);
  RegisterTest('Url.Parsing', 'IPv6 literal host', TestIpv6Host);
  RegisterTest('Url.Parsing', 'relative references', TestRelativeReferences);
  RegisterTest('Url.Parsing', 'scheme without authority (mailto:)', TestSchemeWithoutAuthority);
  RegisterTest('Url.Parsing', 'empty string parses to an empty URL', TestEmptyString);
end.
