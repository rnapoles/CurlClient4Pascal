unit Http.Url;
{ ParseUrl - a parse_url() for Pascal.

    U := ParseUrl('https://ana:pw@example.com:8443/a/b?x=1&y=two#top');
    U.Scheme      'https'          U.User     'ana'        U.Password 'pw'
    U.Host        'example.com'    U.Port     8443         U.Path     '/a/b'
    U.Fragment    'top'

    for Pair in U.Query do
      WriteLn(Pair.Name, ' = ', Pair.Value);        // x = 1, y = two

  Follows RFC 3986: scheme, //authority, path, ?query, #fragment. Relative
  references ('/a/b?x=1', '//host/p', 'a/b') are accepted too; absent parts are
  empty strings / Port 0.

  * The result is an IUrl (reference counted - no Free needed).
  * Scheme is lower-cased; Host keeps its case and has no [] around IPv6.
  * User, Password, Path and Fragment are kept raw (not percent-decoded).
  * Query names/values ARE decoded ('%41' and '+' become 'A' and ' ').
    Duplicates and order are preserved; "flag" (no '=') has the value ''.
  * Build re-assembles the URL; the query is re-encoded canonically, so
    'a=b+c' comes back as 'a=b%20c' and a bare 'flag' as 'flag='. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Utils, Http.Errors;

type
  TUrlQueryPair = record
    Name: string;
    Value: string;
  end;

  TUrlQuery = class;

  { Enumerator behind  for Pair in Url.Query do ... }
  TUrlQueryEnumerator = class
  private
    FQuery: TUrlQuery;
    FIndex: Integer;
    function GetCurrent: TUrlQueryPair;
  public
    constructor Create(AQuery: TUrlQuery);
    function MoveNext: Boolean;
    property Current: TUrlQueryPair read GetCurrent;
  end;

  { Ordered list of decoded query parameters (duplicates allowed). }
  TUrlQuery = class
  private
    FItems: array of TUrlQueryPair;
    FCount: Integer;
    function GetName(Index: Integer): string;
    function GetValue(Index: Integer): string;
    function GetPair(Index: Integer): TUrlQueryPair;
    function IndexOfName(const Name: string): Integer;
  public
    { Replaces the content by parsing a raw query string (without '?'). }
    procedure Parse(const RawQuery: string);
    procedure Add(const Name, Value: string);
    { Replaces every parameter called Name by a single one. }
    procedure SetValue(const Name, Value: string);
    { Removes every parameter called Name; returns how many were removed. }
    function Remove(const Name: string): Integer;
    procedure Clear;
    { First value of Name, or DefaultValue. }
    function Get(const Name: string; const DefaultValue: string = ''): string;
    function TryGetValue(const Name: string; out Value: string): Boolean;
    function GetAll(const Name: string): THttpStringArray;
    function Contains(const Name: string): Boolean;
    { Percent-encoded "a=1&b=x%20y" (no leading '?'). }
    {$IFDEF FPC}
    function ToString:{$IFDEF FPC_HAS_FEATURE_ANSISTRINGS}ansistring{$ELSE}shortstring{$ENDIF}; override;
    {$ELSE}
    function ToString: string; override;
    {$ENDIF}
    
    function GetEnumerator: TUrlQueryEnumerator;
    property Count: Integer read FCount;
    property Names[Index: Integer]: string read GetName;
    property Values[Index: Integer]: string read GetValue;
    property Pairs[Index: Integer]: TUrlQueryPair read GetPair; default;
  end;

  IUrl = interface
    ['{5D2C8E41-7A19-4B3F-9E60-2F1A7C3B8D54}']
    function GetScheme: string;
    function GetUser: string;
    function GetPassword: string;
    function GetHost: string;
    function GetPort: Integer;
    function GetPath: string;
    function GetFragment: string;
    function GetQuery: TUrlQuery;
    function GetRawQuery: string;
    procedure SetScheme(const Value: string);
    procedure SetUser(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetHost(const Value: string);
    procedure SetPort(Value: Integer);
    procedure SetPath(const Value: string);
    procedure SetFragment(const Value: string);

    { Explicit port, or the scheme's default (http 80, https 443, ...), or 0. }
    function EffectivePort: Integer;
    { [user[:password]@]host[:port] ('' when there is no authority). }
    function Authority: string;
    { True for scheme + host (an absolute URL, not a relative reference). }
    function IsAbsolute: Boolean;
    { Re-assembles the URL from the (possibly edited) parts. }
    function Build: string;

    property Scheme: string read GetScheme write SetScheme;
    property User: string read GetUser write SetUser;
    property Password: string read GetPassword write SetPassword;
    property Host: string read GetHost write SetHost;
    property Port: Integer read GetPort write SetPort;           // 0 = not given
    property Path: string read GetPath write SetPath;
    property Fragment: string read GetFragment write SetFragment;
    property Query: TUrlQuery read GetQuery;                     // owned by the IUrl
    property RawQuery: string read GetRawQuery;                  // as parsed, undecoded
  end;

  TUrl = class(TInterfacedObject, IUrl)
  private
    FScheme, FUser, FPassword, FHost, FPath, FFragment, FRawQuery: string;
    FPort: Integer;
    FHasAuthority: Boolean;
    FQuery: TUrlQuery;
    function GetScheme: string;
    function GetUser: string;
    function GetPassword: string;
    function GetHost: string;
    function GetPort: Integer;
    function GetPath: string;
    function GetFragment: string;
    function GetQuery: TUrlQuery;
    function GetRawQuery: string;
    procedure SetScheme(const Value: string);
    procedure SetUser(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetHost(const Value: string);
    procedure SetPort(Value: Integer);
    procedure SetPath(const Value: string);
    procedure SetFragment(const Value: string);
    function ParseAuthority(const Auth: string; out Error: string): Boolean;
    function DoParse(const Url: string; out Error: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { Raises EHttpError when Url is malformed. }
    class function Parse(const Url: string): IUrl;
    class function TryParse(const Url: string; out Parsed: IUrl): Boolean;
    function EffectivePort: Integer;
    function Authority: string;
    function IsAbsolute: Boolean;
    function Build: string;
    {$IFDEF FPC}
    function ToString:{$IFDEF FPC_HAS_FEATURE_ANSISTRINGS}ansistring{$ELSE}shortstring{$ENDIF}; override;
    {$ELSE}
    function ToString: string; override;
    {$ENDIF}
  end;

{ parse_url() equivalent. Raises EHttpError for malformed input
  (control characters/spaces, bad port, unbalanced IPv6 brackets). }
function ParseUrl(const Url: string): IUrl;
{ Same, but returns False instead of raising. }
function TryParseUrlObject(const Url: string; out Parsed: IUrl): Boolean;

implementation

function ParseUrl(const Url: string): IUrl;
begin
  Result := TUrl.Parse(Url);
end;

function TryParseUrlObject(const Url: string; out Parsed: IUrl): Boolean;
begin
  Result := TUrl.TryParse(Url, Parsed);
end;

{ ===== TUrlQueryEnumerator ===== }

constructor TUrlQueryEnumerator.Create(AQuery: TUrlQuery);
begin
  inherited Create;
  FQuery := AQuery;
  FIndex := -1;
end;

function TUrlQueryEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FQuery.Count;
end;

function TUrlQueryEnumerator.GetCurrent: TUrlQueryPair;
begin
  Result := FQuery.Pairs[FIndex];
end;

{ ===== TUrlQuery ===== }

function TUrlQuery.GetName(Index: Integer): string;
begin
  Result := FItems[Index].Name;
end;

function TUrlQuery.GetValue(Index: Integer): string;
begin
  Result := FItems[Index].Value;
end;

function TUrlQuery.GetPair(Index: Integer): TUrlQueryPair;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EHttpError.CreateFmt('Query index %d out of range', [Index]);
  Result := FItems[Index];
end;

function TUrlQuery.IndexOfName(const Name: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if FItems[I].Name = Name then       // query names are case-sensitive
    begin
      Result := I;
      Exit;
    end;
end;

procedure TUrlQuery.Add(const Name, Value: string);
begin
  if FCount = Length(FItems) then
    SetLength(FItems, FCount * 2 + 4);
  FItems[FCount].Name := Name;
  FItems[FCount].Value := Value;
  Inc(FCount);
end;

procedure TUrlQuery.Parse(const RawQuery: string);
var
  Start, I, P: Integer;

  procedure TakeSegment(const Seg: string);
  begin
    if Seg = '' then Exit;
    P := Pos('=', Seg);
    if P = 0 then
      Add(UrlDecode(Seg, True), '')
    else
      Add(UrlDecode(Copy(Seg, 1, P - 1), True), UrlDecode(Copy(Seg, P + 1, MaxInt), True));
  end;

begin
  Clear;
  Start := 1;
  for I := 1 to Length(RawQuery) + 1 do
    if (I > Length(RawQuery)) or (RawQuery[I] = '&') then
    begin
      TakeSegment(Copy(RawQuery, Start, I - Start));
      Start := I + 1;
    end;
end;

procedure TUrlQuery.SetValue(const Name, Value: string);
begin
  Remove(Name);
  Add(Name, Value);
end;

function TUrlQuery.Remove(const Name: string): Integer;
var
  I, N: Integer;
begin
  N := 0;
  Result := 0;
  for I := 0 to FCount - 1 do
    if FItems[I].Name = Name then
      Inc(Result)
    else
    begin
      if N <> I then FItems[N] := FItems[I];
      Inc(N);
    end;
  for I := N to FCount - 1 do
  begin
    FItems[I].Name := '';
    FItems[I].Value := '';
  end;
  FCount := N;
end;

procedure TUrlQuery.Clear;
begin
  SetLength(FItems, 0);
  FCount := 0;
end;

function TUrlQuery.Get(const Name, DefaultValue: string): string;
begin
  if not TryGetValue(Name, Result) then
    Result := DefaultValue;
end;

function TUrlQuery.TryGetValue(const Name: string; out Value: string): Boolean;
var
  I: Integer;
begin
  I := IndexOfName(Name);
  Result := I >= 0;
  if Result then Value := FItems[I].Value else Value := '';
end;

function TUrlQuery.GetAll(const Name: string): THttpStringArray;
var
  I, N: Integer;
begin
  SetLength(Result, FCount);
  N := 0;
  for I := 0 to FCount - 1 do
    if FItems[I].Name = Name then
    begin
      Result[N] := FItems[I].Value;
      Inc(N);
    end;
  SetLength(Result, N);
end;

function TUrlQuery.Contains(const Name: string): Boolean;
begin
  Result := IndexOfName(Name) >= 0;
end;

{$IFDEF FPC}
function TUrlQuery.ToString:{$IFDEF FPC_HAS_FEATURE_ANSISTRINGS}ansistring{$ELSE}shortstring{$ENDIF}; 
{$ELSE}
function TUrlQuery.ToString: string;
{$ENDIF}
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FCount - 1 do
  begin
    if I > 0 then Result := Result + '&';
    Result := Result + UrlEncode(FItems[I].Name) + '=' + UrlEncode(FItems[I].Value);
  end;
end;

function TUrlQuery.GetEnumerator: TUrlQueryEnumerator;
begin
  Result := TUrlQueryEnumerator.Create(Self);
end;

{ ===== TUrl ===== }

constructor TUrl.Create;
begin
  inherited Create;
  FQuery := TUrlQuery.Create;
end;

destructor TUrl.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

class function TUrl.Parse(const Url: string): IUrl;
var
  U: TUrl;
  Err: string;
begin
  U := TUrl.Create;
  Result := U;                       // the interface owns it from here on
  if not U.DoParse(Url, Err) then
    raise EHttpError.CreateFmt('Invalid URL "%s": %s', [Url, Err]);
end;

class function TUrl.TryParse(const Url: string; out Parsed: IUrl): Boolean;
var
  U: TUrl;
  Err: string;
begin
  U := TUrl.Create;
  Parsed := U;
  Result := U.DoParse(Url, Err);
  if not Result then Parsed := nil;
end;

function IsAlpha(C: Char): Boolean;
begin
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z'));
end;

function IsSchemeChar(C: Char): Boolean;
begin
  Result := IsAlpha(C) or ((C >= '0') and (C <= '9')) or (C = '+') or (C = '-') or (C = '.');
end;

function TUrl.ParseAuthority(const Auth: string; out Error: string): Boolean;
var
  I, At, Colons: Integer;
  UserInfo, HostPort, PortText: string;
  P: Integer;
begin
  Result := False;
  Error := '';
  At := 0;
  for I := Length(Auth) downto 1 do
    if Auth[I] = '@' then
    begin
      At := I;
      Break;
    end;
  if At > 0 then
  begin
    UserInfo := Copy(Auth, 1, At - 1);
    HostPort := Copy(Auth, At + 1, MaxInt);
    P := Pos(':', UserInfo);
    if P > 0 then
    begin
      FUser := Copy(UserInfo, 1, P - 1);
      FPassword := Copy(UserInfo, P + 1, MaxInt);
    end
    else
      FUser := UserInfo;
  end
  else
    HostPort := Auth;

  PortText := '';
  if (HostPort <> '') and (HostPort[1] = '[') then
  begin
    P := Pos(']', HostPort);
    if P = 0 then
    begin
      Error := 'unbalanced [ in IPv6 host';
      Exit;
    end;
    FHost := Copy(HostPort, 2, P - 2);
    HostPort := Copy(HostPort, P + 1, MaxInt);
    if HostPort <> '' then
    begin
      if HostPort[1] <> ':' then
      begin
        Error := 'unexpected text after IPv6 host';
        Exit;
      end;
      PortText := Copy(HostPort, 2, MaxInt);
    end;
  end
  else
  begin
    Colons := 0;
    for I := 1 to Length(HostPort) do
      if HostPort[I] = ':' then Inc(Colons);
    if Colons > 1 then
    begin
      Error := 'IPv6 host must be written in [brackets]';
      Exit;
    end;
    P := Pos(':', HostPort);
    if P > 0 then
    begin
      FHost := Copy(HostPort, 1, P - 1);
      PortText := Copy(HostPort, P + 1, MaxInt);
    end
    else
      FHost := HostPort;
  end;

  if PortText <> '' then
  begin
    FPort := ParseIntDef(PortText, -1);
    if (FPort < 1) or (FPort > 65535) then
    begin
      FPort := 0;
      Error := 'port must be a number between 1 and 65535';
      Exit;
    end;
  end;
  Result := True;
end;

function TUrl.DoParse(const Url: string; out Error: string): Boolean;
var
  S, Authority_: string;
  I, P, E: Integer;
begin
  Result := False;
  Error := '';
  for I := 1 to Length(Url) do
    if (Ord(Url[I]) <= 32) or (Ord(Url[I]) = 127) then
    begin
      Error := 'contains whitespace or control characters';
      Exit;
    end;
  S := Url;

  P := Pos('#', S);
  if P > 0 then
  begin
    FFragment := Copy(S, P + 1, MaxInt);
    S := Copy(S, 1, P - 1);
  end;

  P := Pos('?', S);
  if P > 0 then
  begin
    FRawQuery := Copy(S, P + 1, MaxInt);
    S := Copy(S, 1, P - 1);
    FQuery.Parse(FRawQuery);
  end;

  // scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ":"
  if (S <> '') and IsAlpha(S[1]) then
  begin
    I := 2;
    while (I <= Length(S)) and IsSchemeChar(S[I]) do Inc(I);
    if (I <= Length(S)) and (S[I] = ':') then
    begin
      FScheme := AsciiLower(Copy(S, 1, I - 1));
      S := Copy(S, I + 1, MaxInt);
    end;
  end;

  if Copy(S, 1, 2) = '//' then
  begin
    FHasAuthority := True;
    S := Copy(S, 3, MaxInt);
    E := 1;
    while (E <= Length(S)) and (S[E] <> '/') do Inc(E);
    Authority_ := Copy(S, 1, E - 1);
    S := Copy(S, E, MaxInt);
    if not ParseAuthority(Authority_, Error) then Exit;
  end;

  FPath := S;
  Result := True;
end;

function TUrl.GetScheme: string;
begin
  Result := FScheme;
end;

function TUrl.GetUser: string;
begin
  Result := FUser;
end;

function TUrl.GetPassword: string;
begin
  Result := FPassword;
end;

function TUrl.GetHost: string;
begin
  Result := FHost;
end;

function TUrl.GetPort: Integer;
begin
  Result := FPort;
end;

function TUrl.GetPath: string;
begin
  Result := FPath;
end;

function TUrl.GetFragment: string;
begin
  Result := FFragment;
end;

function TUrl.GetQuery: TUrlQuery;
begin
  Result := FQuery;
end;

function TUrl.GetRawQuery: string;
begin
  Result := FRawQuery;
end;

procedure TUrl.SetScheme(const Value: string);
begin
  FScheme := AsciiLower(Value);
end;

procedure TUrl.SetUser(const Value: string);
begin
  FUser := Value;
end;

procedure TUrl.SetPassword(const Value: string);
begin
  FPassword := Value;
end;

procedure TUrl.SetHost(const Value: string);
begin
  FHost := Value;
end;

procedure TUrl.SetPort(Value: Integer);
begin
  if (Value < 0) or (Value > 65535) then
    raise EHttpError.CreateFmt('Invalid port %d', [Value]);
  FPort := Value;
end;

procedure TUrl.SetPath(const Value: string);
begin
  FPath := Value;
end;

procedure TUrl.SetFragment(const Value: string);
begin
  FFragment := Value;
end;

function TUrl.EffectivePort: Integer;
begin
  if FPort > 0 then
    Result := FPort
  else if (FScheme = 'http') or (FScheme = 'ws') then
    Result := 80
  else if (FScheme = 'https') or (FScheme = 'wss') then
    Result := 443
  else if FScheme = 'ftp' then
    Result := 21
  else
    Result := 0;
end;

function TUrl.Authority: string;
begin
  Result := '';
  if not (FHasAuthority or (FHost <> '') or (FUser <> '')) then Exit;
  if FUser <> '' then
  begin
    Result := FUser;
    if FPassword <> '' then Result := Result + ':' + FPassword;
    Result := Result + '@';
  end;
  if Pos(':', FHost) > 0 then
    Result := Result + '[' + FHost + ']'      // IPv6 literal
  else
    Result := Result + FHost;
  if FPort > 0 then Result := Result + ':' + IntToStr(FPort);
end;

function TUrl.IsAbsolute: Boolean;
begin
  Result := (FScheme <> '') and (FHost <> '');
end;

function TUrl.Build: string;
var
  Path_: string;
begin
  Result := '';
  if FScheme <> '' then Result := FScheme + ':';
  if FHasAuthority or (FHost <> '') or (FUser <> '') then
  begin
    Result := Result + '//' + Authority;
    Path_ := FPath;
    if (Path_ <> '') and (Path_[1] <> '/') then Path_ := '/' + Path_;
  end
  else
    Path_ := FPath;
  Result := Result + Path_;
  if FQuery.Count > 0 then Result := Result + '?' + FQuery.ToString;
  if FFragment <> '' then Result := Result + '#' + FFragment;
end;

{$IFDEF FPC}
function TUrl.ToString:{$IFDEF FPC_HAS_FEATURE_ANSISTRINGS}ansistring{$ELSE}shortstring{$ENDIF}; 
{$ELSE}
function TUrl.ToString: string;
{$ENDIF}
begin
  Result := Build;
end;

end.
