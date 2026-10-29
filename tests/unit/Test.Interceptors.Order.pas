unit Test.Interceptors.Order;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

procedure TestBeforeInOrderAfterReversed;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    A, B, X: TRecordingInterceptor; IA, IB, IX: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  IA := NewRecorder('A', A); IB := NewRecorder('B', B); IX := NewRecorder('C', X);
  C := NewHttpClient(T).AddInterceptor(IA).AddInterceptor(IB).AddInterceptor(IX);
  InterceptorLog := '';
  C.Get('http://h/x');
  CheckEqualsStr('A:before;B:before;C:before;C:after;B:after;A:after;', InterceptorLog);
end;
procedure TestErrorHooksRunInReverse;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    A, B: TRecordingInterceptor; IA, IB: IHttpInterceptor; Raised: Boolean;
begin
  T := NewFakeTransport(F);
  F.FailWith(EHttpError, 'boom');
  IA := NewRecorder('A', A); IB := NewRecorder('B', B);
  C := NewHttpClient(T).AddInterceptor(IA).AddInterceptor(IB);
  InterceptorLog := '';
  Raised := False;
  try C.Get('http://h/x'); except on EHttpError do Raised := True; end;
  CheckTrue(Raised, 'original exception still reaches the caller');
  CheckEqualsStr('A:before;B:before;B:error;A:error;', InterceptorLog);
end;
initialization
  RegisterTest('Interceptors.Order', 'before in order, after in reverse', TestBeforeInOrderAfterReversed);
  RegisterTest('Interceptors.Order', 'error hooks run in reverse and the error propagates', TestErrorHooksRunInReverse);
end.
