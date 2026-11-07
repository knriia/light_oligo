unit AutomationDocumentStorage;
// Папка со сценариями шприцевой станции (data\automation рядом с exe).

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function EnsureAutomationDirectory(const ADirectory: string;
  out AErrorText: string): Boolean;

implementation

uses
  Classes;

function EnsureAutomationDirectory(const ADirectory: string;
  out AErrorText: string): Boolean;
begin
  Result := False;
  AErrorText := '';
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
