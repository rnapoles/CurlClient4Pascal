unit Test.Url.EffectivePort;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Url, Http.Services;

procedure TestExplicitPortWins;
begin
  CheckEqualsInt(8080, ParseUrl('http://h:8080/').EffectivePort);
end;
procedure TestSchemeResolvedThroughServices;
var Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  Db.LoadFromText('http 80/tcp'#10 + 'gopher 70/tcp'#10 + 'mqtt 1883/tcp'#10);
  SetDefaultServices(Db);
  try
    CheckEqualsInt(80, ParseUrl('http://h/').EffectivePort);
    CheckEqualsInt(70, ParseUrl('gopher://h/').EffectivePort);
    CheckEqualsInt(1883, ParseUrl('MQTT://h/').EffectivePort, 'scheme is case-insensitive');
    CheckEqualsInt(0, ParseUrl('nosuch://h/').EffectivePort);
    CheckEqualsInt(0, ParseUrl('/relative/path').EffectivePort, 'no scheme');
  finally SetDefaultServices(nil); end;
end;
procedure TestExplicitPortIsNotTouchedByServices;
var Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  Db.LoadFromText('http 81/tcp');
  SetDefaultServices(Db);
  try
    CheckEqualsInt(81, ParseUrl('http://h/').EffectivePort);
    CheckEqualsInt(0, ParseUrl('http://h/').Port, 'Port stays 0 = not given');
  finally SetDefaultServices(nil); end;
end;
procedure TestWsFallbackWhenAbsentFromDatabase;
var Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  SetDefaultServices(Db);
  try
    CheckEqualsInt(80, ParseUrl('ws://h/').EffectivePort);
    CheckEqualsInt(443, ParseUrl('wss://h/').EffectivePort);
  finally SetDefaultServices(nil); end;
end;
initialization
  RegisterTest('Url.EffectivePort', 'explicit port wins', TestExplicitPortWins);
  RegisterTest('Url.EffectivePort', 'scheme is resolved through the services database', TestSchemeResolvedThroughServices);
  RegisterTest('Url.EffectivePort', 'Port stays 0 while EffectivePort resolves', TestExplicitPortIsNotTouchedByServices);
  RegisterTest('Url.EffectivePort', 'ws/wss fall back when the database lacks them', TestWsFallbackWhenAbsentFromDatabase);
end.
