unit Test.Client.InvalidUrl;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Transport;

var GC: IHttpClient; GF: TFakeTransport; GT: IHttpTransport;
procedure GetFtp; begin GC.Get('ftp://h/file'); end;
procedure GetRelativeNoBase; begin GC.Get('/just/a/path'); end;
procedure TestRejects;
begin
  GT := NewFakeTransport(GF);
  GC := NewHttpClient(GT);
  CheckRaises(EHttpError, GetFtp);
  CheckRaises(EHttpError, GetRelativeNoBase);
  CheckEqualsInt(0, GF.CallCount, 'transport must not be reached');
  GC := nil; GT := nil;
end;
initialization
  RegisterTest('Client.InvalidUrl', 'rejects non-http schemes and relative URLs without base', TestRejects);
end.
