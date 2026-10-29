unit Test.Interceptors.Timing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

procedure TestCountsSuccessesAndErrors;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; Tm: ITimingInterceptor;
begin
  T := NewFakeTransport(F);
  Tm := NewTimingInterceptor;
  C := NewHttpClient(T).AddInterceptor(Tm);
  C.Get('http://h/1'); C.Get('http://h/2'); C.Get('http://h/3');
  CheckEqualsInt(3, Tm.RequestCount);
  CheckEqualsInt(0, Tm.ErrorCount);
  F.FailWith(EHttpError, 'x');
  try C.Get('http://h/4'); except on EHttpError do ; end;
  CheckEqualsInt(4, Tm.RequestCount);
  CheckEqualsInt(1, Tm.ErrorCount);
end;
procedure TestStatisticsAreConsistent;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; Tm: ITimingInterceptor; I: Integer;
begin
  T := NewFakeTransport(F);
  Tm := NewTimingInterceptor;
  C := NewHttpClient(T).AddInterceptor(Tm);
  for I := 1 to 5 do C.Get('http://h/');
  CheckTrue(Tm.TotalMs >= Tm.LastMs);
  CheckTrue(Tm.MaxMs >= Tm.LastMs);
  CheckTrue(Tm.AverageMs <= Tm.MaxMs);
  CheckEqualsInt(Tm.TotalMs div 5, Tm.AverageMs);
end;
procedure TestResetAndEmptyAverage;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; Tm: ITimingInterceptor;
begin
  T := NewFakeTransport(F);
  Tm := NewTimingInterceptor;
  CheckEqualsInt(0, Tm.AverageMs, 'no division by zero');
  C := NewHttpClient(T).AddInterceptor(Tm);
  C.Get('http://h/');
  Tm.Reset;
  CheckEqualsInt(0, Tm.RequestCount);
  CheckEqualsInt(0, Tm.TotalMs);
end;
initialization
  RegisterTest('Interceptors.Timing', 'counts successes and errors', TestCountsSuccessesAndErrors);
  RegisterTest('Interceptors.Timing', 'statistics are consistent', TestStatisticsAreConsistent);
  RegisterTest('Interceptors.Timing', 'Reset and empty average', TestResetAndEmptyAverage);
end.
