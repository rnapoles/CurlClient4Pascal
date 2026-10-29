unit Http.Curl.Transport;
{ ===========================================================================
  HIGH-LEVEL libcurl transport.

  TCurlHttpClient implements IHttpTransport on top of Http.Curl.Native. It owns
  no raw pointers itself: every CURL* and curl_slist* lives inside an object
  that is released in a try..finally, so nothing leaks on any error path.

  Using this unit registers libcurl as THttpClient's default transport.
  =========================================================================== }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes, libcurl, Http.Errors, Http.Utils, Http.Headers,
  Http.Request, Http.Response, Http.Options, Http.Transport, Http.Curl.Native;

type
  TCurlHttpClient = class(TInterfacedObject, IHttpTransport)
  private
    procedure ConfigureConnection(Easy: TCurlEasy; const Request: IHttpRequest;
      const Options: THttpClientOptions; DebugSink: TCurlDebugSink);
    procedure ConfigureMethodAndBody(Easy: TCurlEasy; const Request: IHttpRequest;
      Source: TCurlBodySource; Mime: TCurlMime);
    procedure ApplyHttpVersion(Easy: TCurlEasy; Version: THttpVersion);
    function CreateBodySource(const Request: IHttpRequest): TCurlBodySource;
    function CreateMime(Easy: TCurlEasy; const Request: IHttpRequest): TCurlMime;
    procedure ConfigureHeaders(Easy: TCurlEasy; const Request: IHttpRequest;
      HeaderList: TCurlSlist);
    function BuildResponse(Easy: TCurlEasy; BodySink: TCurlBodySink;
      HeaderSink: TCurlHeaderSink; HasStream: Boolean): IHttpResponse;
  public
    function Execute(const Request: IHttpRequest;
      const Options: THttpClientOptions): IHttpResponse;
  end;

function NewCurlTransport: IHttpTransport;

implementation

function NewCurlTransport: IHttpTransport;
begin
  Result := TCurlHttpClient.Create;
end;

{ ---- configuration helpers ---- }

{ 1.0 and 1.1 are always available. HTTP/2 and HTTP/3 depend on how libcurl was
  built (nghttp2, QUIC); a build without them answers CURLE_UNSUPPORTED_PROTOCOL.
  They are *preferences*, so in that case we silently keep libcurl's default
  (HTTP/1.1) instead of failing the request. Any other error is still raised. }
procedure TCurlHttpClient.ApplyHttpVersion(Easy: TCurlEasy; Version: THttpVersion);
var
  Code: CURLcode;
begin
  case Version of
    hvHttp1:   Easy.SetLong(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_0);
    hvHttp1_1: Easy.SetLong(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    hvHttp2, hvHttp3:
      begin
        if Version = hvHttp2 then
          Code := Easy.TrySetLong(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS)
        else
          Code := Easy.TrySetLong(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_3);
        if (Code <> CURLE_OK) and (Code <> CURLE_UNSUPPORTED_PROTOCOL) then
          Easy.CheckResult(Code, 'curl_easy_setopt');
      end;
  else
    // hvDefault: leave libcurl's own choice untouched
  end;
end;


procedure TCurlHttpClient.ConfigureConnection(Easy: TCurlEasy;
  const Request: IHttpRequest; const Options: THttpClientOptions;
  DebugSink: TCurlDebugSink);
begin
  Easy.SetStr(CURLOPT_URL, Request.Url);

  // Only plain web protocols, also after redirects (blocks file://, ftp://, ...)
  Easy.SetStr(CURLOPT_PROTOCOLS_STR, 'http,https');
  Easy.SetStr(CURLOPT_REDIR_PROTOCOLS_STR, 'http,https');

  // Required for multi-threaded programs: no SIGALRM based timeouts
  Easy.SetBool(CURLOPT_NOSIGNAL, True);

  if Options.UserAgent <> '' then
    Easy.SetStr(CURLOPT_USERAGENT, Options.UserAgent);
  if Options.TimeoutMs > 0 then
    Easy.SetLong(CURLOPT_TIMEOUT_MS, Options.TimeoutMs);
  if Options.ConnectTimeoutMs > 0 then
    Easy.SetLong(CURLOPT_CONNECTTIMEOUT_MS, Options.ConnectTimeoutMs);

  Easy.SetBool(CURLOPT_FOLLOWLOCATION, Options.FollowRedirects);
  if Options.FollowRedirects then
    Easy.SetLong(CURLOPT_MAXREDIRS, Options.MaxRedirects);

  Easy.SetBool(CURLOPT_SSL_VERIFYPEER, Options.VerifySsl);
  if Options.VerifySsl then
    Easy.SetLong(CURLOPT_SSL_VERIFYHOST, 2)
  else
    Easy.SetLong(CURLOPT_SSL_VERIFYHOST, 0);
  if Options.CaBundlePath <> '' then
    Easy.SetStr(CURLOPT_CAINFO, Options.CaBundlePath);

  if Options.ProxyUrl <> '' then
    Easy.SetStr(CURLOPT_PROXY, Options.ProxyUrl);

  if Options.AutoDecompress then
    Easy.SetStr(CURLOPT_ACCEPT_ENCODING, '');   // '' = every encoding libcurl supports

  ApplyHttpVersion(Easy, Options.HttpVersion);

  if Options.CookieFile <> '' then
  begin
    Easy.SetStr(CURLOPT_COOKIEFILE, Options.CookieFile);  // enables the engine
    Easy.SetStr(CURLOPT_COOKIEJAR, Options.CookieFile);   // persists on cleanup
  end;

  if Options.Verbose then
  begin
    // With a logger the trace is routed to it; without one libcurl keeps
    // printing to stderr.
    if DebugSink <> nil then
    begin
      Easy.SetPtr(CURLOPT_DEBUGFUNCTION, Pointer(@CurlDebugCallback));
      Easy.SetPtr(CURLOPT_DEBUGDATA, Pointer(DebugSink));
    end;
    Easy.SetBool(CURLOPT_VERBOSE, True);
  end;
end;

{ Raw body: an in-memory buffer, a caller-owned stream, or a local file. }
function TCurlHttpClient.CreateBodySource(const Request: IHttpRequest): TCurlBodySource;
var
  Stream: TFileStream;
begin
  if Length(Request.MultipartParts) > 0 then
  begin
    Result := nil;                       // multipart uses TCurlMime instead
    Exit;
  end;
  if Request.BodyStream <> nil then
    Result := TCurlBodySource.Create(Request.BodyStream, False)   // caller keeps ownership
  else if Request.BodyFilePath <> '' then
  begin
    try
      Stream := TFileStream.Create(Request.BodyFilePath, fmOpenRead or fmShareDenyWrite);
    except
      on E: EStreamError do
        raise EHttpError.CreateFmt('Cannot open upload file "%s": %s',
          [Request.BodyFilePath, E.Message]);
    end;
    Result := TCurlBodySource.Create(Stream, True);   // source owns the stream
  end
  else
    Result := TCurlBodySource.Create(Request.Body);
end;

function TCurlHttpClient.CreateMime(Easy: TCurlEasy;
  const Request: IHttpRequest): TCurlMime;
var
  Parts: THttpMultipartParts;
  I: Integer;
begin
  Parts := Request.MultipartParts;
  Result := nil;
  if Length(Parts) = 0 then Exit;
  Result := TCurlMime.Create(Easy);
  try
    for I := 0 to High(Parts) do
      case Parts[I].Kind of
        mpField: Result.AddField(Parts[I].Name, Parts[I].Value);
        mpFile:  Result.AddFile(Parts[I].Name, Parts[I].Value, Parts[I].FileName,
                   Parts[I].ContentType);
        mpBytes: Result.AddBytes(Parts[I].Name, Parts[I].FileName, Parts[I].Data,
                   Parts[I].ContentType);
        mpStream: Result.AddStream(Parts[I].Name, Parts[I].FileName, Parts[I].Stream,
                   Parts[I].ContentType);
      end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TCurlHttpClient.ConfigureMethodAndBody(Easy: TCurlEasy;
  const Request: IHttpRequest; Source: TCurlBodySource; Mime: TCurlMime);
var
  Method: THttpMethod;
  HasBody, SendsBody: Boolean;
begin
  Method := Request.Method;
  HasBody := (Mime <> nil) or (Request.BodyFilePath <> '') or (Request.BodyStream <> nil) or
    (Length(Request.Body) > 0);

  if (Method in [hmGet, hmHead]) and HasBody then
    raise EHttpError.CreateFmt('%s requests cannot have a body', [HttpMethodToString(Method)]);

  case Method of
    hmGet:  Easy.SetBool(CURLOPT_HTTPGET, True);
    hmHead: Easy.SetBool(CURLOPT_NOBODY, True);
  end;

  if Mime <> nil then
  begin
    // multipart/form-data: libcurl builds the boundary, Content-Type and
    // Content-Length and streams every part.
    Easy.SetPtr(CURLOPT_MIMEPOST, Mime.Handle);
  end
  else
  begin
    // POST/PUT/PATCH always send a (possibly empty) body with Content-Length;
    // DELETE/OPTIONS only when one was supplied.
    SendsBody := (Method in [hmPost, hmPut, hmPatch]) or HasBody;
    if SendsBody then
    begin
      // POST + READFUNCTION + known size == streamed upload without copying
      Easy.SetBool(CURLOPT_POST, True);
      Easy.SetInt64(CURLOPT_POSTFIELDSIZE_LARGE, Source.Size);
      Easy.SetPtr(CURLOPT_READFUNCTION, Pointer(@CurlReadCallback));
      Easy.SetPtr(CURLOPT_READDATA, Pointer(Source));
      // needed to re-send the body after 307/308 redirects or auth retries
      Easy.SetPtr(CURLOPT_SEEKFUNCTION, Pointer(@CurlSeekCallback));
      Easy.SetPtr(CURLOPT_SEEKDATA, Pointer(Source));
    end;
  end;

  if Method in [hmPut, hmPatch, hmDelete, hmOptions] then
    Easy.SetStr(CURLOPT_CUSTOMREQUEST, HttpMethodToString(Method));
end;

procedure TCurlHttpClient.ConfigureHeaders(Easy: TCurlEasy;
  const Request: IHttpRequest; HeaderList: TCurlSlist);
var
  H: THttpHeaders;
  I: Integer;
begin
  H := Request.Headers;
  for I := 0 to H.Count - 1 do
    if H.Values[I] = '' then
      HeaderList.Append(H.Names[I] + ';')            // libcurl syntax: send empty header
    else
      HeaderList.Append(H.Names[I] + ': ' + H.Values[I]);
  if HeaderList.Handle <> nil then
    Easy.SetPtr(CURLOPT_HTTPHEADER, HeaderList.Handle);
end;

function TCurlHttpClient.BuildResponse(Easy: TCurlEasy; BodySink: TCurlBodySink;
  HeaderSink: TCurlHeaderSink; HasStream: Boolean): IHttpResponse;
var
  R: THttpResponse;
begin
  R := THttpResponse.Create;
  Result := R;                                       // interface owns it from here
  R.StatusCode := Integer(Easy.InfoLong(CURLINFO_RESPONSE_CODE));
  if R.StatusCode = 0 then
    R.StatusCode := HeaderSink.StatusCode;
  R.StatusText := HeaderSink.Reason;
  R.HttpVersion := HeaderSink.HttpVersion;
  R.Headers.Assign(HeaderSink.Headers);
  if not HasStream then
    R.Body := BodySink.ToBytes;
  R.EffectiveUrl := Easy.InfoStr(CURLINFO_EFFECTIVE_URL);
  R.TotalTimeMs := Easy.InfoInt64(CURLINFO_TOTAL_TIME_T) div 1000;
  R.RedirectCount := Integer(Easy.InfoLong(CURLINFO_REDIRECT_COUNT));
end;

{ ---- IHttpTransport ---- }

function TCurlHttpClient.Execute(const Request: IHttpRequest;
  const Options: THttpClientOptions): IHttpResponse;
var
  Easy: TCurlEasy;
  HeaderList: TCurlSlist;
  BodySink: TCurlBodySink;
  HeaderSink: TCurlHeaderSink;
  Source: TCurlBodySource;
  Mime: TCurlMime;
  DebugSink: TCurlDebugSink;
  Code: CURLcode;
begin
  // Strict ownership chain: every native resource is released in `finally`,
  // in reverse order of acquisition, whatever happens in between.
  Easy := TCurlEasy.Create;                          // curl_easy_init
  try
    HeaderList := TCurlSlist.Create;                 // curl_slist (may stay empty)
    try
      BodySink := TCurlBodySink.Create(Request.ResponseStream, Options.MaxResponseBytes);
      try
        HeaderSink := TCurlHeaderSink.Create;
        try
          Source := nil;
          Mime := nil;
          DebugSink := nil;
          try
            Source := CreateBodySource(Request);         // raw body / file (or nil)
            Mime := CreateMime(Easy, Request);           // multipart (or nil)
            if Options.Verbose and (Options.Logger <> nil) then
              DebugSink := TCurlDebugSink.Create(Options.Logger, Options.RedactLogs);
            ConfigureConnection(Easy, Request, Options, DebugSink);
            ConfigureMethodAndBody(Easy, Request, Source, Mime);
            ConfigureHeaders(Easy, Request, HeaderList);

            Easy.SetPtr(CURLOPT_WRITEFUNCTION, Pointer(@CurlWriteCallback));
            Easy.SetPtr(CURLOPT_WRITEDATA, Pointer(BodySink));
            Easy.SetPtr(CURLOPT_HEADERFUNCTION, Pointer(@CurlHeaderCallback));
            Easy.SetPtr(CURLOPT_HEADERDATA, Pointer(HeaderSink));

            Code := Easy.PerformRaw;
            if BodySink.LimitExceeded then
              raise EHttpResponseTooLarge.Create(Options.MaxResponseBytes);
            Easy.CheckResult(Code, 'curl_easy_perform');

            Result := BuildResponse(Easy, BodySink, HeaderSink,
              Request.ResponseStream <> nil);
          finally
            DebugSink.Free;
            Mime.Free;                                   // curl_mime_free + close files
            Source.Free;
          end;
        finally
          HeaderSink.Free;
        end;
      finally
        BodySink.Free;
      end;
    finally
      HeaderList.Free;                               // curl_slist_free_all
    end;
  finally
    Easy.Free;                                       // curl_easy_cleanup
  end;
end;

initialization
  RegisterDefaultTransport(NewCurlTransport);

end.
