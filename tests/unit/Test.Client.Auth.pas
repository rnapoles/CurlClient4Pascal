unit Test.Client.Auth;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestBearer;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetBearerToken('tok');
  C.Get('http://h/');
  CheckEqualsStr('Bearer tok', F.LastRequest.Headers.Get('Authorization'));
end;
procedure TestBasic;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetBasicAuth('Aladdin', 'open sesame');
  C.Get('http://h/');
  CheckEqualsStr('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==', F.LastRequest.Headers.Get('Authorization'));
end;
initialization
  RegisterTest('Client.Auth', 'bearer token header', TestBearer);
  RegisterTest('Client.Auth', 'basic auth header', TestBasic);
end.
