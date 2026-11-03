unit ManualSettings;
// Настройки ручной вкладки (configs\manual.ini): геометрия массива точек,
// показывать ли подложку в просмотре и размер матрицы. Перо лазера лежит
// в том же файле, но читается и пишется модулем LaserPen.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, MarkGeometry;

const
  MANUAL_SECTION = 'Manual';

type
  TManualSettings = record
    Geometry: TMarkGeometry;
    ShowSubstrate: Boolean;
    MatrixRows: Integer;
    MatrixCols: Integer;
  end;

// Значения по умолчанию - те, что раньше лежали в ProgConfig.ini.
function DefaultManualSettings: TManualSettings;
// Нет файла, ключа или значение недопустимо - значение по умолчанию.
function LoadManualSettings(const AFileName: string): TManualSettings;
// Записывает разделы [Geometry] и [Manual]; другие разделы сохраняются.
function SaveManualSettings(const AFileName: string;
  const ASettings: TManualSettings; out AErrorText: string): Boolean;

implementation

uses
  IniFiles;

function DefaultManualSettings: TManualSettings;
begin
  Result.Geometry := DefaultMarkGeometry;
  Result.Geometry.SpotSize := 60;
  Result.ShowSubstrate := False;
  Result.MatrixRows := 30;
  Result.MatrixCols := 30;
end;

function LoadManualSettings(const AFileName: string): TManualSettings;
var
  D: TManualSettings;
  Ini: TMemIniFile;

  function Size(const AKey: string; ADefault: Integer): Integer;
  begin
    Result := Ini.ReadInteger(MANUAL_SECTION, AKey, ADefault);
    if Result < 1 then
      Result := ADefault;
  end;

begin
  D := DefaultManualSettings;
  Result := D;
  Result.Geometry := LoadMarkGeometry(AFileName, D.Geometry);
  if not FileExists(AFileName) then
    Exit;
  try
    Ini := TMemIniFile.Create(AFileName);
  except
    Exit;
  end;
  try
    Result.ShowSubstrate := Ini.ReadBool(MANUAL_SECTION, 'ShowSubstrate',
      D.ShowSubstrate);
    Result.MatrixRows := Size('MatrixRows', D.MatrixRows);
    Result.MatrixCols := Size('MatrixCols', D.MatrixCols);
  finally
    Ini.Free;
  end;
end;

function SaveManualSettings(const AFileName: string;
  const ASettings: TManualSettings; out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := SaveMarkGeometry(AFileName, ASettings.Geometry, AErrorText);
  if not Result then
    Exit;
  Result := False;
  try
    Ini := TMemIniFile.Create(AFileName);
    try
      Ini.WriteBool(MANUAL_SECTION, 'ShowSubstrate', ASettings.ShowSubstrate);
      Ini.WriteInteger(MANUAL_SECTION, 'MatrixRows', ASettings.MatrixRows);
      Ini.WriteInteger(MANUAL_SECTION, 'MatrixCols', ASettings.MatrixCols);
      Ini.UpdateFile;
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать настройки ручной вкладки:' +
        LineEnding + AFileName + LineEnding + E.Message;
  end;
end;

end.
