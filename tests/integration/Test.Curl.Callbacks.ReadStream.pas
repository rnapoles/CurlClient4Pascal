unit Test.Curl.Callbacks.ReadStream;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Curl.Native;

procedure TestReadsFromStreamPosition;
var M: TMemoryStream; Src: TCurlBodySource; Buf: array[0..7] of Byte; S: AnsiString;
begin
  M := TMemoryStream.Create;
  try
    S := 'XXabcdef';
    M.WriteBuffer(S[1], 8);
    M.Position := 2;                      // upload starts at the current position
    Src := TCurlBodySource.Create(M, False);
    try
      CheckEqualsInt(6, Src.Size);
      CheckEqualsInt(4, CurlReadCallback(@Buf[0], 1, 4, Src));
      CheckEqualsInt(Ord('a'), Buf[0]);
      CheckEqualsInt(2, CurlReadCallback(@Buf[0], 1, 4, Src));
      CheckEqualsInt(0, CurlReadCallback(@Buf[0], 1, 4, Src), 'EOF');
    finally Src.Free; end;
  finally M.Free; end;
end;
procedure TestSeekRewindsStream;
var M: TMemoryStream; Src: TCurlBodySource; Buf: array[0..7] of Byte; S: AnsiString;
begin
  M := TMemoryStream.Create;
  try
    S := 'abcdef';
    M.WriteBuffer(S[1], 6);
    M.Position := 0;
    Src := TCurlBodySource.Create(M, False);
    try
      CurlReadCallback(@Buf[0], 1, 6, Src);
      CheckEqualsInt(0, CurlSeekCallback(Src, 3, 0));
      CheckEqualsInt(3, CurlReadCallback(@Buf[0], 1, 8, Src));
      CheckEqualsInt(Ord('d'), Buf[0]);
    finally Src.Free; end;
  finally M.Free; end;
end;
procedure TestNonOwnedStreamPositionRestored;
var M: TMemoryStream; Src: TCurlBodySource; Buf: array[0..7] of Byte; S: AnsiString;
begin
  M := TMemoryStream.Create;
  try
    S := 'abcdef';
    M.WriteBuffer(S[1], 6);
    M.Position := 2;
    Src := TCurlBodySource.Create(M, False);
    CurlReadCallback(@Buf[0], 1, 4, Src);
    Src.Free;                              // not owned: stream must survive...
    CheckEqualsInt(2, M.Position, '...and be left where it was found');
  finally M.Free; end;
end;

initialization
  RegisterTest('Curl.Callbacks.ReadStream', 'reads from the stream position to its end', TestReadsFromStreamPosition);
  RegisterTest('Curl.Callbacks.ReadStream', 'seek repositions the underlying stream', TestSeekRewindsStream);
  RegisterTest('Curl.Callbacks.ReadStream', 'non-owned stream position is restored on release', TestNonOwnedStreamPositionRestored);
end.
