unit Test.Curl.Head;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestHeadReturnsHeadersOnly;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Head('/echo');
  CheckEqualsInt(200, R.StatusCode);
  CheckEqualsInt(0, Length(R.Body));
  CheckEqualsStr('yes', R.Header('X-Echo'));
end;
initialization
  RegisterTest('Curl.Head', 'HEAD returns headers and no body', TestHeadReturnsHeadersOnly);
end.
