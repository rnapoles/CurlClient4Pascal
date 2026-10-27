unit Test.Curl.Concurrency;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Client, Http.Request, Http.Response, Http.Options, Http.Errors, Http.Utils, Http.Curl.Transport;

type
  TWorker = class(TThread)
  public
    Url: string;
    Ok: Integer;
    procedure Execute; override;
  end;
procedure TWorker.Execute;
var C: IHttpClient; I: Integer;
begin
  try
    C := NewHttpClient.SetBaseUrl(Url);
    for I := 1 to 5 do
      if C.Get('/echo').StatusCode = 200 then Inc(Ok);
  except
    // counted as failure through Ok
  end;
end;
procedure TestParallelClientsDoNotInterfere;
var W: array[0..3] of TWorker; I, Total: Integer;
begin
  for I := 0 to 3 do
  begin
    W[I] := TWorker.Create(True);
    W[I].Url := IntegrationBaseUrl;
  end;
  for I := 0 to 3 do W[I].Start;
  Total := 0;
  for I := 0 to 3 do
  begin
    W[I].WaitFor;
    Inc(Total, W[I].Ok);
    W[I].Free;
  end;
  CheckEqualsInt(20, Total);
end;
initialization
  RegisterTest('Curl.Concurrency', '4 threads x 5 requests all succeed', TestParallelClientsDoNotInterfere);
end.
