program Example_Builder;
{ Builder pattern, cookies, other verbs, streaming a download to a file.
  Usage: Example_Builder [baseUrl]  (default https://httpbin.org) }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils, Classes,
  Http.Errors, Http.Request, Http.Response, Http.Client,
  Http.Curl.Transport;

var
  BaseUrl: string;
  Client: IHttpClient;
  Response: IHttpResponse;
  F: TFileStream;
begin
  if ParamCount > 0 then BaseUrl := ParamStr(1) else BaseUrl := 'https://httpbin.org';
  try
    // Immutable-style configuration through the builder
    Client := NewHttpClientBuilder
      .BaseUrl(BaseUrl)
      .UserAgent('ExampleBuilder/1.0')
      .Timeout(20000)
      .ConnectTimeout(5000)
      .FollowRedirects(True, 5)
      .MaxResponseBytes(10 * 1024 * 1024)          // never buffer more than 10 MB
      .Header('Accept-Language', 'en')
      .Cookie('session', 'demo-session')
      .Build;

    // Cookies and headers can be read and changed afterwards
    Client.SetCookie('theme', 'dark');
    WriteLn('Accept-Language = ', Client.GetHeader('Accept-Language'));
    WriteLn('theme cookie    = ', Client.GetCookie('theme'));

    Response := Client.Put('/put', '{"id":1}', 'application/json');
    WriteLn('PUT    -> ', Response.StatusCode);
    Response := Client.Patch('/patch', '{"id":1}', 'application/json');
    WriteLn('PATCH  -> ', Response.StatusCode);
    Response := Client.Delete('/delete');
    WriteLn('DELETE -> ', Response.StatusCode);
    Response := Client.Head('/get');
    WriteLn('HEAD   -> ', Response.StatusCode, ', Content-Length: ', Response.Header('Content-Length'));

    // Stream a download straight to disk (not kept in memory)
    F := TFileStream.Create('download.bin', fmCreate);
    try
      Response := Client.Execute(
        Client.NewRequest(hmGet, '/bytes/2048').SaveResponseTo(F));
      WriteLn('Saved ', F.Size, ' bytes to download.bin (HTTP ', Response.StatusCode, ')');
    finally
      F.Free;
    end;
  except
    on E: EHttpStatusError do
    begin
      WriteLn('Server answered ', E.StatusCode);
      Halt(4);
    end;
    on E: ECurlError do
    begin
      WriteLn('Transport error ', E.Code, ': ', E.CurlMessage);
      Halt(2);
    end;
    on E: EHttpError do
    begin
      WriteLn('HTTP error: ', E.Message);
      Halt(3);
    end;
  end;
end.
