program RunIntegrationTests;
{ Tests the libcurl transport. Needs libcurl; most tests also need the local
  echo server (HTTP_TEST_BASE_URL) and are skipped when it is not running. }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  {$IFDEF FPC}{$IFDEF UNIX}cthreads,{$ENDIF}{$ENDIF}
  SysUtils, Test.Framework,
  Test.Curl.Callbacks.Write, Test.Curl.Callbacks.Header, Test.Curl.Callbacks.Read, Test.Curl.Callbacks.ReadStream,
  Test.Curl.ConnectionRefused, Test.Curl.ProtocolRestriction,
  Test.Curl.Get, Test.Curl.PostBody, Test.Curl.PutPatchDelete, Test.Curl.Head,
  Test.Curl.RequestHeaders, Test.Curl.ResponseHeaders, Test.Curl.Timeout,
  Test.Curl.HttpVersion, Test.Curl.Redirect, Test.Curl.StatusCodes, Test.Curl.Cookies, Test.Curl.Gzip,
  Test.Curl.MultipartUpload, Test.Curl.RawFileUpload, Test.Curl.UploadFileVanished,
  Test.Curl.ResponseStream, Test.Curl.MaxResponseBytes, Test.Curl.Concurrency;

begin
  if RunAllTests > 0 then
    Halt(1);
end.
