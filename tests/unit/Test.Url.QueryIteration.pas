unit Test.Url.QueryIteration;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url;

procedure TestForInVisitsPairsInOrder;
var U: IUrl; Pair: TUrlQueryPair; Seen: string;
begin
  U := ParseUrl('http://h/?a=1&b=2&a=3');
  Seen := '';
  for Pair in U.Query do
    Seen := Seen + Pair.Name + '=' + Pair.Value + ';';
  CheckEqualsStr('a=1;b=2;a=3;', Seen);
end;
procedure TestForInOnEmptyQuery;
var U: IUrl; Pair: TUrlQueryPair; N: Integer;
begin
  U := ParseUrl('http://h/path');
  N := 0;
  for Pair in U.Query do Inc(N);
  CheckEqualsInt(0, N);
end;
procedure TestIndexedAccess;
var Q: TUrlQuery; I: Integer; Seen: string;
begin
  Q := ParseUrl('http://h/?x=1&y=2').Query;
  Seen := '';
  for I := 0 to Q.Count - 1 do
    Seen := Seen + Q.Names[I] + Q.Values[I];
  CheckEqualsStr('x1y2', Seen);
  CheckEqualsStr('y', Q[1].Name, 'default indexed property');
end;
initialization
  RegisterTest('Url.QueryIteration', 'for..in visits pairs in order', TestForInVisitsPairsInOrder);
  RegisterTest('Url.QueryIteration', 'for..in over an empty query', TestForInOnEmptyQuery);
  RegisterTest('Url.QueryIteration', 'indexed Names/Values/Pairs access', TestIndexedAccess);
end.
