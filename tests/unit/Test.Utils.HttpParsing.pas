unit Test.Utils.HttpParsing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Utils;

procedure TestStatusLineHttp11;
var V, R: string; C: Integer;
begin
  CheckTrue(TryParseStatusLine('HTTP/1.1 404 Not Found', V, C, R));
  CheckEqualsStr('1.1', V); CheckEqualsInt(404, C); CheckEqualsStr('Not Found', R);
end;
procedure TestStatusLineHttp2NoReason;
var V, R: string; C: Integer;
begin
  CheckTrue(TryParseStatusLine('HTTP/2 200', V, C, R));
  CheckEqualsStr('2', V); CheckEqualsInt(200, C); CheckEqualsStr('', R);
end;
procedure TestNotAStatusLine;
var V, R: string; C: Integer;
begin
  CheckFalse(TryParseStatusLine('Content-Type: text/plain', V, C, R));
end;
procedure TestHttpDate;
var D: TDateTime;
begin
  CheckTrue(TryParseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT', D));
  CheckTrue(D = EncodeDate(1994, 11, 6) + EncodeTime(8, 49, 37, 0));
  CheckTrue(TryParseHttpDate('Sunday, 06-Nov-94 08:49:37 GMT', D));
  CheckFalse(TryParseHttpDate('garbage', D));
end;
initialization
  RegisterTest('Utils.HttpParsing', 'parses HTTP/1.1 status line', TestStatusLineHttp11);
  RegisterTest('Utils.HttpParsing', 'parses HTTP/2 status line without reason', TestStatusLineHttp2NoReason);
  RegisterTest('Utils.HttpParsing', 'header line is not a status line', TestNotAStatusLine);
  RegisterTest('Utils.HttpParsing', 'parses RFC 1123 and cookie dates', TestHttpDate);
end.
