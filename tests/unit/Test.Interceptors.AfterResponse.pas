unit Test.Interceptors.AfterResponse;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

procedure TestReceivesResolvedRequestResponseAndElapsed;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  F.RespondWith(201);
  I := NewRecorder('R', R);
  C := NewHttpClient(T).SetBaseUrl('http://api.test').AddInterceptor(I);
  C.Get('/items');
  CheckEqualsInt(201, R.LastStatus);
  CheckEqualsStr('http://api.test/items', R.LastUrl, 'resolved, absolute URL');
  CheckTrue(R.LastElapsed >= 0);
  CheckEqualsInt(1, R.AfterCalls);
end;
procedure TestHooksRunForEveryRequest;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  I := NewRecorder('R', R);
  C := NewHttpClient(T).AddInterceptor(I);
  C.Get('http://h/1'); C.Get('http://h/2'); C.Post('http://h/3', 'x');
  CheckEqualsInt(3, R.AfterCalls);
end;
initialization
  RegisterTest('Interceptors.AfterResponse', 'gets the resolved request, response and elapsed time', TestReceivesResolvedRequestResponseAndElapsed);
  RegisterTest('Interceptors.AfterResponse', 'runs for every request', TestHooksRunForEveryRequest);
end.
