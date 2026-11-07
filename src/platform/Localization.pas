unit Localization;
// Доступ к подписям интерфейса и настройкам программы. Файлы открывает
// composition root; формы не знают, где лежат конфигурации.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

// Инициализирует чтение Interface.ini и ProgConfig.ini.
procedure InitializeLocalization(const AInterfaceFileName,
  AConfigFileName: string);
procedure FinalizeLocalization;

function InterfaceIniFile: TCustomIniFile;
function ReadInterfaceString(const ASection, AKey, ADefault: string): string;
function ReadConfigString(const ASection, AKey, ADefault: string): string;
function ReadConfigInteger(const ASection, AKey: string;
  ADefault: Integer): Integer;

implementation

var
  FInterfaceIni: TIniFile;
  FConfigIni: TIniFile;

procedure InitializeLocalization(const AInterfaceFileName,
  AConfigFileName: string);
begin
  FinalizeLocalization;
  FInterfaceIni := TIniFile.Create(AInterfaceFileName);
  FConfigIni := TIniFile.Create(AConfigFileName);
end;

procedure FinalizeLocalization;
begin
  FreeAndNil(FInterfaceIni);
  FreeAndNil(FConfigIni);
end;

function InterfaceIniFile: TCustomIniFile;
begin
  Result := FInterfaceIni;
end;

function ReadInterfaceString(const ASection, AKey, ADefault: string): string;
begin
  if FInterfaceIni = nil then
    Result := ADefault
  else
    Result := FInterfaceIni.ReadString(ASection, AKey, ADefault);
end;

function ReadConfigString(const ASection, AKey, ADefault: string): string;
begin
  if FConfigIni = nil then
    Result := ADefault
  else
    Result := FConfigIni.ReadString(ASection, AKey, ADefault);
end;

function ReadConfigInteger(const ASection, AKey: string;
  ADefault: Integer): Integer;
begin
  if FConfigIni = nil then
    Result := ADefault
  else
    Result := FConfigIni.ReadInteger(ASection, AKey, ADefault);
end;

end.
