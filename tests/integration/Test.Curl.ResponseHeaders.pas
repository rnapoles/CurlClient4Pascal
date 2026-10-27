unit Test.Curl.ResponseHeaders;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Headers, Http.Curl.Transport;

procedure TestMultiValueAndCase;
var R: IHttpResponse; A: THttpStringArray;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Get('/headers');
  A := R.Headers.GetAll('x-multi');
  CheckEqualsInt(2, Length(A));
  CheckEqualsStr('one', A[0]);
  CheckEqualsStr('two', A[1]);
  CheckEqualsStr('Value', R.Header('X-CASE'));
  CheckEqualsStr('1.1', R.HttpVersion);
end;
initialization
  RegisterTest('Curl.ResponseHeaders', 'duplicate headers and case-insensitive lookup', TestMultiValueAndCase);
end.
