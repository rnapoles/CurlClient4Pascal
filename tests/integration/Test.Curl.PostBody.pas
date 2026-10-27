unit Test.Curl.PostBody;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

function Client: IHttpClient;
begin Result := NewHttpClient.SetBaseUrl(IntegrationBaseUrl); end;
procedure TestPostTextBody;
var R: IHttpResponse;
begin
  R := Client.Post('/echo', 'hello ' + #$00E9);
  CheckJsonField(R.Text, 'method', 'POST');
  CheckJsonField(R.Text, 'body', 'hello ' + #$00E9);
  CheckJsonField(R.Text, 'content-type', 'text/plain; charset=utf-8');
end;
procedure TestPostJson;
var R: IHttpResponse;
begin
  R := Client.PostJson('/echo', '{x:1}');
  CheckJsonField(R.Text, 'content-type', 'application/json; charset=utf-8');
end;
procedure TestPostForm;
var R: IHttpResponse;
begin
  R := Client.PostForm('/echo', ['name', 'Ana Maria', 'q', 'a&b']);
  CheckJsonField(R.Text, 'content-type', 'application/x-www-form-urlencoded');
  CheckJsonField(R.Text, 'body', 'name=Ana%20Maria&q=a%26b');
end;
procedure TestLargeBodyIsStreamedIntact;
var B: TBytes; R: IHttpResponse; I: Integer;
begin
  SetLength(B, 300000);
  for I := 0 to High(B) do B[I] := Ord('a');
  R := Client.PostBytes('/echo', B, 'text/plain');
  CheckContains('aaaaaaaaaaaaaaaa', R.Text);
  CheckTrue(Length(R.Body) > 300000);
end;
procedure TestEmptyPostSendsContentLengthZero;
var R: IHttpResponse;
begin
  R := Client.Post('/echo', '');
  CheckJsonField(R.Text, 'content-length', '0');
end;
initialization
  RegisterTest('Curl.PostBody', 'POST sends a UTF-8 text body', TestPostTextBody);
  RegisterTest('Curl.PostBody', 'PostJson sets the JSON content type', TestPostJson);
  RegisterTest('Curl.PostBody', 'PostForm url-encodes fields', TestPostForm);
  RegisterTest('Curl.PostBody', '300 KB body is uploaded intact', TestLargeBodyIsStreamedIntact);
  RegisterTest('Curl.PostBody', 'empty POST sends Content-Length 0', TestEmptyPostSendsContentLengthZero);
end.
