unit AutomationDocumentStorage;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function GetProtocolsDirectory(const AExecutableFileName: string): string;
function EnsureProtocolsDirectory(const AExecutableFileName: string;
  out ADirectory, AErrorText: string): Boolean;
function ReadAutomationTextFile(const AFileName: string;
  out AContent: UTF8String; out AErrorText: string): Boolean;
function WriteAutomationTextFile(const AFileName: string;
  const AContent: UTF8String;
  out AErrorText: string): Boolean;

implementation

uses
  Classes, AppPaths, TextFileUtils;

function GetProtocolsDirectory(const AExecutableFileName: string): string;
begin
  // Станция работает с теми же протоколами синтеза, что и главное окно:
  // data\protocols рядом с exe.
  Result := DataSubDir(PROTOCOLS_FOLDER, AExecutableFileName);
end;

function EnsureProtocolsDirectory(const AExecutableFileName: string;
  out ADirectory, AErrorText: string): Boolean;
begin
  Result := False;
  AErrorText := '';
  ADirectory := GetProtocolsDirectory(AExecutableFileName);
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

function ReadAutomationTextFile(const AFileName: string;
  out AContent: UTF8String; out AErrorText: string): Boolean;
begin
  Result := ReadUtf8TextFile(AFileName, AContent, AErrorText);
end;

function WriteAutomationTextFile(const AFileName: string;
  const AContent: UTF8String;
  out AErrorText: string): Boolean;
begin
  Result := WriteUtf8TextFile(AFileName, AContent, AErrorText);
end;

end.
