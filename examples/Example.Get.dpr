program Example_Get;
{ GET with custom headers and timeouts.
  Usage: Example_Get [baseUrl]      (default https://httpbin.org) }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Http.Errors, Http.Request, Http.Response, Http.Client,
  Http.Curl.Transport;   // registers libcurl as the default transport

var
  BaseUrl: string;
  Client: IHttpClient;
  Response: IHttpResponse;
  I: Integer;
begin
  if ParamCount > 0 then BaseUrl := ParamStr(1) else BaseUrl := 'https://httpbin.org';
  try
    // Every setter returns the client, so configuration reads as one chain.
    Client := NewHttpClient
      .SetBaseUrl(BaseUrl)
      .SetUserAgent('ExampleGet/1.0')
      .SetTimeout(10000)            // whole transfer: 10 s
      .SetConnectTimeout(3000)      // connect phase: 3 s
      .SetHeader('Accept', 'application/json')
      .SetHeader('X-Request-Source', 'example');

    // Simple GET (relative URL is resolved against the base URL)
    Response := Client.Get('/get');
    WriteLn('Status : ', Response.StatusCode, ' ', Response.StatusText);
    WriteLn('Type   : ', Response.ContentType);
    WriteLn('Time   : ', Response.TotalTimeMs, ' ms');
    WriteLn('Headers:');
    for I := 0 to Response.Headers.Count - 1 do
      WriteLn('  ', Response.Headers.Names[I], ': ', Response.Headers.Values[I]);
    WriteLn('Body   : ', Response.Text);

    // Per-request header, query parameter and a tighter timeout
    Response := Client.Execute(
      Client.NewRequest(hmGet, '/get')
        .AddQuery('search', 'pascal & curl')
        .SetHeader('X-Trace-Id', '42')
        .SetTimeout(5000));
    WriteLn('Second request: ', Response.EnsureSuccess.EffectiveUrl);
  except
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
