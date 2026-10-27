unit Test.Headers.Validation;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Headers, Http.Errors;

var GH: THttpHeaders;
procedure BadValue; begin GH.Add('X', 'a'#13#10'Injected: 1'); end;
procedure EmptyName; begin GH.Add('', 'v'); end;
procedure SpaceInName; begin GH.Add('Bad Name', 'v'); end;
procedure ColonInName; begin GH.SetValue('A:B', 'v'); end;
procedure TestRejects;
begin
  GH := THttpHeaders.Create;
  try
    CheckRaises(EHttpError, BadValue, 'CRLF injection');
    CheckRaises(EHttpError, EmptyName);
    CheckRaises(EHttpError, SpaceInName);
    CheckRaises(EHttpError, ColonInName);
    CheckEqualsInt(0, GH.Count);
  finally GH.Free; end;
end;
initialization
  RegisterTest('Headers.Validation', 'rejects CRLF injection and malformed names', TestRejects);
end.
