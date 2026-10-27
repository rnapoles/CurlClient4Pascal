unit Test.Curl.Callbacks.Read;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Curl.Native, Http.Utils;

procedure TestReadsInChunksThenEof;
var Src: TCurlBodySource; B: TBytes; Buf: array[0..3] of Byte;
begin
  B := StringToBytes('abcdef');
  Src := TCurlBodySource.Create(B);
  try
    CheckEqualsInt(4, CurlReadCallback(@Buf[0], 1, 4, Src));
    CheckEqualsInt(2, CurlReadCallback(@Buf[0], 1, 4, Src));
    CheckEqualsInt(Ord('f'), Buf[1]);
    CheckEqualsInt(0, CurlReadCallback(@Buf[0], 1, 4, Src), 'EOF');
  finally Src.Free; end;
end;
procedure TestSeekRewinds;
var Src: TCurlBodySource; Buf: array[0..3] of Byte;
begin
  Src := TCurlBodySource.Create(StringToBytes('abcd'));
  try
    CurlReadCallback(@Buf[0], 1, 4, Src);
    CheckEqualsInt(0, CurlSeekCallback(Src, 0, 0), 'CURL_SEEKFUNC_OK');
    CheckEqualsInt(4, CurlReadCallback(@Buf[0], 1, 4, Src));
    CheckEqualsInt(1, CurlSeekCallback(Src, 99, 0), 'beyond end fails');
  finally Src.Free; end;
end;
initialization
  RegisterTest('Curl.Callbacks.Read', 'delivers the body in chunks until EOF', TestReadsInChunksThenEof);
  RegisterTest('Curl.Callbacks.Read', 'seek callback rewinds the body', TestSeekRewinds);
end.
