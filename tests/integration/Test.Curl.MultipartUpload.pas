unit Test.Curl.MultipartUpload;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport, Test.Files;

function Client: IHttpClient;
begin Result := NewHttpClient.SetBaseUrl(IntegrationBaseUrl); end;
procedure TestFieldsAndFile;
var C: IHttpClient; P: string; R: IHttpResponse;
begin
  P := MakeTempFile('mp_hello.txt', 1000);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/upload')
      .AddMultipartField('title', 'Quarterly report')
      .AddMultipartField('note', 'caf' + #$00E9 + ' ol' + #$00E1)
      .AddMultipartFile('document', P));
    CheckEqualsInt(200, R.StatusCode);
    CheckJsonField(R.Text, 'content_type', 'multipart/form-data');
    CheckJsonField(R.Text, 'title', 'Quarterly report');
    CheckJsonField(R.Text, 'note', 'caf' + #$00E9 + ' ol' + #$00E1);
    CheckJsonField(R.Text, 'field', 'document');
    CheckJsonField(R.Text, 'filename', 'mp_hello.txt');
    CheckJsonField(R.Text, 'content_type', 'text/plain');
    CheckJsonNumber(R.Text, 'sum', PatternSum(1000));
  finally DeleteTempFile(P); end;
end;
procedure TestUploadFileShortcut;
var P: string; R: IHttpResponse;
begin
  P := MakeTempFile('mp_short.bin', 2048);
  try
    R := Client.UploadFile('/upload', 'file', P);
    CheckJsonField(R.Text, 'field', 'file');
    CheckJsonField(R.Text, 'filename', 'mp_short.bin');
    CheckJsonField(R.Text, 'content_type', 'application/octet-stream');
    CheckJsonNumber(R.Text, 'size', 2048);
    CheckJsonNumber(R.Text, 'sum', PatternSum(2048));
  finally DeleteTempFile(P); end;
end;
procedure TestInMemoryBytesPart;
var C: IHttpClient; B: TBytes; R: IHttpResponse; I: Integer;
begin
  SetLength(B, 300);
  for I := 0 to High(B) do B[I] := Byte(I);
  C := Client;
  R := C.Execute(C.NewRequest(hmPost, '/upload').AddMultipartBytes('blob', 'data.bin', B, 'application/x-test'));
  CheckJsonField(R.Text, 'filename', 'data.bin');
  CheckJsonField(R.Text, 'content_type', 'application/x-test');
  CheckJsonNumber(R.Text, 'size', 300);
  CheckJsonNumber(R.Text, 'sum', 32640 + 946 { bytes 0..255 plus 0..43 });
end;
procedure TestCustomFileNameAndType;
var C: IHttpClient; P: string; R: IHttpResponse;
begin
  P := MakeTempFile('mp_orig.dat', 64);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/upload').AddMultipartFile('f', P, 'renamed.csv', 'text/csv'));
    CheckJsonField(R.Text, 'filename', 'renamed.csv');
    CheckJsonField(R.Text, 'content_type', 'text/csv');
  finally DeleteTempFile(P); end;
end;
procedure TestMultipleFiles;
var C: IHttpClient; P1, P2: string; R: IHttpResponse;
begin
  P1 := MakeTempFile('mp_one.txt', 100);
  P2 := MakeTempFile('mp_two.txt', 200);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/upload').AddMultipartFile('a', P1).AddMultipartFile('b', P2));
    CheckJsonField(R.Text, 'filename', 'mp_one.txt');
    CheckJsonField(R.Text, 'filename', 'mp_two.txt');
    CheckJsonNumber(R.Text, 'sum', PatternSum(200));
  finally DeleteTempFile(P1); DeleteTempFile(P2); end;
end;
procedure TestLargeFileIsStreamed;
var P: string; R: IHttpResponse;
begin
  P := MakeTempFile('mp_large.bin', 5 * 1024 * 1024);
  try
    R := Client.SetTimeout(60000).UploadFile('/upload', 'big', P);
    CheckJsonNumber(R.Text, 'sum', PatternSum(5 * 1024 * 1024));
  finally DeleteTempFile(P); end;
end;
procedure TestMultipartWithPutAndAuth;
var C: IHttpClient; R: IHttpResponse;
begin
  C := Client.SetBearerToken('t');
  R := C.Execute(C.NewRequest(hmPut, '/upload').AddMultipartField('k', 'v'));
  CheckJsonField(R.Text, 'method', 'PUT');
  CheckJsonField(R.Text, 'k', 'v');
end;
initialization
  RegisterTest('Curl.MultipartUpload', 'text fields and a file in one request', TestFieldsAndFile);
  RegisterTest('Curl.MultipartUpload', 'UploadFile shortcut', TestUploadFileShortcut);
  RegisterTest('Curl.MultipartUpload', 'in-memory bytes part', TestInMemoryBytesPart);
  RegisterTest('Curl.MultipartUpload', 'custom file name and content type', TestCustomFileNameAndType);
  RegisterTest('Curl.MultipartUpload', 'several files', TestMultipleFiles);
  RegisterTest('Curl.MultipartUpload', '5 MB file is streamed intact', TestLargeFileIsStreamed);
  RegisterTest('Curl.MultipartUpload', 'multipart works with PUT', TestMultipartWithPutAndAuth);
end.
