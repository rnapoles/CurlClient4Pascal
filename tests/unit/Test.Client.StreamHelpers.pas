unit Test.Client.StreamHelpers;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Http.Client, Http.Request, Http.Transport;

procedure TestPutStream;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T);
    C.PutStream('http://h/x', M, 'application/x-data');
    CheckTrue(F.LastRequest.Method = hmPut);
    CheckTrue(F.LastRequest.BodyStream = M);
    CheckEqualsStr('application/x-data', F.LastRequest.Headers.Get('Content-Type'));
  finally M.Free; end;
end;
procedure TestUploadStream;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T);
    C.UploadStream('http://h/u', 'avatar', 'me.png', M);
    CheckTrue(F.LastRequest.Method = hmPost);
    CheckEqualsInt(1, Length(F.LastRequest.MultipartParts));
    CheckTrue(F.LastRequest.MultipartParts[0].Stream = M);
    CheckEqualsStr('image/png', F.LastRequest.MultipartParts[0].ContentType);
  finally M.Free; end;
end;
initialization
  RegisterTest('Client.StreamHelpers', 'PutStream builds a stream-body PUT', TestPutStream);
  RegisterTest('Client.StreamHelpers', 'UploadStream builds a multipart stream part', TestUploadStream);
end.
