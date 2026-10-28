# CurlClient4Pascal a Pascal libcurl HTTP client

Fluent, memory-safe HTTP client for **Delphi 12+** and **Free Pascal 3.2.2+**,
built on libcurl through the supplied `vendor/libcurl.pas` binding.

```pascal
uses Http.Client, Http.Response, Http.Curl.Transport;   // last unit = libcurl

var
  Client: IHttpClient;               // always keep it in an interface variable
  Resp: IHttpResponse;
begin
  Client := NewHttpClient
    .SetBaseUrl('https://httpbin.org')
    .SetTimeout(10000)
    .SetHeader('Accept', 'application/json')
    .SetBearerToken('secret');

  Resp := Client.Get('/get');
  WriteLn(Resp.StatusCode, ' ', Resp.Text);

  Resp := Client.PostJson('/post', '{"a":1}').EnsureSuccess;
end;
```

## Layout

```
vendor/libcurl.pas            your Chet-generated binding (unchanged)
src/
  Http.Defines.inc            {$IFDEF FPC}{$MODE DELPHI}{$ENDIF} + string settings
  Http.Utils.pas              URL/Base64/date helpers            (pure Pascal)
  Http.Url.pas                ParseUrl -> IUrl (parts + iterable query)
  Http.Errors.pas             EHttpError, ECurlError, EHttpStatusError, ...
  Http.Headers.pas            THttpHeaders (case-insensitive, multi-value)
  Http.Cookies.pas            THttpCookieJar (RFC 6265 subset, thread-safe)
  Http.Request.pas            IHttpRequest / THttpRequest (fluent)
  Http.Response.pas           IHttpResponse / THttpResponse
  Http.Options.pas            THttpClientOptions record
  Http.Transport.pas          IHttpTransport  (the seam between client and wire)
  Http.Client.pas             IHttpClient, THttpClient, IHttpClientBuilder
  curl/
    Http.Curl.Native.pas      LOW LEVEL : cdecl callbacks, CURL*/slist owners
    Http.Curl.Transport.pas   HIGH LEVEL: TCurlHttpClient (IHttpTransport)
examples/                     Example.Get / .Post / .Builder / .Upload
tests/
  RunUnitTests.dpr            no network, no libcurl needed
  RunIntegrationTests.dpr     libcurl + local echo server
  unit/ integration/          one small file per feature
  support/                    Test.Framework, Test.FakeTransport, echo_server.py
build.sh / test.sh            FPC on Linux/macOS
build.bat / test.bat          FPC and/or Delphi on Windows
```

## Design

* **SOLID** - `THttpClient` (fluent API, header/cookie/option state) depends only on
  `IHttpTransport`. libcurl lives in `TCurlHttpClient`; tests inject `TFakeTransport`.
* **Builder** - `NewHttpClientBuilder.BaseUrl(..).Timeout(..).Header(..).Build`.
* **Resource safety** - every request creates a `CURL*` (`TCurlEasy`), a header
  `curl_slist` (`TCurlSlist`) and the callback contexts inside nested `try..finally`
  blocks: `curl_easy_cleanup` / `curl_slist_free_all` always run. Per-request
  handles also make `Execute` thread-safe. Verified leak-free with FPC `heaptrc`.
* **Callbacks** - plain `cdecl` global functions; the `CURLOPT_*DATA` pointer is a
  Pascal object (`TCurlBodySink`, `TCurlHeaderSink`, `TCurlBodySource`). Exceptions
  are caught inside the callbacks (never cross the C boundary) and reported through
  libcurl's return-value protocol. A seek callback lets 307/308 redirects re-send bodies.
* **Errors** - every `curl_easy_setopt/getinfo/perform` result is checked and raised as
  `ECurlError` (`Code`, `CurlMessage` = `curl_easy_strerror`, `Detail` = error buffer).
  HTTP 4xx/5xx are *not* exceptions; call `Response.EnsureSuccess` (`EHttpStatusError`).
* **Hardening** - only `http`/`https` (also after redirects); CR/LF in header values
  rejected; optional `MaxResponseBytes`; `CURLOPT_NOSIGNAL` set; cookies are
  domain/path/Secure scoped.
* **`long` portability** - variadic `curl_easy_setopt` values use `NativeInt`, which is
  correct for `long` on Win32, Win64 (LLP64) and LP64 Unix.

## Building and testing

Requirements: libcurl of the same bitness as your compiler target
(Windows: `libcurl.dll` next to the .exe, or set `CURL_DLL_DIR`;
Debian/Ubuntu: `apt install libcurl4-openssl-dev` because the binding imports `libcurl.so`).
Integration tests need Python 3 (stdlib only) for the echo server and, on Windows, `curl.exe`.

```sh
./build.sh          # build examples + test runners  -> build/fpc/bin
./test.sh           # build, start echo server, run unit + integration + examples
```

```bat
set BDS=C:\Program Files (x86)\Embarcadero\Studio\37.0
build.bat [fpc|delphi|all] [win32|win64]
test.bat  [fpc|delphi]     [win32|win64]
```

Run the examples against the internet instead: `build\fpc\bin\Example.Get` (defaults to
https://httpbin.org) or pass any base URL as the first argument.

## Curl in Windows

```
git clone --depth 1 https://github.com/Microsoft/vcpkg
cd vcpkg
bootstrap-vcpkg.bat
vcpkg integrate install
vcpkg install curl[tool]
cd installed\x64-windows\tools\curl\
copy libcurl.dll my-project
copy z.dll my-project
```

## Notes and limits

* Hold clients in `IHttpClient` variables (reference counted); never keep a bare
  `THttpClient` and call the fluent methods on it.
* The Pascal cookie jar keeps cookies from the *final* response. For redirect chains,
  persistence and full RFC semantics use `SetCookieFile(path)` (libcurl's engine).
* Configure a client before sharing it between threads; `Execute` itself is thread-safe.
* Not included: async/multi interface, upload/download progress and cancel callbacks.
* Validation status: the full suite (121 unit + 72 integration tests, 4 examples) was
  executed with **FPC 3.2.2 on Linux/Windows x86-64**. The Delphi code path and `.bat` scripts
  were written to the same dialect rules but **not compiled or run** in this environment.
