unit Test.Curl.ProtocolRestriction;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport, Http.Transport;

procedure TestTransportRefusesFileScheme;
var T: IHttpTransport; Code: Integer;
begin
  T := NewCurlTransport;
  Code := 0;
  try T.Execute(NewHttpRequest(hmGet, 'file:///etc/hostname'), DefaultHttpClientOptions);
  except on E: ECurlError do Code := E.Code; end;
  CheckEqualsInt(1, Code, 'CURLE_UNSUPPORTED_PROTOCOL');
end;
initialization
  RegisterTest('Curl.ProtocolRestriction', 'transport itself refuses file://', TestTransportRefusesFileScheme);
end.
