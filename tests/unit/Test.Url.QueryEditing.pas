unit Test.Url.QueryEditing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Url;

procedure TestAddSetRemove;
var Q: TUrlQuery;
begin
  Q := ParseUrl('http://h/?a=1&b=2&a=3').Query;
  Q.Add('c', '4');
  CheckEqualsInt(4, Q.Count);
  Q.SetValue('a', '9');
  CheckEqualsInt(1, Length(Q.GetAll('a')));
  CheckEqualsStr('9', Q.Get('a'));
  CheckEqualsInt(1, Q.Remove('b'));
  CheckEqualsInt(0, Q.Remove('zzz'));
  Q.Clear;
  CheckEqualsInt(0, Q.Count);
end;
procedure TestToStringEncodes;
var Q: TUrlQuery;
begin
  Q := ParseUrl('http://h/').Query;
  Q.Add('q', 'a b&c');
  Q.Add('lang', 'pt-BR');
  CheckEqualsStr('q=a%20b%26c&lang=pt-BR', Q.ToString);
end;
initialization
  RegisterTest('Url.QueryEditing', 'add, set, remove and clear', TestAddSetRemove);
  RegisterTest('Url.QueryEditing', 'ToString percent-encodes', TestToStringEncodes);
end.
