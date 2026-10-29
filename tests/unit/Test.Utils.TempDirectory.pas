unit Test.Utils.TempDirectory;
{$I Http.Defines.inc}
interface
implementation
uses SysUtils, Classes, Test.Framework, Http.Utils;

procedure TestEndsWithPathDelimiter;
var
  D: string;
begin
  D := GetTempDirectory;
  CheckTrue(D <> '');
  CheckTrue(D[Length(D)] = PathDelim, 'must end with a path delimiter');
end;

procedure TestDirectoryExists;
begin
  CheckTrue(DirectoryExists(GetTempDirectory));
end;

procedure TestFilesCanBeCreatedThere;
var
  P: string;
  F: TFileStream;
begin
  P := GetTempDirectory + 'tempdir_probe.tmp';
  F := TFileStream.Create(P, fmCreate);
  try
    F.WriteBuffer(P[1], 1);
  finally
    F.Free;
  end;
  try
    CheckTrue(FileExists(P));
  finally
    DeleteFile(P);
  end;
end;

initialization
  RegisterTest('Utils.TempDirectory', 'ends with a path delimiter', TestEndsWithPathDelimiter);
  RegisterTest('Utils.TempDirectory', 'directory exists', TestDirectoryExists);
  RegisterTest('Utils.TempDirectory', 'temp files can be created there', TestFilesCanBeCreatedThere);
end.
