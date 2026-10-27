unit Test.Client.BaseUrl;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestRelativeUrlUsesBase;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetBaseUrl('http://api.test/v1/');
  C.Get('/users');
  CheckEqualsStr('http://api.test/v1/users', F.LastRequest.Url);
  C.Get('http://other.test/z');
  CheckEqualsStr('http://other.test/z', F.LastRequest.Url);
end;
initialization
  RegisterTest('Client.BaseUrl', 'relative URLs are resolved against the base', TestRelativeUrlUsesBase);
end.
