unit SynthesisFolder;
// Папка одного синтеза: <папка проекта>\<папка слайса>\synthes_<дата>\
// (синтез лежит внутри слайса, из которого взяты слои). В ней лежат EZD-файлы
// слоёв (ezd\), Slices.lays с путями к ним, геометрия и перо лазера, с которыми
// созданы EZD (geometry.ini, laser.ini), протоколы букв (protocols\), а файл
// синтеза synthesis.ini хранит, когда синтез изменён, какой проект, из какого
// слайса слои, сколько слоёв и какие буквы. При запуске в него дописывается
// время запуска, рядом пишется журнал log.txt, а при завершении - итог
// (завершён, остановлен или ошибка). Синтез идёт по файлам своей папки, поэтому
// папка - точная запись того, что выполнялось, даже если слайс потом изменится.
// Здесь отдельные действия над папкой; когда и что делать, решает
// SynthesisWorkspace.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, OligoSlices, ProtocolModel, AppPaths;

const
  SYNTHESIS_INFO_FILE = 'synthesis.ini';
  SYNTHESIS_LOG_FILE = 'log.txt';
  SYNTHESIS_FOLDER_PREFIX = 'synthes_';
  SYNTHESIS_EZD_FOLDER = EZD_FOLDER;       // EZD-файлы слоёв (то же имя пишет лазер)
  SYNTHESIS_PROTOCOLS_FOLDER = 'protocols';
  SYNTHESIS_SLICES_FILE = 'Slices.lays';   // таблица слоёв с путями к EZD
  // Перо лазера, с которым созданы EZD (то же имя, что у LASER_PEN_FILE в
  // модуле laser: synthesis с ним не связан и только стирает файл вместе со
  // слоями).
  SYNTHESIS_LASER_FILE = 'laser.ini';
  SLICE_STATISTICS_FILE = 'Slices.txt';    // слайс: слои и пути к матрицам

type
  TSynthesisSnapshot = record
    Folder: string;
    LogFile: string;
    Layers: TSliceLayers;   // слои с путями к EZD внутри папки
  end;

  TSynthesisResult = (srCompleted, srStopped, srFailed);

  // Что записано о синтезе в synthesis.ini (файл синтеза).
  TSynthesisInfo = record
    ArrayName: string;      // имя проекта (папки проекта)
    SourceFolder: string;   // папка слайса, из которого взяты слои
    LayerCount: Integer;
    Started: Boolean;       // синтез уже запускался
  end;

// Часть имени папки без символов, недопустимых в Windows, не длиннее 60.
function SafeFolderPart(const AText: string): string;
// Имя папки синтеза по умолчанию: synthes_<гггг-мм-дд>
function SynthesisFolderName(ANow: TDateTime): string;
// То же, но свободное в папке слайса: если такая папка есть, добавляется
// _2, _3...
function FreeSynthesisFolderName(const ASliceDir: string;
  ANow: TDateTime): string;

// Папка проекта: в ней есть файл массива (*.csv).
function IsProjectFolder(const AFolder: string): Boolean;
// Имя папки синтеза внутри слайса: начинается с synthes_, чтобы не совпасть со
// служебными папками слайса. Иначе - False, текст объясняет почему.
function CheckSynthesisFolderName(const AName: string;
  out AErrorText: string): Boolean;
// Слайс синтеза: папка со Slices.txt внутри папки проекта (или сама папка
// проекта). Иначе - False, текст объясняет почему.
function CheckSliceFolder(const AProjectDir, ASliceDir: string;
  out AErrorText: string): Boolean;

// Удаляет папку со всем содержимым (нет папки - ничего не делает).
procedure RemoveDirectoryTree(const ADirectory: string);

// Папка с EZD-файлами слоёв внутри папки синтеза (с разделителем на конце).
function EzdFolderOf(const AFolder: string): string;

// Удаляет из папки синтеза всё, что относится к слоям: ezd\, Slices.lays,
// geometry.ini и laser.ini. Протоколы и synthesis.ini остаются.
procedure RemoveLayerFiles(const AFolder: string);

// Файл копии протокола буквы: AFolder\protocols\<буква>.pro
function ProtocolCopyFileName(const AFolder, ALetter: string): string;

// Записывает протокол буквы в AFolder\protocols\<буква>.pro как есть.
function WriteProtocolCopy(AProtocol: TProtocolModel; const ALetter,
  AFolder: string; out AErrorText: string): Boolean;

// Записывает файл синтеза synthesis.ini: проект, слайс, слои, буквы. Время
// создания (Created) пишется один раз, при повторной записи остаётся прежним.
function SaveSynthesisInfo(const AFolder, AArrayName, ASourceFolder: string;
  ALayerCount: Integer; ALetters: TStringList; ANow: TDateTime;
  out AErrorText: string): Boolean;

// Дописывает в synthesis.ini, когда синтез запущен.
function SaveSynthesisStart(const AFolder: string; ANow: TDateTime;
  out AErrorText: string): Boolean;

// Читает файл синтеза; не тот файл или не читается - False, текст объясняет.
function ReadSynthesisInfo(const AIniFile: string; out AInfo: TSynthesisInfo;
  out AErrorText: string): Boolean;

// Дописывает в synthesis.ini итог запуска: когда закончен и как.
function SaveSynthesisResult(const AFolder: string; AResult: TSynthesisResult;
  ANow: TDateTime; out AErrorText: string): Boolean;

implementation

uses
  TextFileUtils, MarkGeometry;

const
  INFO_SECTION = 'Synthesis';
  RESULT_SECTION = 'Result';
  DATE_TIME_FORMAT = 'yyyy-mm-dd hh:nn:ss';

function SafeFolderPart(const AText: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AText) do
    if AText[I] in ['\', '/', ':', '*', '?', '"', '<', '>', '|', #0..#31] then
      Result := Result + '_'
    else
      Result := Result + AText[I];
  Result := Trim(Result);
  while (Result <> '') and (Result[Length(Result)] = '.') do
    Delete(Result, Length(Result), 1);
  if Length(Result) > 60 then
    SetLength(Result, 60);
  if Result = '' then
    Result := 'array';
end;

function SynthesisFolderName(ANow: TDateTime): string;
begin
  Result := SYNTHESIS_FOLDER_PREFIX + FormatDateTime('yyyy-mm-dd', ANow);
end;

function FreeSynthesisFolderName(const ASliceDir: string;
  ANow: TDateTime): string;
var
  Dir, Base: string;
  N: Integer;
begin
  Dir := IncludeTrailingPathDelimiter(ASliceDir);
  Base := SynthesisFolderName(ANow);
  Result := Base;
  N := 2;
  while DirectoryExists(Dir + Result) or FileExists(Dir + Result) do
  begin
    Result := Base + '_' + IntToStr(N);
    Inc(N);
  end;
end;

function CheckSynthesisFolderName(const AName: string;
  out AErrorText: string): Boolean;
begin
  Result := SameText(Copy(AName, 1, Length(SYNTHESIS_FOLDER_PREFIX)),
    SYNTHESIS_FOLDER_PREFIX);
  if Result then
    AErrorText := ''
  else
    AErrorText := 'Имя папки синтеза должно начинаться с ' +
      SYNTHESIS_FOLDER_PREFIX;
end;

function IsProjectFolder(const AFolder: string): Boolean;
var
  Search: TSearchRec;
begin
  Result := False;
  if (AFolder = '') or not DirectoryExists(AFolder) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*.csv',
    faAnyFile and not faDirectory, Search) = 0 then
  begin
    Result := True;
    FindClose(Search);
  end;
end;

function CheckSliceFolder(const AProjectDir, ASliceDir: string;
  out AErrorText: string): Boolean;
var
  Project, Slice: string;
begin
  Result := False;
  AErrorText := '';
  Project := IncludeTrailingPathDelimiter(ExpandFileName(AProjectDir));
  Slice := IncludeTrailingPathDelimiter(ExpandFileName(ASliceDir));
  if not SameText(Copy(Slice, 1, Length(Project)), Project) then
  begin
    AErrorText := 'Слайс должен лежать в папке проекта синтеза:' + LineEnding +
      ExcludeTrailingPathDelimiter(Project);
    Exit;
  end;
  if not FileExists(Slice + SLICE_STATISTICS_FILE) then
  begin
    AErrorText := 'В выбранной папке нет файла ' + SLICE_STATISTICS_FILE +
      ': это не папка слайса.';
    Exit;
  end;
  Result := True;
end;

procedure RemoveDirectoryTree(const ADirectory: string);
var
  Search: TSearchRec;
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(ADirectory);
  if FindFirst(Dir + '*', faAnyFile, Search) = 0 then
  try
    repeat
      if (Search.Name = '.') or (Search.Name = '..') then
        Continue;
      if (Search.Attr and faDirectory) <> 0 then
        RemoveDirectoryTree(Dir + Search.Name)
      else
        DeleteFile(Dir + Search.Name);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  RemoveDir(ADirectory);
end;

function EzdFolderOf(const AFolder: string): string;
begin
  Result := IncludeTrailingPathDelimiter(AFolder) + SYNTHESIS_EZD_FOLDER +
    PathDelim;
end;

procedure RemoveLayerFiles(const AFolder: string);
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(AFolder);
  RemoveDirectoryTree(ExcludeTrailingPathDelimiter(EzdFolderOf(AFolder)));
  DeleteFile(Dir + SYNTHESIS_SLICES_FILE);
  DeleteFile(Dir + GEOMETRY_FILE);
  DeleteFile(Dir + SYNTHESIS_LASER_FILE);
end;

function ProtocolCopyFileName(const AFolder, ALetter: string): string;
begin
  Result := IncludeTrailingPathDelimiter(AFolder) +
    SYNTHESIS_PROTOCOLS_FOLDER + PathDelim + SafeFolderPart(ALetter) + '.pro';
end;

function WriteProtocolCopy(AProtocol: TProtocolModel; const ALetter,
  AFolder: string; out AErrorText: string): Boolean;
var
  Dir, FileName, WriteError: string;
begin
  Result := False;
  AErrorText := '';
  Dir := IncludeTrailingPathDelimiter(AFolder) + SYNTHESIS_PROTOCOLS_FOLDER +
    PathDelim;
  if not ForceDirectories(Dir) then
  begin
    AErrorText := 'Не удалось создать папку для протоколов:' + LineEnding + Dir;
    Exit;
  end;
  // это запись того, что выполнялось: пишем как есть, без новой проверки
  FileName := ProtocolCopyFileName(AFolder, ALetter);
  if not WriteUtf8TextFile(FileName, AProtocol.ToText, WriteError) then
  begin
    AErrorText := 'Не удалось записать протокол буквы "' + ALetter + '":' +
      LineEnding + FileName + LineEnding + WriteError;
    Exit;
  end;
  Result := True;
end;

function SaveSynthesisInfo(const AFolder, AArrayName, ASourceFolder: string;
  ALayerCount: Integer; ALetters: TStringList; ANow: TDateTime;
  out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := False;
  AErrorText := '';
  try
    Ini := TMemIniFile.Create(IncludeTrailingPathDelimiter(AFolder) +
      SYNTHESIS_INFO_FILE);
    try
      Ini.WriteString(INFO_SECTION, 'Program', 'LightOligo');
      if not Ini.ValueExists(INFO_SECTION, 'Created') then
        Ini.WriteString(INFO_SECTION, 'Created',
          FormatDateTime(DATE_TIME_FORMAT, ANow));
      Ini.WriteString(INFO_SECTION, 'ArrayName', AArrayName);
      Ini.WriteString(INFO_SECTION, 'SourceFolder', ASourceFolder);
      Ini.WriteInteger(INFO_SECTION, 'LayerCount', ALayerCount);
      Ini.WriteString(INFO_SECTION, 'Letters', ALetters.CommaText);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать ' + SYNTHESIS_INFO_FILE + ':' +
        LineEnding + E.Message;
  end;
end;

function SaveSynthesisStart(const AFolder: string; ANow: TDateTime;
  out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := False;
  AErrorText := '';
  if not DirectoryExists(AFolder) then
  begin
    AErrorText := 'Папка синтеза не найдена, запуск не записан:' + LineEnding +
      AFolder;
    Exit;
  end;
  try
    Ini := TMemIniFile.Create(IncludeTrailingPathDelimiter(AFolder) +
      SYNTHESIS_INFO_FILE);
    try
      Ini.WriteString(INFO_SECTION, 'Started', FormatDateTime(DATE_TIME_FORMAT, ANow));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать ' + SYNTHESIS_INFO_FILE + ':' +
        LineEnding + E.Message;
  end;
end;

function ReadSynthesisInfo(const AIniFile: string; out AInfo: TSynthesisInfo;
  out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := False;
  AInfo := Default(TSynthesisInfo);
  AErrorText := '';
  if not FileExists(AIniFile) then
  begin
    AErrorText := 'Файл синтеза не найден:' + LineEnding + AIniFile;
    Exit;
  end;
  try
    Ini := TMemIniFile.Create(AIniFile);
    try
      if not Ini.SectionExists(INFO_SECTION) then
      begin
        AErrorText := 'Это не файл синтеза (нет раздела [' + INFO_SECTION +
          ']):' + LineEnding + AIniFile;
        Exit;
      end;
      AInfo.ArrayName := Ini.ReadString(INFO_SECTION, 'ArrayName', '');
      AInfo.SourceFolder := Ini.ReadString(INFO_SECTION, 'SourceFolder', '');
      AInfo.LayerCount := Ini.ReadInteger(INFO_SECTION, 'LayerCount', 0);
      AInfo.Started := Ini.ValueExists(INFO_SECTION, 'Started');
    finally
      Ini.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := 'Не удалось прочитать ' + AIniFile + ':' + LineEnding +
        E.Message;
  end;
end;

function SaveSynthesisResult(const AFolder: string; AResult: TSynthesisResult;
  ANow: TDateTime; out AErrorText: string): Boolean;
const
  STATUS_NAMES: array[TSynthesisResult] of string =
    ('completed', 'stopped', 'failed');
var
  Ini: TMemIniFile;
begin
  Result := False;
  AErrorText := '';
  // TMemIniFile сам создаёт недостающие папки, а итог пишется только в
  // существующую папку запуска
  if not DirectoryExists(AFolder) then
  begin
    AErrorText := 'Папка синтеза не найдена, итог не записан:' + LineEnding +
      AFolder;
    Exit;
  end;
  try
    Ini := TMemIniFile.Create(IncludeTrailingPathDelimiter(AFolder) +
      SYNTHESIS_INFO_FILE);
    try
      Ini.WriteString(RESULT_SECTION, 'Finished',
        FormatDateTime(DATE_TIME_FORMAT, ANow));
      Ini.WriteString(RESULT_SECTION, 'Status', STATUS_NAMES[AResult]);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать итог в ' + SYNTHESIS_INFO_FILE + ':' +
        LineEnding + E.Message;
  end;
end;

end.
