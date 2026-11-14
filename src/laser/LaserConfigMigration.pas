unit LaserConfigMigration;
// Перенос настроек лазера из общего конфига вкладки
// последовательностей (sequences.ini) в собственный файл лазера
// (laser.ini). Раньше и перо лазера, и геометрия лежали в sequences.ini;
// теперь они читаются из laser.ini, а старые значения копируются один раз.
// Старый файл не изменяется и не удаляется.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

// Копирует разделы [LaserPen] и [Geometry] из ASequencesIni в ALaserIni,
// если в ALaserIni этих разделов ещё нет. Существующие разделы ALaserIni
// никогда не перезаписываются, ASequencesIni не изменяется. Файл ALaserIni
// создаётся, только если есть что записать. Нет старого файла или нужных
// разделов в нём - ничего не делается, результат True. При ошибке записи -
// False и текст об ошибке в AErrorText.
function MigrateLaserSettings(const ASequencesIni, ALaserIni: string;
  out AErrorText: string): Boolean;

implementation

uses
  Classes, IniFiles, LaserPen, MarkGeometry;

function HasSection(const AFileName, ASection: string): Boolean;
// Есть ли в файле раздел [ASection] (без учёта регистра и пробелов вокруг
// заголовка, BOM в начале файла пропускается). Нет файла - раздела нет.
// Файл есть, но не читается - исключение: молча считать, что раздела нет,
// нельзя, иначе миграция перезаписала бы чужие настройки.
const
  UTF8_BOM = #$EF#$BB#$BF;
var
  Lines: TStringList;
  i: integer;
  Line: string;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      if (i = 0) and (Copy(Line, 1, Length(UTF8_BOM)) = UTF8_BOM) then
        Line := Trim(Copy(Line, Length(UTF8_BOM) + 1, MaxInt));
      if SameText(Line, '[' + ASection + ']') then
        Exit(True);
    end;
  finally
    Lines.Free;
  end;
end;

function MigrateLaserSettings(const ASequencesIni, ALaserIni: string;
  out AErrorText: string): Boolean;
var
  OldIni, NewIni: TMemIniFile;
  OldLines, NewLines: TStringList;
  PenValues, GeometryValues: TStringList;
  HasPen, HasGeometry: Boolean;

  function ReadSection(const ASection: string): TStringList;
  // Значения ключей раздела в порядке файла; пустой список, если раздела нет.
  // Повторяющиеся ключи ReadSectionValues оставляет один раз.
  begin
    Result := TStringList.Create;
    OldIni.ReadSectionValues(ASection, Result);
    Result.CaseSensitive := False;
  end;

  procedure AddSection(const ASection: string; const AValues: TStringList);
  begin
    NewLines.Add('[' + ASection + ']');
    NewLines.AddStrings(AValues);
  end;

begin
  Result := False;
  AErrorText := '';
  OldIni := nil;
  NewIni := nil;
  OldLines := nil;
  NewLines := nil;
  PenValues := nil;
  GeometryValues := nil;
  try
    if not FileExists(ASequencesIni) then
    begin
      Result := True; // старых настроек нет - переносить нечего
      Exit;
    end;
    try
      OldIni := TMemIniFile.Create(ASequencesIni);
    except
      Result := True; // файл не читается - переносить нечего
      Exit;
    end;

    PenValues := ReadSection(LASER_PEN_SECTION);
    GeometryValues := ReadSection(GEOMETRY_SECTION);
    if (PenValues.Count = 0) and (GeometryValues.Count = 0) then
    begin
      Result := True; // в старом файле нет нужных разделов
      Exit;
    end;

    HasPen := HasSection(ALaserIni, LASER_PEN_SECTION);
    HasGeometry := HasSection(ALaserIni, GEOMETRY_SECTION);
    if HasPen and HasGeometry then
    begin
      Result := True; // в новом файле уже есть оба раздела
      Exit;
    end;

    // Новый файл пишем по строкам: TMemIniFile.UpdateFile переписывает файл
    // целиком, поэтому его свободные строки (комментарии) сохраняются.
    NewLines := TStringList.Create;
    NewLines.CaseSensitive := False;
    if FileExists(ALaserIni) then
    begin
      // не читается - исключение (ниже станет текстом ошибки): начинать с
      // пустого нельзя, это стёрло бы настройки пользователя
      OldLines := TStringList.Create;
      OldLines.LoadFromFile(ALaserIni);
      NewLines.Assign(OldLines);
    end;

    // пустые разделы старого файла не переносим
    if (not HasPen) and (PenValues.Count > 0) then
      AddSection(LASER_PEN_SECTION, PenValues);
    if (not HasGeometry) and (GeometryValues.Count > 0) then
      AddSection(GEOMETRY_SECTION, GeometryValues);
    if NewLines.Count = 0 then
    begin
      Result := True; // записывать нечего
      Exit;
    end;

    if not ForceDirectories(ExtractFileDir(ALaserIni)) then
      raise Exception.Create('не удалось создать папку ' +
        ExtractFileDir(ALaserIni));
    NewIni := TMemIniFile.Create(ALaserIni);
    NewIni.SetStrings(NewLines);
    NewIni.UpdateFile;
    Result := True;
  except
    on E: Exception do
      AErrorText := 'Не удалось перенести настройки лазера из ' +
        ASequencesIni + ' в ' + ALaserIni + ':' + LineEnding + E.Message;
  end;
  NewLines.Free;
  OldLines.Free;
  PenValues.Free;
  GeometryValues.Free;
  NewIni.Free;
  OldIni.Free;
end;

end.
