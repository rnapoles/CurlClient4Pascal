unit Test.Request.Fluent;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Request, Http.Utils;

procedure TestChainAndQuery;
var R: IHttpRequest;
begin
  R := NewHttpRequest(hmGet, 'http://h/p').AddQuery('q', 'a b').SetHeader('X-A', '1').SetTimeout(500);
  CheckEqualsStr('http://h/p?q=a%20b', R.Url);
  CheckEqualsStr('1', R.Headers.Get('x-a'));
  CheckEqualsInt(500, R.TimeoutMs);
  CheckEqualsInt(HTTP_INHERIT, R.ConnectTimeoutMs);
end;
procedure TestJsonBody;
var R: IHttpRequest;
begin
  R := NewHttpRequest(hmPost).SetJson('{}');
  CheckEqualsStr('application/json; charset=utf-8', R.Headers.Get('Content-Type'));
  CheckEqualsInt(2, Length(R.Body));
end;
procedure TestFormBody;
var R: IHttpRequest;
begin
  R := NewHttpRequest(hmPost).AddFormField('a', '1 2').AddFormField('b', '&');
  CheckEqualsStr('a=1%202&b=%26', BytesToString(R.Body));
  CheckEqualsStr('application/x-www-form-urlencoded', R.Headers.Get('Content-Type'));
end;
procedure TestCloneIsIndependent;
var R, C: IHttpRequest;
begin
  R := NewHttpRequest(hmPost, 'http://h').SetHeader('A', '1').SetBody('x');
  C := R.Clone;
  C.SetHeader('A', '2').SetUrl('http://other');
  CheckEqualsStr('1', R.Headers.Get('A'));
  CheckEqualsStr('http://h', R.Url);
  CheckEqualsInt(1, Length(C.Body));
end;
initialization
  RegisterTest('Request.Fluent', 'chains setters and encodes query', TestChainAndQuery);
  RegisterTest('Request.Fluent', 'SetJson sets body and content type', TestJsonBody);
  RegisterTest('Request.Fluent', 'AddFormField builds urlencoded body', TestFormBody);
  RegisterTest('Request.Fluent', 'Clone does not share mutable state', TestCloneIsIndependent);
end.
