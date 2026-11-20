unit SynthesisWorkspace;
// Синтез, который собирает оператор: сессия (что загружено) и его папка
// внутри слайса проекта. Папка создаётся вместе с синтезом, и всё, что оператор добавляет,
// сразу пишется в неё: протокол копируется в protocols\, слои создаются в
// ezd\ вместе с Slices.lays, геометрией и пером лазера, а synthesis.ini хранит
// состав. Поэтому состояние на диске всегда равно состоянию в окне, а синтез
// не зависит от исходных протоколов и слайса. «Открыть» загружает сохранённый
// синтез. Запуск возможен только для созданного синтеза; после запуска его
// папка - запись того, что выполнялось, и не изменяется.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoSlices, SynthesisSession, SynthesisFolder,
  SynthesisPorts;

type
  TSynthesisWorkspace = class
  private
    FSession: TSynthesisSession;
    FFolder: string;          // пусто, пока синтез не создан и не открыт
    FSourceFolder: string;    // папка слайса, из которого созданы слои
    FCreated: TDateTime;
    FStarted: Boolean;
    function GetProjectDir: string;
    function GetSliceDir: string;
    function SaveInfo(out AErrorText: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // Можно ли менять синтез: он создан и не запускался. Иначе False и текст.
    function CheckEditable(out AErrorText: string): Boolean;
    // Создаёт пустой синтез в новой папке AFolder (внутри папки слайса):
    // папка и synthesis.ini. Папка не должна существовать. Ошибка - False,
    // текст объясняет, что не сделано. Прежний синтез из окна убирается.
    function CreateNew(const AFolder: string; ANow: TDateTime;
      out AErrorText: string): Boolean;
    // Добавляет протокол в синтез (проверяет его) и сразу копирует в папку.
    // Ошибка - False, текст объясняет, что не сделано; ничего не меняется.
    function AddProtocolFile(const AFileName: string; out ALetter,
      AErrorText: string): Boolean;
    // Убирает протокол буквы из синтеза и его копию из папки.
    function RemoveProtocol(const ALetter: string;
      out AErrorText: string): Boolean;
    // Создаёт слои синтеза по слайсу ASliceFolder: геометрия и EZD в папке
    // синтеза. Слайс - только тот, в папке которого лежит синтез (SliceDir).
    // lbsBuilt - слои в
    // синтезе; lbsCancelled - оператор отказался, синтез не изменился;
    // lbsFailed - причина в AErrorText, файлы слоёв в папке убраны.
    function AddLayers(ABuilder: TLayersBuilder; const ASliceFolder: string;
      out AErrorText: string): TLayersBuildStatus;
    // Убирает все слои из синтеза и их файлы из папки (протоколы остаются).
    function RemoveLayers(out AErrorText: string): Boolean;
    // Показывает геометрию слоёв синтеза; нет слоёв - False и текст.
    function ShowGeometry(ABuilder: TLayersBuilder;
      out AErrorText: string): Boolean;

    // Загружает сохранённый синтез по его файлу synthesis.ini.
    function Open(const AIniFile: string; out AErrorText: string): Boolean;
    // Готовит запуск: синтез создан, не запускался, слои и протоколы на
    // месте, EZD-файлы слоёв есть на диске. ASnapshot - папка и слои для хода синтеза.
    function PrepareStart(ANow: TDateTime; out ASnapshot: TSynthesisSnapshot;
      out AErrorText: string): Boolean;
    // Закрывает синтез в окне; файлы остаются на диске.
    procedure NewSynthesis;

    property Session: TSynthesisSession read FSession;
    // Папка синтеза; пусто, пока синтез не создан и не открыт.
    property Folder: string read FFolder;
    // Папка слайса, внутри которой лежит синтез (родитель папки синтеза).
    property SliceDir: string read GetSliceDir;
    // Папка проекта синтеза (родитель папки слайса).
    property ProjectDir: string read GetProjectDir;
    // Папка слайса, из которого созданы слои; пусто, пока слоёв нет.
    property SourceFolder: string read FSourceFolder;
    property Started: Boolean read FStarted;
  end;

implementation

const
  NO_SYNTHESIS_TEXT = 'Синтез не создан. Нажмите «Создать синтез» или ' +
    '«Открыть».';
  STARTED_TEXT = 'Синтез уже запускался, его папка - запись выполненного и ' +
    'не изменяется. Создайте новый синтез.';

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

function TSynthesisWorkspace.GetProjectDir: string;
begin
  if FFolder = '' then
    Result := ''
  else
    Result := ExtractFileDir(GetSliceDir);
end;

function TSynthesisWorkspace.GetSliceDir: string;
begin
  if FFolder = '' then
    Result := ''
  else
    Result := ExtractFileDir(FFolder);
end;

function TSynthesisWorkspace.CheckEditable(out AErrorText: string): Boolean;
begin
  AErrorText := '';
  Result := False;
  if FFolder = '' then
    AErrorText := NO_SYNTHESIS_TEXT
  else if FStarted then
    AErrorText := STARTED_TEXT
  else
    Result := True;
end;

function TSynthesisWorkspace.SaveInfo(out AErrorText: string): Boolean;
var
  Letters: TStringList;
  I: Integer;
begin
  Letters := TStringList.Create;
  try
    for I := 0 to FSession.ProtocolCount - 1 do
      Letters.Add(FSession.ProtocolLetters[I]);
    Result := SaveSynthesisInfo(FFolder, ExtractFileName(GetProjectDir),
      FSourceFolder, FSession.LayerCount, Letters, FCreated, AErrorText);
  finally
    Letters.Free;
  end;
end;

function TSynthesisWorkspace.CreateNew(const AFolder: string; ANow: TDateTime;
  out AErrorText: string): Boolean;
var
  Target: string;
begin
  Result := False;
  AErrorText := '';
  Target := ExcludeTrailingPathDelimiter(AFolder);
  if Target = '' then
  begin
    AErrorText := 'Не указана папка синтеза.';
    Exit;
  end;
  if DirectoryExists(Target) or FileExists(Target) then
  begin
    AErrorText := 'Папка уже существует, синтез не создан:' + LineEnding +
      Target;
    Exit;
  end;
  if not ForceDirectories(Target) then
  begin
    AErrorText := 'Не удалось создать папку синтеза:' + LineEnding + Target;
    Exit;
  end;
  NewSynthesis;
  FFolder := Target;
  FCreated := ANow;
  if not SaveInfo(AErrorText) then
  begin
    RemoveDirectoryTree(Target);
    NewSynthesis;
    AErrorText := 'Синтез не создан.' + LineEnding + AErrorText;
    Exit;
  end;
  Result := True;
end;

function TSynthesisWorkspace.AddProtocolFile(const AFileName: string;
  out ALetter, AErrorText: string): Boolean;
var
  Stored: Boolean;
begin
  Result := False;
  ALetter := '';
  if not CheckEditable(AErrorText) then
    Exit;
  if not FSession.AddProtocolFile(AFileName, ALetter, AErrorText) then
    Exit;
  // протокол в синтезе только вместе с копией в папке
  Stored := WriteProtocolCopy(FSession.ProtocolOf(ALetter), ALetter, FFolder,
    AErrorText);
  if Stored then
    Stored := SaveInfo(AErrorText);
  if not Stored then
  begin
    FSession.RemoveProtocol(ALetter);
    DeleteFile(ProtocolCopyFileName(FFolder, ALetter));
    ALetter := '';
    Exit;
  end;
  Result := True;
end;

function TSynthesisWorkspace.RemoveProtocol(const ALetter: string;
  out AErrorText: string): Boolean;
var
  CopyFile: string;
begin
  Result := False;
  if not CheckEditable(AErrorText) then
    Exit;
  if not FSession.HasProtocol(ALetter) then
  begin
    AErrorText := 'Протокол ' + ALetter + ' не найден в синтезе.';
    Exit;
  end;
  CopyFile := ProtocolCopyFileName(FFolder, ALetter);
  if FileExists(CopyFile) and not DeleteFile(CopyFile) then
  begin
    AErrorText := 'Не удалось удалить копию протокола:' + LineEnding + CopyFile;
    Exit;
  end;
  FSession.RemoveProtocol(ALetter);
  Result := SaveInfo(AErrorText);
end;

function TSynthesisWorkspace.AddLayers(ABuilder: TLayersBuilder;
  const ASliceFolder: string; out AErrorText: string): TLayersBuildStatus;
var
  Layers: TSliceLayers;
  InfoError: string;
begin
  Result := lbsFailed;
  if not CheckEditable(AErrorText) then
    Exit;
  if FSession.LayerCount > 0 then
  begin
    AErrorText := 'Слои уже загружены. Чтобы загрузить другие, сначала ' +
      'уберите слои из синтеза.';
    Exit;
  end;
  if not SameText(ExcludeTrailingPathDelimiter(ExpandFileName(ASliceFolder)),
    ExcludeTrailingPathDelimiter(ExpandFileName(GetSliceDir))) then
  begin
    AErrorText := 'Синтез лежит в папке своего слайса, слои можно взять ' +
      'только из него:' + LineEnding + GetSliceDir;
    Exit;
  end;
  if not CheckSliceFolder(GetProjectDir, ASliceFolder, AErrorText) then
    Exit;
  Layers := nil;
  Result := ABuilder.Build(ASliceFolder, FFolder, Layers, AErrorText);
  if Result <> lbsBuilt then
  begin
    RemoveLayerFiles(FFolder);   // часть EZD могла быть создана
    Exit;
  end;
  FSession.SetLayers(Layers);
  FSourceFolder := ExcludeTrailingPathDelimiter(ASliceFolder);
  if not SaveInfo(InfoError) then
  begin
    FSession.ClearLayers;
    FSourceFolder := '';
    RemoveLayerFiles(FFolder);
    AErrorText := InfoError;
    Result := lbsFailed;
  end;
end;

function TSynthesisWorkspace.RemoveLayers(out AErrorText: string): Boolean;
begin
  Result := False;
  if not CheckEditable(AErrorText) then
    Exit;
  RemoveLayerFiles(FFolder);
  FSession.ClearLayers;
  FSourceFolder := '';
  Result := SaveInfo(AErrorText);
end;

function TSynthesisWorkspace.ShowGeometry(ABuilder: TLayersBuilder;
  out AErrorText: string): Boolean;
begin
  AErrorText := '';
  if FSession.LayerCount = 0 then
  begin
    AErrorText := 'Нет загруженных слоёв для просмотра геометрии.';
    Exit(False);
  end;
  Result := ABuilder.ShowGeometry(FSourceFolder, FFolder, AErrorText);
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
  if not FileExists(IncludeTrailingPathDelimiter(ExtractFileDir(SynthFolder)) +
    SLICE_STATISTICS_FILE) then
  begin
    AErrorText := 'Синтез лежит не в папке слайса (нет ' + SLICE_STATISTICS_FILE +
      ' в родительской папке). Перенесите папку синтеза внутрь папки слайса ' +
      '(например slices_base):' + LineEnding + SynthFolder;
    Exit;
  end;
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
    FSourceFolder := Info.SourceFolder;
    FCreated := Now;
    FStarted := Info.Started;
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
var
  I: Integer;
begin
  Result := False;
  ASnapshot := Default(TSynthesisSnapshot);
  if FFolder = '' then
  begin
    AErrorText := NO_SYNTHESIS_TEXT;
    Exit;
  end;
  if FStarted then
  begin
    AErrorText := 'Этот синтез уже запускался, его папка - запись ' +
      'выполненного. Создайте новый синтез и запустите его.';
    Exit;
  end;
  if not FSession.CheckReady(AErrorText) then
    Exit;
  for I := 0 to FSession.LayerCount - 1 do
    if not FileExists(FSession.Layers[I].EZDFile) then
    begin
      AErrorText := 'Слой ' + IntToStr(FSession.Layers[I].LayerNumber) +
        ': файл EZD не найден, синтез не запущен:' + LineEnding +
        FSession.Layers[I].EZDFile;
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
  FSourceFolder := '';
  FCreated := 0;
  FStarted := False;
end;

end.
