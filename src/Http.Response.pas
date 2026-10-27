unit Http.Response;
{ Immutable-looking response object returned by IHttpClient.
  Transports fill THttpResponse; consumers only see IHttpResponse. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Utils, Http.Headers, Http.Errors;

type
  IHttpResponse = interface
    ['{6F1D3A52-8B0E-4C77-9E21-5A3C0D7B1F10}']
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetHttpVersion: string;
    function GetHeaders: THttpHeaders;
    function GetBody: TBytes;
    function GetText: string;
    function GetContentType: string;
    function GetEffectiveUrl: string;
    function GetTotalTimeMs: Int64;
    function GetRedirectCount: Integer;

    function IsSuccess: Boolean;        // 200..299
    function IsRedirect: Boolean;       // 300..399
    function IsClientError: Boolean;    // 400..499
    function IsServerError: Boolean;    // 500..599
    { Convenience for GetHeaders.Get(Name). }
    function Header(const Name: string): string;
    { Raises EHttpStatusError unless IsSuccess; returns Self to allow chaining. }
    function EnsureSuccess: IHttpResponse;

    property StatusCode: Integer read GetStatusCode;
    property StatusText: string read GetStatusText;
    property HttpVersion: string read GetHttpVersion;
    property Headers: THttpHeaders read GetHeaders;
    property Body: TBytes read GetBody;
    property Text: string read GetText;
    property ContentType: string read GetContentType;
    property EffectiveUrl: string read GetEffectiveUrl;
    property TotalTimeMs: Int64 read GetTotalTimeMs;
    property RedirectCount: Integer read GetRedirectCount;
  end;

  THttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FHttpVersion: string;
    FHeaders: THttpHeaders;
    FBody: TBytes;
    FEffectiveUrl: string;
    FTotalTimeMs: Int64;
    FRedirectCount: Integer;
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetHttpVersion: string;
    function GetHeaders: THttpHeaders;
    function GetBody: TBytes;
    function GetText: string;
    function GetContentType: string;
    function GetEffectiveUrl: string;
    function GetTotalTimeMs: Int64;
    function GetRedirectCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function IsSuccess: Boolean;
    function IsRedirect: Boolean;
    function IsClientError: Boolean;
    function IsServerError: Boolean;
    function Header(const Name: string): string;
    function EnsureSuccess: IHttpResponse;

    { Writable side, used by transports. }
    property StatusCode: Integer read FStatusCode write FStatusCode;
    property StatusText: string read FStatusText write FStatusText;
    property HttpVersion: string read FHttpVersion write FHttpVersion;
    property Headers: THttpHeaders read FHeaders;
    property Body: TBytes read FBody write FBody;
    property EffectiveUrl: string read FEffectiveUrl write FEffectiveUrl;
    property TotalTimeMs: Int64 read FTotalTimeMs write FTotalTimeMs;
    property RedirectCount: Integer read FRedirectCount write FRedirectCount;
  end;

implementation

{ Extracts the charset parameter of a Content-Type value ('' when absent). }
function CharsetOf(const ContentType: string): string;
var
  P: Integer;
  S: string;
begin
  Result := '';
  S := AsciiLower(ContentType);
  P := Pos('charset=', S);
  if P = 0 then Exit;
  S := Copy(S, P + 8, MaxInt);
  P := Pos(';', S);
  if P > 0 then S := Copy(S, 1, P - 1);
  S := Trim(S);
  if (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"') then
    S := Copy(S, 2, Length(S) - 2);
  Result := S;
end;

constructor THttpResponse.Create;
begin
  inherited Create;
  FHeaders := THttpHeaders.Create;
end;

destructor THttpResponse.Destroy;
begin
  FHeaders.Free;
  inherited Destroy;
end;

function THttpResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function THttpResponse.GetStatusText: string;
begin
  Result := FStatusText;
end;

function THttpResponse.GetHttpVersion: string;
begin
  Result := FHttpVersion;
end;

function THttpResponse.GetHeaders: THttpHeaders;
begin
  Result := FHeaders;
end;

function THttpResponse.GetBody: TBytes;
begin
  Result := FBody;
end;

function THttpResponse.GetText: string;
var
  Cs: string;
begin
  Cs := CharsetOf(GetContentType);
  if (Cs = 'iso-8859-1') or (Cs = 'latin1') or (Cs = 'us-ascii') then
    Result := Latin1ToString(FBody)
  else
    Result := BytesToString(FBody);   // UTF-8 (default)
end;

function THttpResponse.GetContentType: string;
begin
  Result := FHeaders.Get('Content-Type');
end;

function THttpResponse.GetEffectiveUrl: string;
begin
  Result := FEffectiveUrl;
end;

function THttpResponse.GetTotalTimeMs: Int64;
begin
  Result := FTotalTimeMs;
end;

function THttpResponse.GetRedirectCount: Integer;
begin
  Result := FRedirectCount;
end;

function THttpResponse.IsSuccess: Boolean;
begin
  Result := (FStatusCode >= 200) and (FStatusCode <= 299);
end;

function THttpResponse.IsRedirect: Boolean;
begin
  Result := (FStatusCode >= 300) and (FStatusCode <= 399);
end;

function THttpResponse.IsClientError: Boolean;
begin
  Result := (FStatusCode >= 400) and (FStatusCode <= 499);
end;

function THttpResponse.IsServerError: Boolean;
begin
  Result := (FStatusCode >= 500) and (FStatusCode <= 599);
end;

function THttpResponse.Header(const Name: string): string;
begin
  Result := FHeaders.Get(Name);
end;

function THttpResponse.EnsureSuccess: IHttpResponse;
begin
  if not IsSuccess then
    raise EHttpStatusError.Create(FStatusCode, FEffectiveUrl, FStatusText);
  Result := Self;
end;

end.
