unit Test.Logging.MemoryLogger;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging;

procedure TestFormatAndAccess;
var L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  L.Log(llInfo, 'http', 'hello');
  L.Log(llWarning, 'curl', 'careful');
  CheckEqualsInt(2, L.Count);
  CheckEqualsStr('INFO http: hello', L[0]);
  CheckEqualsStr('WARN curl: careful', L.Lines[1]);
  CheckTrue(L.Contains('careful'));
  CheckFalse(L.Contains('absent'));
  CheckContains('hello', L.Text);
end;
procedure TestClear;
var L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  L.Log(llError, 'x', 'y');
  L.Clear;
  CheckEqualsInt(0, L.Count);
end;
initialization
  RegisterTest('Logging.MemoryLogger', 'formats lines and gives indexed access', TestFormatAndAccess);
  RegisterTest('Logging.MemoryLogger', 'Clear empties the log', TestClear);
end.
