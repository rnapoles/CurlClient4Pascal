program RunUnitTests;
{ Pure-Pascal unit tests: no network, no libcurl library needed. }
{$I Http.Defines.inc}
{$APPTYPE CONSOLE}
uses
  SysUtils, Test.Framework,
  Test.Utils.UrlEncode, Test.Utils.Base64, Test.Utils.UrlParts,
  Test.Utils.CombineUrl, Test.Utils.HttpParsing,
  Test.Headers.CaseInsensitive, Test.Headers.MultiValue,
  Test.Headers.Validation, Test.Headers.MergeAssign,
  Test.Url.Parsing, Test.Url.Invalid, Test.Url.QueryParsing, Test.Url.QueryIteration,
  Test.Url.QueryEditing, Test.Url.Build, Test.Url.ToString, Test.Url.EffectivePort,
  Test.Services.Parsing, Test.Services.Lookup, Test.Services.CustomFile,
  Test.Services.BundledCopy,
  Test.Utils.TickCount,
  Test.Logging.Levels, Test.Logging.MemoryLogger, Test.Logging.ProcLogger,
  Test.Logging.FileLogger, Test.Logging.Redaction, Test.Logging.CustomLogger,
  Test.Interceptors.Order, Test.Interceptors.ModifyRequest, Test.Interceptors.AfterResponse,
  Test.Interceptors.ErrorHook, Test.Interceptors.Management,
  Test.Interceptors.HeadersInterceptor, Test.Interceptors.BearerToken,
  Test.Interceptors.Timing, Test.Interceptors.LoggingInterceptor,
  Test.Errors.CurlError,
  Test.Cookies.Jar, Test.Cookies.HeaderBuilding, Test.Cookies.SetCookieParsing,
  Test.Utils.ContentTypeGuess, Test.Utils.TempDirectory,
  Test.Request.Fluent, Test.Request.Multipart, Test.Request.BodyFile,
  Test.Client.UploadHelpers, Test.Request.BodyStream, Test.Client.StreamHelpers,
  Test.Response.StatusHelpers, Test.Response.TextDecoding,
  Test.Client.DefaultHeaders, Test.Client.BaseUrl, Test.Client.InvalidUrl,
  Test.Client.Auth, Test.Client.CookieSending, Test.Client.CookieStoring,
  Test.Client.TimeoutOptions, Test.Client.PostHelpers, Test.Client.Builder,
  Test.Transport.DefaultRegistry;

begin
  if RunAllTests > 0 then
    Halt(1);
end.
