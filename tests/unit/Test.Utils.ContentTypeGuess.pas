unit Test.Utils.ContentTypeGuess;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Utils;

procedure TestKnownExtensions;
begin
  CheckEqualsStr('image/png', GuessContentType('photo.PNG'));
  CheckEqualsStr('application/pdf', GuessContentType('C:\docs\report.pdf'));
  CheckEqualsStr('text/plain', GuessContentType('/tmp/a.txt'));
  CheckEqualsStr('application/json', GuessContentType('data.json'));
end;
procedure TestUnknownFallsBack;
begin
  CheckEqualsStr('application/octet-stream', GuessContentType('blob.xyz'));
  CheckEqualsStr('application/octet-stream', GuessContentType('noextension'));
end;
initialization
  RegisterTest('Utils.ContentTypeGuess', 'maps common extensions case-insensitively', TestKnownExtensions);
  RegisterTest('Utils.ContentTypeGuess', 'unknown extension gives octet-stream', TestUnknownFallsBack);
end.
