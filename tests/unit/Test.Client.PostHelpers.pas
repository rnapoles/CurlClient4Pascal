unit Test.Client.PostHelpers;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

var GC: IHttpClient;
procedure OddPairs; begin GC.PostForm('http://h/', ['a']); end;
procedure TestPostSetsMethodBodyAndType;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T);
  C.Post('http://h/', 'hello');
  CheckTrue(F.LastRequest.Method = hmPost);
  CheckEqualsInt(5, Length(F.LastRequest.Body));
  CheckContains('text/plain', F.LastRequest.Headers.Get('Content-Type'));
end;
procedure TestPostJson;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T);
  C.PostJson('http://h/', '{}');
  CheckContains('application/json', F.LastRequest.Headers.Get('Content-Type'));
end;
procedure TestPostForm;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T);
  C.PostForm('http://h/', ['a', '1', 'b', 'x y']);
  CheckEqualsStr('application/x-www-form-urlencoded', F.LastRequest.Headers.Get('Content-Type'));
  CheckEqualsInt(Length('a=1&b=x%20y'), Length(F.LastRequest.Body));
  GC := C;
  CheckRaises(EHttpError, OddPairs);
  GC := nil;
end;
procedure TestVerbs;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient;
begin
  T := NewFakeTransport(F);
  C := NewHttpClient(T);
  C.Put('http://h/', 'x');    CheckTrue(F.LastRequest.Method = hmPut);
  C.Patch('http://h/', 'x');  CheckTrue(F.LastRequest.Method = hmPatch);
  C.Delete('http://h/');      CheckTrue(F.LastRequest.Method = hmDelete);
  C.Head('http://h/');        CheckTrue(F.LastRequest.Method = hmHead);
end;
initialization
  RegisterTest('Client.PostHelpers', 'Post sets method, body and default content type', TestPostSetsMethodBodyAndType);
  RegisterTest('Client.PostHelpers', 'PostJson sets JSON content type', TestPostJson);
  RegisterTest('Client.PostHelpers', 'PostForm encodes pairs and validates arity', TestPostForm);
  RegisterTest('Client.PostHelpers', 'shortcut verbs map to the right method', TestVerbs);
end.
