unit Test.Response.StatusHelpers;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Response, Http.Errors;

function Make(Code: Integer): IHttpResponse;
var R: THttpResponse;
begin
  R := THttpResponse.Create; Result := R; R.StatusCode := Code; R.StatusText := 'X'; R.EffectiveUrl := 'http://h/';
end;
procedure TestClassification;
begin
  CheckTrue(Make(204).IsSuccess);
  CheckTrue(Make(302).IsRedirect);
  CheckTrue(Make(404).IsClientError);
  CheckTrue(Make(503).IsServerError);
  CheckFalse(Make(404).IsSuccess);
end;
var GResp: IHttpResponse;
procedure CallEnsure; begin GResp.EnsureSuccess; end;
procedure TestEnsureSuccess;
begin
  GResp := Make(200);
  CheckTrue(GResp.EnsureSuccess = GResp, 'returns self');
  GResp := Make(500);
  CheckRaises(EHttpStatusError, CallEnsure);
  GResp := nil;
end;
initialization
  RegisterTest('Response.StatusHelpers', 'classifies status codes', TestClassification);
  RegisterTest('Response.StatusHelpers', 'EnsureSuccess chains or raises EHttpStatusError', TestEnsureSuccess);
end.
