unit AutomationDocumentStorage;
// Папка со сценариями шприцевой станции (data\automation рядом с exe).

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function GetAutomationDirectory(const AExecutableFileName: string): string;
function EnsureAutomationDirectory(const AExecutableFileName: string;
  out ADirectory, AErrorText: string): Boolean;

implementation

uses
  Classes, AppPaths;

function GetAutomationDirectory(const AExecutableFileName: string): string;
begin
  Result := AutomationDir(AExecutableFileName);
end;

function EnsureAutomationDirectory(const AExecutableFileName: string;
  out ADirectory, AErrorText: string): Boolean;
begin
  Result := False;
  AErrorText := '';
  ADirectory := GetAutomationDirectory(AExecutableFileName);
  try
    if not DirectoryExists(ADirectory) and not ForceDirectories(ADirectory) then
      raise Exception.Create('Не удалось создать папку "' + ADirectory + '".');
    Result := DirectoryExists(ADirectory);
    if not Result then
      AErrorText := 'Папка "' + ADirectory + '" недоступна.';
  except
    on E: Exception do
      AErrorText := E.Message;
  end;
end;

end.
