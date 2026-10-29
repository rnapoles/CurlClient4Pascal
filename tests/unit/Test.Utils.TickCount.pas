unit Test.Utils.TickCount;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Utils;

procedure TestIsMonotonic;
var A, B: Int64;
begin
  A := TickCountMs;
  Sleep(30);
  B := TickCountMs;
  CheckTrue(B >= A, 'never goes backwards');
  CheckTrue(B - A < 5000, 'sane magnitude');
end;
initialization
  RegisterTest('Utils.TickCount', 'TickCountMs advances monotonically', TestIsMonotonic);
end.
