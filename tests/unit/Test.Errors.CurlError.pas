unit Test.Errors.CurlError;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Errors;

procedure TestCarriesCodeAndMessages;
var E: ECurlError;
begin
  E := ECurlError.Create(28, 'curl_easy_perform', 'Timeout was reached', 'Operation timed out');
  try
    CheckEqualsInt(28, E.Code);
    CheckEqualsStr('Timeout was reached', E.CurlMessage);
    CheckEqualsStr('curl_easy_perform', E.Operation);
    CheckContains('28', E.Message);
    CheckContains('Timeout was reached', E.Message);
    CheckContains('Operation timed out', E.Message);
  finally E.Free; end;
end;
procedure TestIsAnHttpError;
var E: ECurlError;
begin
  E := ECurlError.Create(7, 'x', 'y');
  try CheckTrue(E is EHttpError); finally E.Free; end;
end;
initialization
  RegisterTest('Errors.CurlError', 'exposes code, strerror and detail', TestCarriesCodeAndMessages);
  RegisterTest('Errors.CurlError', 'derives from EHttpError', TestIsAnHttpError);
end.
