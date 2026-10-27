unit Test.Curl.Gzip;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestTransparentDecompression;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Get('/gzip');
  CheckContains('gzipped', R.Text);
end;
initialization
  RegisterTest('Curl.Gzip', 'gzip responses are decoded automatically', TestTransparentDecompression);
end.
