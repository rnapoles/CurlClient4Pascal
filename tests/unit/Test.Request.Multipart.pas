unit Test.Request.Multipart;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Request, Http.Errors, Test.Files;

var GR: IHttpRequest;
procedure BadFieldName; begin GR.AddMultipartField('a'#13#10'b', 'v'); end;
procedure EmptyFieldName; begin GR.AddMultipartField('', 'v'); end;
procedure MissingFile; begin GR.AddMultipartFile('f', '/no/such/file.bin'); end;
procedure BadFileName; begin GR.AddMultipartBytes('f', 'x'#10'.txt', nil); end;
procedure TestCollectsPartsInOrder;
var P: string; Parts: THttpMultipartParts;
begin
  P := MakeTempFile('req_multipart.txt', 10);
  try
    GR := NewHttpRequest(hmPost, 'http://h/u')
      .AddMultipartField('title', 'Hello')
      .AddMultipartFile('doc', P)
      .AddMultipartBytes('raw', 'blob.bin', nil);
    Parts := GR.MultipartParts;
    CheckEqualsInt(3, Length(Parts));
    CheckTrue(Parts[0].Kind = mpField);
    CheckEqualsStr('Hello', Parts[0].Value);
    CheckTrue(Parts[1].Kind = mpFile);
    CheckEqualsStr('req_multipart.txt', Parts[1].FileName, 'defaults to base name');
    CheckEqualsStr('text/plain', Parts[1].ContentType, 'guessed from extension');
    CheckTrue(Parts[2].Kind = mpBytes);
    CheckEqualsStr('application/octet-stream', Parts[2].ContentType);
  finally DeleteTempFile(P); GR := nil; end;
end;
procedure TestExplicitNameAndTypeWin;
var P: string;
begin
  P := MakeTempFile('req_multipart2.dat', 4);
  try
    GR := NewHttpRequest(hmPost).AddMultipartFile('f', P, 'custom.csv', 'text/csv');
    CheckEqualsStr('custom.csv', GR.MultipartParts[0].FileName);
    CheckEqualsStr('text/csv', GR.MultipartParts[0].ContentType);
  finally DeleteTempFile(P); GR := nil; end;
end;
procedure TestReplacesOtherBodyAndStaleContentType;
begin
  GR := NewHttpRequest(hmPost).SetJson('{}').AddMultipartField('a', '1');
  CheckEqualsInt(0, Length(GR.Body));
  CheckFalse(GR.Headers.Contains('Content-Type'), 'libcurl must generate the boundary');
  GR := nil;
end;
procedure TestValidation;
begin
  GR := NewHttpRequest(hmPost);
  CheckRaises(EHttpError, BadFieldName, 'CRLF in name');
  CheckRaises(EHttpError, EmptyFieldName);
  CheckRaises(EHttpError, MissingFile, 'file must exist');
  CheckRaises(EHttpError, BadFileName);
  CheckEqualsInt(0, Length(GR.MultipartParts));
  GR := nil;
end;
procedure TestCloneCopiesParts;
var C: IHttpRequest;
begin
  GR := NewHttpRequest(hmPost).AddMultipartField('a', '1');
  C := GR.Clone;
  C.AddMultipartField('b', '2');
  CheckEqualsInt(1, Length(GR.MultipartParts));
  CheckEqualsInt(2, Length(C.MultipartParts));
  GR := nil;
end;
initialization
  RegisterTest('Request.Multipart', 'collects fields, files and bytes in order', TestCollectsPartsInOrder);
  RegisterTest('Request.Multipart', 'explicit file name and type override defaults', TestExplicitNameAndTypeWin);
  RegisterTest('Request.Multipart', 'replaces other bodies and drops stale Content-Type', TestReplacesOtherBodyAndStaleContentType);
  RegisterTest('Request.Multipart', 'rejects control chars, empty names and missing files', TestValidation);
  RegisterTest('Request.Multipart', 'Clone copies parts independently', TestCloneCopiesParts);
end.
