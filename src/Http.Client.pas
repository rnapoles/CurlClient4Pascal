unit Http.Client;
{ High-level, fluent HTTP client (IHttpClient / THttpClient) and its builder.

  This unit knows nothing about libcurl: it talks to an IHttpTransport.
  Add Http.Curl.Transport to your uses clause to get libcurl as the default
  transport, or inject your own into THttpClient.Create / the builder.

  IMPORTANT (Delphi/FPC reference counting): always hold the client in an
  IHttpClient variable (e.g. NewHttpClient). Holding it in a THttpClient
  variable and calling the fluent methods would free the object as soon as
  the temporary interface returned by the first call goes out of scope. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes, Http.Utils, Http.Errors, Http.Headers, Http.Cookies, Http.Request,
  Http.Response, Http.Options, Http.Transport;

const
  DEFAULT_TEXT_CONTENT_TYPE = 'text/plain; charset=utf-8';
  DEFAULT_BINARY_CONTENT_TYPE = 'application/octet-stream';

type
  IHttpClient = interface
    ['{C3E5A7B9-1D2F-4E60-9B8A-7F6D5C4B3A21}']
    function GetHeaders: THttpHeaders;
    function GetCookies: THttpCookieJar;
    function GetOptions: THttpClientOptions;

    { ---- configuration (fluent) ---- }
    function SetOptions(const Value: THttpClientOptions): IHttpClient;
    function SetBaseUrl(const Value: string): IHttpClient;
    function SetUserAgent(const Value: string): IHttpClient;
    function SetTimeout(Milliseconds: Integer): IHttpClient;
    function SetConnectTimeout(Milliseconds: Integer): IHttpClient;
    function SetFollowRedirects(Enabled: Boolean; MaxRedirects: Integer = 10): IHttpClient;
    function SetVerifySsl(Enabled: Boolean): IHttpClient;
    function SetCaBundle(const Path: string): IHttpClient;
    function SetProxy(const ProxyUrl: string): IHttpClient;
    function SetCookieFile(const Path: string): IHttpClient;
    function SetMaxResponseBytes(MaxBytes: Int64): IHttpClient;
    function SetHttpVersion(Value: THttpVersion): IHttpClient;

    { ---- default headers & cookies (set / get) ---- }
    function SetHeader(const Name, Value: string): IHttpClient;
    function AddHeader(const Name, Value: string): IHttpClient;
    function RemoveHeader(const Name: string): IHttpClient;
    function GetHeader(const Name: string): string;
    function SetBearerToken(const Token: string): IHttpClient;
    function SetBasicAuth(const User, Password: string): IHttpClient;
    function SetCookie(const Name, Value: string; const Domain: string = '';
      const Path: string = '/'): IHttpClient;
    function GetCookie(const Name: string): string;
    function RemoveCookie(const Name: string): IHttpClient;

    { ---- execution ---- }
    function NewRequest(Method: THttpMethod; const Url: string): IHttpRequest;
    function Execute(const Request: IHttpRequest): IHttpResponse;
    function Get(const Url: string): IHttpResponse;
    function Head(const Url: string): IHttpResponse;
    function Delete(const Url: string): IHttpResponse;
    function Post(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function Put(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function Patch(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function PostBytes(const Url: string; const Body: TBytes;
      const ContentType: string = DEFAULT_BINARY_CONTENT_TYPE): IHttpResponse;
    function PostJson(const Url, JsonText: string): IHttpResponse;
    { NameValuePairs = ['name1', 'value1', 'name2', 'value2', ...] }
    function PostForm(const Url: string; const NameValuePairs: array of string): IHttpResponse;
    { multipart/form-data POST with a single file part (streamed from disk). }
    function UploadFile(const Url, FieldName, FilePath: string): IHttpResponse;
    { PUT with the raw content of a file as body (streamed from disk).
      ContentType '' = guessed from the file extension. }
    function PutFile(const Url, FilePath: string; const ContentType: string = ''): IHttpResponse;
    { Same, but the data comes from the rest of AStream (not owned, seekable;
      see IHttpRequest.SetBodyStream). }
    function PutStream(const Url: string; AStream: TStream;
      const ContentType: string = ''): IHttpResponse;
    { multipart/form-data POST with a single part fed from AStream. }
    function UploadStream(const Url, FieldName, FileName: string; AStream: TStream;
      const ContentType: string = ''): IHttpResponse;

    property Headers: THttpHeaders read GetHeaders;
    property Cookies: THttpCookieJar read GetCookies;
    property Options: THttpClientOptions read GetOptions;
  end;

  THttpClient = class(TInterfacedObject, IHttpClient)
  private
    FTransport: IHttpTransport;
    FOptions: THttpClientOptions;
    FHeaders: THttpHeaders;
    FCookies: THttpCookieJar;
    function GetHeaders: THttpHeaders;
    function GetCookies: THttpCookieJar;
    function GetOptions: THttpClientOptions;
    function ResolveRequest(const Request: IHttpRequest;
      out Opts: THttpClientOptions): IHttpRequest;
  public
    { ATransport = nil uses the registered default (libcurl). }
    constructor Create(const ATransport: IHttpTransport = nil);
    destructor Destroy; override;

    function SetOptions(const Value: THttpClientOptions): IHttpClient;
    function SetBaseUrl(const Value: string): IHttpClient;
    function SetUserAgent(const Value: string): IHttpClient;
    function SetTimeout(Milliseconds: Integer): IHttpClient;
    function SetConnectTimeout(Milliseconds: Integer): IHttpClient;
    function SetFollowRedirects(Enabled: Boolean; MaxRedirects: Integer = 10): IHttpClient;
    function SetVerifySsl(Enabled: Boolean): IHttpClient;
    function SetCaBundle(const Path: string): IHttpClient;
    function SetProxy(const ProxyUrl: string): IHttpClient;
    function SetCookieFile(const Path: string): IHttpClient;
    function SetMaxResponseBytes(MaxBytes: Int64): IHttpClient;
    function SetHttpVersion(Value: THttpVersion): IHttpClient;

    function SetHeader(const Name, Value: string): IHttpClient;
    function AddHeader(const Name, Value: string): IHttpClient;
    function RemoveHeader(const Name: string): IHttpClient;
    function GetHeader(const Name: string): string;
    function SetBearerToken(const Token: string): IHttpClient;
    function SetBasicAuth(const User, Password: string): IHttpClient;
    function SetCookie(const Name, Value: string; const Domain: string = '';
      const Path: string = '/'): IHttpClient;
    function GetCookie(const Name: string): string;
    function RemoveCookie(const Name: string): IHttpClient;

    function NewRequest(Method: THttpMethod; const Url: string): IHttpRequest;
    function Execute(const Request: IHttpRequest): IHttpResponse;
    function Get(const Url: string): IHttpResponse;
    function Head(const Url: string): IHttpResponse;
    function Delete(const Url: string): IHttpResponse;
    function Post(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function Put(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function Patch(const Url, Body: string;
      const ContentType: string = DEFAULT_TEXT_CONTENT_TYPE): IHttpResponse;
    function PostBytes(const Url: string; const Body: TBytes;
      const ContentType: string = DEFAULT_BINARY_CONTENT_TYPE): IHttpResponse;
    function PostJson(const Url, JsonText: string): IHttpResponse;
    function PostForm(const Url: string; const NameValuePairs: array of string): IHttpResponse;
    function UploadFile(const Url, FieldName, FilePath: string): IHttpResponse;
    function PutFile(const Url, FilePath: string; const ContentType: string = ''): IHttpResponse;
    function PutStream(const Url: string; AStream: TStream;
      const ContentType: string = ''): IHttpResponse;
    function UploadStream(const Url, FieldName, FileName: string; AStream: TStream;
      const ContentType: string = ''): IHttpResponse;
  end;

  { ---- Builder ---- }
  IHttpClientBuilder = interface
    ['{E1F3A5C7-2B4D-4968-8A7C-0D1E2F3A4B5C}']
    function BaseUrl(const Value: string): IHttpClientBuilder;
    function UserAgent(const Value: string): IHttpClientBuilder;
    function Timeout(Milliseconds: Integer): IHttpClientBuilder;
    function ConnectTimeout(Milliseconds: Integer): IHttpClientBuilder;
    function FollowRedirects(Enabled: Boolean; MaxRedirects: Integer = 10): IHttpClientBuilder;
    function VerifySsl(Enabled: Boolean): IHttpClientBuilder;
    function CaBundle(const Path: string): IHttpClientBuilder;
    function Proxy(const ProxyUrl: string): IHttpClientBuilder;
    function CookieFile(const Path: string): IHttpClientBuilder;
    function MaxResponseBytes(MaxBytes: Int64): IHttpClientBuilder;
    function HttpVersion(Value: THttpVersion): IHttpClientBuilder;
    function AutoDecompress(Enabled: Boolean): IHttpClientBuilder;
    function Header(const Name, Value: string): IHttpClientBuilder;
    function Cookie(const Name, Value: string; const Domain: string = ''): IHttpClientBuilder;
    function BearerToken(const Token: string): IHttpClientBuilder;
    function BasicAuth(const User, Password: string): IHttpClientBuilder;
    function Transport(const Value: IHttpTransport): IHttpClientBuilder;
    function Build: IHttpClient;
  end;

  THttpClientBuilder = class(TInterfacedObject, IHttpClientBuilder)
  private
    FOptions: THttpClientOptions;
    FHeaders: THttpHeaders;
    FCookies: THttpCookieJar;
    FTransport: IHttpTransport;
  public
    constructor Create;
    destructor Destroy; override;
    function BaseUrl(const Value: string): IHttpClientBuilder;
    function UserAgent(const Value: string): IHttpClientBuilder;
    function Timeout(Milliseconds: Integer): IHttpClientBuilder;
    function ConnectTimeout(Milliseconds: Integer): IHttpClientBuilder;
    function FollowRedirects(Enabled: Boolean; MaxRedirects: Integer = 10): IHttpClientBuilder;
    function VerifySsl(Enabled: Boolean): IHttpClientBuilder;
    function CaBundle(const Path: string): IHttpClientBuilder;
    function Proxy(const ProxyUrl: string): IHttpClientBuilder;
    function CookieFile(const Path: string): IHttpClientBuilder;
    function MaxResponseBytes(MaxBytes: Int64): IHttpClientBuilder;
    function HttpVersion(Value: THttpVersion): IHttpClientBuilder;
    function AutoDecompress(Enabled: Boolean): IHttpClientBuilder;
    function Header(const Name, Value: string): IHttpClientBuilder;
    function Cookie(const Name, Value: string; const Domain: string = ''): IHttpClientBuilder;
    function BearerToken(const Token: string): IHttpClientBuilder;
    function BasicAuth(const User, Password: string): IHttpClientBuilder;
    function Transport(const Value: IHttpTransport): IHttpClientBuilder;
    function Build: IHttpClient;
  end;

{ Factories - always keep the results in interface variables. }
function NewHttpClient(const ATransport: IHttpTransport = nil): IHttpClient;
function NewHttpClientBuilder: IHttpClientBuilder;

implementation

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := THttpClient.Create(ATransport);
end;

function NewHttpClientBuilder: IHttpClientBuilder;
begin
  Result := THttpClientBuilder.Create;
end;

{ THttpClient }

constructor THttpClient.Create(const ATransport: IHttpTransport);
begin
  inherited Create;
  FOptions := DefaultHttpClientOptions;
  FHeaders := THttpHeaders.Create;
  FCookies := THttpCookieJar.Create;
  if ATransport <> nil then
    FTransport := ATransport
  else
    FTransport := CreateDefaultTransport;
end;

destructor THttpClient.Destroy;
begin
  FCookies.Free;
  FHeaders.Free;
  inherited Destroy;
end;

function THttpClient.GetHeaders: THttpHeaders;
begin
  Result := FHeaders;
end;

function THttpClient.GetCookies: THttpCookieJar;
begin
  Result := FCookies;
end;

function THttpClient.GetOptions: THttpClientOptions;
begin
  Result := FOptions;
end;

function THttpClient.SetOptions(const Value: THttpClientOptions): IHttpClient;
begin
  FOptions := Value;
  Result := Self;
end;

function THttpClient.SetBaseUrl(const Value: string): IHttpClient;
begin
  FOptions.BaseUrl := Value;
  Result := Self;
end;

function THttpClient.SetUserAgent(const Value: string): IHttpClient;
begin
  FOptions.UserAgent := Value;
  Result := Self;
end;

function THttpClient.SetTimeout(Milliseconds: Integer): IHttpClient;
begin
  FOptions.TimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpClient.SetConnectTimeout(Milliseconds: Integer): IHttpClient;
begin
  FOptions.ConnectTimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpClient.SetFollowRedirects(Enabled: Boolean; MaxRedirects: Integer): IHttpClient;
begin
  FOptions.FollowRedirects := Enabled;
  FOptions.MaxRedirects := MaxRedirects;
  Result := Self;
end;

function THttpClient.SetVerifySsl(Enabled: Boolean): IHttpClient;
begin
  FOptions.VerifySsl := Enabled;
  Result := Self;
end;

function THttpClient.SetCaBundle(const Path: string): IHttpClient;
begin
  FOptions.CaBundlePath := Path;
  Result := Self;
end;

function THttpClient.SetProxy(const ProxyUrl: string): IHttpClient;
begin
  FOptions.ProxyUrl := ProxyUrl;
  Result := Self;
end;

function THttpClient.SetCookieFile(const Path: string): IHttpClient;
begin
  FOptions.CookieFile := Path;
  Result := Self;
end;

function THttpClient.SetMaxResponseBytes(MaxBytes: Int64): IHttpClient;
begin
  FOptions.MaxResponseBytes := MaxBytes;
  Result := Self;
end;

function THttpClient.SetHttpVersion(Value: THttpVersion): IHttpClient;
begin
  FOptions.HttpVersion := Value;
  Result := Self;
end;

function THttpClient.SetHeader(const Name, Value: string): IHttpClient;
begin
  FHeaders.SetValue(Name, Value);
  Result := Self;
end;

function THttpClient.AddHeader(const Name, Value: string): IHttpClient;
begin
  FHeaders.Add(Name, Value);
  Result := Self;
end;

function THttpClient.RemoveHeader(const Name: string): IHttpClient;
begin
  FHeaders.Remove(Name);
  Result := Self;
end;

function THttpClient.GetHeader(const Name: string): string;
begin
  Result := FHeaders.Get(Name);
end;

function THttpClient.SetBearerToken(const Token: string): IHttpClient;
begin
  FHeaders.SetValue('Authorization', 'Bearer ' + Token);
  Result := Self;
end;

function THttpClient.SetBasicAuth(const User, Password: string): IHttpClient;
begin
  FHeaders.SetValue('Authorization', 'Basic ' + Base64EncodeString(User + ':' + Password));
  Result := Self;
end;

function THttpClient.SetCookie(const Name, Value, Domain, Path: string): IHttpClient;
begin
  FCookies.SetCookie(Name, Value, Domain, Path);
  Result := Self;
end;

function THttpClient.GetCookie(const Name: string): string;
begin
  Result := FCookies.Get(Name);
end;

function THttpClient.RemoveCookie(const Name: string): IHttpClient;
begin
  FCookies.Remove(Name);
  Result := Self;
end;

function THttpClient.NewRequest(Method: THttpMethod; const Url: string): IHttpRequest;
begin
  Result := NewHttpRequest(Method, Url);
end;

{ Builds the immutable snapshot handed to the transport: absolute URL,
  merged headers (client defaults < request), Cookie header, effective options. }
function THttpClient.ResolveRequest(const Request: IHttpRequest;
  out Opts: THttpClientOptions): IHttpRequest;
var
  Url, CookieHeader, Existing: string;
  Parts: TUrlParts;
  Merged: THttpHeaders;
begin
  Opts := FOptions;
  Url := CombineUrl(Opts.BaseUrl, Request.Url);
  if not TryParseUrl(Url, Parts) or
     ((Parts.Scheme <> 'http') and (Parts.Scheme <> 'https')) then
    raise EHttpError.CreateFmt('Invalid or unsupported URL "%s" (only http and https are allowed)', [Url]);

  if Request.TimeoutMs <> HTTP_INHERIT then
    Opts.TimeoutMs := Request.TimeoutMs;
  if Request.ConnectTimeoutMs <> HTTP_INHERIT then
    Opts.ConnectTimeoutMs := Request.ConnectTimeoutMs;

  Result := Request.Clone;
  Result.SetUrl(Url);

  Merged := THttpHeaders.Create;
  try
    Merged.Assign(FHeaders);
    Merged.Merge(Request.Headers);
    Result.Headers.Assign(Merged);
  finally
    Merged.Free;
  end;

  CookieHeader := FCookies.BuildCookieHeader(Url);
  if CookieHeader <> '' then
  begin
    if Result.Headers.TryGetValue('Cookie', Existing) and (Existing <> '') then
      CookieHeader := Existing + '; ' + CookieHeader;
    Result.Headers.SetValue('Cookie', CookieHeader);
  end;
end;

function THttpClient.Execute(const Request: IHttpRequest): IHttpResponse;
var
  Resolved: IHttpRequest;
  Opts: THttpClientOptions;
  CookieUrl: string;
begin
  Resolved := ResolveRequest(Request, Opts);
  Result := FTransport.Execute(Resolved, Opts);
  // With CookieFile set libcurl's own engine owns cookie storage.
  if Opts.CookieFile = '' then
  begin
    CookieUrl := Result.EffectiveUrl;
    if CookieUrl = '' then CookieUrl := Resolved.Url;
    FCookies.StoreFromHeaders(CookieUrl, Result.Headers);
  end;
end;

function THttpClient.Get(const Url: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmGet, Url));
end;

function THttpClient.Head(const Url: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmHead, Url));
end;

function THttpClient.Delete(const Url: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmDelete, Url));
end;

function THttpClient.Post(const Url, Body, ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPost, Url).SetBody(Body, ContentType));
end;

function THttpClient.Put(const Url, Body, ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPut, Url).SetBody(Body, ContentType));
end;

function THttpClient.Patch(const Url, Body, ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPatch, Url).SetBody(Body, ContentType));
end;

function THttpClient.PostBytes(const Url: string; const Body: TBytes;
  const ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPost, Url).SetBodyBytes(Body, ContentType));
end;

function THttpClient.PostJson(const Url, JsonText: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPost, Url).SetJson(JsonText));
end;

function THttpClient.PostForm(const Url: string;
  const NameValuePairs: array of string): IHttpResponse;
var
  Req: IHttpRequest;
  I: Integer;
begin
  if Odd(Length(NameValuePairs)) then
    raise EHttpError.Create('PostForm expects name/value pairs (an even number of strings)');
  Req := NewRequest(hmPost, Url);
  I := 0;
  while I < Length(NameValuePairs) do
  begin
    Req.AddFormField(NameValuePairs[I], NameValuePairs[I + 1]);
    Inc(I, 2);
  end;
  Result := Execute(Req);
end;

function THttpClient.UploadFile(const Url, FieldName, FilePath: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPost, Url).AddMultipartFile(FieldName, FilePath));
end;

function THttpClient.PutFile(const Url, FilePath, ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPut, Url).SetBodyFile(FilePath, ContentType));
end;

function THttpClient.PutStream(const Url: string; AStream: TStream;
  const ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPut, Url).SetBodyStream(AStream, ContentType));
end;

function THttpClient.UploadStream(const Url, FieldName, FileName: string;
  AStream: TStream; const ContentType: string): IHttpResponse;
begin
  Result := Execute(NewRequest(hmPost, Url)
    .AddMultipartStream(FieldName, FileName, AStream, ContentType));
end;

{ THttpClientBuilder }

constructor THttpClientBuilder.Create;
begin
  inherited Create;
  FOptions := DefaultHttpClientOptions;
  FHeaders := THttpHeaders.Create;
  FCookies := THttpCookieJar.Create;
end;

destructor THttpClientBuilder.Destroy;
begin
  FCookies.Free;
  FHeaders.Free;
  inherited Destroy;
end;

function THttpClientBuilder.BaseUrl(const Value: string): IHttpClientBuilder;
begin
  FOptions.BaseUrl := Value;
  Result := Self;
end;

function THttpClientBuilder.UserAgent(const Value: string): IHttpClientBuilder;
begin
  FOptions.UserAgent := Value;
  Result := Self;
end;

function THttpClientBuilder.Timeout(Milliseconds: Integer): IHttpClientBuilder;
begin
  FOptions.TimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpClientBuilder.ConnectTimeout(Milliseconds: Integer): IHttpClientBuilder;
begin
  FOptions.ConnectTimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpClientBuilder.FollowRedirects(Enabled: Boolean;
  MaxRedirects: Integer): IHttpClientBuilder;
begin
  FOptions.FollowRedirects := Enabled;
  FOptions.MaxRedirects := MaxRedirects;
  Result := Self;
end;

function THttpClientBuilder.VerifySsl(Enabled: Boolean): IHttpClientBuilder;
begin
  FOptions.VerifySsl := Enabled;
  Result := Self;
end;

function THttpClientBuilder.CaBundle(const Path: string): IHttpClientBuilder;
begin
  FOptions.CaBundlePath := Path;
  Result := Self;
end;

function THttpClientBuilder.Proxy(const ProxyUrl: string): IHttpClientBuilder;
begin
  FOptions.ProxyUrl := ProxyUrl;
  Result := Self;
end;

function THttpClientBuilder.CookieFile(const Path: string): IHttpClientBuilder;
begin
  FOptions.CookieFile := Path;
  Result := Self;
end;

function THttpClientBuilder.MaxResponseBytes(MaxBytes: Int64): IHttpClientBuilder;
begin
  FOptions.MaxResponseBytes := MaxBytes;
  Result := Self;
end;

function THttpClientBuilder.HttpVersion(Value: THttpVersion): IHttpClientBuilder;
begin
  FOptions.HttpVersion := Value;
  Result := Self;
end;

function THttpClientBuilder.AutoDecompress(Enabled: Boolean): IHttpClientBuilder;
begin
  FOptions.AutoDecompress := Enabled;
  Result := Self;
end;

function THttpClientBuilder.Header(const Name, Value: string): IHttpClientBuilder;
begin
  FHeaders.SetValue(Name, Value);
  Result := Self;
end;

function THttpClientBuilder.Cookie(const Name, Value, Domain: string): IHttpClientBuilder;
begin
  FCookies.SetCookie(Name, Value, Domain);
  Result := Self;
end;

function THttpClientBuilder.BearerToken(const Token: string): IHttpClientBuilder;
begin
  Result := Header('Authorization', 'Bearer ' + Token);
end;

function THttpClientBuilder.BasicAuth(const User, Password: string): IHttpClientBuilder;
begin
  Result := Header('Authorization', 'Basic ' + Base64EncodeString(User + ':' + Password));
end;

function THttpClientBuilder.Transport(const Value: IHttpTransport): IHttpClientBuilder;
begin
  FTransport := Value;
  Result := Self;
end;

function THttpClientBuilder.Build: IHttpClient;
var
  C: THttpClient;
begin
  C := THttpClient.Create(FTransport);
  Result := C;                       // hold the interface before touching C
  C.FOptions := FOptions;
  C.FHeaders.Assign(FHeaders);
  C.FCookies.Assign(FCookies);
end;

end.
