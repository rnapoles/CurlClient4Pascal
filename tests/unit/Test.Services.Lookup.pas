unit Test.Services.Lookup;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Services;

function Sample: IServiceDatabase;
begin
  Result := NewServiceDatabase;
  Result.LoadFromText('domain 53/tcp'#10 + 'domain 53/udp'#10 + 'http 80/tcp www'#10 +
    'https 443/tcp'#10 + 'https 443/udp h3'#10 + 'dup 1000/tcp'#10 + 'dup 2000/tcp'#10);
end;
procedure TestNameLookupIsCaseInsensitive;
var P: Integer;
begin
  CheckTrue(Sample.TryGetPort('HTTP', P)); CheckEqualsInt(80, P);
  CheckTrue(Sample.TryGetPort('WwW', P)); CheckEqualsInt(80, P);
end;
procedure TestProtocolFilter;
var Db: IServiceDatabase; P: Integer;
begin
  Db := Sample;
  CheckTrue(Db.TryGetPort('domain', P, 'udp')); CheckEqualsInt(53, P);
  CheckFalse(Db.TryGetPort('http', P, 'udp'), 'http is only tcp here');
  CheckTrue(Db.TryGetPort('h3', P, '')); CheckEqualsInt(443, P, 'any protocol');
  CheckFalse(Db.TryGetPort('h3', P), 'alias exists for udp only; default is tcp');
end;
procedure TestUnknownName;
var P: Integer;
begin
  CheckFalse(Sample.TryGetPort('nosuch', P));
  CheckEqualsInt(0, P);
end;
procedure TestFirstEntryWins;
var P: Integer;
begin
  CheckTrue(Sample.TryGetPort('dup', P));
  CheckEqualsInt(1000, P);
end;
procedure TestReverseLookupReturnsOfficialName;
var Db: IServiceDatabase; N: string;
begin
  Db := Sample;
  CheckTrue(Db.TryGetName(80, N));
  CheckEqualsStr('http', N, 'not the alias www');
  CheckTrue(Db.TryGetName(443, N, 'udp'));
  CheckEqualsStr('https', N);
  CheckFalse(Db.TryGetName(9999, N));
end;
initialization
  RegisterTest('Services.Lookup', 'name lookup is case-insensitive and includes aliases', TestNameLookupIsCaseInsensitive);
  RegisterTest('Services.Lookup', 'protocol filter and any-protocol lookup', TestProtocolFilter);
  RegisterTest('Services.Lookup', 'unknown name', TestUnknownName);
  RegisterTest('Services.Lookup', 'first entry for a name wins', TestFirstEntryWins);
  RegisterTest('Services.Lookup', 'reverse lookup returns the official name', TestReverseLookupReturnsOfficialName);
end.
