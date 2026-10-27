unit Http.Headers;
{ Case-insensitive, multi-value HTTP header collection. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Http.Utils, Http.Errors;

type
  THttpHeader = record
    Name: string;
    Value: string;
  end;

  THttpHeaders = class
  private
    FItems: array of THttpHeader;
    FCount: Integer;
    function IndexOfName(const Name: string): Integer;
    function GetName(Index: Integer): string;
    function GetValue(Index: Integer): string;
    procedure AppendRaw(const Name, Value: string);
    class procedure Validate(const Name, Value: string);
  public
    { Appends a header; existing headers of the same name are kept. }
    procedure Add(const Name, Value: string);
    { Replaces every header of that name by a single one. }
    procedure SetValue(const Name, Value: string);
    { First value of the header, or DefaultValue. }
    function Get(const Name: string; const DefaultValue: string = ''): string;
    function TryGetValue(const Name: string; out Value: string): Boolean;
    function GetAll(const Name: string): THttpStringArray;
    function Contains(const Name: string): Boolean;
    { Removes all headers of that name; returns how many were removed. }
    function Remove(const Name: string): Integer;
    procedure Clear;
    procedure Assign(Source: THttpHeaders);
    { Copies Source on top of Self: names present in Source replace ours. }
    procedure Merge(Source: THttpHeaders);
    { Parses a raw "Name: value" line (as received from the wire). }
    function TryAddLine(const Line: string): Boolean;
    function ToText: string;
    property Count: Integer read FCount;
    property Names[Index: Integer]: string read GetName;
    property Values[Index: Integer]: string read GetValue;
  end;

implementation

class procedure THttpHeaders.Validate(const Name, Value: string);
var
  I: Integer;
begin
  if Name = '' then
    raise EHttpError.Create('Header name must not be empty');
  for I := 1 to Length(Name) do
    if (Ord(Name[I]) <= 32) or (Ord(Name[I]) >= 127) or (Name[I] = ':') then
      raise EHttpError.CreateFmt('Invalid character in header name "%s"', [Name]);
  // CR/LF/NUL in a value would allow header injection (request splitting)
  for I := 1 to Length(Value) do
    if (Value[I] = #13) or (Value[I] = #10) or (Value[I] = #0) then
      raise EHttpError.CreateFmt('Invalid control character in value of header "%s"', [Name]);
end;

function THttpHeaders.IndexOfName(const Name: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if AsciiSameText(FItems[I].Name, Name) then
    begin
      Result := I;
      Exit;
    end;
end;

function THttpHeaders.GetName(Index: Integer): string;
begin
  Result := FItems[Index].Name;
end;

function THttpHeaders.GetValue(Index: Integer): string;
begin
  Result := FItems[Index].Value;
end;

procedure THttpHeaders.AppendRaw(const Name, Value: string);
begin
  if FCount = Length(FItems) then
    SetLength(FItems, FCount * 2 + 8);
  FItems[FCount].Name := Name;
  FItems[FCount].Value := Value;
  Inc(FCount);
end;

procedure THttpHeaders.Add(const Name, Value: string);
begin
  Validate(Name, Value);
  AppendRaw(Name, Value);
end;

procedure THttpHeaders.SetValue(const Name, Value: string);
begin
  Validate(Name, Value);
  Remove(Name);
  AppendRaw(Name, Value);
end;

function THttpHeaders.Get(const Name, DefaultValue: string): string;
begin
  if not TryGetValue(Name, Result) then
    Result := DefaultValue;
end;

function THttpHeaders.TryGetValue(const Name: string; out Value: string): Boolean;
var
  I: Integer;
begin
  I := IndexOfName(Name);
  Result := I >= 0;
  if Result then
    Value := FItems[I].Value
  else
    Value := '';
end;

function THttpHeaders.GetAll(const Name: string): THttpStringArray;
var
  I, N: Integer;
begin
  SetLength(Result, FCount);
  N := 0;
  for I := 0 to FCount - 1 do
    if AsciiSameText(FItems[I].Name, Name) then
    begin
      Result[N] := FItems[I].Value;
      Inc(N);
    end;
  SetLength(Result, N);
end;

function THttpHeaders.Contains(const Name: string): Boolean;
begin
  Result := IndexOfName(Name) >= 0;
end;

function THttpHeaders.Remove(const Name: string): Integer;
var
  I, N: Integer;
begin
  N := 0;
  Result := 0;
  for I := 0 to FCount - 1 do
    if AsciiSameText(FItems[I].Name, Name) then
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

procedure THttpHeaders.Clear;
begin
  SetLength(FItems, 0);
  FCount := 0;
end;

procedure THttpHeaders.Assign(Source: THttpHeaders);
var
  I: Integer;
begin
  if Source = Self then Exit;
  Clear;
  SetLength(FItems, Source.FCount);
  for I := 0 to Source.FCount - 1 do
    AppendRaw(Source.FItems[I].Name, Source.FItems[I].Value);
end;

procedure THttpHeaders.Merge(Source: THttpHeaders);
var
  I, J: Integer;
  Seen: Boolean;
begin
  if Source = Self then Exit;
  for I := 0 to Source.FCount - 1 do
  begin
    Seen := False;
    for J := 0 to I - 1 do
      if AsciiSameText(Source.FItems[J].Name, Source.FItems[I].Name) then
      begin
        Seen := True;
        Break;
      end;
    if not Seen then
      Remove(Source.FItems[I].Name);
    AppendRaw(Source.FItems[I].Name, Source.FItems[I].Value);
  end;
end;

function THttpHeaders.TryAddLine(const Line: string): Boolean;
var
  P: Integer;
  N: string;
begin
  P := Pos(':', Line);
  Result := P > 1;
  if not Result then Exit;
  N := Trim(Copy(Line, 1, P - 1));
  Result := N <> '';
  if Result then
    AppendRaw(N, Trim(Copy(Line, P + 1, MaxInt)));
end;

function THttpHeaders.ToText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FCount - 1 do
    Result := Result + FItems[I].Name + ': ' + FItems[I].Value + #13#10;
end;

end.
