unit Test.Url.QueryParsing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url, Http.Utils;

procedure TestDecodesNamesAndValues;
var Q: TUrlQuery;
begin
  Q := ParseUrl('http://h/?name=Ana+Maria&city=S%C3%A3o%20Paulo&sym=%26%3D').Query;
  CheckEqualsStr('Ana Maria', Q.Get('name'), 'plus is a space');
  CheckEqualsStr('S' + #$00E3 + 'o Paulo', Q.Get('city'));
  CheckEqualsStr('&=', Q.Get('sym'));
end;
procedure TestDuplicatesKeepOrder;
var Q: TUrlQuery; A: THttpStringArray;
begin
  Q := ParseUrl('http://h/?t=a&u=1&t=b&t=c').Query;
  CheckEqualsInt(4, Q.Count);
  A := Q.GetAll('t');
  CheckEqualsInt(3, Length(A));
  CheckEqualsStr('a', A[0]);
  CheckEqualsStr('c', A[2]);
  CheckEqualsStr('a', Q.Get('t'), 'Get returns the first');
end;
procedure TestMissingValueAndEmptyPieces;
var Q: TUrlQuery;
begin
  Q := ParseUrl('http://h/?flag&empty=&&x=1&').Query;
  CheckEqualsInt(3, Q.Count);
  CheckTrue(Q.Contains('flag'));
  CheckEqualsStr('', Q.Get('flag', 'dflt'));
  CheckEqualsStr('', Q.Get('empty', 'dflt'));
  CheckEqualsStr('dflt', Q.Get('nope', 'dflt'));
  CheckFalse(Q.Contains('nope'));
end;
procedure TestValueContainingEquals;
begin
  CheckEqualsStr('a=b', ParseUrl('http://h/?k=a=b').Query.Get('k'));
end;
procedure TestNamesAreCaseSensitive;
var Q: TUrlQuery;
begin
  Q := ParseUrl('http://h/?A=1&a=2').Query;
  CheckEqualsStr('1', Q.Get('A'));
  CheckEqualsStr('2', Q.Get('a'));
end;
procedure TestBadPercentIsKeptLiteral;
begin
  CheckEqualsStr('100%zz', ParseUrl('http://h/?p=100%zz').Query.Get('p'));
end;
initialization
  RegisterTest('Url.QueryParsing', 'decodes percent escapes and plus', TestDecodesNamesAndValues);
  RegisterTest('Url.QueryParsing', 'duplicates are kept in order', TestDuplicatesKeepOrder);
  RegisterTest('Url.QueryParsing', 'flags, empty values and stray ampersands', TestMissingValueAndEmptyPieces);
  RegisterTest('Url.QueryParsing', 'only the first = splits name and value', TestValueContainingEquals);
  RegisterTest('Url.QueryParsing', 'names are case-sensitive', TestNamesAreCaseSensitive);
  RegisterTest('Url.QueryParsing', 'invalid escape stays literal', TestBadPercentIsKeptLiteral);
end.
