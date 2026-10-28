unit Test.Curl.HttpVersion;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Client, Http.Response, Http.Options, Http.Curl.Transport;

function VersionSeenByServer(Version: THttpVersion): string;
var
  R: IHttpResponse;
begin
  R := NewHttpClient.SetBaseUrl(IntegrationBaseUrl).SetHttpVersion(Version).Get('/echo');
  Result := R.Text;
end;

procedure TestHttp1SendsHttp10;
begin
  CheckJsonField(VersionSeenByServer(hvHttp1), 'version', 'HTTP/1.0');
end;

procedure TestHttp11SendsHttp11;
begin
  CheckJsonField(VersionSeenByServer(hvHttp1_1), 'version', 'HTTP/1.1');
end;

procedure TestHttp2OverPlainHttpFallsBackTo11;
begin
  CheckJsonField(VersionSeenByServer(hvHttp2), 'version', 'HTTP/1.1');
end;

procedure TestHttp3PreferenceNeverFailsPlainHttp;
begin
  // must succeed whether or not this libcurl build supports HTTP/3
  CheckJsonField(VersionSeenByServer(hvHttp3), 'method', 'GET');
end;

procedure TestDefaultWorks;
begin
  CheckJsonField(VersionSeenByServer(hvDefault), 'method', 'GET');
end;

initialization
  RegisterTest('Curl.HttpVersion', 'hvHttp1 sends an HTTP/1.0 request', TestHttp1SendsHttp10);
  RegisterTest('Curl.HttpVersion', 'hvHttp1_1 sends an HTTP/1.1 request', TestHttp11SendsHttp11);
  RegisterTest('Curl.HttpVersion', 'hvHttp2 falls back to 1.1 on plain http', TestHttp2OverPlainHttpFallsBackTo11);
  RegisterTest('Curl.HttpVersion', 'hvHttp3 preference never fails a plain-http request', TestHttp3PreferenceNeverFailsPlainHttp);
  RegisterTest('Curl.HttpVersion', 'hvDefault leaves the choice to libcurl', TestDefaultWorks);
end.
