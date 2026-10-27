unit Test.Curl.MaxResponseBytes;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

var GC: IHttpClient;
procedure Big; begin GC.Get('/bytes/50000'); end;
procedure TestLimitRaisesTooLarge;
begin
  GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetMaxResponseBytes(1000);
  CheckRaises(EHttpResponseTooLarge, Big);
  GC := nil;
end;
procedure TestUnderLimitIsFine;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetMaxResponseBytes(60000).Get('/bytes/50000');
  CheckEqualsInt(50000, Length(R.Body));
end;
initialization
  RegisterTest('Curl.MaxResponseBytes', 'oversized body raises EHttpResponseTooLarge', TestLimitRaisesTooLarge);
  RegisterTest('Curl.MaxResponseBytes', 'body under the limit succeeds', TestUnderLimitIsFine);
end.
