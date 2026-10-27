unit Http.Cookies;
{ Small in-memory cookie jar (RFC 6265 subset).

  Supported : name/value, Domain, Path, Secure, HttpOnly, Max-Age, Expires,
              host-only vs domain cookies, default-path, deletion.
  Not done  : public-suffix list, SameSite, cookie ordering by path length.
  For complete cookie semantics (incl. redirect chains and persistence)
  use THttpClientOptions.CookieFile, which enables libcurl's own engine.

  All public methods are thread-safe. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, SyncObjs, Http.Utils, Http.Headers;

type
  THttpCookie = record
    Name: string;
    Value: string;
    Domain: string;       // '' = matches any host (cookie set explicitly by the caller)
    Path: string;         // '' or '/' = whole site
    Secure: Boolean;      // only sent over https
    HttpOnly: Boolean;
    HostOnly: Boolean;    // True: exact host match, False: domain match
    ExpiresUtc: TDateTime; // 0 = session cookie
  end;

  THttpCookieJar = class
  private
    FLock: TCriticalSection;
    FItems: array of THttpCookie;
    FCount: Integer;
    function GetCount: Integer;
    function GetItem(Index: Integer): THttpCookie;
    function IndexOfExact(const Name, Domain, Path: string): Integer;
    procedure DeleteAt(Index: Integer);
    procedure Upsert(const Cookie: THttpCookie);
    function Matches(const C: THttpCookie; const Url: TUrlParts; NowU: TDateTime): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Adds/replaces a cookie. Empty Domain => sent to every host. }
    procedure SetCookie(const Name, Value: string; const Domain: string = '';
      const Path: string = '/'; Secure: Boolean = False);
    { Value of the first live cookie called Name, or DefaultValue. }
    function Get(const Name: string; const DefaultValue: string = ''): string;
    function Contains(const Name: string): Boolean;
    { Removes every cookie called Name; returns the number removed. }
    function Remove(const Name: string): Integer;
    procedure Clear;
    procedure Assign(Source: THttpCookieJar);

    { "a=1; b=2" for the cookies applicable to Url ('' if none). }
    function BuildCookieHeader(const Url: string): string;
    { Parses one Set-Cookie header received from RequestUrl. }
    function StoreFromSetCookie(const RequestUrl, SetCookieValue: string): Boolean;
    { Stores every Set-Cookie header found in Headers. }
    procedure StoreFromHeaders(const RequestUrl: string; Headers: THttpHeaders);

    property Count: Integer read GetCount;
    property Items[Index: Integer]: THttpCookie read GetItem; default;
  end;

implementation

function DomainMatches(const Host, Domain: string): Boolean;
begin
  Result := (Host = Domain) or
    ((Length(Host) > Length(Domain)) and
     (Copy(Host, Length(Host) - Length(Domain), Length(Domain) + 1) = '.' + Domain));
end;

function DefaultCookiePath(const RequestPath: string): string;
var
  I: Integer;
begin
  Result := '/';
  if (RequestPath = '') or (RequestPath[1] <> '/') then Exit;
  for I := Length(RequestPath) downto 1 do
    if RequestPath[I] = '/' then
    begin
      if I > 1 then Result := Copy(RequestPath, 1, I - 1);
      Exit;
    end;
end;

{ THttpCookieJar }

constructor THttpCookieJar.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor THttpCookieJar.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function THttpCookieJar.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.GetItem(Index: Integer): THttpCookie;
begin
  FLock.Enter;
  try
    Result := FItems[Index];
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.IndexOfExact(const Name, Domain, Path: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if (FItems[I].Name = Name) and (FItems[I].Domain = Domain) and (FItems[I].Path = Path) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure THttpCookieJar.DeleteAt(Index: Integer);
var
  I: Integer;
begin
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  Dec(FCount);
  FItems[FCount].Name := '';
  FItems[FCount].Value := '';
end;

procedure THttpCookieJar.Upsert(const Cookie: THttpCookie);
var
  I: Integer;
begin
  I := IndexOfExact(Cookie.Name, Cookie.Domain, Cookie.Path);
  if I < 0 then
  begin
    if FCount = Length(FItems) then
      SetLength(FItems, FCount * 2 + 8);
    I := FCount;
    Inc(FCount);
  end;
  FItems[I] := Cookie;
end;

function THttpCookieJar.Matches(const C: THttpCookie; const Url: TUrlParts;
  NowU: TDateTime): Boolean;
var
  P: string;
begin
  Result := False;
  if (C.ExpiresUtc <> 0) and (C.ExpiresUtc <= NowU) then Exit;
  if C.Secure and (Url.Scheme <> 'https') then Exit;
  if C.Domain <> '' then
  begin
    if C.HostOnly then
    begin
      if Url.Host <> C.Domain then Exit;
    end
    else if not DomainMatches(Url.Host, C.Domain) then
      Exit;
  end;
  P := C.Path;
  if (P <> '') and (P <> '/') then
  begin
    if Copy(Url.Path, 1, Length(P)) <> P then Exit;
    if (Length(Url.Path) > Length(P)) and (P[Length(P)] <> '/') and
       (Url.Path[Length(P) + 1] <> '/') then Exit;
  end;
  Result := True;
end;

procedure THttpCookieJar.SetCookie(const Name, Value, Domain, Path: string;
  Secure: Boolean);
var
  C: THttpCookie;
begin
  C.Name := Name;
  C.Value := Value;
  C.Domain := AsciiLower(Domain);
  C.Path := Path;
  C.Secure := Secure;
  C.HttpOnly := False;
  C.HostOnly := False;
  C.ExpiresUtc := 0;
  FLock.Enter;
  try
    Upsert(C);
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.Get(const Name, DefaultValue: string): string;
var
  I: Integer;
  NowU: TDateTime;
begin
  Result := DefaultValue;
  NowU := NowUtc;
  FLock.Enter;
  try
    for I := 0 to FCount - 1 do
      if (FItems[I].Name = Name) and
         ((FItems[I].ExpiresUtc = 0) or (FItems[I].ExpiresUtc > NowU)) then
      begin
        Result := FItems[I].Value;
        Exit;
      end;
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.Contains(const Name: string): Boolean;
const
  Sentinel = #1#2#3;
begin
  Result := Get(Name, Sentinel) <> Sentinel;
end;

function THttpCookieJar.Remove(const Name: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  FLock.Enter;
  try
    I := 0;
    while I < FCount do
      if FItems[I].Name = Name then
      begin
        DeleteAt(I);
        Inc(Result);
      end
      else
        Inc(I);
  finally
    FLock.Leave;
  end;
end;

procedure THttpCookieJar.Clear;
begin
  FLock.Enter;
  try
    SetLength(FItems, 0);
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure THttpCookieJar.Assign(Source: THttpCookieJar);
var
  I: Integer;
  Copy_: array of THttpCookie;
  N: Integer;
begin
  if Source = Self then Exit;
  Source.FLock.Enter;
  try
    N := Source.FCount;
    SetLength(Copy_, N);
    for I := 0 to N - 1 do
      Copy_[I] := Source.FItems[I];
  finally
    Source.FLock.Leave;
  end;
  FLock.Enter;
  try
    SetLength(FItems, N);
    FCount := N;
    for I := 0 to N - 1 do
      FItems[I] := Copy_[I];
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.BuildCookieHeader(const Url: string): string;
var
  Parts: TUrlParts;
  I: Integer;
  NowU: TDateTime;
begin
  Result := '';
  if not TryParseUrl(Url, Parts) then Exit;
  NowU := NowUtc;
  FLock.Enter;
  try
    for I := 0 to FCount - 1 do
      if Matches(FItems[I], Parts, NowU) then
      begin
        if Result <> '' then Result := Result + '; ';
        Result := Result + FItems[I].Name + '=' + FItems[I].Value;
      end;
  finally
    FLock.Leave;
  end;
end;

function THttpCookieJar.StoreFromSetCookie(const RequestUrl, SetCookieValue: string): Boolean;
var
  Parts: TUrlParts;
  C: THttpCookie;
  Segments: THttpStringArray;
  Seg, AttrName, AttrValue: string;
  I, P, Start, MaxAge: Integer;
  HasMaxAge, Expired: Boolean;
  ExpDate: TDateTime;
  Idx: Integer;
begin
  Result := False;
  if not TryParseUrl(RequestUrl, Parts) then Exit;

  // split on ';'
  SetLength(Segments, 0);
  Start := 1;
  for I := 1 to Length(SetCookieValue) + 1 do
    if (I > Length(SetCookieValue)) or (SetCookieValue[I] = ';') then
    begin
      SetLength(Segments, Length(Segments) + 1);
      Segments[High(Segments)] := Trim(Copy(SetCookieValue, Start, I - Start));
      Start := I + 1;
    end;
  if Length(Segments) = 0 then Exit;

  P := Pos('=', Segments[0]);
  if P < 2 then Exit;                          // no name => ignore
  C.Name := Trim(Copy(Segments[0], 1, P - 1));
  C.Value := Trim(Copy(Segments[0], P + 1, MaxInt));
  C.Domain := Parts.Host;
  C.HostOnly := True;
  C.Path := '';
  C.Secure := False;
  C.HttpOnly := False;
  C.ExpiresUtc := 0;
  HasMaxAge := False;
  MaxAge := 0;
  Expired := False;

  for I := 1 to High(Segments) do
  begin
    Seg := Segments[I];
    P := Pos('=', Seg);
    if P > 0 then
    begin
      AttrName := AsciiLower(Trim(Copy(Seg, 1, P - 1)));
      AttrValue := Trim(Copy(Seg, P + 1, MaxInt));
    end
    else
    begin
      AttrName := AsciiLower(Seg);
      AttrValue := '';
    end;
    if AttrName = 'domain' then
    begin
      AttrValue := AsciiLower(AttrValue);
      if (AttrValue <> '') and (AttrValue[1] = '.') then Delete(AttrValue, 1, 1);
      if AttrValue = '' then Continue;
      // a server may only set cookies for its own domain
      if not DomainMatches(Parts.Host, AttrValue) then Exit;
      C.Domain := AttrValue;
      C.HostOnly := False;
    end
    else if AttrName = 'path' then
    begin
      if (AttrValue <> '') and (AttrValue[1] = '/') then C.Path := AttrValue;
    end
    else if AttrName = 'secure' then
      C.Secure := True
    else if AttrName = 'httponly' then
      C.HttpOnly := True
    else if AttrName = 'max-age' then
    begin
      MaxAge := ParseIntDef(AttrValue, MaxInt);
      HasMaxAge := MaxAge <> MaxInt;
    end
    else if AttrName = 'expires' then
    begin
      if TryParseHttpDate(AttrValue, ExpDate) then
      begin
        if not HasMaxAge then C.ExpiresUtc := ExpDate;
        if ExpDate <= NowUtc then Expired := True;
      end;
    end;
  end;

  if C.Path = '' then C.Path := DefaultCookiePath(Parts.Path);

  if HasMaxAge then
  begin
    Expired := MaxAge <= 0;
    if not Expired then C.ExpiresUtc := NowUtc + MaxAge / 86400.0;
  end;

  FLock.Enter;
  try
    if Expired then
    begin
      Idx := IndexOfExact(C.Name, C.Domain, C.Path);
      if Idx >= 0 then DeleteAt(Idx);
    end
    else
      Upsert(C);
  finally
    FLock.Leave;
  end;
  Result := True;
end;

procedure THttpCookieJar.StoreFromHeaders(const RequestUrl: string; Headers: THttpHeaders);
var
  Values: THttpStringArray;
  I: Integer;
begin
  Values := Headers.GetAll('Set-Cookie');
  for I := 0 to High(Values) do
    StoreFromSetCookie(RequestUrl, Values[I]);
end;

end.
