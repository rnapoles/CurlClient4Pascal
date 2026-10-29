unit Test.Curl.VerboseRedaction;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Logging, Http.Interceptors, Http.Curl.Transport;

procedure TestSecretsAreMaskedByDefault;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L)
        .SetBearerToken('hunter2-token').SetCookie('sid', 'cookie-secret-77');
  C.Get('/echo');
  CheckFalse(L.Contains('hunter2-token'), 'bearer token leaked');
  CheckFalse(L.Contains('cookie-secret-77'), 'cookie leaked');
  CheckTrue(L.Contains('> Authorization: ***'));
  CheckTrue(L.Contains('> Cookie: ***'));
end;
procedure TestMaskingCanBeDisabled;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L)
        .SetRedactLogs(False).SetBearerToken('hunter2-token');
  C.Get('/echo');
  CheckTrue(L.Contains('> Authorization: Bearer hunter2-token'));
end;
procedure TestResponseCookiesAreMasked;
var C: IHttpClient; L: IMemoryLogger;
begin
  L := NewMemoryLogger;
  C := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetVerbose(True).SetLogger(L);
  C.Get('/cookies/set?session=server-secret-99');
  // the value is part of the request URL (query strings are not redacted),
  // so check the Set-Cookie header lines specifically
  CheckFalse(L.Contains('Set-Cookie: session=server-secret-99'));
  CheckTrue(L.Contains('< Set-Cookie: ***'));
  L.Clear;
  C.Get('/echo');                       // the stored cookie is replayed
  CheckFalse(L.Contains('Cookie: session=server-secret-99'));
  CheckTrue(L.Contains('> Cookie: ***'));
end;
initialization
  RegisterTest('Curl.VerboseRedaction', 'Authorization and Cookie are masked by default', TestSecretsAreMaskedByDefault);
  RegisterTest('Curl.VerboseRedaction', 'masking can be disabled', TestMaskingCanBeDisabled);
  RegisterTest('Curl.VerboseRedaction', 'Set-Cookie of responses is masked', TestResponseCookiesAreMasked);
end.
