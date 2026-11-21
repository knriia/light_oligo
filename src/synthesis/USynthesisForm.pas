unit USynthesisForm;
// Вкладка «Синтез»: создание синтеза в слайсе проекта, загрузка слоёв и протоколов,
// запуск и остановка синтеза. Что загружено - в синтезе (SynthesisWorkspace:
// сессия и папка синтеза внутри слайса, куда всё пишется сразу), ход синтеза - в
// потоке (SynthesisThread и SynthesisRunner). Вкладка ничего не знает о
// главном окне: журнал, шприцевую станцию, создание слоёв (геометрия и EZD),
// текущий проект и запуск наблюдателя за окнами EzCAD ей передаёт владелец.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, IniFiles,
  OligoSlices, SynthesisSession, SynthesisWorkspace, SynthesisThread,
  SynthesisFolder, SynthesisPorts, ProtocolFormat, ProtocolModel;

type
  TSynthesisLogEvent = procedure(const AMsg: string) of object;
  // Папка открытого проекта (проект, открытый на вкладке последовательностей);
  // пусто - проект не открыт.
  TSynthesisProjectEvent = function: string of object;

  { TSynthesisForm }

  TSynthesisForm = class(TForm)
    B_NewSynthesis: TButton;
    B_OpenSynthesis: TButton;
    B_Geometry: TButton;
    B_LaserParams: TButton;
    B_LoadLayers: TButton;
    B_RemoveSelected: TButton;
    B_LoadProtToSynth: TButton;
    B_Pause: TButton;
    B_Start: TButton;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    OD_File: TOpenDialog;
    TV_Synthesis: TTreeView;
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_RemoveSelectedClick(Sender: TObject);
    procedure B_NewSynthesisClick(Sender: TObject);
    procedure B_OpenSynthesisClick(Sender: TObject);
    procedure B_GeometryClick(Sender: TObject);
    procedure B_LaserParamsClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
  private
    FWorkspace: TSynthesisWorkspace;      // слои и протоколы синтеза и его папка
    FThread: TSynthesisThread;            // nil, пока синтез не идёт
    FHost: TSynthesisHost;                // связь потока с окнами
    FStation: TSyringeStation;
    FMarker: TLayerMarker;
    FLayersBuilder: TLayersBuilder;
    FOnGetProjectDir: TSynthesisProjectEvent;
    FOnEditLaserParams: TNotifyEvent;
    FOnLog: TSynthesisLogEvent;
    FOnCheckSyringeStep: TSyringeStepCheck;
    FOnClearLog: TNotifyEvent;
    function Running: Boolean;
    // Расхождения SyrSt всех протоколов синтеза с конфигурацией дозаторов.
    function ProtocolsConfigReport: string;
    procedure ThreadFinished(Sender: TObject);
    procedure RebuildTree;
    // Папка открытого проекта или пусто.
    function OpenProjectDir: string;
    // Выбор проекта в корне projects; пусто - отказ или это не проект.
    function ChooseProjectDir: string;
    // Выбор слайса в проекте (окно со списком); пусто - отказ или слайсов нет.
    function ChooseSliceFolder(const AProjectDir: string): string;
    // Создание слоёв синтеза из слайса, в папке которого лежит синтез.
    procedure LoadLayersFromSlice;
    procedure Log(const AText: string);
    procedure SetOnEditLaserParams(AValue: TNotifyEvent);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Перед закрытием программы: идущий синтез останавливаем только с согласия.
    function CanCloseFromHost: Boolean;
    // Как кнопки вкладки; вызываются из главного меню.
    procedure NewSynthesis;
    // False - синтез идёт или файл не открылся.
    function OpenSynthesisFile(const AFileName: string): Boolean;
    property Station: TSyringeStation read FStation write FStation;
    property Marker: TLayerMarker read FMarker write FMarker;
    // Геометрия и EZD слоёв; без него слои создать и показать нельзя.
    property LayersBuilder: TLayersBuilder read FLayersBuilder
      write FLayersBuilder;
    // Открытый проект: слайс для синтеза выбирают в нём; нет события - проект выбирают.
    property OnGetProjectDir: TSynthesisProjectEvent read FOnGetProjectDir
      write FOnGetProjectDir;
    // Параметры лазера (перо), с которыми создаются EZD; без события кнопка
    // недоступна.
    property OnEditLaserParams: TNotifyEvent read FOnEditLaserParams
      write SetOnEditLaserParams;
    property OnLog: TSynthesisLogEvent read FOnLog write FOnLog;
    // Сверка SyrSt протоколов с конфигурацией дозаторов при запуске синтеза.
    property OnCheckSyringeStep: TSyringeStepCheck
      read FOnCheckSyringeStep write FOnCheckSyringeStep;
    // Перед запуском синтеза владелец очищает журнал.
    property OnClearLog: TNotifyEvent read FOnClearLog write FOnClearLog;
  end;

implementation

{$R *.lfm}

uses
  AppPaths, UChoiceForm;

const
  // Node.Data узла дерева: протокол - его номер + 1, слои - эта метка
  TREE_LAYERS_MARK = -1;

type
  // Передаёт потоку журнал и порты из окна синтеза.
  TFormHost = class(TSynthesisHost)
  private
    FForm: TSynthesisForm;
  public
    constructor Create(AForm: TSynthesisForm);
    procedure WriteLog(const AText: string); override;
    function Station: TSyringeStation; override;
    function Marker: TLayerMarker; override;
  end;

constructor TFormHost.Create(AForm: TSynthesisForm);
begin
  inherited Create;
  FForm := AForm;
end;

procedure TFormHost.WriteLog(const AText: string);
begin
  FForm.Log(AText);
end;

function TFormHost.Station: TSyringeStation;
begin
  Result := FForm.FStation;
end;

function TFormHost.Marker: TLayerMarker;
begin
  Result := FForm.FMarker;
end;

{ TSynthesisForm }

constructor TSynthesisForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  B_LaserParams.Enabled := False;
  FWorkspace := TSynthesisWorkspace.Create;
  FHost := TFormHost.Create(Self);
end;

destructor TSynthesisForm.Destroy;
begin
  // идущий синтез останавливаем и дожидаемся завершения: адаптеры оборудования
  // принадлежат главному окну и не должны освобождаться раньше потока.
  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FThread := nil;
  end;
  FreeAndNil(FWorkspace);
  inherited Destroy;
end;

procedure TSynthesisForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_SynthControl.Caption := AIni.ReadString('Synthesis', 'GB_SynthControl', 'Synthesis Control');
  GB_Files.Caption := AIni.ReadString('Synthesis', 'GB_Files', 'Synthesis Tree');
  B_LoadProtToSynth.Caption := AIni.ReadString('Synthesis', 'B_LoadProtToSynth', 'Load Protocol');
  B_LoadLayers.Caption := AIni.ReadString('Synthesis', 'B_LoadLayers', 'Load Layers');
  B_RemoveSelected.Caption := AIni.ReadString('Synthesis', 'B_RemoveSelected', 'Remove Selected');
  B_NewSynthesis.Caption := AIni.ReadString('Synthesis', 'B_NewSynthesis', 'New Synthesis');
  B_OpenSynthesis.Caption := AIni.ReadString('Synthesis', 'B_OpenSynthesis', 'Open');
  B_Geometry.Caption := AIni.ReadString('Synthesis', 'B_Geometry', 'Geometry');
  B_LaserParams.Caption := AIni.ReadString('Synthesis', 'B_LaserParams', 'Laser parameters');
  B_Start.Caption := AIni.ReadString('Synthesis', 'B_Start', 'Start');
  B_Pause.Caption := AIni.ReadString('Synthesis', 'B_Pause', 'Pause');
end;

function TSynthesisForm.Running: Boolean;
// один источник: идёт ли синтез, знает workspace (папку менять нельзя)
begin
  Result := FWorkspace.Running;
end;

procedure TSynthesisForm.Log(const AText: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AText);
end;

procedure TSynthesisForm.ThreadFinished(Sender: TObject);
// Поток закончил работу (сам освободится): синтез можно менять и запускать снова
begin
  FThread := nil;
  FWorkspace.FinishRun;
end;

function TSynthesisForm.CanCloseFromHost: Boolean;
begin
  Result := True;
  if Running then
    Result := MessageDlg('Синтез идёт. Остановить его и закрыть программу?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  if Result and (FThread <> nil) then
    FThread.Terminate;
end;

procedure TSynthesisForm.RebuildTree;
// Дерево синтеза: папка, протоколы и слои так, как они сейчас в синтезе
var
  Root, Node: TTreeNode;
  Lines: TStringList;
  I, J: Integer;
  Session: TSynthesisSession;
  Letter: string;
begin
  Session := FWorkspace.Session;
  Lines := TStringList.Create;
  TV_Synthesis.Items.BeginUpdate;
  try
    TV_Synthesis.Items.Clear;
    if FWorkspace.Folder = '' then
      Exit;
    Root := TV_Synthesis.Items.Add(nil, 'Синтез: ' + FWorkspace.Folder);
    for I := 0 to Session.ProtocolCount - 1 do
    begin
      Letter := Session.ProtocolLetters[I];
      Node := TV_Synthesis.Items.AddChild(Root, Letter + '.pro');
      Node.Data := Pointer(PtrInt(I + 1));
      Lines.Text := Session.ProtocolOf(Letter).ToText;
      for J := 0 to Lines.Count - 1 do
        if Trim(Lines[J]) <> '' then
          TV_Synthesis.Items.AddChild(Node, Lines[J]);
      Node.Expand(True);
    end;
    if Session.LayerCount > 0 then
    begin
      Node := TV_Synthesis.Items.AddChild(Root, 'Слои: ' +
        IntToStr(Session.LayerCount));
      Node.Data := Pointer(PtrInt(TREE_LAYERS_MARK));
      for I := 0 to Session.LayerCount - 1 do
        TV_Synthesis.Items.AddChild(Node, IntToStr(Session.Layers[I].LayerNumber) +
          ' ' + Session.Layers[I].Letter + ' ' + Session.Layers[I].EZDFile);
    end;
    Root.Expand(False);
  finally
    TV_Synthesis.Items.EndUpdate;
    Lines.Free;
  end;
end;

function TSynthesisForm.OpenProjectDir: string;
begin
  Result := '';
  if Assigned(FOnGetProjectDir) then
    Result := FOnGetProjectDir();
end;

function TSynthesisForm.ChooseProjectDir: string;
// Диалог открывается в корне projects; проектом считается любая выбранная
// папка с файлом массива (.csv)
var
  Dialog: TSelectDirectoryDialog;
begin
  Result := '';
  ForceDirectories(ProjectsDir);
  Dialog := TSelectDirectoryDialog.Create(nil);
  try
    Dialog.Title := 'Проект, для которого создаётся синтез';
    Dialog.InitialDir := ProjectsDir;
    if not Dialog.Execute then
      Exit;
    Result := ExcludeTrailingPathDelimiter(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  if not IsProjectFolder(Result) then
  begin
    ShowMessage('Это не папка проекта: в ней нет файла массива (.csv).' +
      LineEnding + Result);
    Result := '';
  end;
end;

function TSynthesisForm.ChooseSliceFolder(const AProjectDir: string): string;
// Слайс выбирают из папок slice* проекта; синтез будет лежать внутри выбранного
var
  Folders: TStringArray;
  Items: TStringList;
  Index, I: Integer;
begin
  Result := '';
  Folders := ListSliceFolders(AProjectDir);
  if Length(Folders) = 0 then
  begin
    ShowMessage('В проекте нет слайса (папки slice со Slices.txt).' +
      LineEnding + 'Сначала выполните слайсинг массива на вкладке ' +
      '«Последовательности».');
    Exit;
  end;
  Items := TStringList.Create;
  try
    for I := 0 to High(Folders) do
      Items.Add(Folders[I]);
    Index := 0;
    if not ChooseFromList('Слайс для синтеза', 'Слайс в проекте:', Items,
      Index) then
      Exit;
    Result := IncludeTrailingPathDelimiter(AProjectDir) + Folders[Index];
  finally
    Items.Free;
  end;
end;

procedure TSynthesisForm.LoadLayersFromSlice;
// Слои берутся из слайса, внутри которого лежит синтез; отказ оставляет слои как были
var
  SliceFolder, ErrorText: string;
begin
  if FLayersBuilder = nil then
  begin
    ShowMessage('Создание слоёв не подключено.');
    Exit;
  end;
  SliceFolder := FWorkspace.SliceDir;
  case FWorkspace.AddLayers(FLayersBuilder, SliceFolder, ErrorText) of
    lbsBuilt:
      Log('Слои созданы: ' + IntToStr(FWorkspace.Session.LayerCount) +
        ', слайс ' + SliceFolder);
    lbsFailed:
      begin
        Log('ERROR: ' + ErrorText);
        ShowMessage(ErrorText);
      end;
  end;
  RebuildTree;
end;

procedure TSynthesisForm.B_NewSynthesisClick(Sender: TObject);
// Новый синтез: выбор слайса, синтез создаётся внутри его папки; затем слои
// из этого слайса, отказ оставляет синтез пустым
var
  ProjectDir, SliceDir, FolderName, ErrorText: string;
  NameOk: Boolean;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы создать новый.');
    Exit;
  end;
  ProjectDir := OpenProjectDir;
  if ProjectDir = '' then
    ProjectDir := ChooseProjectDir;
  if ProjectDir = '' then
    Exit;
  SliceDir := ChooseSliceFolder(ProjectDir);
  if SliceDir = '' then
    Exit;
  FolderName := FreeSynthesisFolderName(SliceDir, Now);
  repeat
    if not InputQuery('Создать синтез', 'Папка синтеза в слайсе' +
      LineEnding + SliceDir + LineEnding + 'Имя папки:', FolderName) then
      Exit;
    FolderName := Trim(FolderName);
    NameOk := CheckFileNamePart(FolderName, 'Имя папки', ErrorText) and
      CheckSynthesisFolderName(FolderName, ErrorText);
    if NameOk and (DirectoryExists(IncludeTrailingPathDelimiter(SliceDir) +
      FolderName) or FileExists(IncludeTrailingPathDelimiter(SliceDir) + FolderName)) then
    begin
      NameOk := False;
      ErrorText := 'Такая папка уже есть в слайсе: ' + FolderName;
    end;
    if not NameOk then
      ShowMessage(ErrorText);
  until NameOk;
  if not FWorkspace.CreateNew(IncludeTrailingPathDelimiter(SliceDir) + FolderName,
    Now, ErrorText) then
  begin
    ShowMessage(ErrorText);
    RebuildTree;
    Exit;
  end;
  Log('Синтез создан: ' + FWorkspace.Folder);
  RebuildTree;
  LoadLayersFromSlice;
end;

procedure TSynthesisForm.NewSynthesis;
begin
  B_NewSynthesisClick(nil);
end;

function TSynthesisForm.OpenSynthesisFile(const AFileName: string): Boolean;
// Открыть сохранённый синтез по его файлу synthesis.ini
var
  ErrorText: string;
begin
  Result := False;
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы открыть другой.');
    Exit;
  end;
  Result := FWorkspace.Open(AFileName, ErrorText);
  if Result then
    Log('Синтез открыт: ' + FWorkspace.Folder)
  else
    ShowMessage(ErrorText);
  RebuildTree;
end;

procedure TSynthesisForm.B_OpenSynthesisClick(Sender: TObject);
var
  StartDir: string;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы открыть другой.');
    Exit;
  end;
  StartDir := OpenProjectDir;
  if StartDir = '' then
    StartDir := FWorkspace.ProjectDir;
  if StartDir = '' then
    StartDir := ProjectsDir;
  OD_File.Filter := 'Файл синтеза|' + SYNTHESIS_INFO_FILE;
  OD_File.InitialDir := StartDir;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  OpenSynthesisFile(OD_File.FileName);
end;

procedure TSynthesisForm.B_GeometryClick(Sender: TObject);
// Геометрия слоёв синтеза - только просмотр
var
  ErrorText: string;
begin
  if (FLayersBuilder = nil) and (FWorkspace.Session.LayerCount > 0) then
  begin
    ShowMessage('Просмотр геометрии не подключён.');
    Exit;
  end;
  if not FWorkspace.ShowGeometry(FLayersBuilder, ErrorText) then
    ShowMessage(ErrorText);
end;

function TSynthesisForm.ProtocolsConfigReport: string;
var
  Session: TSynthesisSession;
  Letter, Report: string;
  I: Integer;
begin
  Result := '';
  Session := FWorkspace.Session;
  for I := 0 to Session.ProtocolCount - 1 do
  begin
    Letter := Session.ProtocolLetters[I];
    Report := Session.ProtocolOf(Letter).SyringeConfigReport(
      FOnCheckSyringeStep);
    if Report <> '' then
      Result := Result + 'Протокол ' + Letter + ':' + LineEnding + Report +
        LineEnding + LineEnding;
  end;
  Result := TrimRight(Result);
end;

procedure TSynthesisForm.B_LoadProtToSynthClick(Sender: TObject);
// Добавить протокол в синтез
var
  Letter, ErrorText, Errors: string;
  FileNames: TStringList;
  I: Integer;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять протоколы.');
    Exit;
  end;
  if not FWorkspace.CheckEditable(ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  OD_File.Filter := 'Протокол|*.pro';
  OD_File.InitialDir := ProtocolsDir;
  OD_File.FileName := '';
  FileNames := TStringList.Create;
  try
    OD_File.Options := OD_File.Options + [ofAllowMultiSelect];
    try
      if not OD_File.Execute then
        Exit;
      FileNames.Assign(OD_File.Files);
      FileNames.Sort;
    finally
      OD_File.Options := OD_File.Options - [ofAllowMultiSelect];
    end;
    Errors := '';
    for I := 0 to FileNames.Count - 1 do
      if FWorkspace.AddProtocolFile(FileNames[I], Letter, ErrorText) then
        Log('Протокол для буквы ' + Letter + ' загружен: ' + FileNames[I])
      else
        Errors := Errors + ErrorText + LineEnding;
    RebuildTree;
    if Errors <> '' then
      ShowMessage(Trim(Errors));
  finally
    FileNames.Free;
  end;
end;

procedure TSynthesisForm.B_RemoveSelectedClick(Sender: TObject);
// Убрать из синтеза выбранный протокол или все слои (узел или его потомок)
var
  Node: TTreeNode;
  Mark: PtrInt;
  Letter, Question, ErrorText: string;
  I: Integer;
  HasLayersOfLetter: Boolean;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять состав синтеза.');
    Exit;
  end;
  if not FWorkspace.CheckEditable(ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  Node := TV_Synthesis.Selected;
  while (Node <> nil) and (Node.Level > 1) do
    Node := Node.Parent;
  if (Node = nil) or (Node.Level <> 1) then
  begin
    ShowMessage('Выберите в дереве протокол или слои.');
    Exit;
  end;
  Mark := PtrInt(Node.Data);
  if Mark = TREE_LAYERS_MARK then
  begin
    Question := 'Убрать из синтеза все слои? EZD-файлы слоёв будут удалены ' +
      'из папки синтеза.';
    if MessageDlg(Question, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
    if not FWorkspace.RemoveLayers(ErrorText) then
      ShowMessage(ErrorText)
    else
      Log('Слои убраны из синтеза');
  end
  else
  begin
    if (Mark < 1) or (Mark > FWorkspace.Session.ProtocolCount) then
      Exit;
    Letter := FWorkspace.Session.ProtocolLetters[Mark - 1];
    Question := 'Убрать из синтеза протокол ' + Letter + '.pro?';
    HasLayersOfLetter := False;
    for I := 0 to FWorkspace.Session.LayerCount - 1 do
      if FWorkspace.Session.Layers[I].Letter = Letter then
        HasLayersOfLetter := True;
    if HasLayersOfLetter then
      Question := Question + LineEnding + 'Слои с буквой ' + Letter +
        ' останутся без протокола, синтез нельзя будет запустить.';
    if MessageDlg(Question, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
    if not FWorkspace.RemoveProtocol(Letter, ErrorText) then
    begin
      ShowMessage(ErrorText);
      RebuildTree;
      Exit;
    end;
    Log('Протокол ' + Letter + ' убран из синтеза');
  end;
  RebuildTree;
end;

procedure TSynthesisForm.B_LoadLayersClick(Sender: TObject);
// Слои в созданный синтез: слайс, в папке которого лежит синтез, геометрия, EZD
var
  ErrorText: string;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять слои.');
    Exit;
  end;
  if not FWorkspace.CheckEditable(ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  if FWorkspace.Session.LayerCount > 0 then
  begin
    ShowMessage('Слои уже загружены. Чтобы загрузить другие, сначала ' +
      'уберите слои из синтеза.');
    Exit;
  end;
  LoadLayersFromSlice;
end;

procedure TSynthesisForm.B_StartClick(Sender: TObject);
// Запуск синтеза: только созданного, со слоями и протоколами
var
  I: Integer;
  ErrorText: string;
  Snapshot: TSynthesisSnapshot;
  Session: TSynthesisSession;
begin
  if Running then
  begin
    ShowMessage('Синтез уже идёт.');
    Exit;
  end;
  // протоколы должны соответствовать конфигурации дозаторов
  ErrorText := ProtocolsConfigReport;
  if ErrorText <> '' then
  begin
    ShowMessage('Протоколы не соответствуют конфигурации дозаторов:' +
      LineEnding + LineEnding + ErrorText);
    Exit;
  end;
  // проверка, что синтез создан, есть слои и протоколы на все буквы
  if not FWorkspace.PrepareStart(Now, Snapshot, ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  try
    if Assigned(FOnClearLog) then
      FOnClearLog(Self);
    Session := FWorkspace.Session;
    for I := 0 to Session.ProtocolCount - 1 do
      Log(Session.ProtocolLetters[I]);
    Log('Число слоев=' + IntToStr(Session.LayerCount));
    Log('Первыйслой=' + IntToStr(Session.Layers[0].LayerNumber) + ' ' +
      Session.Layers[0].EZDFile);
    Log('Последний слой=' +
      IntToStr(Session.Layers[Session.LayerCount - 1].LayerNumber) + ' ' +
      Session.Layers[Session.LayerCount - 1].EZDFile);
    Log('Папка синтеза: ' + Snapshot.Folder);

    FThread := TSynthesisThread.Create(Session, FHost, Snapshot);
    FThread.OnTerminate := @ThreadFinished;
    FThread.Start;
  except
    // поток не пошёл: ThreadFinished не придёт, снимаем признак «идёт» сами
    FThread := nil;
    FWorkspace.FinishRun;
    raise;
  end;
end;

procedure TSynthesisForm.SetOnEditLaserParams(AValue: TNotifyEvent);
begin
  FOnEditLaserParams := AValue;
  B_LaserParams.Enabled := Assigned(FOnEditLaserParams);
end;

procedure TSynthesisForm.B_LaserParamsClick(Sender: TObject);
// Параметры лазера - только когда синтез не идёт: с ними создаются EZD
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять параметры лазера.');
    Exit;
  end;
  if Assigned(FOnEditLaserParams) then
    FOnEditLaserParams(Self);
end;

procedure TSynthesisForm.B_PauseClick(Sender: TObject);
begin
  if FThread <> nil then
    FThread.Terminate;
  Log('Synthesis aborted');
end;

end.
