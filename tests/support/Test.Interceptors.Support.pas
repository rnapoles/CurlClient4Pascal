unit Test.Interceptors.Support;
{ Recording interceptor used by the interceptor tests. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Interceptors, Http.Request, Http.Response;

var
  { Every recorder appends "<name>:before", "<name>:after" or "<name>:error;". }
  InterceptorLog: string;

type
  TRecordingInterceptor = class(THttpInterceptor)
  private
    FName: string;
  public
    RaiseInBefore: Boolean;
    RaiseInOnError: Boolean;
    LastStatus: Integer;
    LastElapsed: Int64;
    LastUrl: string;
    LastErrorClass: string;
    LastErrorMessage: string;
    AfterCalls: Integer;
    constructor Create(const AName: string);
    procedure BeforeRequest(const Request: IHttpRequest); override;
    procedure AfterResponse(const Request: IHttpRequest; const Response: IHttpResponse;
      ElapsedMs: Int64); override;
    procedure OnError(const Request: IHttpRequest; E: Exception; ElapsedMs: Int64); override;
  end;

{ Keep BOTH results alive: the interface owns the object. }
function NewRecorder(const AName: string; out Rec: TRecordingInterceptor): IHttpInterceptor;

implementation

constructor TRecordingInterceptor.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

procedure TRecordingInterceptor.BeforeRequest(const Request: IHttpRequest);
begin
  InterceptorLog := InterceptorLog + FName + ':before;';
  if RaiseInBefore then
    raise EAbort.Create('before failed');
end;

procedure TRecordingInterceptor.AfterResponse(const Request: IHttpRequest;
  const Response: IHttpResponse; ElapsedMs: Int64);
begin
  InterceptorLog := InterceptorLog + FName + ':after;';
  Inc(AfterCalls);
  LastStatus := Response.StatusCode;
  LastElapsed := ElapsedMs;
  LastUrl := Request.Url;
end;

procedure TRecordingInterceptor.OnError(const Request: IHttpRequest; E: Exception;
  ElapsedMs: Int64);
begin
  InterceptorLog := InterceptorLog + FName + ':error;';
  LastElapsed := ElapsedMs;
  LastUrl := Request.Url;
  LastErrorClass := E.ClassName;
  LastErrorMessage := E.Message;
  if RaiseInOnError then
    raise EAbort.Create('hook failed');
end;

function NewRecorder(const AName: string; out Rec: TRecordingInterceptor): IHttpInterceptor;
begin
  Rec := TRecordingInterceptor.Create(AName);
  Result := Rec;
end;

end.
