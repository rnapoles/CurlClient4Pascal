unit Test.Interceptors.ModifyRequest;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

type
  TAddHeader = class(THttpInterceptor)
    procedure BeforeRequest(const Request: IHttpRequest); override;
  end;
procedure TAddHeader.BeforeRequest(const Request: IHttpRequest);
begin
  Request.Headers.SetValue('X-Added', 'by-interceptor');
  Request.Headers.SetValue('Accept', 'overridden');
end;
procedure TestHeaderReachesTransport;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetHeader('Accept', 'text/html').AddInterceptor(TAddHeader.Create);
  C.Get('http://h/');
  CheckEqualsStr('by-interceptor', F.LastRequest.Headers.Get('X-Added'));
  CheckEqualsStr('overridden', F.LastRequest.Headers.Get('Accept'), 'runs after client defaults are merged');
end;
procedure TestCallersRequestIsNotMutated;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; Req: IHttpRequest;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).AddInterceptor(TAddHeader.Create);
  Req := C.NewRequest(hmGet, 'http://h/');
  C.Execute(Req);
  CheckFalse(Req.Headers.Contains('X-Added'), 'interceptors see a clone');
  C.Execute(Req);
  CheckEqualsInt(0, Req.Headers.Count);
end;
initialization
  RegisterTest('Interceptors.ModifyRequest', 'added headers reach the transport and override defaults', TestHeaderReachesTransport);
  RegisterTest('Interceptors.ModifyRequest', 'the request object of the caller is not mutated', TestCallersRequestIsNotMutated);
end.
