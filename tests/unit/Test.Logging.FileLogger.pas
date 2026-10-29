unit Test.Logging.FileLogger;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging, Http.Utils;

function ReadAll(const Path: string): string;
var F: TFileStream; B: TBytes;
begin
  F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  try SetLength(B, F.Size); if F.Size > 0 then F.ReadBuffer(B[0], F.Size); finally F.Free; end;
  Result := BytesToString(B);
end;
procedure TestAppendsTimestampedLines;
var P, T: string; L: IHttpLogger;
begin
  P := GetTempDirectory + 'filelogger_test.log';
  if FileExists(P) then DeleteFile(P);
  try
    L := NewFileLogger(P, llInfo);
    L.Log(llInfo, 'http', 'first');
    L.Log(llDebug, 'http', 'filtered out');
    L.Log(llError, 'curl', 'second');
    L := nil;
    // a second logger on the same file appends instead of truncating
    NewFileLogger(P, llInfo).Log(llInfo, 'http', 'third');
    T := ReadAll(P);
    CheckContains('[INFO ] http: first', T);
    CheckContains('[ERROR] curl: second', T);
    CheckContains('http: third', T);
    CheckFalse(Pos('filtered out', T) > 0);
    CheckEqualsStr('-', Copy(T, 5, 1), 'starts with a yyyy-mm-dd timestamp');
  finally DeleteFile(P); end;
end;
initialization
  RegisterTest('Logging.FileLogger', 'appends timestamped, filtered lines', TestAppendsTimestampedLines);
end.
