unit Test.Headers.MultiValue;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Headers, Http.Utils;

procedure TestAddKeepsDuplicates;
var H: THttpHeaders; A: THttpStringArray;
begin
  H := THttpHeaders.Create;
  try
    H.Add('Set-Cookie', 'a=1'); H.Add('Set-Cookie', 'b=2');
    CheckEqualsInt(2, H.Count);
    A := H.GetAll('set-cookie');
    CheckEqualsInt(2, Length(A));
    CheckEqualsStr('b=2', A[1]);
  finally H.Free; end;
end;
procedure TestGetReturnsFirst;
var H: THttpHeaders;
begin
  H := THttpHeaders.Create;
  try
    H.Add('X', 'one'); H.Add('X', 'two');
    CheckEqualsStr('one', H.Get('X'));
  finally H.Free; end;
end;
procedure TestParseLine;
var H: THttpHeaders;
begin
  H := THttpHeaders.Create;
  try
    CheckTrue(H.TryAddLine('Content-Length:   42  '));
    CheckEqualsStr('42', H.Get('content-length'));
    CheckTrue(H.TryAddLine('Date: Mon, 01 Jan 2024 10:00:00 GMT'));
    CheckEqualsStr('Mon, 01 Jan 2024 10:00:00 GMT', H.Get('Date'));
    CheckFalse(H.TryAddLine('no colon here'));
  finally H.Free; end;
end;
initialization
  RegisterTest('Headers.MultiValue', 'Add keeps duplicates and GetAll returns them', TestAddKeepsDuplicates);
  RegisterTest('Headers.MultiValue', 'Get returns the first value', TestGetReturnsFirst);
  RegisterTest('Headers.MultiValue', 'TryAddLine parses wire format', TestParseLine);
end.
