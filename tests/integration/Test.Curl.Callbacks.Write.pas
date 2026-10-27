unit Test.Curl.Callbacks.Write;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Curl.Native;

procedure TestAccumulatesInMemory;
var S: TCurlBodySink; B: TBytes; Data: AnsiString;
begin
  S := TCurlBodySink.Create(nil, 0);
  try
    Data := 'hello';
    CheckEqualsInt(5, CurlWriteCallback(@Data[1], 1, 5, S));
    CheckEqualsInt(5, CurlWriteCallback(@Data[1], 5, 1, S), 'size*nmemb');
    B := S.ToBytes;
    CheckEqualsInt(10, Length(B));
    CheckEqualsInt(Ord('h'), B[5]);
  finally S.Free; end;
end;
procedure TestWritesToStream;
var S: TCurlBodySink; M: TMemoryStream; Data: AnsiString;
begin
  M := TMemoryStream.Create;
  S := TCurlBodySink.Create(M, 0);
  try
    Data := 'abc';
    CheckEqualsInt(3, CurlWriteCallback(@Data[1], 1, 3, S));
    CheckEqualsInt(3, M.Size);
  finally S.Free; M.Free; end;
end;
procedure TestLimitAbortsTransfer;
var S: TCurlBodySink; Data: AnsiString;
begin
  S := TCurlBodySink.Create(nil, 4);
  try
    Data := '12345';
    CheckEqualsInt(0, CurlWriteCallback(@Data[1], 1, 5, S), '0 tells libcurl to abort');
    CheckTrue(S.LimitExceeded);
  finally S.Free; end;
end;
procedure TestNilContextIsSafe;
var Data: AnsiString;
begin
  Data := 'x';
  CheckEqualsInt(0, CurlWriteCallback(@Data[1], 1, 1, nil));
end;
initialization
  RegisterTest('Curl.Callbacks.Write', 'accumulates chunks in memory', TestAccumulatesInMemory);
  RegisterTest('Curl.Callbacks.Write', 'can stream into a TStream', TestWritesToStream);
  RegisterTest('Curl.Callbacks.Write', 'size limit aborts the transfer', TestLimitAbortsTransfer);
  RegisterTest('Curl.Callbacks.Write', 'nil context returns an error instead of crashing', TestNilContextIsSafe);
end.
