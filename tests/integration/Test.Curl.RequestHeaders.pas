unit Test.Curl.RequestHeaders;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestClientAndRequestHeadersAreSent;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetHeader('X-Client', 'c1').SetUserAgent('Test/9');
  R := C.Execute(C.NewRequest(hmGet, '/echo').SetHeader('X-Request', 'r1'));
  CheckJsonField(R.Text, 'x-client', 'c1');
  CheckJsonField(R.Text, 'x-request', 'r1');
  CheckJsonField(R.Text, 'user-agent', 'Test/9');
end;
procedure TestBearerHeader;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetBearerToken('abc').Get('/echo');
  CheckJsonField(R.Text, 'authorization', 'Bearer abc');
end;
procedure TestQueryParametersAreEncoded;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  R := C.Execute(C.NewRequest(hmGet, '/echo').AddQuery('q', 'a b&c'));
  CheckJsonField(R.Text, 'q', 'a b&c');
end;
initialization
  RegisterTest('Curl.RequestHeaders', 'client, request headers and user agent are sent', TestClientAndRequestHeadersAreSent);
  RegisterTest('Curl.RequestHeaders', 'bearer token reaches the server', TestBearerHeader);
  RegisterTest('Curl.RequestHeaders', 'query parameters are URL-encoded', TestQueryParametersAreEncoded);
end.
