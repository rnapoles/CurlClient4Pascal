unit Test.Services.Parsing;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Services;

procedure TestParsesNamePortProtocol;
var Db: IServiceDatabase; P: Integer;
begin
  Db := NewServiceDatabase;
  CheckEqualsInt(1, Db.LoadFromText('ssh 22/tcp'));
  CheckTrue(Db.TryGetPort('ssh', P));
  CheckEqualsInt(22, P);
end;
procedure TestAliasesCommentsAndWhitespace;
var Db: IServiceDatabase; P: Integer; N: Integer;
begin
  Db := NewServiceDatabase;
  N := Db.LoadFromText('# full-line comment'#10 +
    'http'#9#9'80/tcp'#9'www web'#9'# trailing comment'#10 +
    '   '#10 +
    'smtp 25/tcp mail'#13#10);
  CheckEqualsInt(5, N, 'http + 2 aliases, smtp + 1 alias');
  CheckTrue(Db.TryGetPort('www', P)); CheckEqualsInt(80, P);
  CheckTrue(Db.TryGetPort('web', P)); CheckEqualsInt(80, P);
  CheckTrue(Db.TryGetPort('mail', P)); CheckEqualsInt(25, P, 'CRLF line');
  CheckFalse(Db.TryGetPort('comment', P), 'comment text is not an alias');
end;
procedure TestMalformedLinesAreIgnored;
var Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  Db.LoadFromText('justaname'#10 + 'noslash 80'#10 + 'bigport 70000/tcp'#10 +
    'zero 0/tcp'#10 + 'badnum abc/tcp'#10 + 'noproto 80/'#10 + '/tcp 80/tcp'#10);
  CheckEqualsInt(1, Db.Count, 'only the last line is valid (name = /tcp)');
end;
procedure TestLoadsAddUp;
var Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  Db.LoadFromText('a 1/tcp');
  Db.LoadFromText('b 2/tcp');
  CheckEqualsInt(2, Db.Count);
  Db.Clear;
  CheckEqualsInt(0, Db.Count);
end;
initialization
  RegisterTest('Services.Parsing', 'parses name, port and protocol', TestParsesNamePortProtocol);
  RegisterTest('Services.Parsing', 'aliases, comments, tabs and CRLF', TestAliasesCommentsAndWhitespace);
  RegisterTest('Services.Parsing', 'malformed lines are ignored', TestMalformedLinesAreIgnored);
  RegisterTest('Services.Parsing', 'loads accumulate and Clear empties', TestLoadsAddUp);
end.
