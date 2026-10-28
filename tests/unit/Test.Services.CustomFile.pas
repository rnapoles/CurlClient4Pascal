unit Test.Services.CustomFile;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Services, Http.Errors, Http.Url, Http.Utils, Test.Files;

function WriteServicesFile(const Name, Text: string): string;
var L: TStringList;
begin
  Result := GetTempDirectory + Name;
  L := TStringList.Create;
  try L.Text := Text; L.SaveToFile(Result); finally L.Free; end;
end;
procedure TestLoadFromFileAddsEntries;
var Db: IServiceDatabase; P: Integer; F: string;
begin
  F := WriteServicesFile('svc_custom1.txt', '# mine'#10 + 'myproto 4242/tcp mp'#10);
  try
    Db := NewServiceDatabase;
    CheckEqualsInt(2, Db.LoadFromFile(F));
    CheckTrue(Db.TryGetPort('mp', P)); CheckEqualsInt(4242, P);
  finally DeleteTempFile(F); end;
end;
var GPath: string;
procedure LoadMissing; begin NewServiceDatabase.LoadFromFile(GPath); end;
procedure LoadMissingGlobal; begin LoadServicesFile(GPath); end;
procedure TestMissingFileRaises;
begin
  GPath := GetTempDirectory + 'no_such_services_file';
  CheckRaises(EHttpError, LoadMissing);
  CheckRaises(EHttpError, LoadMissingGlobal);
end;
procedure TestLoadServicesFileReplacesTheDefault;
var F: string;
begin
  F := WriteServicesFile('svc_custom2.txt', 'acme 7777/tcp'#10);
  try
    LoadServicesFile(F);
    CheckEqualsInt(7777, ResolveServicePort('acme'));
    CheckEqualsInt(0, ResolveServicePort('ssh'), 'custom file replaces, not extends');
    CheckEqualsInt(7777, ParseUrl('acme://host/x').EffectivePort);
  finally SetDefaultServices(nil); DeleteTempFile(F); end;
end;
procedure TestFailedLoadKeepsPreviousDatabase;
var F: string;
begin
  F := WriteServicesFile('svc_custom3.txt', 'keepme 5555/tcp'#10);
  try
    LoadServicesFile(F);
    GPath := GetTempDirectory + 'no_such_services_file';
    try LoadServicesFile(GPath); except on EHttpError do ; end;
    CheckEqualsInt(5555, ResolveServicePort('keepme'));
  finally SetDefaultServices(nil); DeleteTempFile(F); end;
end;
initialization
  RegisterTest('Services.CustomFile', 'LoadFromFile reads a custom file', TestLoadFromFileAddsEntries);
  RegisterTest('Services.CustomFile', 'missing file raises EHttpError', TestMissingFileRaises);
  RegisterTest('Services.CustomFile', 'LoadServicesFile replaces the default database', TestLoadServicesFileReplacesTheDefault);
  RegisterTest('Services.CustomFile', 'a failed load keeps the previous database', TestFailedLoadKeepsPreviousDatabase);
end.
