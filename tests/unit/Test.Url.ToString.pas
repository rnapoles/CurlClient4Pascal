unit Test.Url.ToString;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url;

procedure TestUrlToStringIsBuild;
var
  O: TUrl;
  U: IUrl;
begin
  O := TUrl.Create;
  U := O;                    // the interface owns the object; never call O.Free
  U.Scheme := 'http';
  U.Host := 'h.test';
  U.Path := '/p';
  CheckEqualsStr('http://h.test/p', O.ToString);
  CheckEqualsStr(U.Build, O.ToString);
  U := nil;
end;

procedure TestQueryToStringIsBuild;
var
  U: IUrl;
begin
  U := ParseUrl('http://h/?a=b%20c&d=1');
  CheckEqualsStr('a=b%20c&d=1', U.Query.ToString);
  CheckEqualsStr(U.Query.Build, U.Query.ToString);
end;

initialization
  RegisterTest('Url.ToString', 'TUrl.ToString returns Build', TestUrlToStringIsBuild);
  RegisterTest('Url.ToString', 'TUrlQuery.ToString returns the encoded query', TestQueryToStringIsBuild);
end.
