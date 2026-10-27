unit Test.Curl.Callbacks.Header;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Curl.Native, Http.Headers;

function Feed(S: TCurlHeaderSink; const Line: AnsiString): NativeUInt;
begin
  Result := CurlHeaderCallback(@Line[1], 1, Length(Line), S);
end;
procedure TestParsesStatusAndHeaders;
var S: TCurlHeaderSink;
begin
  S := TCurlHeaderSink.Create;
  try
    CheckEqualsInt(17, Feed(S, 'HTTP/1.1 200 OK'#13#10), 'returns bytes consumed');
    Feed(S, 'Content-Type: text/plain'#13#10);
    Feed(S, 'X-Multi: a'#13#10);
    Feed(S, 'X-Multi: b'#13#10);
    Feed(S, #13#10);
    CheckEqualsInt(200, S.StatusCode);
    CheckEqualsStr('OK', S.Reason);
    CheckEqualsStr('1.1', S.HttpVersion);
    CheckEqualsStr('text/plain', S.Headers.Get('content-type'));
    CheckEqualsInt(2, Length(S.Headers.GetAll('X-Multi')));
  finally S.Free; end;
end;
procedure TestNewStatusLineResetsHeaders;
var S: TCurlHeaderSink;
begin
  S := TCurlHeaderSink.Create;
  try
    Feed(S, 'HTTP/1.1 302 Found'#13#10);
    Feed(S, 'Location: /next'#13#10);
    Feed(S, 'HTTP/1.1 200 OK'#13#10);
    Feed(S, 'X-Final: yes'#13#10);
    CheckEqualsInt(200, S.StatusCode);
    CheckFalse(S.Headers.Contains('Location'), 'redirect hop headers dropped');
    CheckTrue(S.Headers.Contains('X-Final'));
  finally S.Free; end;
end;
initialization
  RegisterTest('Curl.Callbacks.Header', 'parses status line and headers', TestParsesStatusAndHeaders);
  RegisterTest('Curl.Callbacks.Header', 'a new status line resets the collection', TestNewStatusLineResetsHeaders);
end.
