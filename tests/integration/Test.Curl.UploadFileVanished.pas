unit Test.Curl.UploadFileVanished;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport, Test.Files;

var GC: IHttpClient; GReq: IHttpRequest;
procedure RunIt; begin GC.Execute(GReq); end;
procedure TestMultipartFileDeletedBeforeSend;
var P: string;
begin
  P := MakeTempFile('vanish_mp.txt', 10);
  GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  GReq := GC.NewRequest(hmPost, '/upload').AddMultipartFile('f', P);
  DeleteTempFile(P);
  CheckRaises(EHttpError, RunIt, 'no crash, no leak, clear error');
  GReq := nil; GC := nil;
end;
procedure TestBodyFileDeletedBeforeSend;
var P: string;
begin
  P := MakeTempFile('vanish_body.txt', 10);
  GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
  GReq := GC.NewRequest(hmPut, '/upload').SetBodyFile(P);
  DeleteTempFile(P);
  CheckRaises(EHttpError, RunIt);
  GReq := nil; GC := nil;
end;
procedure TestBodyOnGetIsRejected;
var P: string;
begin
  P := MakeTempFile('vanish_get.txt', 10);
  try
    GC := NewHttpClient.SetBaseUrl(IntegrationBaseUrl);
    GReq := GC.NewRequest(hmGet, '/echo').SetBodyFile(P);
    CheckRaises(EHttpError, RunIt, 'GET cannot carry a file');
  finally DeleteTempFile(P); GReq := nil; GC := nil; end;
end;
initialization
  RegisterTest('Curl.UploadFileVanished', 'multipart file removed before send raises EHttpError', TestMultipartFileDeletedBeforeSend);
  RegisterTest('Curl.UploadFileVanished', 'body file removed before send raises EHttpError', TestBodyFileDeletedBeforeSend);
  RegisterTest('Curl.UploadFileVanished', 'GET with a file body is rejected', TestBodyOnGetIsRejected);
end.
