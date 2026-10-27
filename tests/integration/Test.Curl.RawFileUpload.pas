unit Test.Curl.RawFileUpload;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport, Test.Files;

function Client: IHttpClient;
begin Result := NewHttpClient.SetBaseUrl(IntegrationBaseUrl); end;
procedure TestPutFileSendsRawContent;
var P: string; R: IHttpResponse;
begin
  P := MakeTempFile('raw_put.png', 70000);
  try
    R := Client.PutFile('/upload', P);
    CheckJsonField(R.Text, 'method', 'PUT');
    CheckJsonField(R.Text, 'content_type', 'image/png');
    CheckJsonNumber(R.Text, 'size', 70000);
    CheckJsonNumber(R.Text, 'sum', PatternSum(70000));
  finally DeleteTempFile(P); end;
end;
procedure TestPostWithBodyFileAndCustomType;
var C: IHttpClient; P: string; R: IHttpResponse;
begin
  P := MakeTempFile('raw_post.bin', 1234);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/upload').SetBodyFile(P, 'application/x-special'));
    CheckJsonField(R.Text, 'content_type', 'application/x-special');
    CheckJsonNumber(R.Text, 'sum', PatternSum(1234));
  finally DeleteTempFile(P); end;
end;
procedure TestEmptyFile;
var P: string; R: IHttpResponse;
begin
  P := MakeTempFile('raw_empty.txt', 0);
  try
    R := Client.PutFile('/upload', P);
    CheckEqualsInt(200, R.StatusCode);
    CheckJsonNumber(R.Text, 'size', 0);
  finally DeleteTempFile(P); end;
end;
procedure TestLargeFileOver10MB;
var P: string; R: IHttpResponse;
begin
  P := MakeTempFile('raw_large.bin', 12 * 1024 * 1024);
  try
    R := Client.SetTimeout(120000).PutFile('/upload', P);
    CheckJsonNumber(R.Text, 'size', 12 * 1024 * 1024);
    CheckJsonNumber(R.Text, 'sum', PatternSum(12 * 1024 * 1024));
  finally DeleteTempFile(P); end;
end;
procedure TestBodyFileSurvives307Redirect;
var C: IHttpClient; P: string; R: IHttpResponse;
begin
  // 307 forces libcurl to rewind the file through the seek callback
  P := MakeTempFile('raw_307.txt', 500);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/redirect-307').SetBodyFile(P));
    CheckEqualsInt(200, R.StatusCode);
    CheckJsonField(R.Text, 'method', 'POST');
  finally DeleteTempFile(P); end;
end;
initialization
  RegisterTest('Curl.RawFileUpload', 'PutFile sends the raw file with a guessed type', TestPutFileSendsRawContent);
  RegisterTest('Curl.RawFileUpload', 'POST body file with explicit content type', TestPostWithBodyFileAndCustomType);
  RegisterTest('Curl.RawFileUpload', 'empty file uploads as empty body', TestEmptyFile);
  RegisterTest('Curl.RawFileUpload', '12 MB file is streamed intact', TestLargeFileOver10MB);
  RegisterTest('Curl.RawFileUpload', 'file body is rewound for a 307 redirect', TestBodyFileSurvives307Redirect);
end.
