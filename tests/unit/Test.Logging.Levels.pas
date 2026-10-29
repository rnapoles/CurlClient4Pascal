unit Test.Logging.Levels;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging;

procedure TestMinLevelFilters;
var L: IMemoryLogger;
begin
  L := NewMemoryLogger(llWarning);
  L.Log(llDebug, 'c', 'd');
  L.Log(llInfo, 'c', 'i');
  L.Log(llWarning, 'c', 'w');
  L.Log(llError, 'c', 'e');
  CheckEqualsInt(2, L.Count);
  CheckFalse(L.IsEnabled(llInfo));
  CheckTrue(L.IsEnabled(llWarning));
  CheckTrue(L.IsEnabled(llError));
end;
procedure TestDebugEnablesEverything;
var L: IMemoryLogger;
begin
  L := NewMemoryLogger(llDebug);
  L.Log(llDebug, 'c', 'd');
  CheckEqualsInt(1, L.Count);
  CheckTrue(L.IsEnabled(llDebug));
end;
procedure TestLevelNames;
begin
  CheckEqualsStr('DEBUG', LogLevelName(llDebug));
  CheckEqualsStr('ERROR', LogLevelName(llError));
end;
initialization
  RegisterTest('Logging.Levels', 'MinLevel filters lower levels', TestMinLevelFilters);
  RegisterTest('Logging.Levels', 'llDebug lets everything through', TestDebugEnablesEverything);
  RegisterTest('Logging.Levels', 'level names', TestLevelNames);
end.
