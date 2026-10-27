unit Test.Curl.Get;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestGetReturnsBodyAndStatus;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  R := C.Get('/echo?a=1');
  CheckEqualsInt(200, R.StatusCode);
  CheckEqualsStr('OK', R.StatusText);
  CheckJsonField(R.Text, 'method', 'GET');
  CheckJsonField(R.Text, 'a', '1');
  CheckContains('application/json', R.ContentType);
  CheckTrue(R.TotalTimeMs >= 0);
  CheckContains('/echo', R.EffectiveUrl);
end;
initialization
  RegisterTest('Curl.Get', 'GET returns status, headers and body', TestGetReturnsBodyAndStatus);
end.
