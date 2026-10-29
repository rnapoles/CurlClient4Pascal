unit Test.Logging.ProcLogger;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Logging;

var GSeen: string;
procedure Capture(Level: THttpLogLevel; const Category, Msg: string);
begin
  GSeen := GSeen + LogLevelName(Level) + '|' + Category + '|' + Msg + ';';
end;
procedure TestForwardsAcceptedMessages;
var L: IHttpLogger;
begin
  GSeen := '';
  L := NewProcLogger(Capture, llInfo);
  L.Log(llDebug, 'a', 'dropped');
  L.Log(llInfo, 'a', 'kept');
  CheckEqualsStr('INFO |a|kept;', GSeen);
end;
initialization
  RegisterTest('Logging.ProcLogger', 'forwards accepted messages to the procedure', TestForwardsAcceptedMessages);
end.
