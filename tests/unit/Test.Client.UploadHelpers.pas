unit Test.Client.UploadHelpers;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Test.FakeTransport, Test.Files, Http.Client, Http.Request, Http.Transport, Http.Errors;

procedure TestUploadFileBuildsMultipartPost;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; P: string;
begin
  P := MakeTempFile('client_upload.txt', 16);
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T);
    C.UploadFile('http://h/upload', 'attachment', P);
    CheckTrue(F.LastRequest.Method = hmPost);
    CheckEqualsInt(1, Length(F.LastRequest.MultipartParts));
    CheckEqualsStr('attachment', F.LastRequest.MultipartParts[0].Name);
    CheckEqualsStr('client_upload.txt', F.LastRequest.MultipartParts[0].FileName);
  finally DeleteTempFile(P); end;
end;
procedure TestPutFileUsesFileBody;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; P: string;
begin
  P := MakeTempFile('client_put.json', 16);
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T);
    C.PutFile('http://h/doc', P);
    CheckTrue(F.LastRequest.Method = hmPut);
    CheckEqualsStr(P, F.LastRequest.BodyFilePath);
    CheckEqualsStr('application/json', F.LastRequest.Headers.Get('Content-Type'));
  finally DeleteTempFile(P); end;
end;
procedure TestMultipartKeepsClientHeaders;
var F: TFakeTransport; T: IHttpTransport; C: IHttpClient; P: string;
begin
  P := MakeTempFile('client_hdr.txt', 4);
  try
    T := NewFakeTransport(F);
    C := NewHttpClient(T).SetBearerToken('tok');
    C.Execute(C.NewRequest(hmPost, 'http://h/u').AddMultipartField('a', '1').AddMultipartFile('f', P));
    CheckEqualsStr('Bearer tok', F.LastRequest.Headers.Get('Authorization'));
    CheckEqualsInt(2, Length(F.LastRequest.MultipartParts));
  finally DeleteTempFile(P); end;
end;
initialization
  RegisterTest('Client.UploadHelpers', 'UploadFile builds a multipart POST', TestUploadFileBuildsMultipartPost);
  RegisterTest('Client.UploadHelpers', 'PutFile uses a streamed file body', TestPutFileUsesFileBody);
  RegisterTest('Client.UploadHelpers', 'multipart requests keep client headers', TestMultipartKeepsClientHeaders);
end.
