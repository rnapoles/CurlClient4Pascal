unit Test.Curl.Timeout;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

var GC: IHttpClient;
procedure SlowGet; begin GC.Get('/delay/1500'); end;
procedure TestTimeoutRaisesCode28;
var Code: Integer;
begin
  GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetTimeout(200);
  Code := 0;
  try SlowGet; except on E: ECurlError do Code := E.Code; end;
  CheckEqualsInt(28, Code, 'CURLE_OPERATION_TIMEDOUT');
  GC := nil;
end;
procedure TestPerRequestTimeoutOverride;
var C: IHttpClient; R: IHttpResponse;
begin
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetTimeout(100);
  R := C.Execute(C.NewRequest(hmGet, '/delay/300').SetTimeout(5000));
  CheckEqualsInt(200, R.StatusCode);
end;
initialization
  RegisterTest('Curl.Timeout', 'exceeding the timeout raises CURLE_OPERATION_TIMEDOUT', TestTimeoutRaisesCode28);
  RegisterTest('Curl.Timeout', 'per-request timeout overrides the client default', TestPerRequestTimeoutOverride);
end.
