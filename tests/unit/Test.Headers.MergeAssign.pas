unit Test.Headers.MergeAssign;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Headers;

procedure TestAssignCopies;
var A, B: THttpHeaders;
begin
  A := THttpHeaders.Create; B := THttpHeaders.Create;
  try
    A.Add('X', '1'); B.Add('Old', 'z');
    B.Assign(A);
    A.SetValue('X', 'changed');
    CheckEqualsInt(1, B.Count);
    CheckEqualsStr('1', B.Get('X'));
  finally A.Free; B.Free; end;
end;
procedure TestMergeOverrides;
var A, B: THttpHeaders;
begin
  A := THttpHeaders.Create; B := THttpHeaders.Create;
  try
    A.Add('Accept', 'a'); A.Add('Keep', 'k');
    B.Add('ACCEPT', 'b1'); B.Add('Accept', 'b2');
    A.Merge(B);
    CheckEqualsStr('k', A.Get('Keep'));
    CheckEqualsInt(2, Length(A.GetAll('accept')));
    CheckEqualsStr('b1', A.Get('accept'));
  finally A.Free; B.Free; end;
end;
initialization
  RegisterTest('Headers.MergeAssign', 'Assign makes an independent copy', TestAssignCopies);
  RegisterTest('Headers.MergeAssign', 'Merge replaces same-name headers only', TestMergeOverrides);
end.
