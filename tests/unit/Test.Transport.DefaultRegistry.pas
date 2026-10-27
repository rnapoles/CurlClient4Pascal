unit Test.Transport.DefaultRegistry;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Transport, Http.Errors;

procedure TestNoTransportRaisesHelpfulError;
var Raised: Boolean;
begin
  // The unit-test runner links no libcurl, so nothing is registered.
  Raised := False;
  try NewHttpClient; except on EHttpError do Raised := True; end;
  CheckTrue(Raised);
end;
initialization
  RegisterTest('Transport.DefaultRegistry', 'client without any transport raises EHttpError', TestNoTransportRaisesHelpfulError);
end.
