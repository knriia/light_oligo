unit PathUtils;
// Общие операции с абсолютными и относительными путями.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function IsAbsolutePath(const AFileName: string): Boolean;
function MakePathRelative(const ABaseDir, AFileName: string): string;
function ResolvePath(const ABaseDir, AFileName: string): string;

implementation

function IsAbsolutePath(const AFileName: string): Boolean;
begin
  Result := (ExtractFileDrive(AFileName) <> '') or
    ((AFileName <> '') and (AFileName[1] in ['\', '/']));
end;

function MakePathRelative(const ABaseDir, AFileName: string): string;
var
  BaseDir: string;
  FullName: string;
begin
  Result := AFileName;
  if (Trim(ABaseDir) = '') or (Trim(AFileName) = '') then
    Exit;
  BaseDir := IncludeTrailingPathDelimiter(ExpandFileName(ABaseDir));
  FullName := ExpandFileName(AFileName);
  if SameText(Copy(FullName, 1, Length(BaseDir)), BaseDir) then
    Result := Copy(FullName, Length(BaseDir) + 1, MaxInt);
end;

function ResolvePath(const ABaseDir, AFileName: string): string;
begin
  if (Trim(AFileName) = '') or IsAbsolutePath(AFileName) then
    Result := AFileName
  else
    Result := IncludeTrailingPathDelimiter(ABaseDir) + AFileName;
end;

end.
