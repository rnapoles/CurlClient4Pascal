unit Test.Utils.Base64;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Test.Framework, Http.Utils;

procedure TestRfcVectors;
begin
  CheckEqualsStr('', Base64EncodeString(''));
  CheckEqualsStr('Zg==', Base64EncodeString('f'));
  CheckEqualsStr('Zm8=', Base64EncodeString('fo'));
  CheckEqualsStr('Zm9v', Base64EncodeString('foo'));
  CheckEqualsStr('Zm9vYg==', Base64EncodeString('foob'));
end;
procedure TestBasicAuthSample;
begin
  CheckEqualsStr('QWxhZGRpbjpvcGVuIHNlc2FtZQ==', Base64EncodeString('Aladdin:open sesame'));
end;
initialization
  RegisterTest('Utils.Base64', 'matches RFC 4648 vectors', TestRfcVectors);
  RegisterTest('Utils.Base64', 'matches the RFC 7617 Basic sample', TestBasicAuthSample);
end.
