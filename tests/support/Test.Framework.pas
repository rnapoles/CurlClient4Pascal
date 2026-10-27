unit Test.Framework;
{ Minimal xUnit-style framework that compiles unchanged on Delphi and FPC
  (no anonymous methods, no RTTI, no external dependency).

  Each test unit registers its tests from an initialization section:

      RegisterTest('Headers.CaseInsensitive', 'Get ignores name case', TestGet);

  The runner program just lists the test units in its uses clause. }
{$I Http.Defines.inc}

interface

uses
  SysUtils;

type
  TTestProc = procedure;
  ETestFailure = class(Exception);
  ETestSkipped = class(Exception);

procedure RegisterTest(const Suite, Name: string; Proc: TTestProc);

{ --- assertions --- }
procedure Fail(const Msg: string);
procedure Skip(const Reason: string);
procedure CheckTrue(Condition: Boolean; const Msg: string = '');
procedure CheckFalse(Condition: Boolean; const Msg: string = '');
procedure CheckEqualsStr(const Expected, Actual: string; const Msg: string = '');
procedure CheckEqualsInt(Expected, Actual: Int64; const Msg: string = '');
procedure CheckContains(const Needle, Haystack: string; const Msg: string = '');
procedure CheckRaises(AClass: ExceptClass; Proc: TTestProc; const Msg: string = '');
{ Asserts that Json contains  "Key": "Value"  (string field, any nesting). }
procedure CheckJsonField(const Json, Key, Value: string);
{ Asserts that Json contains  "Key": <Value>  (number field). }
procedure CheckJsonNumber(const Json, Key: string; Value: Int64; const Msg: string = '');

{ Base URL of the local echo server (env HTTP_TEST_BASE_URL).
  Marks the test as skipped when it is not configured. }
function IntegrationBaseUrl: string;

{ Runs everything that was registered; returns the number of failures. }
function RunAllTests: Integer;

implementation

type
  TTestCase = record
    Suite: string;
    Name: string;
    Proc: TTestProc;
  end;

var
  GTests: array of TTestCase;

procedure RegisterTest(const Suite, Name: string; Proc: TTestProc);
begin
  SetLength(GTests, Length(GTests) + 1);
  GTests[High(GTests)].Suite := Suite;
  GTests[High(GTests)].Name := Name;
  GTests[High(GTests)].Proc := Proc;
end;

procedure Fail(const Msg: string);
begin
  raise ETestFailure.Create(Msg);
end;

procedure Skip(const Reason: string);
begin
  raise ETestSkipped.Create(Reason);
end;

procedure CheckTrue(Condition: Boolean; const Msg: string);
begin
  if not Condition then
    Fail('expected True' + ': ' + Msg);
end;

procedure CheckFalse(Condition: Boolean; const Msg: string);
begin
  if Condition then
    Fail('expected False' + ': ' + Msg);
end;

procedure CheckEqualsStr(const Expected, Actual, Msg: string);
begin
  if Expected <> Actual then
    Fail(Format('expected "%s" but was "%s" %s', [Expected, Actual, Msg]));
end;

procedure CheckEqualsInt(Expected, Actual: Int64; const Msg: string);
begin
  if Expected <> Actual then
    Fail(Format('expected %d but was %d %s', [Expected, Actual, Msg]));
end;

procedure CheckContains(const Needle, Haystack, Msg: string);
begin
  if Pos(Needle, Haystack) = 0 then
    Fail(Format('"%s" not found in "%s" %s', [Needle, Haystack, Msg]));
end;

procedure CheckRaises(AClass: ExceptClass; Proc: TTestProc; const Msg: string);
var
  Raised: string;
begin
  Raised := '';
  try
    Proc;
  except
    on E: Exception do
    begin
      if E is AClass then Exit;
      Raised := E.ClassName + ': ' + E.Message;
    end;
  end;
  if Raised = '' then
    Fail('expected ' + AClass.ClassName + ' but nothing was raised ' + Msg)
  else
    Fail('expected ' + AClass.ClassName + ' but got ' + Raised);
end;

procedure CheckJsonField(const Json, Key, Value: string);
var
  Needle: string;
begin
  Needle := Chr(34) + Key + Chr(34) + ': ' + Chr(34) + Value + Chr(34);
  if Pos(Needle, Json) = 0 then
    Fail(Format('JSON field %s not found in %s', [Needle, Json]));
end;

procedure CheckJsonNumber(const Json, Key: string; Value: Int64; const Msg: string);
var
  Needle: string;
begin
  Needle := Chr(34) + Key + Chr(34) + ': ' + IntToStr(Value);
  if Pos(Needle, Json) = 0 then
    Fail(Format('JSON number %s not found in %s %s', [Needle, Json, Msg]));
end;

function IntegrationBaseUrl: string;
begin
  Result := GetEnvironmentVariable('HTTP_TEST_BASE_URL');
  if Result = '' then
    Skip('HTTP_TEST_BASE_URL not set (start tests/support/echo_server.py)');
  while (Result <> '') and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
end;

function RunAllTests: Integer;
var
  I, Passed, Failed, Skipped: Integer;
  Label_: string;
begin
  Passed := 0;
  Failed := 0;
  Skipped := 0;
  for I := 0 to High(GTests) do
  begin
    Label_ := GTests[I].Suite + ' :: ' + GTests[I].Name;
    try
      GTests[I].Proc;
      Inc(Passed);
      WriteLn('[PASS] ', Label_);
    except
      on E: ETestSkipped do
      begin
        Inc(Skipped);
        WriteLn('[SKIP] ', Label_, ' (', E.Message, ')');
      end;
      on E: Exception do
      begin
        Inc(Failed);
        WriteLn('[FAIL] ', Label_);
        WriteLn('       ', E.ClassName, ': ', E.Message);
      end;
    end;
  end;
  WriteLn;
  WriteLn(Format('%d tests: %d passed, %d failed, %d skipped',
    [Length(GTests), Passed, Failed, Skipped]));
  Result := Failed;
end;

end.
