unit Test.Interceptors.Management;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

var GC: IHttpClient;
procedure AddNil; begin GC.AddInterceptor(nil); end;
procedure TestNilRejected;
var F: TFakeTransport; T: IHttpTransport;
begin
  T := NewFakeTransport(F);
  GC := NewHttpClient(T);
  CheckRaises(EHttpError, AddNil);
  GC := nil;
end;
procedure TestClearInterceptors;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  I := NewRecorder('R', R);
  C := NewHttpClient(T).AddInterceptor(I);
  C.Get('http://h/');
  C.ClearInterceptors;
  C.Get('http://h/');
  CheckEqualsInt(1, R.AfterCalls);
end;
procedure TestBuilderRegistersInterceptors;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
    A, B: TRecordingInterceptor; IA, IB: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  IA := NewRecorder('A', A); IB := NewRecorder('B', B);
  C := NewHttpClientBuilder.Transport(T).Interceptor(IA).Interceptor(IB).Build;
  InterceptorLog := '';
  C.Get('http://h/');
  CheckEqualsStr('A:before;B:before;B:after;A:after;', InterceptorLog);
end;
procedure TestAddingLaterDoesNotAffectOtherClients;
var F: TFakeTransport; T: IHttpTransport; B: IHttpClientBuilder; C1, C2: IHttpClient;
    R: TRecordingInterceptor; I: IHttpInterceptor;
begin
  T := NewFakeTransport(F);
  B := NewHttpClientBuilder.Transport(T);
  C1 := B.Build; C2 := B.Build;
  I := NewRecorder('R', R);
  C1.AddInterceptor(I);
  C2.Get('http://h/');
  CheckEqualsInt(0, R.AfterCalls);
  C1.Get('http://h/');
  CheckEqualsInt(1, R.AfterCalls);
end;
initialization
  RegisterTest('Interceptors.Management', 'nil interceptor is rejected', TestNilRejected);
  RegisterTest('Interceptors.Management', 'ClearInterceptors removes them all', TestClearInterceptors);
  RegisterTest('Interceptors.Management', 'builder registers interceptors in order', TestBuilderRegistersInterceptors);
  RegisterTest('Interceptors.Management', 'clients built from one builder stay independent', TestAddingLaterDoesNotAffectOtherClients);
end.
