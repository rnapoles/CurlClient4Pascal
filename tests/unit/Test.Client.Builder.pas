unit Test.Client.Builder;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

procedure TestBuilderAppliesEverything;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClientBuilder
    .BaseUrl('http://api.test').UserAgent('B/1').Timeout(777).ConnectTimeout(88)
    .FollowRedirects(False).VerifySsl(False).MaxResponseBytes(1024)
    .Header('X-K', 'v').BearerToken('t').Cookie('c', '1').Transport(T).Build;
  C.Get('/p');
  CheckEqualsStr('http://api.test/p', F.LastRequest.Url);
  CheckEqualsStr('B/1', F.LastOptions.UserAgent);
  CheckEqualsInt(777, F.LastOptions.TimeoutMs);
  CheckEqualsInt(88, F.LastOptions.ConnectTimeoutMs);
  CheckFalse(F.LastOptions.FollowRedirects);
  CheckFalse(F.LastOptions.VerifySsl);
  CheckEqualsInt(1024, F.LastOptions.MaxResponseBytes);
  CheckEqualsStr('v', F.LastRequest.Headers.Get('X-K'));
  CheckEqualsStr('Bearer t', F.LastRequest.Headers.Get('Authorization'));
  CheckEqualsStr('c=1', F.LastRequest.Headers.Get('Cookie'));
end;
procedure TestBuiltClientsAreIndependent;
var F: TFakeTransport; T: IHttpTransport; B: IHttpClientBuilder; C1, C2: IHttpClient;
begin
  T := NewFakeTransport(F);
  B := NewHttpClientBuilder.Transport(T).Header('A', '1');
  C1 := B.Build; C2 := B.Build;
  C1.SetHeader('A', 'changed');
  CheckEqualsStr('1', C2.GetHeader('A'));
end;
initialization
  RegisterTest('Client.Builder', 'builder applies options, headers and cookies', TestBuilderAppliesEverything);
  RegisterTest('Client.Builder', 'clients built from one builder are independent', TestBuiltClientsAreIndependent);
end.
