unit Test.Curl.StreamUpload;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport, Test.Files;

function Client: IHttpClient;
begin Result := NewHttpClient.SetBaseUrl(IntegrationBaseUrl); end;
procedure TestPutStreamSendsWholeStream;
var M: TMemoryStream; R: IHttpResponse;
begin
  M := MakePatternStream(70000);
  try
    R := Client.PutStream('/upload', M);
    CheckJsonField(R.Text, 'method', 'PUT');
    CheckJsonField(R.Text, 'content_type', 'application/octet-stream');
    CheckJsonNumber(R.Text, 'size', 70000);
    CheckJsonNumber(R.Text, 'sum', PatternSum(70000));
  finally M.Free; end;
end;
procedure TestUploadStartsAtCurrentPosition;
var M: TMemoryStream; R: IHttpResponse;
begin
  M := MakePatternStream(1000, 25);        // 25 junk bytes first
  try
    M.Position := 25;
    R := Client.PutStream('/upload', M, 'application/x-test');
    CheckJsonNumber(R.Text, 'size', 1000, 'junk prefix must be skipped');
    CheckJsonNumber(R.Text, 'sum', PatternSum(1000));
    CheckJsonField(R.Text, 'content_type', 'application/x-test');
  finally M.Free; end;
end;
procedure TestPositionIsRestoredAndStreamStaysUsable;
var M: TMemoryStream; R: IHttpResponse;
begin
  M := MakePatternStream(500, 10);
  try
    M.Position := 10;
    Client.PutStream('/upload', M);
    CheckEqualsInt(10, M.Position, 'position restored');
    CheckEqualsInt(510, M.Size, 'stream not freed or modified');
  finally M.Free; end;
end;
procedure TestSameRequestCanBeSentTwice;
var C: IHttpClient; M: TMemoryStream; Req: IHttpRequest; R1, R2: IHttpResponse;
begin
  M := MakePatternStream(3000);
  try
    C := Client;
    Req := C.NewRequest(hmPut, '/upload').SetBodyStream(M);
    R1 := C.Execute(Req);
    R2 := C.Execute(Req);
    CheckJsonNumber(R1.Text, 'sum', PatternSum(3000));
    CheckJsonNumber(R2.Text, 'sum', PatternSum(3000), 'second send must not be empty');
  finally M.Free; end;
end;
procedure TestUploadStreamAsMultipartPart;
var M: TMemoryStream; R: IHttpResponse;
begin
  M := MakePatternStream(2048);
  try
    R := Client.UploadStream('/upload', 'avatar', 'me.png', M);
    CheckJsonField(R.Text, 'content_type', 'multipart/form-data');
    CheckJsonField(R.Text, 'field', 'avatar');
    CheckJsonField(R.Text, 'filename', 'me.png');
    CheckJsonField(R.Text, 'content_type', 'image/png');
    CheckJsonNumber(R.Text, 'size', 2048);
    CheckJsonNumber(R.Text, 'sum', PatternSum(2048));
    CheckEqualsInt(0, M.Position);
  finally M.Free; end;
end;
procedure TestMultipartMixesStreamFileAndFields;
var C: IHttpClient; M: TMemoryStream; P: string; R: IHttpResponse;
begin
  M := MakePatternStream(100);
  P := MakeTempFile('stream_mix.txt', 200);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/upload')
      .AddMultipartField('title', 'mixed')
      .AddMultipartStream('s', 'stream.bin', M)
      .AddMultipartFile('f', P));
    CheckJsonField(R.Text, 'title', 'mixed');
    CheckJsonField(R.Text, 'filename', 'stream.bin');
    CheckJsonField(R.Text, 'filename', 'stream_mix.txt');
    CheckJsonNumber(R.Text, 'sum', PatternSum(100));
    CheckJsonNumber(R.Text, 'sum', PatternSum(200));
  finally M.Free; DeleteTempFile(P); end;
end;
procedure TestFileStreamLargeAndPartial;
var P: string; F: TFileStream; R: IHttpResponse;
begin
  P := MakeTempFile('stream_large.bin', 8 * 1024 * 1024);
  F := TFileStream.Create(P, fmOpenRead or fmShareDenyWrite);
  try
    R := Client.SetTimeout(60000).PutStream('/upload', F);
    CheckJsonNumber(R.Text, 'sum', PatternSum(8 * 1024 * 1024));
  finally F.Free; DeleteTempFile(P); end;
end;
procedure TestStreamSurvives307Redirect;
var C: IHttpClient; M: TMemoryStream; R: IHttpResponse;
begin
  M := MakePatternStream(400);
  try
    C := Client;
    R := C.Execute(C.NewRequest(hmPost, '/redirect-307').SetBodyStream(M));
    CheckEqualsInt(200, R.StatusCode);
    CheckJsonField(R.Text, 'method', 'POST');
    CheckEqualsInt(0, M.Position);
  finally M.Free; end;
end;
var GC: IHttpClient; GReq: IHttpRequest;
procedure RunIt; begin GC.Execute(GReq); end;
procedure TestGetWithStreamIsRejected;
var M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    GC := Client;
    GReq := GC.NewRequest(hmGet, '/echo').SetBodyStream(M);
    CheckRaises(EHttpError, RunIt);
  finally GReq := nil; GC := nil; M.Free; end;
end;
initialization
  RegisterTest('Curl.StreamUpload', 'PutStream sends the whole stream', TestPutStreamSendsWholeStream);
  RegisterTest('Curl.StreamUpload', 'upload starts at the current stream position', TestUploadStartsAtCurrentPosition);
  RegisterTest('Curl.StreamUpload', 'position is restored and stream stays usable', TestPositionIsRestoredAndStreamStaysUsable);
  RegisterTest('Curl.StreamUpload', 'the same request can be sent twice', TestSameRequestCanBeSentTwice);
  RegisterTest('Curl.StreamUpload', 'UploadStream sends a multipart stream part', TestUploadStreamAsMultipartPart);
  RegisterTest('Curl.StreamUpload', 'multipart mixes stream, file and fields', TestMultipartMixesStreamFileAndFields);
  RegisterTest('Curl.StreamUpload', '8 MB TFileStream is streamed intact', TestFileStreamLargeAndPartial);
  RegisterTest('Curl.StreamUpload', 'stream is rewound for a 307 redirect', TestStreamSurvives307Redirect);
  RegisterTest('Curl.StreamUpload', 'GET with a stream body is rejected', TestGetWithStreamIsRejected);
end.
