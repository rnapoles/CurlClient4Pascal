unit Http.Errors;
{ Exception hierarchy. Free of any libcurl dependency. }
{$I Http.Defines.inc}

interface

uses
  SysUtils;

type
  { Base class of everything this library raises. }
  EHttpError = class(Exception);

  { Raised when libcurl reports a failure (curl_easy_setopt/perform/...).
    Code is the numeric CURLcode, CurlMessage is curl_easy_strerror(),
    Detail is the (optional) text from CURLOPT_ERRORBUFFER. }
  ECurlError = class(EHttpError)
  private
    FCode: Integer;
    FOperation: string;
    FCurlMessage: string;
    FDetail: string;
  public
    constructor Create(ACode: Integer; const AOperation, ACurlMessage: string;
      const ADetail: string = '');
    property Code: Integer read FCode;
    property Operation: string read FOperation;
    property CurlMessage: string read FCurlMessage;
    property Detail: string read FDetail;
  end;

  { Raised by IHttpResponse.EnsureSuccess for non 2xx responses. }
  EHttpStatusError = class(EHttpError)
  private
    FStatusCode: Integer;
    FUrl: string;
  public
    constructor Create(AStatusCode: Integer; const AUrl, AReason: string);
    property StatusCode: Integer read FStatusCode;
    property Url: string read FUrl;
  end;

  { Raised when a response exceeds THttpClientOptions.MaxResponseBytes. }
  EHttpResponseTooLarge = class(EHttpError)
  private
    FLimit: Int64;
  public
    constructor Create(ALimit: Int64);
    property Limit: Int64 read FLimit;
  end;

implementation

constructor ECurlError.Create(ACode: Integer; const AOperation, ACurlMessage,
  ADetail: string);
var
  Msg: string;
begin
  FCode := ACode;
  FOperation := AOperation;
  FCurlMessage := ACurlMessage;
  FDetail := ADetail;
  Msg := Format('libcurl error %d (%s) in %s', [ACode, ACurlMessage, AOperation]);
  if (ADetail <> '') and (ADetail <> ACurlMessage) then
    Msg := Msg + ': ' + ADetail;
  inherited Create(Msg);
end;

constructor EHttpStatusError.Create(AStatusCode: Integer; const AUrl, AReason: string);
begin
  FStatusCode := AStatusCode;
  FUrl := AUrl;
  inherited CreateFmt('HTTP %d %s (%s)', [AStatusCode, AReason, AUrl]);
end;

constructor EHttpResponseTooLarge.Create(ALimit: Int64);
begin
  FLimit := ALimit;
  inherited CreateFmt('Response body exceeded the configured limit of %d bytes', [ALimit]);
end;

end.
