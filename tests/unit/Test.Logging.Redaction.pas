unit Test.Logging.Redaction;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging;

procedure TestSensitiveHeaderNames;
begin
  CheckTrue(IsSensitiveHeader('Authorization'));
  CheckTrue(IsSensitiveHeader('AUTHORIZATION'));
  CheckTrue(IsSensitiveHeader('proxy-authorization'));
  CheckTrue(IsSensitiveHeader('Cookie'));
  CheckTrue(IsSensitiveHeader('Set-Cookie'));
  CheckTrue(IsSensitiveHeader('X-Api-Key'));
  CheckFalse(IsSensitiveHeader('Content-Type'));
  CheckFalse(IsSensitiveHeader('Accept'));
end;
procedure TestHeaderValueRedaction;
begin
  CheckEqualsStr('***', RedactHeaderValue('Authorization', 'Bearer abc'));
  CheckEqualsStr('text/plain', RedactHeaderValue('Content-Type', 'text/plain'));
  CheckEqualsStr('', RedactHeaderValue('Authorization', ''));
end;
procedure TestHeaderLineRedaction;
begin
  CheckEqualsStr('Authorization: ***', RedactHeaderLine('Authorization: Bearer secret'));
  CheckEqualsStr('Set-Cookie: ***', RedactHeaderLine('Set-Cookie: sid=1; Path=/'));
  CheckEqualsStr('Accept: */*', RedactHeaderLine('Accept: */*'));
  CheckEqualsStr('GET /x HTTP/1.1', RedactHeaderLine('GET /x HTTP/1.1'), 'request line untouched');
  CheckEqualsStr('HTTP/1.1 200 OK', RedactHeaderLine('HTTP/1.1 200 OK'));
end;
procedure TestUrlRedaction;
begin
  CheckEqualsStr('http://ana:***@h/x', RedactUrl('http://ana:pw@h/x'));
  CheckEqualsStr('https://ana:***@h:8443/p?q=1', RedactUrl('https://ana:s3cret@h:8443/p?q=1'));
  CheckEqualsStr('http://ana@h/x', RedactUrl('http://ana@h/x'), 'user only');
  CheckEqualsStr('http://h/x', RedactUrl('http://h/x'));
  CheckEqualsStr('http://h/a@b:c', RedactUrl('http://h/a@b:c'), '@ in the path is not userinfo');
  CheckEqualsStr('/relative', RedactUrl('/relative'));
end;
initialization
  RegisterTest('Logging.Redaction', 'recognises sensitive header names', TestSensitiveHeaderNames);
  RegisterTest('Logging.Redaction', 'redacts header values', TestHeaderValueRedaction);
  RegisterTest('Logging.Redaction', 'redacts raw header lines only', TestHeaderLineRedaction);
  RegisterTest('Logging.Redaction', 'masks the password in URLs', TestUrlRedaction);
end.
