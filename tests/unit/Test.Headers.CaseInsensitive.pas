unit Test.Headers.CaseInsensitive;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Headers;

procedure TestGetIgnoresCase;
var H: THttpHeaders;
begin
  H := THttpHeaders.Create;
  try
    H.Add('Content-Type', 'text/plain');
    CheckEqualsStr('text/plain', H.Get('content-type'));
    CheckTrue(H.Contains('CONTENT-TYPE'));
  finally H.Free; end;
end;
procedure TestSetValueReplaces;
var H: THttpHeaders;
begin
  H := THttpHeaders.Create;
  try
    H.Add('X-A', '1'); H.Add('x-a', '2');
    H.SetValue('X-a', '3');
    CheckEqualsInt(1, H.Count);
    CheckEqualsStr('3', H.Get('X-A'));
  finally H.Free; end;
end;
procedure TestRemoveAndDefault;
var H: THttpHeaders;
begin
  H := THttpHeaders.Create;
  try
    H.Add('X-A', '1');
    CheckEqualsInt(1, H.Remove('x-a'));
    CheckEqualsStr('dflt', H.Get('X-A', 'dflt'));
  finally H.Free; end;
end;
initialization
  RegisterTest('Headers.CaseInsensitive', 'lookup ignores name case', TestGetIgnoresCase);
  RegisterTest('Headers.CaseInsensitive', 'SetValue replaces all case variants', TestSetValueReplaces);
  RegisterTest('Headers.CaseInsensitive', 'Remove returns count and Get falls back to default', TestRemoveAndDefault);
end.
