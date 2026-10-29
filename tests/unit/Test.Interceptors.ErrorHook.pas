unit Test.Interceptors.ErrorHook;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

procedure TestOnErrorSeesTheException;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  F.FailWith(ECurlError, 'x');
  I := NewRecorder('R', R);
  C := NewHttpClient(T).AddInterceptor(I);
  try C.Get('http://h/x'); except on Exception do ; end;
  CheckEqualsStr('ECurlError', R.LastErrorClass);
  CheckEqualsInt(0, R.AfterCalls, 'AfterResponse is not called on failure');
  CheckEqualsStr('http://h/x', R.LastUrl);
end;
procedure TestHookFailureDoesNotMaskTheOriginal;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor; Msg: string;
begin
  T := NewFakeTransport(F);
  F.FailWith(EHttpError, 'the real problem');
  I := NewRecorder('R', R);
  R.RaiseInOnError := True;
  C := NewHttpClient(T).AddInterceptor(I);
  Msg := '';
  try C.Get('http://h/x'); except on E: Exception do Msg := E.Message; end;
  CheckEqualsStr('the real problem', Msg);
end;
procedure TestBeforeFailureAbortsTheRequest;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor; Aborted: Boolean;
begin
  T := NewFakeTransport(F);
  I := NewRecorder('R', R);
  R.RaiseInBefore := True;
  C := NewHttpClient(T).AddInterceptor(I);
  Aborted := False;
  try C.Get('http://h/x'); except on EAbort do Aborted := True; end;
  CheckTrue(Aborted);
  CheckEqualsInt(0, F.CallCount, 'transport never reached');
end;
initialization
  RegisterTest('Interceptors.ErrorHook', 'OnError receives the exception, AfterResponse does not run', TestOnErrorSeesTheException);
  RegisterTest('Interceptors.ErrorHook', 'an exception inside OnError never masks the original', TestHookFailureDoesNotMaskTheOriginal);
  RegisterTest('Interceptors.ErrorHook', 'an exception in BeforeRequest aborts the request', TestBeforeFailureAbortsTheRequest);
end.
