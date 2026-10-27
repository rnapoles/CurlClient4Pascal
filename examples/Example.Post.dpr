program Example_Post;
{ POST: JSON, form data and raw text, with headers and timeouts.
  Usage: Example_Post [baseUrl]     (default https://httpbin.org) }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Http.Errors, Http.Request, Http.Response, Http.Client,
  Http.Curl.Transport;

var
  BaseUrl: string;
  Client: IHttpClient;
  Response: IHttpResponse;
begin
  if ParamCount > 0 then BaseUrl := ParamStr(1) else BaseUrl := 'https://httpbin.org';
  try
    Client := NewHttpClient
      .SetBaseUrl(BaseUrl)
      .SetTimeout(15000)
      .SetBearerToken('my-secret-token');          // Authorization: Bearer ...

    // 1) JSON body
    Response := Client.PostJson('/post', '{"name":"Ana","langs":["pascal","c"]}');
    WriteLn('JSON  -> ', Response.StatusCode);

    // 2) application/x-www-form-urlencoded
    Response := Client.PostForm('/post', ['user', 'ana', 'comment', 'ol'#$00E1' & bye']);
    WriteLn('Form  -> ', Response.StatusCode);

    // 3) Raw text with a custom content type, extra header and its own timeout
    Response := Client.Execute(
      Client.NewRequest(hmPost, '/post')
        .SetBody('<note>hi</note>', 'application/xml')
        .SetHeader('X-Idempotency-Key', 'abc-123')
        .SetTimeout(5000));
    WriteLn('XML   -> ', Response.EnsureSuccess.StatusCode);
    WriteLn(Response.Text);
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
