unit Test.Client.DefaultHeaders;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestClientHeaderIsSent;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetHeader('X-Api', 'k1');
  C.Get('http://h/x');
  CheckEqualsStr('k1', F.LastRequest.Headers.Get('X-Api'));
  CheckEqualsStr('k1', C.GetHeader('x-api'));
end;
procedure TestRequestHeaderOverridesClientHeader;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetHeader('Accept', 'text/html');
  C.Execute(C.NewRequest(hmGet, 'http://h/').SetHeader('accept', 'application/json'));
  CheckEqualsStr('application/json', F.LastRequest.Headers.Get('Accept'));
  CheckEqualsInt(1, F.LastRequest.Headers.Count);
end;
procedure TestRemoveHeader;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetHeader('X', '1').RemoveHeader('X');
  C.Get('http://h/');
  CheckFalse(F.LastRequest.Headers.Contains('X'));
end;
initialization
  RegisterTest('Client.DefaultHeaders', 'client header is sent with each request', TestClientHeaderIsSent);
  RegisterTest('Client.DefaultHeaders', 'request header overrides client header', TestRequestHeaderOverridesClientHeader);
  RegisterTest('Client.DefaultHeaders', 'RemoveHeader stops sending it', TestRemoveHeader);
end.
