unit Test.Curl.PutPatchDelete;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

function Client: IHttpClient;
begin Result := NewHttpClient.SetBaseUrl(IntegrationBaseUrl); end;
procedure TestPut;
var R: IHttpResponse;
begin
  R := Client.Put('/echo', 'put-body');
  CheckJsonField(R.Text, 'method', 'PUT');
  CheckJsonField(R.Text, 'body', 'put-body');
end;
procedure TestPatch;
var R: IHttpResponse;
begin
  R := Client.Patch('/echo', 'patch-body');
  CheckJsonField(R.Text, 'method', 'PATCH');
  CheckJsonField(R.Text, 'body', 'patch-body');
end;
procedure TestDeleteWithoutBody;
var R: IHttpResponse;
begin
  R := Client.Delete('/echo');
  CheckJsonField(R.Text, 'method', 'DELETE');
  CheckJsonField(R.Text, 'body', '');
end;
initialization
  RegisterTest('Curl.PutPatchDelete', 'PUT sends method and body', TestPut);
  RegisterTest('Curl.PutPatchDelete', 'PATCH sends method and body', TestPatch);
  RegisterTest('Curl.PutPatchDelete', 'DELETE works without a body', TestDeleteWithoutBody);
end.
