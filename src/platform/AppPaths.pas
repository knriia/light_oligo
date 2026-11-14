unit AppPaths;
// Папки приложения. Данные, которые создаёт программа, хранятся в папке
// data, а настройки - в папке configs рядом с exe, поэтому программу можно
// переносить одной папкой. Файлы EzCAD (EZCAD.CFG и др.) остаются рядом с
// exe: их там ищут EzCAD и MarkEzd.dll.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  DATA_FOLDER = 'data';
  ARRAYS_FOLDER = 'arrays';          // массивы олигов (CSV)
  MATRICES_FOLDER = 'matrices';      // матрицы точек
  SLICES_FOLDER = 'slices';          // результаты нарезки на слои
  PROTOCOLS_FOLDER = 'protocols';    // протоколы синтеза (.pro)
  AUTOMATION_FOLDER = 'automation';  // сценарии шприцевой станции
  SYNTHESES_FOLDER = 'syntheses';    // папки запусков синтеза
  SETTINGS_FOLDER = 'settings';      // старое место настроек станции (data\settings)
  EZD_FOLDER = 'ezd';                // файлы EzCAD, созданные вручную
  SETTINGS_FILE = 'syringe_pump.ini';
  LAYERS_FOLDER = 'layers';          // файлы слоёв рядом с файлом массива
  CONFIGS_FOLDER = 'configs';        // настройки программы рядом с exe
  INTERFACE_FILE = 'Interface.ini';  // надписи интерфейса
  PROG_CONFIG_FILE = 'ProgConfig.ini'; // настройки ручной вкладки, лазера, станции
  SEQUENCES_CONFIG_FILE = 'sequences.ini'; // настройки вкладки последовательностей
  MANUAL_CONFIG_FILE = 'manual.ini'; // настройки ручной вкладки
  LASER_CONFIG_FILE = 'laser.ini';   // настройки лазера

// Папка с exe. Пустой AExecutableFileName означает текущую программу.
function AppDir(const AExecutableFileName: string = ''): string;
// Папка data и её подпапки (без завершающего разделителя).
function DataDir(const AExecutableFileName: string = ''): string;
function DataSubDir(const AFolderName: string;
  const AExecutableFileName: string = ''): string;
function ArraysDir: string;
function MatricesDir: string;
function SlicesDir: string;
function ProtocolsDir: string;
function AutomationDir(const AExecutableFileName: string = ''): string;
// Папки запусков синтеза: в каждой копии слоёв и протоколов, журнал и итог.
function SynthesesDir(const AExecutableFileName: string = ''): string;
function EzdDir: string;
// Папка настроек (configs рядом с exe) и файлы в ней.
function ConfigsDir(const AExecutableFileName: string = ''): string;
function ConfigFilePath(const AFileName: string;
  const AExecutableFileName: string = ''): string;
// Настройки шприцевой станции и её окон.
function SettingsFilePath: string;
function SequencesConfigPath: string;
function ManualConfigPath: string;
function LaserConfigPath: string;

// Создаёт папки data (со всеми подпапками) и configs.
procedure EnsureDataDirs;

// Однократный перенос данных из старых мест в папку data:
// настройки станции из профиля пользователя и файлы из папки protocols у exe.
procedure MigrateLegacyData(const AExecutableFileName: string = '');

// Имя папки или файла без пути: не пустое, без символов \ / : * ? " < > |
// и не заканчивается точкой или пробелом. ACaption - начало сообщения об ошибке.
function CheckFileNamePart(const AName, ACaption: string;
  out ErrorText: string): Boolean;

// Полный путь к файлу AName с расширением AExt (например '.csv') в папке
// AFolder. Папка - полный путь (с диском), каждая её часть и имя файла
// проверяются как CheckFileNamePart. Если AExt уже есть в имени, второй раз
// не добавляется.
function MakeFilePathInFolder(const AFolder, AName, AExt: string;
  out AFilePath, AErrorText: string): Boolean;

// Папка - полный путь с диском, каждая часть проходит CheckFileNamePart.
// Самой папки может ещё не быть.
function CheckFolderPath(const AFolder: string; out AErrorText: string): Boolean;

implementation

function AppDir(const AExecutableFileName: string): string;
var
  ExecutableFileName: string;
begin
  ExecutableFileName := AExecutableFileName;
  if Trim(ExecutableFileName) = '' then
    ExecutableFileName := ParamStr(0);
  Result := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ExecutableFileName)));
end;

function DataDir(const AExecutableFileName: string): string;
begin
  Result := AppDir(AExecutableFileName) + DATA_FOLDER;
end;

function DataSubDir(const AFolderName: string;
  const AExecutableFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(DataDir(AExecutableFileName)) +
    AFolderName;
end;

function ArraysDir: string;
begin
  Result := DataSubDir(ARRAYS_FOLDER);
end;

function MatricesDir: string;
begin
  Result := DataSubDir(MATRICES_FOLDER);
end;

function SlicesDir: string;
begin
  Result := DataSubDir(SLICES_FOLDER);
end;

function ProtocolsDir: string;
begin
  Result := DataSubDir(PROTOCOLS_FOLDER);
end;

function AutomationDir(const AExecutableFileName: string): string;
begin
  Result := DataSubDir(AUTOMATION_FOLDER, AExecutableFileName);
end;

function SynthesesDir(const AExecutableFileName: string): string;
begin
  Result := DataSubDir(SYNTHESES_FOLDER, AExecutableFileName);
end;

function ConfigsDir(const AExecutableFileName: string): string;
begin
  Result := AppDir(AExecutableFileName) + CONFIGS_FOLDER;
end;

function ConfigFilePath(const AFileName: string;
  const AExecutableFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ConfigsDir(AExecutableFileName)) +
    AFileName;
end;

function SequencesConfigPath: string;
begin
  Result := ConfigFilePath(SEQUENCES_CONFIG_FILE);
end;

function ManualConfigPath: string;
begin
  Result := ConfigFilePath(MANUAL_CONFIG_FILE);
end;

function LaserConfigPath: string;
begin
  Result := ConfigFilePath(LASER_CONFIG_FILE);
end;

function EzdDir: string;
begin
  Result := DataSubDir(EZD_FOLDER);
end;

function SettingsFilePath: string;
begin
  Result := ConfigFilePath(SETTINGS_FILE);
end;

procedure EnsureDataDirs;
begin
  ForceDirectories(ArraysDir);
  ForceDirectories(MatricesDir);
  ForceDirectories(SlicesDir);
  ForceDirectories(ProtocolsDir);
  ForceDirectories(AutomationDir);
  ForceDirectories(SynthesesDir);
  ForceDirectories(EzdDir);
  ForceDirectories(ConfigsDir);
end;

procedure MoveFilesFromLegacyProtocols(const AExecutableFileName: string);
// В старой версии и протоколы синтеза (.pro), и сценарии станции лежали
// в папке protocols рядом с exe. Раскладываем их по новым папкам.
var
  OldDir: string;
  Search: TSearchRec;
  TargetDir: string;
  TargetFile: string;
begin
  OldDir := IncludeTrailingPathDelimiter(AppDir(AExecutableFileName) +
    PROTOCOLS_FOLDER);
  if not DirectoryExists(OldDir) then
    Exit;

  if FindFirst(OldDir + '*', faAnyFile and not faDirectory, Search) = 0 then
  try
    repeat
      if SameText(ExtractFileExt(Search.Name), '.pro') then
        TargetDir := DataSubDir(PROTOCOLS_FOLDER, AExecutableFileName)
      else
        TargetDir := AutomationDir(AExecutableFileName);
      ForceDirectories(TargetDir);
      TargetFile := IncludeTrailingPathDelimiter(TargetDir) + Search.Name;
      if not FileExists(TargetFile) then
        RenameFile(OldDir + Search.Name, TargetFile);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;

  // Папку удаляем, только если в ней ничего не осталось.
  RemoveDir(OldDir);
end;

procedure CopySettingsFromUserProfile(const AExecutableFileName: string);
// Раньше настройки станции хранились в %LOCALAPPDATA%\<программа>.
var
  OldFile: string;
  NewFile: string;
  Source: TFileStream;
  Target: TFileStream;
begin
  NewFile := ConfigFilePath(SETTINGS_FILE, AExecutableFileName);
  OldFile := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
    SETTINGS_FILE;
  if FileExists(NewFile) or not FileExists(OldFile) then
    Exit;

  ForceDirectories(ExtractFileDir(NewFile));
  Source := TFileStream.Create(OldFile, fmOpenRead or fmShareDenyWrite);
  try
    Target := TFileStream.Create(NewFile, fmCreate);
    try
      Target.CopyFrom(Source, 0);
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure MoveConfigFile(const AOldFile, AExecutableFileName: string);
// Файл настроек со старого места - в configs, если там его ещё нет.
var
  NewFile: string;
begin
  NewFile := ConfigFilePath(ExtractFileName(AOldFile), AExecutableFileName);
  if FileExists(NewFile) or not FileExists(AOldFile) then
    Exit;
  ForceDirectories(ExtractFileDir(NewFile));
  RenameFile(AOldFile, NewFile);
end;

procedure MoveConfigsToConfigsFolder(const AExecutableFileName: string);
// Раньше настройки лежали рядом с exe (Interface.ini, ProgConfig.ini) и в
// data\settings (настройки станции).
var
  OldSettingsDir: string;
begin
  MoveConfigFile(AppDir(AExecutableFileName) + INTERFACE_FILE,
    AExecutableFileName);
  MoveConfigFile(AppDir(AExecutableFileName) + PROG_CONFIG_FILE,
    AExecutableFileName);
  OldSettingsDir := DataSubDir(SETTINGS_FOLDER, AExecutableFileName);
  MoveConfigFile(IncludeTrailingPathDelimiter(OldSettingsDir) + SETTINGS_FILE,
    AExecutableFileName);
  // Папку удаляем, только если в ней ничего не осталось.
  RemoveDir(OldSettingsDir);
end;

procedure MigrateLegacyData(const AExecutableFileName: string);
begin
  try
    MoveFilesFromLegacyProtocols(AExecutableFileName);
  except
    // Перенос не обязателен для работы: старые файлы останутся на месте.
  end;
  try
    MoveConfigsToConfigsFolder(AExecutableFileName);
  except
    // Не перенеслось - программа начнёт с настроек по умолчанию.
  end;
  try
    CopySettingsFromUserProfile(AExecutableFileName);
  except
    // Если скопировать не удалось, станция начнёт с настроек по умолчанию.
  end;
end;


function CheckFileNamePart(const AName, ACaption: string;
  out ErrorText: string): Boolean;
const
  BadChars = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  I: Integer;
begin
  Result := False;
  ErrorText := '';
  if Trim(AName) = '' then
  begin
    ErrorText := ACaption + ': имя не задано.';
    Exit;
  end;
  for I := 1 to Length(AName) do
    if AName[I] in BadChars then
    begin
      ErrorText := ACaption + ': недопустимый символ "' + AName[I] + '".' +
        LineEnding + 'Нельзя использовать \ / : * ? " < > |';
      Exit;
    end;
  if (AName[Length(AName)] = '.') or (AName[Length(AName)] = ' ') then
  begin
    ErrorText := ACaption +
      ': имя не может заканчиваться точкой или пробелом.';
    Exit;
  end;
  Result := True;
end;

function CheckFolderPath(const AFolder: string; out AErrorText: string): Boolean;
var
  Folder, Drive: string;
  Parts: TStringArray;
  I: Integer;
begin
  Result := False;
  AErrorText := '';
  Folder := ExcludeTrailingPathDelimiter(Trim(AFolder));
  if Folder = '' then
  begin
    AErrorText := 'Папка: не задана.';
    Exit;
  end;
  Drive := ExtractFileDrive(Folder);
  if Drive = '' then
  begin
    AErrorText := 'Папка: укажите полный путь, например D:\data.';
    Exit;
  end;
  Parts := Copy(Folder, Length(Drive) + 1, MaxInt).Split(['\', '/'],
    TStringSplitOptions.ExcludeEmpty);
  for I := 0 to High(Parts) do
    if not CheckFileNamePart(Parts[I], 'Папка', AErrorText) then
      Exit;
  Result := True;
end;

function MakeFilePathInFolder(const AFolder, AName, AExt: string;
  out AFilePath, AErrorText: string): Boolean;
var
  Folder, Name: string;
begin
  Result := False;
  AFilePath := '';
  if not CheckFolderPath(AFolder, AErrorText) then
    Exit;
  Folder := ExcludeTrailingPathDelimiter(Trim(AFolder));

  Name := Trim(AName);
  if (AExt <> '') and SameText(ExtractFileExt(Name), AExt) then
    Name := ChangeFileExt(Name, '');
  if not CheckFileNamePart(Name, 'Имя файла', AErrorText) then
    Exit;

  AFilePath := IncludeTrailingPathDelimiter(Folder) + Name + AExt;
  Result := True;
end;

end.
