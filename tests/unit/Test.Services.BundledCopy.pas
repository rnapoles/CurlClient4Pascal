unit Test.Services.BundledCopy;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Services;

procedure TestBundledFileIsFoundAndComplete;
var Db: IServiceDatabase; P: Integer; N: string;
begin
  if DefaultServicesFile = '' then
    Skip('bundled data/services not found next to the executable');
  Db := NewServiceDatabase;
  CheckTrue(Db.LoadFromFile(DefaultServicesFile) > 200, 'full IANA list');
  CheckTrue(Db.TryGetPort('http', P)); CheckEqualsInt(80, P);
  CheckTrue(Db.TryGetPort('https', P)); CheckEqualsInt(443, P);
  CheckTrue(Db.TryGetPort('ssh', P)); CheckEqualsInt(22, P);
  CheckTrue(Db.TryGetPort('www', P)); CheckEqualsInt(80, P, 'alias');
  CheckTrue(Db.TryGetName(25, N)); CheckEqualsStr('smtp', N);
end;
procedure TestDefaultDatabaseResolvesCommonSchemes;
begin
  SetDefaultServices(nil);                  // force a fresh default load
  CheckEqualsInt(80, ResolveServicePort('http'));
  CheckEqualsInt(443, ResolveServicePort('https'));
  CheckEqualsInt(21, ResolveServicePort('ftp'));
end;
procedure TestBuiltinFallbackTable;
var Db: IServiceDatabase; P: Integer;
begin
  Db := NewBuiltinServices;
  CheckTrue(Db.TryGetPort('http', P)); CheckEqualsInt(80, P);
  CheckTrue(Db.TryGetPort('https', P)); CheckEqualsInt(443, P);
  CheckTrue(Db.TryGetPort('ftp', P)); CheckEqualsInt(21, P);
end;
procedure TestWebSocketSchemesAreNotInEtcServices;
begin
  CheckEqualsInt(80, ResolveServicePort('ws'));
  CheckEqualsInt(443, ResolveServicePort('wss'));
  CheckEqualsInt(0, ResolveServicePort('nosuchscheme'));
  CheckEqualsInt(0, ResolveServicePort(''));
end;
initialization
  RegisterTest('Services.BundledCopy', 'bundled data/services is found and complete', TestBundledFileIsFoundAndComplete);
  RegisterTest('Services.BundledCopy', 'default database resolves http, https, ftp', TestDefaultDatabaseResolvesCommonSchemes);
  RegisterTest('Services.BundledCopy', 'built-in fallback table', TestBuiltinFallbackTable);
  RegisterTest('Services.BundledCopy', 'ws and wss use the web-socket fallback', TestWebSocketSchemesAreNotInEtcServices);
end.
