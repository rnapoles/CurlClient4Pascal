unit Test.Files;
{ Temp-file helpers for the upload tests. File content is a deterministic byte
  pattern so size and byte-sum can be verified against the echo server. }
{$I Http.Defines.inc}

interface

uses
  SysUtils, Classes;

{ Creates <temp>/<Name> with Size bytes of pattern data; returns its path. }
function MakeTempFile(const Name: string; Size: Integer): string;
{ Sum of all bytes of the pattern file, mod 2^32 (matches echo_server.py). }
function PatternSum(Size: Integer): Int64;
procedure DeleteTempFile(const Path: string);

implementation

function PatternByte(I: Integer): Byte;
begin
  Result := Byte((Int64(I) * 7 + 3) mod 251);
end;

function MakeTempFile(const Name: string; Size: Integer): string;
var
  F: TFileStream;
  Buf: array[0..65535] of Byte;
  Done, N, I: Integer;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + Name;
  F := TFileStream.Create(Result, fmCreate);
  try
    Done := 0;
    while Done < Size do
    begin
      N := Size - Done;
      if N > SizeOf(Buf) then N := SizeOf(Buf);
      for I := 0 to N - 1 do Buf[I] := PatternByte(Done + I);
      F.WriteBuffer(Buf[0], N);
      Inc(Done, N);
    end;
  finally
    F.Free;
  end;
end;

function PatternSum(Size: Integer): Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Size - 1 do
    Result := Result + PatternByte(I);
  Result := Result and $FFFFFFFF;
end;

procedure DeleteTempFile(const Path: string);
begin
  if FileExists(Path) then DeleteFile(Path);
end;

end.
