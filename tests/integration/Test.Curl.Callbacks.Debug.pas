unit Test.Curl.Callbacks.Debug;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Curl.Native, Http.Logging;

procedure Feed(S: TCurlDebugSink; InfoType: Integer; const Text: AnsiString);
begin
  CurlDebugCallback(nil, InfoType, @Text[1], Length(Text), S);
end;
procedure TestTextAndHeadersGetPrefixes;
var L: IMemoryLogger; S: TCurlDebugSink;
begin
  L := NewMemoryLogger;
  S := TCurlDebugSink.Create(L, True);
  try
    Feed(S, 0, 'Connected to host'#10);
    Feed(S, 2, 'GET /x HTTP/1.1'#13#10'Host: h'#13#10#13#10);
    Feed(S, 1, 'HTTP/1.1 200 OK'#13#10);
    CheckEqualsInt(4, L.Count, 'blank header-terminator lines are skipped');
    CheckEqualsStr('DEBUG curl: * Connected to host', L[0]);
    CheckEqualsStr('DEBUG curl: > GET /x HTTP/1.1', L[1]);
    CheckEqualsStr('DEBUG curl: > Host: h', L[2]);
    CheckEqualsStr('DEBUG curl: < HTTP/1.1 200 OK', L[3]);
  finally S.Free; end;
end;
procedure TestBodyDataIsNotLogged;
var L: IMemoryLogger; S: TCurlDebugSink;
begin
  L := NewMemoryLogger;
  S := TCurlDebugSink.Create(L, True);
  try
    Feed(S, 3, 'response body bytes');
    Feed(S, 4, 'request body bytes');
    Feed(S, 5, 'tls');
    Feed(S, 6, 'tls');
    CheckEqualsInt(0, L.Count);
  finally S.Free; end;
end;
procedure TestSecretsAreRedactedOnlyWhenAsked;
var L: IMemoryLogger; S: TCurlDebugSink;
begin
  L := NewMemoryLogger;
  S := TCurlDebugSink.Create(L, True);
  try
    Feed(S, 2, 'Authorization: Bearer hunter2'#13#10'Cookie: sid=abc'#13#10);
    CheckFalse(L.Contains('hunter2'));
    CheckFalse(L.Contains('sid=abc'));
    CheckTrue(L.Contains('> Authorization: ***'));
  finally S.Free; end;
  L := NewMemoryLogger;
  S := TCurlDebugSink.Create(L, False);
  try
    Feed(S, 2, 'Authorization: Bearer hunter2'#13#10);
    CheckTrue(L.Contains('Bearer hunter2'));
  finally S.Free; end;
end;
procedure TestLevelFilterAndNilSafety;
var L: IMemoryLogger; S: TCurlDebugSink; Text: AnsiString;
begin
  L := NewMemoryLogger(llInfo);
  S := TCurlDebugSink.Create(L, True);
  try
    Feed(S, 0, 'ignored at info level'#10);
    CheckEqualsInt(0, L.Count);
  finally S.Free; end;
  Text := 'x';
  CheckEqualsInt(0, CurlDebugCallback(nil, 0, @Text[1], 1, nil), 'nil context must not crash');
  S := TCurlDebugSink.Create(nil, True);
  try Feed(S, 0, 'no logger'#10); finally S.Free; end;
end;
initialization
  RegisterTest('Curl.Callbacks.Debug', 'text and header lines get curl-style prefixes', TestTextAndHeadersGetPrefixes);
  RegisterTest('Curl.Callbacks.Debug', 'body and TLS data are not logged', TestBodyDataIsNotLogged);
  RegisterTest('Curl.Callbacks.Debug', 'secrets are redacted only when asked', TestSecretsAreRedactedOnlyWhenAsked);
  RegisterTest('Curl.Callbacks.Debug', 'level filter and nil context are safe', TestLevelFilterAndNilSafety);
end.
