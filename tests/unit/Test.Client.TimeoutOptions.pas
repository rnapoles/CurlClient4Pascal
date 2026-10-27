unit Test.Client.TimeoutOptions;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestClientDefaultsReachTransport;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetTimeout(1234).SetConnectTimeout(321).SetUserAgent('UA/1');
  C.Get('http://h/');
  CheckEqualsInt(1234, F.LastOptions.TimeoutMs);
  CheckEqualsInt(321, F.LastOptions.ConnectTimeoutMs);
  CheckEqualsStr('UA/1', F.LastOptions.UserAgent);
end;
procedure TestRequestOverrideDoesNotLeak;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetTimeout(1000);
  C.Execute(C.NewRequest(hmGet, 'http://h/').SetTimeout(50));
  CheckEqualsInt(50, F.LastOptions.TimeoutMs);
  C.Get('http://h/');
  CheckEqualsInt(1000, F.LastOptions.TimeoutMs);
end;
initialization
  RegisterTest('Client.TimeoutOptions', 'client options reach the transport', TestClientDefaultsReachTransport);
  RegisterTest('Client.TimeoutOptions', 'per-request timeout does not leak into the client', TestRequestOverrideDoesNotLeak);
end.
