unit Http.Services;
{ Service-name <-> port database in /etc/services format.

    name  port/protocol  [alias ...]  [# comment]

  TServiceDatabase parses that format. The library ships a copy of the IANA
  list as  data/services  and loads it lazily the first time a port has to be
  resolved (TUrl.EffectivePort uses it to map a URL scheme to a port).

  Where the bundled copy is looked for (first hit wins):
    1. the file named by the environment variable HTTP_SERVICES_FILE
    2. <directory of the executable>/services
    3. <directory of the executable>/data/services
    4. <current directory>/data/services
  If none exists a small built-in table (http, https, ftp, ssh, ...) is used,
  so resolution never fails because a file is missing.

  To use your own file:   LoadServicesFile('C:\path\my-services');
  To restore the default: SetDefaultServices(nil);

  Name matching is case-insensitive; the first entry for a name/protocol wins.
  A database must not be modified while other threads read it; build it
  completely and then publish it with SetDefaultServices. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Http.Utils, Http.Errors;

type
  IServiceDatabase = interface
    ['{A7B3E6D2-4C18-4F59-8D01-3E9F2B6A5C70}']
    function Count: Integer;
    procedure Clear;
    { Adds the entries of a services file; returns the number of entries added
      (names + aliases). Raises EHttpError if the file cannot be read.
      Malformed lines are ignored. }
    function LoadFromFile(const FileName: string): Integer;
    { Same for text already in memory. }
    function LoadFromText(const Text: string): Integer;
    { Port of a service name or alias. Protocol '' matches any protocol. }
    function TryGetPort(const Name: string; out Port: Integer;
      const Protocol: string = 'tcp'): Boolean;
    { Official (non-alias) name of a port. Protocol '' matches any protocol. }
    function TryGetName(Port: Integer; out Name: string;
      const Protocol: string = 'tcp'): Boolean;
  end;

  TServiceEntry = record
    Name: string;       // lower-case
    Port: Integer;
    Protocol: string;   // lower-case: tcp, udp, sctp, ...
    IsAlias: Boolean;
  end;

  TServiceDatabase = class(TInterfacedObject, IServiceDatabase)
  private
    FItems: array of TServiceEntry;
    FCount: Integer;
    procedure AddEntry(const Name: string; Port: Integer; const Protocol: string;
      IsAlias: Boolean);
    function ParseLine(const Line: string): Integer;
  public
    function Count: Integer;
    procedure Clear;
    function LoadFromFile(const FileName: string): Integer;
    function LoadFromText(const Text: string): Integer;
    function TryGetPort(const Name: string; out Port: Integer;
      const Protocol: string = 'tcp'): Boolean;
    function TryGetName(Port: Integer; out Name: string;
      const Protocol: string = 'tcp'): Boolean;
  end;

{ An empty database. }
function NewServiceDatabase: IServiceDatabase;
{ Small built-in table used when no services file can be found. }
function NewBuiltinServices: IServiceDatabase;
{ Path of the bundled copy per the search order above, or '' if not found. }
function DefaultServicesFile: string;

{ The process-wide database (loaded on first use). Thread-safe. }
function Services: IServiceDatabase;
{ Replaces the process-wide database; nil = forget it and reload the default
  on next use. }
procedure SetDefaultServices(const Db: IServiceDatabase);
{ Loads a custom services file and makes it the process-wide database.
  Raises EHttpError (and changes nothing) if the file cannot be read. }
procedure LoadServicesFile(const FileName: string);

{ Port for a service name / URL scheme, or 0 when unknown. Consults Services,
  then a tiny fallback for web schemes absent from /etc/services (ws, wss). }
function ResolveServicePort(const Name: string; const Protocol: string = 'tcp'): Integer;

implementation

const
  BuiltinText =
    'ftp 21/tcp'#10'ssh 22/tcp'#10'telnet 23/tcp'#10'smtp 25/tcp mail'#10 +
    'domain 53/tcp'#10'domain 53/udp'#10'http 80/tcp www'#10'pop3 110/tcp'#10 +
    'nntp 119/tcp'#10'imap 143/tcp'#10'ldap 389/tcp'#10'https 443/tcp'#10 +
    'smtps 465/tcp'#10'rsync 873/tcp'#10'imaps 993/tcp'#10'pop3s 995/tcp'#10;

var
  GLock: TCriticalSection = nil;
  GServices: IServiceDatabase = nil;

{ ===== TServiceDatabase ===== }

function TServiceDatabase.Count: Integer;
begin
  Result := FCount;
end;

procedure TServiceDatabase.Clear;
begin
  SetLength(FItems, 0);
  FCount := 0;
end;

procedure TServiceDatabase.AddEntry(const Name: string; Port: Integer;
  const Protocol: string; IsAlias: Boolean);
begin
  if FCount = Length(FItems) then
    SetLength(FItems, FCount * 2 + 64);
  FItems[FCount].Name := AsciiLower(Name);
  FItems[FCount].Port := Port;
  FItems[FCount].Protocol := AsciiLower(Protocol);
  FItems[FCount].IsAlias := IsAlias;
  Inc(FCount);
end;

{ "name  port/proto  [aliases]  [# comment]"  ->  number of entries added }
function TServiceDatabase.ParseLine(const Line: string): Integer;
var
  S: string;
  Tokens: THttpStringArray;
  Cur: string;
  I, P, Port: Integer;
  Proto: string;
begin
  Result := 0;
  S := Line;
  P := Pos('#', S);
  if P > 0 then S := Copy(S, 1, P - 1);

  SetLength(Tokens, 0);
  Cur := '';
  for I := 1 to Length(S) + 1 do
    if (I > Length(S)) or (S[I] = ' ') or (S[I] = #9) or (S[I] = #13) then
    begin
      if Cur <> '' then
      begin
        SetLength(Tokens, Length(Tokens) + 1);
        Tokens[High(Tokens)] := Cur;
        Cur := '';
      end;
    end
    else
      Cur := Cur + S[I];
  if Length(Tokens) < 2 then Exit;

  P := Pos('/', Tokens[1]);
  if P < 2 then Exit;
  Port := ParseIntDef(Copy(Tokens[1], 1, P - 1), -1);
  Proto := Copy(Tokens[1], P + 1, MaxInt);
  if (Port < 1) or (Port > 65535) or (Proto = '') then Exit;

  AddEntry(Tokens[0], Port, Proto, False);
  Inc(Result);
  for I := 2 to High(Tokens) do
  begin
    AddEntry(Tokens[I], Port, Proto, True);
    Inc(Result);
  end;
end;

function TServiceDatabase.LoadFromText(const Text: string): Integer;
var
  Start, I: Integer;
begin
  Result := 0;
  Start := 1;
  for I := 1 to Length(Text) + 1 do
    if (I > Length(Text)) or (Text[I] = #10) then
    begin
      Inc(Result, ParseLine(Copy(Text, Start, I - Start)));
      Start := I + 1;
    end;
end;

function TServiceDatabase.LoadFromFile(const FileName: string): Integer;
var
  F: TFileStream;
  B: TBytes;
begin
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: EStreamError do
      raise EHttpError.CreateFmt('Cannot read services file "%s": %s', [FileName, E.Message]);
  end;
  try
    SetLength(B, F.Size);
    if Length(B) > 0 then
      F.ReadBuffer(B[0], Length(B));
  finally
    F.Free;
  end;
  Result := LoadFromText(BytesToString(B));
end;

function TServiceDatabase.TryGetPort(const Name: string; out Port: Integer;
  const Protocol: string): Boolean;
var
  I: Integer;
  N, P: string;
begin
  Result := False;
  Port := 0;
  N := AsciiLower(Name);
  P := AsciiLower(Protocol);
  for I := 0 to FCount - 1 do
    if (FItems[I].Name = N) and ((P = '') or (FItems[I].Protocol = P)) then
    begin
      Port := FItems[I].Port;
      Result := True;
      Exit;
    end;
end;

function TServiceDatabase.TryGetName(Port: Integer; out Name: string;
  const Protocol: string): Boolean;
var
  I: Integer;
  P: string;
begin
  Result := False;
  Name := '';
  P := AsciiLower(Protocol);
  for I := 0 to FCount - 1 do
    if (FItems[I].Port = Port) and (not FItems[I].IsAlias) and
       ((P = '') or (FItems[I].Protocol = P)) then
    begin
      Name := FItems[I].Name;
      Result := True;
      Exit;
    end;
end;

{ ===== factories ===== }

function NewServiceDatabase: IServiceDatabase;
begin
  Result := TServiceDatabase.Create;
end;

function NewBuiltinServices: IServiceDatabase;
begin
  Result := TServiceDatabase.Create;
  Result.LoadFromText(BuiltinText);
end;

function DefaultServicesFile: string;
var
  ExeDir: string;
begin
  Result := GetEnvironmentVariable('HTTP_SERVICES_FILE');
  if (Result <> '') and FileExists(Result) then Exit;

  ExeDir := ExtractFilePath(ParamStr(0));
  Result := ExeDir + 'services';
  if FileExists(Result) then Exit;
  Result := ExeDir + 'data' + PathDelim + 'services';
  if FileExists(Result) then Exit;
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + 'data' + PathDelim + 'services';
  if FileExists(Result) then Exit;
  Result := '';
end;

{ Bundled copy if present and readable, otherwise the built-in table. }
function LoadDefaultDatabase: IServiceDatabase;
var
  Path: string;
begin
  Result := NewServiceDatabase;
  Path := DefaultServicesFile;
  if Path <> '' then
    try
      if Result.LoadFromFile(Path) > 0 then Exit;
    except
      on EHttpError do
        Result.Clear;               // unreadable copy: fall through to built-ins
    end;
  Result := NewBuiltinServices;
end;

function Services: IServiceDatabase;
begin
  GLock.Enter;
  try
    if GServices = nil then
      GServices := LoadDefaultDatabase;
    Result := GServices;
  finally
    GLock.Leave;
  end;
end;

procedure SetDefaultServices(const Db: IServiceDatabase);
begin
  GLock.Enter;
  try
    GServices := Db;                // readers still holding the old one keep it alive
  finally
    GLock.Leave;
  end;
end;

procedure LoadServicesFile(const FileName: string);
var
  Db: IServiceDatabase;
begin
  Db := NewServiceDatabase;
  Db.LoadFromFile(FileName);        // raises before anything is replaced
  SetDefaultServices(Db);
end;

function ResolveServicePort(const Name, Protocol: string): Integer;
var
  Port: Integer;
begin
  Result := 0;
  if Name = '' then Exit;
  if Services.TryGetPort(Name, Port, Protocol) then
  begin
    Result := Port;
    Exit;
  end;
  // web-socket schemes are URL schemes, not IANA service names
  if (Protocol = '') or AsciiSameText(Protocol, 'tcp') then
  begin
    if AsciiSameText(Name, 'ws') then Result := 80
    else if AsciiSameText(Name, 'wss') then Result := 443;
  end;
end;

initialization
  GLock := TCriticalSection.Create;

finalization
  GServices := nil;
  GLock.Free;

end.
