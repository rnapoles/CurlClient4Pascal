unit Test.Response.TextDecoding;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Response, Http.Utils;

function Make(const CT: string; const B: TBytes): IHttpResponse;
var R: THttpResponse;
begin
  R := THttpResponse.Create; Result := R; R.Headers.Add('Content-Type', CT); R.Body := B;
end;
procedure TestUtf8Default;
begin
  CheckEqualsStr(#$00E9, Make('text/plain', StringToBytes(#$00E9)).Text);
end;
procedure TestLatin1;
var B: TBytes;
begin
  SetLength(B, 1); B[0] := $E9;
  CheckEqualsStr(#$00E9, Make('text/plain; charset=ISO-8859-1', B).Text);
end;
procedure TestEmptyBody;
begin
  CheckEqualsStr('', Make('text/plain', nil).Text);
end;
initialization
  RegisterTest('Response.TextDecoding', 'decodes UTF-8 by default', TestUtf8Default);
  RegisterTest('Response.TextDecoding', 'honours charset=ISO-8859-1', TestLatin1);
  RegisterTest('Response.TextDecoding', 'empty body gives empty text', TestEmptyBody);
end.
