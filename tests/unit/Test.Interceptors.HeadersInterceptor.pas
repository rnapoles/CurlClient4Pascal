unit Test.Interceptors.HeadersInterceptor;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

var GP: Integer;
procedure OddPairs; begin NewHeadersInterceptor(['only-name']); end;
procedure TestAddsMissingHeadersOnly;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T)
    .AddInterceptor(NewHeadersInterceptor(['X-App', 'demo', 'Accept-Language', 'en']));
  C.Execute(C.NewRequest(hmGet, 'http://h/').SetHeader('accept-language', 'pt'));
  CheckEqualsStr('demo', F.LastRequest.Headers.Get('X-App'));
  CheckEqualsStr('pt', F.LastRequest.Headers.Get('Accept-Language'), 'explicit header wins');
  CheckEqualsInt(1, Length(F.LastRequest.Headers.GetAll('Accept-Language')));
end;
procedure TestOddPairsRejected;
begin
  CheckRaises(EArgumentException, OddPairs);
end;
initialization
  RegisterTest('Interceptors.HeadersInterceptor', 'adds headers the request lacks, never overrides', TestAddsMissingHeadersOnly);
  RegisterTest('Interceptors.HeadersInterceptor', 'odd name/value list is rejected', TestOddPairsRejected);
end.
