unit Test.Curl.ResponseStream;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestBodyGoesToStream;
var C: IHttpClient; M: TMemoryStream; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  M := TMemoryStream.Create;
  try
    R := C.Execute(C.NewRequest(hmGet, '/bytes/100000').SaveResponseTo(M));
    CheckEqualsInt(100000, M.Size);
    CheckEqualsInt(0, Length(R.Body), 'not buffered in memory');
  finally M.Free; end;
end;
initialization
  RegisterTest('Curl.ResponseStream', 'SaveResponseTo streams the body', TestBodyGoesToStream);
end.
