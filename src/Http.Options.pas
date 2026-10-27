unit Http.Options;
{ Client-wide configuration. A plain record: copying it is a cheap, safe
  snapshot, which is how per-request overrides are applied. }
{$I Http.Defines.inc}

interface

type
  THttpVersion = (hvDefault, hvHttp1, hvHttp1_1, hvHttp2, hvHttp3);

  THttpClientOptions = record
    BaseUrl: string;            // prepended to relative request URLs
    UserAgent: string;          // '' = let libcurl decide
    TimeoutMs: Integer;         // total transfer timeout, 0 = none
    ConnectTimeoutMs: Integer;  // connect phase timeout, 0 = libcurl default
    FollowRedirects: Boolean;
    MaxRedirects: Integer;      // -1 = unlimited
    VerifySsl: Boolean;         // verify peer certificate and host name
    CaBundlePath: string;       // '' = libcurl/OS default trust store
    ProxyUrl: string;           // e.g. 'http://127.0.0.1:8080'
    AutoDecompress: Boolean;    // send Accept-Encoding and decode gzip/deflate/br
    HttpVersion: THttpVersion;
    CookieFile: string;         // non-empty enables libcurl's cookie engine + persistence
    MaxResponseBytes: Int64;    // 0 = unlimited; protects against memory exhaustion
    Verbose: Boolean;           // libcurl wire trace on stderr
  end;

function DefaultHttpClientOptions: THttpClientOptions;

implementation

function DefaultHttpClientOptions: THttpClientOptions;
begin
  Result.BaseUrl := '';
  Result.UserAgent := 'Pascal-HttpClient/1.0';
  Result.TimeoutMs := 30000;
  Result.ConnectTimeoutMs := 10000;
  Result.FollowRedirects := True;
  Result.MaxRedirects := 10;
  Result.VerifySsl := True;
  Result.CaBundlePath := '';
  Result.ProxyUrl := '';
  Result.AutoDecompress := True;
  Result.HttpVersion := hvDefault;
  Result.CookieFile := '';
  Result.MaxResponseBytes := 0;
  Result.Verbose := False;
end;

end.
