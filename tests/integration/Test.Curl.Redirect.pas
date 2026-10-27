unit Test.Curl.Redirect;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

procedure TestFollowsRedirects;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Get('/redirect/3');
  CheckEqualsInt(200, R.StatusCode);
  CheckEqualsInt(3, R.RedirectCount);
  CheckContains('/echo', R.EffectiveUrl);
end;
procedure TestCanDisableFollowing;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetFollowRedirects(False).Get('/redirect/3');
  CheckEqualsInt(302, R.StatusCode);
  CheckEqualsStr('/redirect/2', R.Header('Location'));
end;
var GC: IHttpClient;
procedure TooMany; begin GC.Get('/redirect/5'); end;
procedure TestMaxRedirectsEnforced;
var Code: Integer;
begin
  GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetFollowRedirects(True, 2);
  Code := 0;
  try TooMany; except on E: ECurlError do Code := E.Code; end;
  CheckEqualsInt(47, Code, 'CURLE_TOO_MANY_REDIRECTS');
  GC := nil;
end;
procedure TestPostBodyResentOn307;
var R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).Post('/redirect-307', 'again');
  CheckEqualsInt(200, R.StatusCode);
  CheckJsonField(R.Text, 'method', 'POST');
  CheckJsonField(R.Text, 'body', 'again');
end;
initialization
  RegisterTest('Curl.Redirect', 'follows redirect chains', TestFollowsRedirects);
  RegisterTest('Curl.Redirect', 'following can be disabled', TestCanDisableFollowing);
  RegisterTest('Curl.Redirect', 'MaxRedirects is enforced', TestMaxRedirectsEnforced);
  RegisterTest('Curl.Redirect', '307 re-sends the body via the seek callback', TestPostBodyResentOn307);
end.
