unit Test.Curl.StatusCodes;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestErrorStatusIsNotAnException;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Get('/status/404');
  CheckEqualsInt(404, R.StatusCode);
  CheckTrue(R.IsClientError);
  CheckEqualsStr('status 404', R.Text);
end;
var GR: IHttpResponse;
procedure Ensure; begin GR.EnsureSuccess; end;
procedure TestEnsureSuccessRaises;
begin
  GR := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Get('/status/503');
  CheckTrue(GR.IsServerError);
  CheckRaises(EHttpStatusError, Ensure);
  GR := nil;
end;
initialization
  RegisterTest('Curl.StatusCodes', '4xx is returned, not raised', TestErrorStatusIsNotAnException);
  RegisterTest('Curl.StatusCodes', 'EnsureSuccess raises EHttpStatusError on 503', TestEnsureSuccessRaises);
end.
