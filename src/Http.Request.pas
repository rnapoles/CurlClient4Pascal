unit Http.Request;
{ Fluent request description. Pure data: nothing here talks to libcurl. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes, Http.Utils, Http.Headers;

type
  THttpMethod = (hmGet, hmPost, hmPut, hmPatch, hmDelete, hmHead, hmOptions);

const
  { Value of TimeoutMs / ConnectTimeoutMs meaning "use the client default". }
  HTTP_INHERIT = -1;

function HttpMethodToString(Method: THttpMethod): string;

type
  IHttpRequest = interface
    ['{2B7E9C41-5D3A-4F68-A0B2-9C1E8D4F6A21}']
    function GetMethod: THttpMethod;
    function GetUrl: string;
    function GetHeaders: THttpHeaders;
    function GetBody: TBytes;
    function GetTimeoutMs: Integer;
    function GetConnectTimeoutMs: Integer;
    function GetResponseStream: TStream;

    { --- fluent configuration (each returns the same request) --- }
    function SetMethod(Value: THttpMethod): IHttpRequest;
    function SetUrl(const Value: string): IHttpRequest;
    { Appends ?name=value (URL-encoded). Call after SetUrl. }
    function AddQuery(const Name, Value: string): IHttpRequest;
    function SetHeader(const Name, Value: string): IHttpRequest;
    function AddHeader(const Name, Value: string): IHttpRequest;
    function RemoveHeader(const Name: string): IHttpRequest;
    { Text body encoded as UTF-8. ContentType '' leaves Content-Type untouched. }
    function SetBody(const Text: string; const ContentType: string = ''): IHttpRequest;
    function SetBodyBytes(const Data: TBytes; const ContentType: string = ''): IHttpRequest;
    { Text body with Content-Type: application/json; charset=utf-8 }
    function SetJson(const JsonText: string): IHttpRequest;
    { Adds name=value to an application/x-www-form-urlencoded body. }
    function AddFormField(const Name, Value: string): IHttpRequest;
    function SetTimeout(Milliseconds: Integer): IHttpRequest;
    function SetConnectTimeout(Milliseconds: Integer): IHttpRequest;
    { Streams the response body into AStream (not owned) instead of memory. }
    function SaveResponseTo(AStream: TStream): IHttpRequest;
    function Clone: IHttpRequest;

    property Method: THttpMethod read GetMethod;
    property Url: string read GetUrl;
    property Headers: THttpHeaders read GetHeaders;
    property Body: TBytes read GetBody;
    property TimeoutMs: Integer read GetTimeoutMs;
    property ConnectTimeoutMs: Integer read GetConnectTimeoutMs;
    property ResponseStream: TStream read GetResponseStream;
  end;

  THttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: THttpMethod;
    FUrl: string;
    FHeaders: THttpHeaders;
    FBody: TBytes;
    FForm: string;
    FTimeoutMs: Integer;
    FConnectTimeoutMs: Integer;
    FResponseStream: TStream;
    function GetMethod: THttpMethod;
    function GetUrl: string;
    function GetHeaders: THttpHeaders;
    function GetBody: TBytes;
    function GetTimeoutMs: Integer;
    function GetConnectTimeoutMs: Integer;
    function GetResponseStream: TStream;
  public
    constructor Create(AMethod: THttpMethod = hmGet; const AUrl: string = '');
    destructor Destroy; override;
    function SetMethod(Value: THttpMethod): IHttpRequest;
    function SetUrl(const Value: string): IHttpRequest;
    function AddQuery(const Name, Value: string): IHttpRequest;
    function SetHeader(const Name, Value: string): IHttpRequest;
    function AddHeader(const Name, Value: string): IHttpRequest;
    function RemoveHeader(const Name: string): IHttpRequest;
    function SetBody(const Text: string; const ContentType: string = ''): IHttpRequest;
    function SetBodyBytes(const Data: TBytes; const ContentType: string = ''): IHttpRequest;
    function SetJson(const JsonText: string): IHttpRequest;
    function AddFormField(const Name, Value: string): IHttpRequest;
    function SetTimeout(Milliseconds: Integer): IHttpRequest;
    function SetConnectTimeout(Milliseconds: Integer): IHttpRequest;
    function SaveResponseTo(AStream: TStream): IHttpRequest;
    function Clone: IHttpRequest;
  end;

{ Factory. Always keep the result in an IHttpRequest variable. }
function NewHttpRequest(AMethod: THttpMethod = hmGet; const AUrl: string = ''): IHttpRequest;

implementation

function HttpMethodToString(Method: THttpMethod): string;
begin
  case Method of
    hmGet:     Result := 'GET';
    hmPost:    Result := 'POST';
    hmPut:     Result := 'PUT';
    hmPatch:   Result := 'PATCH';
    hmDelete:  Result := 'DELETE';
    hmHead:    Result := 'HEAD';
    hmOptions: Result := 'OPTIONS';
  else
    Result := 'GET';
  end;
end;

function NewHttpRequest(AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := THttpRequest.Create(AMethod, AUrl);
end;

{ THttpRequest }

constructor THttpRequest.Create(AMethod: THttpMethod; const AUrl: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := AUrl;
  FHeaders := THttpHeaders.Create;
  FTimeoutMs := HTTP_INHERIT;
  FConnectTimeoutMs := HTTP_INHERIT;
end;

destructor THttpRequest.Destroy;
begin
  FHeaders.Free;
  inherited Destroy;
end;

function THttpRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function THttpRequest.GetUrl: string;
begin
  Result := FUrl;
end;

function THttpRequest.GetHeaders: THttpHeaders;
begin
  Result := FHeaders;
end;

function THttpRequest.GetBody: TBytes;
begin
  Result := FBody;
end;

function THttpRequest.GetTimeoutMs: Integer;
begin
  Result := FTimeoutMs;
end;

function THttpRequest.GetConnectTimeoutMs: Integer;
begin
  Result := FConnectTimeoutMs;
end;

function THttpRequest.GetResponseStream: TStream;
begin
  Result := FResponseStream;
end;

function THttpRequest.SetMethod(Value: THttpMethod): IHttpRequest;
begin
  FMethod := Value;
  Result := Self;
end;

function THttpRequest.SetUrl(const Value: string): IHttpRequest;
begin
  FUrl := Value;
  Result := Self;
end;

function THttpRequest.AddQuery(const Name, Value: string): IHttpRequest;
begin
  FUrl := AppendQueryParam(FUrl, Name, Value);
  Result := Self;
end;

function THttpRequest.SetHeader(const Name, Value: string): IHttpRequest;
begin
  FHeaders.SetValue(Name, Value);
  Result := Self;
end;

function THttpRequest.AddHeader(const Name, Value: string): IHttpRequest;
begin
  FHeaders.Add(Name, Value);
  Result := Self;
end;

function THttpRequest.RemoveHeader(const Name: string): IHttpRequest;
begin
  FHeaders.Remove(Name);
  Result := Self;
end;

function THttpRequest.SetBody(const Text, ContentType: string): IHttpRequest;
begin
  Result := SetBodyBytes(StringToBytes(Text), ContentType);
end;

function THttpRequest.SetBodyBytes(const Data: TBytes; const ContentType: string): IHttpRequest;
begin
  FBody := Data;
  FForm := '';
  if ContentType <> '' then
    FHeaders.SetValue('Content-Type', ContentType);
  Result := Self;
end;

function THttpRequest.SetJson(const JsonText: string): IHttpRequest;
begin
  Result := SetBody(JsonText, 'application/json; charset=utf-8');
end;

function THttpRequest.AddFormField(const Name, Value: string): IHttpRequest;
begin
  if FForm <> '' then FForm := FForm + '&';
  FForm := FForm + UrlEncode(Name) + '=' + UrlEncode(Value);
  FBody := StringToBytes(FForm);
  FHeaders.SetValue('Content-Type', 'application/x-www-form-urlencoded');
  Result := Self;
end;

function THttpRequest.SetTimeout(Milliseconds: Integer): IHttpRequest;
begin
  FTimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpRequest.SetConnectTimeout(Milliseconds: Integer): IHttpRequest;
begin
  FConnectTimeoutMs := Milliseconds;
  Result := Self;
end;

function THttpRequest.SaveResponseTo(AStream: TStream): IHttpRequest;
begin
  FResponseStream := AStream;
  Result := Self;
end;

function THttpRequest.Clone: IHttpRequest;
var
  C: THttpRequest;
begin
  C := THttpRequest.Create(FMethod, FUrl);
  Result := C;                       // take the reference before anything can fail
  C.FHeaders.Assign(FHeaders);
  C.FBody := FBody;                  // shared, reference-counted; bytes are never mutated in place
  C.FForm := FForm;
  C.FTimeoutMs := FTimeoutMs;
  C.FConnectTimeoutMs := FConnectTimeoutMs;
  C.FResponseStream := FResponseStream;
end;

end.
