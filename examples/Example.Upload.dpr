program Example_Upload;
{ File upload with THttpClient:
    1. multipart/form-data  - text fields + a file + in-memory bytes
    2. UploadFile shortcut  - one file, one line
    3. raw file upload      - PutFile (the file IS the request body)
    4. any TStream          - PutStream / UploadStream (memory, compressed, DB blob...)
  Files are streamed from disk, so memory use stays flat for huge files.

  Usage: Example_Upload [baseUrl] [uploadPath]
         defaults: https://httpbin.org  (multipart -> /post, raw -> /put)
         with an explicit uploadPath it is used for both uploads, e.g.
         Example_Upload http://127.0.0.1:18080 /upload }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils, Classes,
  Http.Errors, Http.Request, Http.Response, Http.Client,
  Http.Curl.Transport;

{ Creates a small demo file so the sample is self-contained. }
function CreateDemoFile(const Name, Content: string): string;
var
  L: TStringList;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + Name;
  L := TStringList.Create;
  try
    L.Text := Content;
    L.SaveToFile(Result);
  finally
    L.Free;
  end;
end;

var
  BaseUrl, PostPath, PutPath, ReportFile, LogoFile: string;
  Client: IHttpClient;
  Response: IHttpResponse;
  Thumbnail: TBytes;
  Payload: TMemoryStream;
  Text: AnsiString;
  I: Integer;
begin
  if ParamCount > 0 then BaseUrl := ParamStr(1) else BaseUrl := 'https://httpbin.org';
  if ParamCount > 1 then
  begin
    PostPath := ParamStr(2);
    PutPath := ParamStr(2);
  end
  else
  begin
    PostPath := '/post';
    PutPath := '/put';
  end;

  ReportFile := CreateDemoFile('upload-demo-report.txt', 'Quarterly report'#13#10'Revenue: 42');
  LogoFile := CreateDemoFile('upload-demo-data.csv', 'id,name'#13#10'1,Ana'#13#10'2,Bruno');
  try
    try
      Client := NewHttpClient
        .SetBaseUrl(BaseUrl)
        .SetTimeout(120000)             // uploads may be slow: 2 minutes
        .SetConnectTimeout(5000)
        .SetBearerToken('my-secret-token');

      // ---- 1. multipart/form-data: fields + files + raw bytes -----------
      SetLength(Thumbnail, 16);
      for I := 0 to High(Thumbnail) do Thumbnail[I] := Byte(I * 16);

      Response := Client.Execute(
        Client.NewRequest(hmPost, PostPath)
          .AddMultipartField('title', 'Q3 report')               // plain text field
          .AddMultipartField('author', 'Ana Gon' + #$00E7 + 'alves')
          .AddMultipartFile('report', ReportFile)                // name + type taken from the path
          .AddMultipartFile('data', LogoFile, 'export.csv', 'text/csv')   // custom name/type
          .AddMultipartBytes('thumb', 'thumb.bin', Thumbnail)    // in-memory part
          .SetHeader('X-Upload-Id', 'demo-001'));
      WriteLn('1) multipart      -> HTTP ', Response.StatusCode);
      WriteLn(Response.Text);

      // ---- 2. one-liner for a single file -------------------------------
      Response := Client.UploadFile(PostPath, 'file', ReportFile);
      WriteLn('2) UploadFile     -> HTTP ', Response.EnsureSuccess.StatusCode);

      // ---- 3. raw upload: the file is the whole request body ------------
      Response := Client.PutFile(PutPath, LogoFile);             // Content-Type: text/csv
      WriteLn('3) PutFile        -> HTTP ', Response.EnsureSuccess.StatusCode);

      // ---- 4. upload from ANY TStream ------------------------------------
      // The stream is not owned: you free it. Data is read from its current
      // Position to the end, and the Position is restored afterwards.
      Payload := TMemoryStream.Create;
      try
        Text := 'header-to-skip|{"generated":"in memory"}';
        Payload.WriteBuffer(Text[1], Length(Text));
        Payload.Position := Length('header-to-skip|');       // skip the prefix

        Response := Client.PutStream(PutPath, Payload, 'application/json');
        WriteLn('4a) PutStream     -> HTTP ', Response.EnsureSuccess.StatusCode);

        // Same stream as one part of a multipart form (position was restored)
        Response := Client.UploadStream(PostPath, 'attachment', 'generated.json', Payload);
        WriteLn('4b) UploadStream  -> HTTP ', Response.EnsureSuccess.StatusCode);

        // or mixed with other parts in a hand-built request
        Response := Client.Execute(
          Client.NewRequest(hmPost, PostPath)
            .AddMultipartField('kind', 'mixed')
            .AddMultipartStream('payload', 'p.json', Payload)
            .AddMultipartFile('report', ReportFile));
        WriteLn('4c) mixed parts   -> HTTP ', Response.EnsureSuccess.StatusCode);
      finally
        Payload.Free;
      end;

      // Errors are explicit: a missing file is reported before any network I/O
      try
        Client.UploadFile(PostPath, 'file', 'C:\does\not\exist.bin');
      except
        on E: EHttpError do
          WriteLn('5) missing file   -> ', E.Message);
      end;
    except
      on E: ECurlError do
      begin
        WriteLn('Transport error ', E.Code, ': ', E.CurlMessage);
        Halt(2);
      end;
      on E: EHttpStatusError do
      begin
        WriteLn('Server answered ', E.StatusCode);
        Halt(4);
      end;
      on E: EHttpError do
      begin
        WriteLn('HTTP error: ', E.Message);
        Halt(3);
      end;
    end;
  finally
    DeleteFile(ReportFile);
    DeleteFile(LogoFile);
  end;
end.
