unit Test.Request.BodyStream;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Request, Http.Errors;

var GR: IHttpRequest;
procedure NilBody; begin GR.SetBodyStream(nil); end;
procedure NilPart; begin GR.AddMultipartStream('f', 'x.txt', nil); end;
procedure TestStoresStreamWithDefaultType;
var M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    GR := NewHttpRequest(hmPut).SetBodyStream(M);
    CheckTrue(GR.BodyStream = M);
    CheckEqualsStr('application/octet-stream', GR.Headers.Get('Content-Type'));
    CheckEqualsInt(0, Length(GR.Body));
  finally GR := nil; M.Free; end;
end;
procedure TestExplicitContentType;
var M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    GR := NewHttpRequest(hmPost).SetBodyStream(M, 'image/png');
    CheckEqualsStr('image/png', GR.Headers.Get('Content-Type'));
  finally GR := nil; M.Free; end;
end;
procedure TestLastBodyWins;
var M: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    GR := NewHttpRequest(hmPost).SetBodyStream(M).SetBody('text');
    CheckTrue(GR.BodyStream = nil);
    CheckEqualsInt(4, Length(GR.Body));
    GR := NewHttpRequest(hmPost).SetBody('text').SetBodyStream(M);
    CheckEqualsInt(0, Length(GR.Body));
  finally GR := nil; M.Free; end;
end;
procedure TestMultipartStreamPart;
var M: TMemoryStream; P: THttpMultipartPart;
begin
  M := TMemoryStream.Create;
  try
    GR := NewHttpRequest(hmPost).SetBodyStream(M).AddMultipartStream('doc', 'notes.csv', M);
    CheckTrue(GR.BodyStream = nil, 'multipart replaces the stream body');
    CheckEqualsInt(1, Length(GR.MultipartParts));
    P := GR.MultipartParts[0];
    CheckTrue(P.Kind = mpStream);
    CheckTrue(P.Stream = M);
    CheckEqualsStr('notes.csv', P.FileName);
    CheckEqualsStr('text/csv', P.ContentType, 'guessed from the file name');
  finally GR := nil; M.Free; end;
end;
procedure TestNilStreamsRejected;
begin
  GR := NewHttpRequest(hmPost);
  CheckRaises(EHttpError, NilBody);
  CheckRaises(EHttpError, NilPart);
  GR := nil;
end;
procedure TestCloneSharesStream;
var M: TMemoryStream; C: IHttpRequest;
begin
  M := TMemoryStream.Create;
  try
    GR := NewHttpRequest(hmPut).SetBodyStream(M);
    C := GR.Clone;
    CheckTrue(C.BodyStream = M);
  finally C := nil; GR := nil; M.Free; end;
end;
initialization
  RegisterTest('Request.BodyStream', 'stores the stream with a default content type', TestStoresStreamWithDefaultType);
  RegisterTest('Request.BodyStream', 'explicit content type wins', TestExplicitContentType);
  RegisterTest('Request.BodyStream', 'last body kind wins', TestLastBodyWins);
  RegisterTest('Request.BodyStream', 'multipart stream part and type guess', TestMultipartStreamPart);
  RegisterTest('Request.BodyStream', 'nil streams are rejected', TestNilStreamsRejected);
  RegisterTest('Request.BodyStream', 'Clone keeps the same stream', TestCloneSharesStream);
end.
