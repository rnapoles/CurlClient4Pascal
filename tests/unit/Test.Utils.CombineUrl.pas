unit Test.Utils.CombineUrl;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Utils;

procedure TestJoinsWithSingleSlash;
begin
  CheckEqualsStr('http://h/api/users', CombineUrl('http://h/api/', '/users'));
  CheckEqualsStr('http://h/api/users', CombineUrl('http://h/api', 'users'));
end;
procedure TestAbsoluteUrlWins;
begin
  CheckEqualsStr('http://other/x', CombineUrl('http://h', 'http://other/x'));
end;
procedure TestEmptyBase;
begin
  CheckEqualsStr('/x', CombineUrl('', '/x'));
end;
procedure TestAppendQuery;
begin
  CheckEqualsStr('http://h/p?a=1', AppendQueryParam('http://h/p', 'a', '1'));
  CheckEqualsStr('http://h/p?a=1&b=x%20y', AppendQueryParam('http://h/p?a=1', 'b', 'x y'));
end;
initialization
  RegisterTest('Utils.CombineUrl', 'joins base and path with one slash', TestJoinsWithSingleSlash);
  RegisterTest('Utils.CombineUrl', 'absolute URL ignores base', TestAbsoluteUrlWins);
  RegisterTest('Utils.CombineUrl', 'empty base returns the relative part', TestEmptyBase);
  RegisterTest('Utils.CombineUrl', 'AppendQueryParam picks ? or & and encodes', TestAppendQuery);
end.
