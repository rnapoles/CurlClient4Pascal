unit Test.Curl.ConnectionRefused;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

var GC: IHttpClient;
procedure DoGet; begin GC.Get('http://127.0.0.1:1/'); end;
procedure TestRaisesCurlErrorWithCode;
var Code: Integer;
begin
  GC := NewHttpClient.SetConnectTimeout(2000);
  Code := 0;
  try DoGet; except on E: ECurlError do Code := E.Code; end;
  CheckEqualsInt(7, Code, 'CURLE_COULDNT_CONNECT');
  GC := nil;
end;
procedure TestMessageHasStrerror;
var Msg: string;
begin
  GC := NewHttpClient.SetConnectTimeout(2000);
  try DoGet; except on E: ECurlError do Msg := E.CurlMessage; end;
  CheckContains('connect', Msg);
  GC := nil;
end;
initialization
  RegisterTest('Curl.ConnectionRefused', 'raises ECurlError with CURLE_COULDNT_CONNECT', TestRaisesCurlErrorWithCode);
  RegisterTest('Curl.ConnectionRefused', 'exposes curl_easy_strerror text', TestMessageHasStrerror);
end.
