unit Test.Logging.CustomLogger;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging;

type
  TBoomLogger = class(THttpLogger)
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  end;
  TCountingLogger = class(THttpLogger)
  public
    Lines: Integer;
  protected
    procedure WriteLine(Level: THttpLogLevel; const Category, Msg: string); override;
  end;
procedure TBoomLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
begin
  raise Exception.Create('disk full');
end;
procedure TCountingLogger.WriteLine(Level: THttpLogLevel; const Category, Msg: string);
begin
  Inc(Lines);
end;
procedure TestFailingSinkNeverBreaksTheCaller;
var L: IHttpLogger;
begin
  L := TBoomLogger.Create;
  L.Log(llError, 'x', 'y');           // must not raise
  CheckTrue(True);
end;
procedure TestSubclassGetsFilteringForFree;
var C: TCountingLogger; L: IHttpLogger;
begin
  C := TCountingLogger.Create(llWarning);
  L := C;
  L.Log(llInfo, 'a', 'no');
  L.Log(llError, 'a', 'yes');
  CheckEqualsInt(1, C.Lines);
  C.MinLevel := llDebug;
  L.Log(llDebug, 'a', 'now yes');
  CheckEqualsInt(2, C.Lines);
  L := nil;
end;
initialization
  RegisterTest('Logging.CustomLogger', 'an exception in the sink never reaches the caller', TestFailingSinkNeverBreaksTheCaller);
  RegisterTest('Logging.CustomLogger', 'subclasses inherit level filtering', TestSubclassGetsFilteringForFree);
end.
