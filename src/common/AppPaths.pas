unit AppPaths;
// Папки приложения. Все данные, которые создаёт программа, хранятся в папке
// data рядом с exe, поэтому программу можно переносить одной папкой.

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
  SETTINGS_FOLDER = 'settings';      // настройки шприцевой станции
  SETTINGS_FILE = 'syringe_pump.ini';

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
function SettingsDir: string;
function SettingsFilePath: string;

// Создаёт папку data со всеми подпапками.
procedure EnsureDataDirs;

// Путь внутри ABaseDir превращает в относительный, остальные не меняет.
function MakePathRelative(const ABaseDir, AFileName: string): string;
// Относительный путь достраивает от ABaseDir, абсолютный не меняет.
function ResolvePath(const ABaseDir, AFileName: string): string;

// Однократный перенос данных из старых мест в папку data:
// настройки станции из профиля пользователя и файлы из папки protocols у exe.
procedure MigrateLegacyData(const AExecutableFileName: string = '');

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

function SettingsDir: string;
begin
  Result := DataSubDir(SETTINGS_FOLDER);
end;

function SettingsFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(SettingsDir) + SETTINGS_FILE;
end;

procedure EnsureDataDirs;
begin
  ForceDirectories(ArraysDir);
  ForceDirectories(MatricesDir);
  ForceDirectories(SlicesDir);
  ForceDirectories(ProtocolsDir);
  ForceDirectories(AutomationDir);
  ForceDirectories(SettingsDir);
end;

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
  NewFile := IncludeTrailingPathDelimiter(
    DataSubDir(SETTINGS_FOLDER, AExecutableFileName)) + SETTINGS_FILE;
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

procedure MigrateLegacyData(const AExecutableFileName: string);
begin
  try
    MoveFilesFromLegacyProtocols(AExecutableFileName);
  except
    // Перенос не обязателен для работы: старые файлы останутся на месте.
  end;
  try
    CopySettingsFromUserProfile(AExecutableFileName);
  except
    // Если скопировать не удалось, станция начнёт с настроек по умолчанию.
  end;
end;

end.
