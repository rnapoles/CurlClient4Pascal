unit Test.Request.BodyFile;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Request, Http.Errors, Test.Files;

var GR: IHttpRequest;
procedure MissingFile; begin GR.SetBodyFile('/no/such/file.bin'); end;
procedure TestSetsPathAndGuessedType;
var P: string;
begin
  P := MakeTempFile('req_bodyfile.json', 8);
  try
    GR := NewHttpRequest(hmPut).SetBodyFile(P);
    CheckEqualsStr(P, GR.BodyFilePath);
    CheckEqualsStr('application/json', GR.Headers.Get('Content-Type'));
    CheckEqualsInt(0, Length(GR.Body), 'file is streamed, never loaded');
  finally DeleteTempFile(P); GR := nil; end;
end;
procedure TestExplicitContentType;
var P: string;
begin
  P := MakeTempFile('req_bodyfile.dat', 8);
  try
    GR := NewHttpRequest(hmPut).SetBodyFile(P, 'application/x-custom');
    CheckEqualsStr('application/x-custom', GR.Headers.Get('Content-Type'));
  finally DeleteTempFile(P); GR := nil; end;
end;
procedure TestLastBodyWins;
var P: string;
begin
  P := MakeTempFile('req_bodyfile2.txt', 8);
  try
    GR := NewHttpRequest(hmPost).SetBodyFile(P).SetBody('text');
    CheckEqualsStr('', GR.BodyFilePath);
    CheckEqualsInt(4, Length(GR.Body));
  finally DeleteTempFile(P); GR := nil; end;
end;
procedure TestMissingFileRaises;
begin
  GR := NewHttpRequest(hmPut);
  CheckRaises(EHttpError, MissingFile);
  GR := nil;
end;
initialization
  RegisterTest('Request.BodyFile', 'stores the path and guesses Content-Type', TestSetsPathAndGuessedType);
  RegisterTest('Request.BodyFile', 'explicit Content-Type wins', TestExplicitContentType);
  RegisterTest('Request.BodyFile', 'a later SetBody replaces the file body', TestLastBodyWins);
  RegisterTest('Request.BodyFile', 'missing file raises EHttpError', TestMissingFileRaises);
end.
