unit SynthesisFolder;
// Папка одного синтеза: data\syntheses\<имя>\. В неё копируются слои
// (EZD-файлы, layers\), протоколы букв (protocols\) и Slices.lays с путями к
// копиям, а файл синтеза synthesis.ini хранит, когда синтез сохранён, какой
// массив, сколько слоёв и какие буквы. При запуске в него дописывается время
// запуска, рядом пишется журнал log.txt, а при завершении - итог (завершён,
// остановлен или ошибка). Синтез идёт по копиям, поэтому папка - точная запись
// того, что выполнялось, даже если исходные файлы потом изменятся. Здесь
// отдельные действия над папкой; когда и что копировать, решает
// SynthesisWorkspace.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, OligoSlices, ProtocolModel;

const
  SYNTHESIS_INFO_FILE = 'synthesis.ini';
  SYNTHESIS_LOG_FILE = 'log.txt';
  SYNTHESIS_LAYERS_FOLDER = 'layers';
  SYNTHESIS_PROTOCOLS_FOLDER = 'protocols';
  SYNTHESIS_SLICES_FILE = 'Slices.lays';   // таблица слоёв с путями к копиям

type
  TSynthesisSnapshot = record
    Folder: string;
    LogFile: string;
    Layers: TSliceLayers;   // слои с путями к копиям EZD внутри папки
  end;

  TSynthesisResult = (srCompleted, srStopped, srFailed);

  // Что записано о синтезе в synthesis.ini (файл синтеза).
  TSynthesisInfo = record
    ArrayName: string;
    SourceFolder: string;   // откуда взяты слои
    LayerCount: Integer;
    Started: Boolean;       // синтез уже запускался
  end;

// Имя массива по папке слоёв: папка ezd или layers внутри папки массива -
// имя берётся от папки массива. Пусто - 'array'.
function ArrayNameOfLayers(const ALayers: TSliceLayers): string;
// Часть имени папки без символов, недопустимых в Windows, не длиннее 60.
function SafeFolderPart(const AText: string): string;
// <гггг-мм-дд>_<ччммсс>_<массив>; без массива - только дата и время
function SynthesisFolderName(const AArrayName: string; ANow: TDateTime): string;

// Удаляет папку со всем содержимым (нет папки - ничего не делает).
procedure RemoveDirectoryTree(const ADirectory: string);

// Папка с EZD-копиями слоёв внутри папки синтеза (с разделителем на конце).
function LayersFolderOf(const AFolder: string): string;

// Копирует EZD каждого слоя в AFolder\layers, один исходный файл - один раз.
// ACopies - те же слои с путями к копиям. Нет файла, не копируется, нет места -
// False, текст называет слой и файл.
function CopyLayersToFolder(const ALayers: TSliceLayers; const AFolder: string;
  out ACopies: TSliceLayers; out AErrorText: string): Boolean;

// Записывает протокол буквы в AFolder\protocols\<буква>.pro как есть.
function WriteProtocolCopy(AProtocol: TProtocolModel; const ALetter,
  AFolder: string; out AErrorText: string): Boolean;

// Записывает файл синтеза synthesis.ini: когда сохранён, массив, слои, буквы.
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
  TextFileUtils;

const
  INFO_SECTION = 'Synthesis';
  RESULT_SECTION = 'Result';
  DATE_TIME_FORMAT = 'yyyy-mm-dd hh:nn:ss';

function ArrayNameOfLayers(const ALayers: TSliceLayers): string;
var
  Dir, Leaf: string;
begin
  Result := 'array';
  if Length(ALayers) = 0 then
    Exit;
  Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ALayers[0].EZDFile));
  Leaf := ExtractFileName(Dir);
  if SameText(Leaf, 'ezd') or SameText(Leaf, SYNTHESIS_LAYERS_FOLDER) then
    Leaf := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(Dir)));
  if Leaf <> '' then
    Result := Leaf;
end;

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

function SynthesisFolderName(const AArrayName: string; ANow: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"_"hhnnss', ANow);
  if AArrayName <> '' then
    Result := Result + '_' + SafeFolderPart(AArrayName);
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

function CopyOneFile(const ASource, ADest: string; out AErrorText: string): Boolean;
var
  Source, Dest: TFileStream;
begin
  Result := False;
  AErrorText := '';
  try
    Source := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
    try
      Dest := TFileStream.Create(ADest, fmCreate);
      try
        Dest.CopyFrom(Source, 0);
      finally
        Dest.Free;
      end;
    finally
      Source.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := E.Message;
  end;
end;

// Свободное имя файла в папке: при совпадении добавляется _2, _3...
function FreeFileName(const ADir, AName: string): string;
var
  Base, Ext: string;
  N: Integer;
begin
  Result := AName;
  if not FileExists(ADir + Result) then
    Exit;
  Ext := ExtractFileExt(AName);
  Base := ChangeFileExt(AName, '');
  N := 2;
  repeat
    Result := Base + '_' + IntToStr(N) + Ext;
    Inc(N);
  until not FileExists(ADir + Result);
end;

function LayersFolderOf(const AFolder: string): string;
begin
  Result := IncludeTrailingPathDelimiter(AFolder) + SYNTHESIS_LAYERS_FOLDER +
    PathDelim;
end;

function CopyLayersToFolder(const ALayers: TSliceLayers; const AFolder: string;
  out ACopies: TSliceLayers; out AErrorText: string): Boolean;
var
  LayersDir, DestName, CopyError: string;
  Sources, Dests: TStringList;
  I, Index: Integer;
begin
  Result := False;
  ACopies := nil;
  AErrorText := '';
  LayersDir := LayersFolderOf(AFolder);
  if not ForceDirectories(LayersDir) then
  begin
    AErrorText := 'Не удалось создать папку для слоёв:' + LineEnding + LayersDir;
    Exit;
  end;
  SetLength(ACopies, Length(ALayers));
  Sources := TStringList.Create;
  Dests := TStringList.Create;
  try
    for I := 0 to High(ALayers) do
    begin
      ACopies[I] := ALayers[I];
      Index := Sources.IndexOf(ALayers[I].EZDFile);
      if Index >= 0 then
      begin
        ACopies[I].EZDFile := Dests[Index]; // тот же файл уже скопирован
        Continue;
      end;
      if not FileExists(ALayers[I].EZDFile) then
      begin
        AErrorText := 'Слой ' + IntToStr(ALayers[I].LayerNumber) +
          ': файл EZD не найден:' + LineEnding + ALayers[I].EZDFile;
        Exit;
      end;
      DestName := FreeFileName(LayersDir, ExtractFileName(ALayers[I].EZDFile));
      if not CopyOneFile(ALayers[I].EZDFile, LayersDir + DestName, CopyError) then
      begin
        AErrorText := 'Слой ' + IntToStr(ALayers[I].LayerNumber) +
          ': не удалось скопировать файл EZD:' + LineEnding +
          ALayers[I].EZDFile + LineEnding + CopyError;
        Exit;
      end;
      Sources.Add(ALayers[I].EZDFile);
      Dests.Add(LayersDir + DestName);
      ACopies[I].EZDFile := LayersDir + DestName;
    end;
  finally
    Dests.Free;
    Sources.Free;
  end;
  Result := True;
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
  FileName := Dir + SafeFolderPart(ALetter) + '.pro';
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
      Ini.WriteString(INFO_SECTION, 'Saved', FormatDateTime(DATE_TIME_FORMAT, ANow));
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
