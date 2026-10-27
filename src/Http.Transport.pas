unit Http.Transport;
{ Abstraction between the high-level client and the wire (Dependency
  Inversion). The libcurl implementation lives in Http.Curl.Transport;
  tests plug in a fake. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Request, Http.Response, Http.Options, Http.Errors;

type
  IHttpTransport = interface
    ['{9A4E2D18-7C63-4B0F-8E55-1D2F6B93A7C4}']
    { Request.Url is absolute and Request.Headers already contain everything
      to send (defaults, auth, cookies). Options is the effective snapshot. }
    function Execute(const Request: IHttpRequest;
      const Options: THttpClientOptions): IHttpResponse;
  end;

  TTransportFactory = function: IHttpTransport;

{ A transport unit registers itself here from its initialization section. }
procedure RegisterDefaultTransport(Factory: TTransportFactory);
function CreateDefaultTransport: IHttpTransport;

implementation

var
  GFactory: TTransportFactory = nil;

procedure RegisterDefaultTransport(Factory: TTransportFactory);
begin
  GFactory := Factory;
end;

function CreateDefaultTransport: IHttpTransport;
begin
  if not Assigned(GFactory) then
    raise EHttpError.Create('No HTTP transport registered. Add Http.Curl.Transport ' +
      'to your uses clause or pass an IHttpTransport to THttpClient.Create.');
  Result := GFactory();
end;

end.
