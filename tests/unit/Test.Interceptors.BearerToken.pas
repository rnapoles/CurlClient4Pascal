unit Test.Interceptors.BearerToken;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Interceptors.Support, Http.Client, Http.Request, Http.Response, Http.Interceptors, Http.Transport, Http.Errors;

var GCalls: Integer;
function NextToken: string;
begin
  Inc(GCalls);
  Result := 'tok' + IntToStr(GCalls);
end;
type
  TTokenHolder = class
    Token: string;
    function Get: string;
  end;
function TTokenHolder.Get: string;
begin
  Result := Token;
end;
procedure TestStaticToken;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).AddInterceptor(NewBearerTokenInterceptor('abc'));
  C.Get('http://h/');
  CheckEqualsStr('Bearer abc', F.LastRequest.Headers.Get('Authorization'));
end;
procedure TestProviderIsCalledForEveryRequest;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  GCalls := 0;
  T := NewFakeTransport(F);
  C := NewHttpClient(T).AddInterceptor(NewTokenProviderInterceptor(NextToken));
  C.Get('http://h/');
  CheckEqualsStr('Bearer tok1', F.LastRequest.Headers.Get('Authorization'));
  C.Get('http://h/');
  CheckEqualsStr('Bearer tok2', F.LastRequest.Headers.Get('Authorization'), 'refreshed token');
end;
procedure TestMethodProvider;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; H: TTokenHolder;
begin
  H := TTokenHolder.Create;
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T).AddInterceptor(NewTokenMethodInterceptor(H.Get));
    H.Token := 'one';
    C.Get('http://h/');
    CheckEqualsStr('Bearer one', F.LastRequest.Headers.Get('Authorization'));
    H.Token := 'two';
    C.Get('http://h/');
    CheckEqualsStr('Bearer two', F.LastRequest.Headers.Get('Authorization'));
    C := nil;
  finally H.Free; end;
end;
procedure TestExplicitAuthorizationIsKept;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  GCalls := 0;
  T := NewFakeTransport(F);
  C := NewHttpClient(T).SetBasicAuth('u', 'p').AddInterceptor(NewTokenProviderInterceptor(NextToken));
  C.Get('http://h/');
  CheckContains('Basic ', F.LastRequest.Headers.Get('Authorization'));
  CheckEqualsInt(0, GCalls, 'provider is not even called');
end;
procedure TestEmptyTokenAddsNothing;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T).AddInterceptor(NewBearerTokenInterceptor(''));
  C.Get('http://h/');
  CheckFalse(F.LastRequest.Headers.Contains('Authorization'));
end;
initialization
  RegisterTest('Interceptors.BearerToken', 'static token', TestStaticToken);
  RegisterTest('Interceptors.BearerToken', 'provider function is called per request', TestProviderIsCalledForEveryRequest);
  RegisterTest('Interceptors.BearerToken', 'provider method of an object', TestMethodProvider);
  RegisterTest('Interceptors.BearerToken', 'an explicit Authorization header wins', TestExplicitAuthorizationIsKept);
  RegisterTest('Interceptors.BearerToken', 'empty token adds no header', TestEmptyTokenAddsNothing);
end.
