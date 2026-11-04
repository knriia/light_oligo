unit SynthesisWorkspace;
// Синтез, который собирает оператор: сессия (что загружено) и его папка на
// диске. Пока синтез не сохранён, файлы только загружены из исходных мест.
// «Сохранить» копирует слои и протоколы в папку синтеза и записывает файл
// синтеза synthesis.ini; дальше сессия работает с копиями, поэтому синтез не
// зависит от исходных файлов. «Открыть» загружает сохранённый синтез. Запуск
// возможен только для сохранённого и неизменённого синтеза; после запуска его
// папка - запись того, что выполнялось, и не перезаписывается: изменённый или
// повторно запускаемый синтез сохраняется в другую папку.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoSlices, SynthesisSession, SynthesisFolder;

type
  TSynthesisWorkspace = class
  private
    FSession: TSynthesisSession;
    FFolder: string;          // пусто, пока синтез не сохранён и не открыт
    FArrayName: string;       // по исходным слоям, не по копиям
    FSourceFolder: string;
    FLayersStored: Boolean;   // слои сессии - копии в папке синтеза
    FDirty: Boolean;          // изменён после сохранения (или не сохранён)
    FStarted: Boolean;
    function GetNeedsSave: Boolean;
    function StoreFiles(const ATarget: string; ASameFolder: Boolean;
      ANow: TDateTime; out ACopies: TSliceLayers;
      out AErrorText: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // Добавляет протокол в сессию (проверяет его). Ошибка - False, текст
    // объясняет, что не сделано; ничего не меняется.
    function AddProtocolFile(const AFileName: string; out ALetter,
      AErrorText: string): Boolean;
    // Слои из файла Slices.lays; уже загруженные заменяются.
    function AddLayersFile(const AFileName: string;
      out AErrorText: string): Boolean;
    // Слои после нарезки массива (пустая таблица - массив сброшен).
    procedure ReplaceLayers(const ALayers: TSliceLayers);

    // Копирует слои и протоколы в AFolder и пишет файл синтеза. Папка должна
    // быть новой или пустой; свою прежнюю папку можно сохранить поверх, если
    // синтез не запускался. Ошибка - False, текст объясняет, что не сделано.
    function Save(const AFolder: string; ANow: TDateTime;
      out AErrorText: string): Boolean;
    // Загружает сохранённый синтез по его файлу synthesis.ini.
    function Open(const AIniFile: string; out AErrorText: string): Boolean;
    // Готовит запуск: синтез сохранён, не менялся, не запускался, слои и
    // протоколы на месте. ASnapshot - папка и слои-копии для хода синтеза.
    function PrepareStart(ANow: TDateTime; out ASnapshot: TSynthesisSnapshot;
      out AErrorText: string): Boolean;
    // Очищает загруженное; сохранённые файлы остаются на диске.
    procedure NewSynthesis;

    property Session: TSynthesisSession read FSession;
    // Папка сохранённого синтеза; пусто, пока он не сохранён.
    property Folder: string read FFolder;
    property Started: Boolean read FStarted;
    // Есть загруженное, чего нет в сохранённой папке.
    property NeedsSave: Boolean read GetNeedsSave;
  end;

implementation

constructor TSynthesisWorkspace.Create;
begin
  inherited Create;
  FSession := TSynthesisSession.Create;
end;

destructor TSynthesisWorkspace.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

function TSynthesisWorkspace.GetNeedsSave: Boolean;
begin
  Result := FDirty and ((FSession.LayerCount > 0) or (FSession.ProtocolCount > 0));
end;

function TSynthesisWorkspace.AddProtocolFile(const AFileName: string;
  out ALetter, AErrorText: string): Boolean;
begin
  Result := FSession.AddProtocolFile(AFileName, ALetter, AErrorText);
  if Result then
    FDirty := True;
end;

function TSynthesisWorkspace.AddLayersFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  Loaded: TSliceLayers;
begin
  Result := LoadSliceLayers(AFileName, Loaded, AErrorText);
  if Result then
    ReplaceLayers(Loaded);
end;

procedure TSynthesisWorkspace.ReplaceLayers(const ALayers: TSliceLayers);
begin
  FSession.SetLayers(ALayers);
  FLayersStored := False;
  FDirty := True;
  if Length(ALayers) > 0 then
  begin
    FArrayName := ArrayNameOfLayers(ALayers);
    FSourceFolder := ExtractFileDir(ALayers[0].EZDFile);
  end
  else
  begin
    FArrayName := '';
    FSourceFolder := '';
  end;
end;

function TSynthesisWorkspace.StoreFiles(const ATarget: string;
  ASameFolder: Boolean; ANow: TDateTime; out ACopies: TSliceLayers;
  out AErrorText: string): Boolean;
// Слои, протоколы и файл синтеза - в папку ATarget
var
  Letters: TStringList;
  I: Integer;
  Letter, SlicesFile: string;
begin
  Result := False;
  ACopies := nil;
  SlicesFile := IncludeTrailingPathDelimiter(ATarget) + SYNTHESIS_SLICES_FILE;
  if FSession.LayerCount > 0 then
  begin
    if ASameFolder and FLayersStored then
      ACopies := Copy(FSession.Layers)       // уже лежат в этой папке
    else
    begin
      if ASameFolder then
        RemoveDirectoryTree(LayersFolderOf(ATarget));
      if not CopyLayersToFolder(FSession.Layers, ATarget, ACopies,
        AErrorText) then
        Exit;
    end;
    if not SaveSliceStatistics(ATarget, ACopies, SLICES_EZD_FILE,
      AErrorText) then
      Exit;
  end
  else
  begin
    RemoveDirectoryTree(LayersFolderOf(ATarget));
    DeleteFile(SlicesFile);
  end;

  RemoveDirectoryTree(IncludeTrailingPathDelimiter(ATarget) +
    SYNTHESIS_PROTOCOLS_FOLDER);
  Letters := TStringList.Create;
  try
    for I := 0 to FSession.ProtocolCount - 1 do
    begin
      Letter := FSession.ProtocolLetters[I];
      if not WriteProtocolCopy(FSession.ProtocolOf(Letter), Letter, ATarget,
        AErrorText) then
        Exit;
      Letters.Add(Letter);
    end;
    Result := SaveSynthesisInfo(ATarget, FArrayName, FSourceFolder,
      FSession.LayerCount, Letters, ANow, AErrorText);
  finally
    Letters.Free;
  end;
end;

function TSynthesisWorkspace.Save(const AFolder: string; ANow: TDateTime;
  out AErrorText: string): Boolean;
var
  Target: string;
  Copies: TSliceLayers;
  SameFolder, CreatedNew: Boolean;
  Search: TSearchRec;
  NotEmpty: Boolean;
begin
  Result := False;
  AErrorText := '';
  Target := ExcludeTrailingPathDelimiter(AFolder);
  if (FSession.LayerCount = 0) and (FSession.ProtocolCount = 0) then
  begin
    AErrorText := 'Нечего сохранять: загрузите слои или протоколы.';
    Exit;
  end;
  if Target = '' then
  begin
    AErrorText := 'Не указана папка синтеза.';
    Exit;
  end;
  SameFolder := (FFolder <> '') and SameText(Target, FFolder);
  if SameFolder and FStarted then
  begin
    AErrorText := 'Синтез уже запускался, его папка - запись выполненного и ' +
      'не перезаписывается. Сохраните синтез в другую папку.';
    Exit;
  end;
  if not SameFolder and DirectoryExists(Target) then
  begin
    NotEmpty := False;
    if FindFirst(Target + PathDelim + '*', faAnyFile, Search) = 0 then
    try
      repeat
        if (Search.Name <> '.') and (Search.Name <> '..') then
          NotEmpty := True;
      until NotEmpty or (FindNext(Search) <> 0);
    finally
      FindClose(Search);
    end;
    if NotEmpty then
    begin
      AErrorText := 'Папка уже существует и не пуста, синтез не сохранён:' +
        LineEnding + Target;
      Exit;
    end;
  end;
  CreatedNew := not DirectoryExists(Target);
  if not ForceDirectories(Target) then
  begin
    AErrorText := 'Не удалось создать папку синтеза:' + LineEnding + Target;
    Exit;
  end;
  if not StoreFiles(Target, SameFolder, ANow, Copies, AErrorText) then
  begin
    AErrorText := 'Синтез не сохранён.' + LineEnding + AErrorText;
    if CreatedNew then
      RemoveDirectoryTree(Target);
    Exit;
  end;
  if FSession.LayerCount > 0 then
    FSession.SetLayers(Copies);
  FFolder := Target;
  FLayersStored := True;
  FDirty := False;
  FStarted := False;
  Result := True;
end;

function TSynthesisWorkspace.Open(const AIniFile: string;
  out AErrorText: string): Boolean;
var
  Info: TSynthesisInfo;
  SynthFolder, SlicesFile, Letter: string;
  Layers: TSliceLayers;
  Search: TSearchRec;
  Names: TStringList;
  I: Integer;
begin
  Result := False;
  if not ReadSynthesisInfo(AIniFile, Info, AErrorText) then
    Exit;
  SynthFolder := ExcludeTrailingPathDelimiter(ExtractFileDir(AIniFile));
  NewSynthesis;
  Names := TStringList.Create;
  try
    SlicesFile := IncludeTrailingPathDelimiter(SynthFolder) + SYNTHESIS_SLICES_FILE;
    if Info.LayerCount > 0 then
    begin
      if not LoadSliceLayers(SlicesFile, Layers, AErrorText) then
        Exit;
      FSession.SetLayers(Layers);
    end;
    if FindFirst(IncludeTrailingPathDelimiter(SynthFolder) +
      SYNTHESIS_PROTOCOLS_FOLDER + PathDelim + '*.pro', faAnyFile,
      Search) = 0 then
    try
      repeat
        if (Search.Attr and faDirectory) = 0 then
          Names.Add(Search.Name);
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    Names.Sort;
    for I := 0 to Names.Count - 1 do
      if not FSession.AddProtocolFile(IncludeTrailingPathDelimiter(SynthFolder) +
        SYNTHESIS_PROTOCOLS_FOLDER + PathDelim + Names[I], Letter,
        AErrorText) then
        Exit;
    FFolder := SynthFolder;
    FArrayName := Info.ArrayName;
    FSourceFolder := Info.SourceFolder;
    FLayersStored := True;
    FStarted := Info.Started;
    FDirty := False;
    Result := True;
  finally
    Names.Free;
    if not Result then
    begin
      NewSynthesis;
      AErrorText := 'Синтез не открыт.' + LineEnding + AErrorText;
    end;
  end;
end;

function TSynthesisWorkspace.PrepareStart(ANow: TDateTime;
  out ASnapshot: TSynthesisSnapshot; out AErrorText: string): Boolean;
begin
  Result := False;
  ASnapshot := Default(TSynthesisSnapshot);
  if not FSession.CheckReady(AErrorText) then
    Exit;
  if FFolder = '' then
  begin
    AErrorText := 'Синтез не сохранён. Нажмите «Сохранить»: слои и протоколы ' +
      'скопируются в папку синтеза, и синтез пойдёт по копиям.';
    Exit;
  end;
  if FDirty then
  begin
    AErrorText := 'Синтез изменён после сохранения. Нажмите «Сохранить».';
    Exit;
  end;
  if FStarted then
  begin
    AErrorText := 'Этот синтез уже запускался, его папка - запись ' +
      'выполненного. Сохраните синтез в другую папку и запустите его.';
    Exit;
  end;
  if not SaveSynthesisStart(FFolder, ANow, AErrorText) then
  begin
    AErrorText := 'Синтез не запущен.' + LineEnding + AErrorText;
    Exit;
  end;
  FStarted := True;
  ASnapshot.Folder := FFolder;
  ASnapshot.LogFile := IncludeTrailingPathDelimiter(FFolder) + SYNTHESIS_LOG_FILE;
  ASnapshot.Layers := Copy(FSession.Layers);
  Result := True;
end;

procedure TSynthesisWorkspace.NewSynthesis;
begin
  FSession.Clear;
  FFolder := '';
  FArrayName := '';
  FSourceFolder := '';
  FLayersStored := False;
  FDirty := False;
  FStarted := False;
end;

end.
