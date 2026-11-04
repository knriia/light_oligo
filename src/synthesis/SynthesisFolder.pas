unit SynthesisFolder;
// Папка одного запуска синтеза: data\syntheses\<дата_время>_<массив>\.
// При старте в неё копируются слои (EZD-файлы) и протоколы букв, которые
// используются, записываются Slices.lays с путями к копиям и synthesis.ini
// (когда запущен, какой массив, сколько слоёв и какие буквы). Синтез идёт по
// копиям, поэтому папка - точная запись того, что выполнялось, даже если
// исходные файлы потом изменятся. Туда же пишется журнал log.txt, а при
// завершении - итог (завершён, остановлен или ошибка).

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, OligoSlices, ProtocolModel, SynthesisSession;

const
  SYNTHESIS_INFO_FILE = 'synthesis.ini';
  SYNTHESIS_LOG_FILE = 'log.txt';
  SYNTHESIS_LAYERS_FOLDER = 'layers';
  SYNTHESIS_PROTOCOLS_FOLDER = 'protocols';

type
  TSynthesisSnapshot = record
    Folder: string;
    LogFile: string;
    Layers: TSliceLayers;   // слои с путями к копиям EZD внутри папки
  end;

  TSynthesisResult = (srCompleted, srStopped, srFailed);

// Имя массива по папке слоёв: папка ezd или layers внутри папки массива -
// имя берётся от папки массива. Пусто - 'array'.
function ArrayNameOfLayers(const ALayers: TSliceLayers): string;
// Часть имени папки без символов, недопустимых в Windows, не длиннее 60.
function SafeFolderPart(const AText: string): string;
// <гггг-мм-дд>_<ччммсс>_<массив>
function SynthesisFolderName(const AArrayName: string; ANow: TDateTime): string;

// Создаёт папку запуска внутри ABaseDir и наполняет её копиями слоёв и
// протоколов. Ошибка (нет файла слоя, не копируется, нет места) - False,
// текст называет слой и файл, а недоделанная папка удаляется.
function CreateSynthesisSnapshot(ASession: TSynthesisSession;
  const ABaseDir: string; ANow: TDateTime; out ASnapshot: TSynthesisSnapshot;
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
  Result := FormatDateTime('yyyy-mm-dd"_"hhnnss', ANow) + '_' +
    SafeFolderPart(AArrayName);
end;

procedure RemoveTree(const ADirectory: string);
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
        RemoveTree(Dir + Search.Name)
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

function CopyLayers(const ALayers: TSliceLayers; const AFolder: string;
  out ACopies: TSliceLayers; out AErrorText: string): Boolean;
// EZD каждого слоя - в AFolder\layers; один исходный файл копируется один раз
var
  LayersDir, DestName, CopyError: string;
  Sources, Dests: TStringList;
  I, Index: Integer;
begin
  Result := False;
  ACopies := nil;
  AErrorText := '';
  LayersDir := IncludeTrailingPathDelimiter(AFolder) + SYNTHESIS_LAYERS_FOLDER +
    PathDelim;
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

// Буквы слоёв без повторов в порядке слоёв
function LettersOf(const ALayers: TSliceLayers): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(ALayers) do
    if Result.IndexOf(ALayers[I].Letter) < 0 then
      Result.Add(ALayers[I].Letter);
end;

function CopyProtocols(ASession: TSynthesisSession; ALetters: TStringList;
  const AFolder: string; out AErrorText: string): Boolean;
var
  Dir, FileName, WriteError: string;
  Protocol: TProtocolModel;
  I: Integer;
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
  for I := 0 to ALetters.Count - 1 do
  begin
    Protocol := ASession.ProtocolOf(ALetters[I]);
    if Protocol = nil then
    begin
      AErrorText := 'Нет протокола для буквы "' + ALetters[I] + '".';
      Exit;
    end;
    // это запись того, что выполнялось: пишем как есть, без новой проверки
    FileName := Dir + SafeFolderPart(ALetters[I]) + '.pro';
    if not WriteUtf8TextFile(FileName, Protocol.ToText, WriteError) then
    begin
      AErrorText := 'Не удалось записать протокол буквы "' + ALetters[I] +
        '":' + LineEnding + FileName + LineEnding + WriteError;
      Exit;
    end;
  end;
  Result := True;
end;

function WriteInfo(const AFolder, AArrayName, ASourceFolder: string;
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
      Ini.WriteString(INFO_SECTION, 'Started', FormatDateTime(DATE_TIME_FORMAT, ANow));
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

function CreateSynthesisSnapshot(ASession: TSynthesisSession;
  const ABaseDir: string; ANow: TDateTime; out ASnapshot: TSynthesisSnapshot;
  out AErrorText: string): Boolean;
var
  ArrayName, Name, Folder, StepError: string;
  Copies: TSliceLayers;
  Letters: TStringList;
  N: Integer;
begin
  Result := False;
  ASnapshot := Default(TSynthesisSnapshot);
  AErrorText := '';
  if ASession.LayerCount = 0 then
  begin
    AErrorText := 'Нет слоёв для синтеза.';
    Exit;
  end;
  ArrayName := ArrayNameOfLayers(ASession.Layers);
  Name := SynthesisFolderName(ArrayName, ANow);
  Folder := IncludeTrailingPathDelimiter(ABaseDir) + Name;
  N := 2;
  while DirectoryExists(Folder) do
  begin
    Folder := IncludeTrailingPathDelimiter(ABaseDir) + Name + '_' + IntToStr(N);
    Inc(N);
  end;
  if not ForceDirectories(Folder) then
  begin
    AErrorText := 'Не удалось создать папку синтеза:' + LineEnding + Folder;
    Exit;
  end;

  Letters := LettersOf(ASession.Layers);
  try
    if CopyLayers(ASession.Layers, Folder, Copies, StepError) and
       CopyProtocols(ASession, Letters, Folder, StepError) and
       SaveSliceStatistics(Folder, Copies, SLICES_EZD_FILE, StepError) and
       WriteInfo(Folder, ArrayName,
         ExtractFileDir(ASession.Layers[0].EZDFile), ASession.LayerCount,
         Letters, ANow, StepError) then
    begin
      ASnapshot.Folder := Folder;
      ASnapshot.LogFile := IncludeTrailingPathDelimiter(Folder) +
        SYNTHESIS_LOG_FILE;
      ASnapshot.Layers := Copies;
      Result := True;
    end
    else
    begin
      AErrorText := 'Синтез не запущен: не удалось подготовить папку ' +
        'синтеза.' + LineEnding + StepError;
      RemoveTree(Folder); // недоделанная папка не нужна
    end;
  finally
    Letters.Free;
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
