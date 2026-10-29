unit Test.FakeTransport;
{ In-memory IHttpTransport used by the unit tests: records what the client
  sent and answers with a canned response. No network, no libcurl. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Utils, Http.Request, Http.Response, Http.Options, Http.Transport;

type
  TFakeTransport = class(TInterfacedObject, IHttpTransport)
  private
    FLastRequest: IHttpRequest;
    FLastOptions: THttpClientOptions;
    FCallCount: Integer;
    FStatusCode: Integer;
    FBodyText: string;
    FFailClass: ExceptClass;
    FFailMessage: string;
    FResponseHeaders: array of array[0..1] of string;
  public
    constructor Create;
    { Canned answer }
    procedure RespondWith(AStatusCode: Integer; const ABodyText: string = '');
    procedure AddResponseHeader(const Name, Value: string);
    { Make Execute raise AClass.Create(Msg) (after recording the request). }
    procedure FailWith(AClass: ExceptClass; const Msg: string);
    function Execute(const Request: IHttpRequest;
      const Options: THttpClientOptions): IHttpResponse;
    property LastRequest: IHttpRequest read FLastRequest;
    property LastOptions: THttpClientOptions read FLastOptions;
    property CallCount: Integer read FCallCount;
  end;

{ Creates a fake. Keep BOTH the returned interface and the object reference
  alive in the test (the interface owns the object). }
function NewFakeTransport(out Fake: TFakeTransport): IHttpTransport;

implementation

function NewFakeTransport(out Fake: TFakeTransport): IHttpTransport;
begin
  Fake := TFakeTransport.Create;
  Result := Fake;
end;

constructor TFakeTransport.Create;
begin
  inherited Create;
  FStatusCode := 200;
end;

procedure TFakeTransport.RespondWith(AStatusCode: Integer; const ABodyText: string);
begin
  FStatusCode := AStatusCode;
  FBodyText := ABodyText;
end;

procedure TFakeTransport.FailWith(AClass: ExceptClass; const Msg: string);
begin
  FFailClass := AClass;
  FFailMessage := Msg;
end;

procedure TFakeTransport.AddResponseHeader(const Name, Value: string);
begin
  SetLength(FResponseHeaders, Length(FResponseHeaders) + 1);
  FResponseHeaders[High(FResponseHeaders)][0] := Name;
  FResponseHeaders[High(FResponseHeaders)][1] := Value;
end;

function TFakeTransport.Execute(const Request: IHttpRequest;
  const Options: THttpClientOptions): IHttpResponse;
var
  R: THttpResponse;
  I: Integer;
begin
  Inc(FCallCount);
  FLastRequest := Request;
  FLastOptions := Options;
  if FFailClass <> nil then
    raise FFailClass.Create(FFailMessage);
  R := THttpResponse.Create;
  Result := R;
  R.StatusCode := FStatusCode;
  R.StatusText := 'FAKE';
  R.Body := StringToBytes(FBodyText);
  R.EffectiveUrl := Request.Url;
  for I := 0 to High(FResponseHeaders) do
    R.Headers.Add(FResponseHeaders[I][0], FResponseHeaders[I][1]);
end;

end.
