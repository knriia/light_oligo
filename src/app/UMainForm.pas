unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons, Menus, ActnList,
  DispenserLayout, Localization, AppComposition, AppPaths, ProjectModel,
  SynthesisFolder, OligoArrayDocument, UArraySaveForm, UChoiceForm,
  UDocumentHost, UProjectPanel, UiIcons, UiIconNames, UiTheme;


type

  { TMainForm }

  TMainForm = class(TForm)
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Panel_Log: TPanel;
    Splitter_Log: TSplitter;
    Tmr_EzCADer: TTimer;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FComposition: TAppComposition;
    FHost: TDocumentHost;
    FHolder: TPanel;
    FActions: TActionList;
    FMenu: TMainMenu;
    FActNewProject, FActNewSequence, FActNewSlicing, FActNewSynthesis, FActNewProtocol,
      FActOpen, FActSave, FActExit: TAction;
    FActTabSequences, FActTabSynthesis, FActTabProtocol, FActTabManual,
      FActTabLog: TAction;
    FActLaserParams: TAction;
    FActOpenProject, FActCloseProject, FActRefreshProject: TAction;
    FProjectPanel: TProjectPanel;
    FProjectSplitter: TSplitter;
    FSynthesisProjectDir: string;  // проект, выбранный для создания синтеза
    procedure BuildProjectPanel;
    procedure BuildHost;
    procedure RegisterDocuments;
    function SynthesisProjectDir: string;
    function ChooseProject(const ANeedKey, ANeedDefault: string): TProject;
    function EnsureArrayOpen(AProject: TProject): Boolean;
    procedure ProjectItemOpen(AKind: TProjectNodeKind; const APath: string);
    procedure RefreshProjectTree;
    procedure ActOpenProjectExecute(Sender: TObject);
    procedure ActCloseProjectExecute(Sender: TObject);
    procedure ActRefreshProjectExecute(Sender: TObject);
    function NewAction(const AKey, ADefault, AIcon: string;
      AHandler: TNotifyEvent): TAction;
    function AddMenu(AParent: TMenuItem; const AKey, ADefault: string): TMenuItem;
    procedure AddItem(AParent: TMenuItem; AAction: TAction);
    procedure BuildMenu;
    procedure ActionsUpdate(AAction: TBasicAction; var Handled: Boolean);
    procedure ActNewProjectExecute(Sender: TObject);
    procedure ActNewSequenceExecute(Sender: TObject);
    procedure ActNewSlicingExecute(Sender: TObject);
    procedure ActNewSynthesisExecute(Sender: TObject);
    procedure ActNewProtocolExecute(Sender: TObject);
    procedure ActOpenExecute(Sender: TObject);
    procedure ActSaveExecute(Sender: TObject);
    procedure ActExitExecute(Sender: TObject);
    procedure ActTabExecute(Sender: TObject);
    procedure ActLaserParamsExecute(Sender: TObject);
    procedure SynthesisClearLog(Sender: TObject);
    procedure SequencesLog(const AMsg: string);
    procedure UpdateManualControlsWidth;
    procedure UpdateMinimumWindowWidth;
    procedure DispenserStationLogMessage(Sender: TObject; const Msg: string);
  public
    destructor Destroy; override;
    // Синтез запустил EzCAD: закрывать его окна лицензии и предупреждений.
    procedure StartEzCadWatcher;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  STATION_PANEL_CHROME = 24;

{ TMainForm }

{ОБЩИЕ ПОДПРОГРАММЫ}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // невидимый контейнер для форм, пока у них нет вкладки
  BuildHost;
  FComposition := TAppComposition.Create(Self, FHolder, @SequencesLog,
    @SequencesLog, @SequencesLog, @SequencesLog,
    @SynthesisClearLog, @DispenserStationLogMessage, @StartEzCadWatcher);
  // данные, папки и настройки программы
  FComposition.Initialize;

  MainForm.Caption:=ReadInterfaceString('Main','MainForm','LightOligo');

  // формы вкладок, адаптеры и связи между ними
  FComposition.Build;
  RegisterDocuments;
  FComposition.SynthesisForm.OnGetProjectDir := @SynthesisProjectDir;
  BuildProjectPanel;
  BuildMenu;
  Randomize();
  UpdateMinimumWindowWidth();
  UpdateManualControlsWidth();
end;

procedure TMainForm.BuildHost;
begin
  FHolder := TPanel.Create(Self);
  FHolder.Parent := Self;
  FHolder.Visible := False;
  FHolder.SetBounds(0, 0, 800, 500);
  FHost := TDocumentHost.Create(PageControl1, FHolder);
end;

procedure TMainForm.RegisterDocuments;
// вкладка появляется, когда форму открывают; подписи - из раздела [Main]
begin
  FHost.Register(FComposition.SequencesForm,
    ReadInterfaceString('Main','TS_Sequences','Sequence'),
    @FComposition.SequencesForm.CanCloseFromHost);
  FHost.Register(FComposition.SynthesisForm,
    ReadInterfaceString('Main','TS_Synthesis','Synthesis'), nil);
  FHost.Register(FComposition.ProtocolForm,
    ReadInterfaceString('Main','TS_Protocol','Protocol'),
    @FComposition.ProtocolForm.CanCloseFromHost);
  FHost.Register(FComposition.ManualForm,
    ReadInterfaceString('Main','TS_Manual','Manual'), nil);
end;

{ПАНЕЛЬ ПРОЕКТОВ}

const
  MENU_SECTION = 'Menu';
  PROJECT_PANEL_WIDTH = 220;

procedure TMainForm.BuildProjectPanel;
// панель проектов слева; контекстное меню дерева собирает BuildMenu
begin
  FProjectPanel := TProjectPanel.Create(Self);
  FProjectPanel.Parent := Self;
  FProjectPanel.Align := alLeft;
  FProjectPanel.Width := ScaleUi(PROJECT_PANEL_WIDTH, Monitor.PixelsPerInch);
  FProjectPanel.OnOpenItem := @ProjectItemOpen;
  FProjectSplitter := TSplitter.Create(Self);
  FProjectSplitter.Parent := Self;
  FProjectSplitter.Align := alLeft;
  FProjectSplitter.Left := FProjectPanel.Width;
end;

function TMainForm.SynthesisProjectDir: string;
// проект для синтеза: выбранный действием «Синтез…», иначе выделенный в дереве
var
  Index: Integer;
begin
  Result := FSynthesisProjectDir;
  if Result <> '' then
    Exit;
  Index := FProjectPanel.SelectedProjectIndex;
  if Index >= 0 then
    Result := FProjectPanel.Projects[Index].Dir;
end;

function TMainForm.ChooseProject(const ANeedKey, ANeedDefault: string): TProject;
// Проект для создаваемого объекта: нет проектов - сообщение и nil, один - он,
// несколько - окно выбора (выделенный в дереве проект выбран заранее).
var
  Items: TStringList;
  Index, I: Integer;
begin
  Result := nil;
  if FProjectPanel.ProjectCount = 0 then
  begin
    ShowMessage(ReadInterfaceString(MENU_SECTION, ANeedKey, ANeedDefault));
    Exit;
  end;
  Index := FProjectPanel.SelectedProjectIndex;
  RefreshProjectTree;  // в папке проекта могло что-то появиться
  if FProjectPanel.ProjectCount > 1 then
  begin
    if Index < 0 then
      Index := 0;
    Items := TStringList.Create;
    try
      for I := 0 to FProjectPanel.ProjectCount - 1 do
        Items.Add(FProjectPanel.Projects[I].Name + ' (' +
          FProjectPanel.Projects[I].Dir + ')');
      if not ChooseFromList(
        ReadInterfaceString(MENU_SECTION, 'ChooseProjectTitle', 'Проект'),
        ReadInterfaceString(MENU_SECTION, 'ChooseProjectPrompt',
          'Выберите проект:'), Items, Index) then
        Exit;
    finally
      Items.Free;
    end;
  end
  else
    Index := 0;
  Result := FProjectPanel.Projects[Index];
end;

function TMainForm.EnsureArrayOpen(AProject: TProject): Boolean;
// массив проекта должен быть открыт на вкладке последовательностей
begin
  Result := SameFileName(FComposition.SequencesForm.ProjectDir, AProject.Dir) or
    FComposition.SequencesForm.OpenArrayFile(AProject.ArrayFile);
end;

procedure TMainForm.ProjectItemOpen(AKind: TProjectNodeKind;
  const APath: string);
// двойной щелчок по строке дерева: массив и синтез открываются на своих
// вкладках, у проекта и слайсинга документа пока нет
begin
  case AKind of
    pnkArray:
      if FComposition.SequencesForm.OpenArrayFile(APath) then
        FHost.Open(FComposition.SequencesForm);
    pnkSynthesis:
      if FComposition.SynthesisForm.OpenSynthesisFile(
        IncludeTrailingPathDelimiter(APath) + SYNTHESIS_INFO_FILE) then
        FHost.Open(FComposition.SynthesisForm);
  end;
end;

procedure TMainForm.RefreshProjectTree;
var
  ErrorText: string;
begin
  if not FProjectPanel.Refresh(ErrorText) then
    SequencesLog(ErrorText);
end;

procedure TMainForm.ActOpenProjectExecute(Sender: TObject);
// папка существующего проекта; проект добавляется в дерево к открытым
var
  Dlg: TSelectDirectoryDialog;
  NewProject: TProject;
  ErrorText: string;
begin
  Dlg := TSelectDirectoryDialog.Create(Self);
  try
    Dlg.Title := FActOpenProject.Caption;
    Dlg.InitialDir := ProjectsDir;
    if not Dlg.Execute then
      Exit;
    NewProject := OpenProject(Dlg.FileName, ErrorText);
  finally
    Dlg.Free;
  end;
  if NewProject = nil then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  FProjectPanel.AddProject(NewProject);
end;

procedure TMainForm.ActCloseProjectExecute(Sender: TObject);
// убирает выделенный проект из дерева; папка и открытые формы не меняются
begin
  FProjectPanel.RemoveProject(FProjectPanel.SelectedProjectIndex);
end;

procedure TMainForm.ActRefreshProjectExecute(Sender: TObject);
begin
  RefreshProjectTree;
end;

{ГЛАВНОЕ МЕНЮ}

function TMainForm.NewAction(const AKey, ADefault, AIcon: string;
  AHandler: TNotifyEvent): TAction;
begin
  Result := TAction.Create(FActions);
  Result.ActionList := FActions;
  Result.Caption := ReadInterfaceString(MENU_SECTION, AKey, ADefault);
  Result.ImageIndex := IconIndex(AIcon);
  Result.OnExecute := AHandler;
end;

function TMainForm.AddMenu(AParent: TMenuItem; const AKey,
  ADefault: string): TMenuItem;
begin
  Result := TMenuItem.Create(FMenu);
  Result.Caption := ReadInterfaceString(MENU_SECTION, AKey, ADefault);
  AParent.Add(Result);
end;

procedure TMainForm.AddItem(AParent: TMenuItem; AAction: TAction);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FMenu);
  Item.Action := AAction;
  AParent.Add(Item);
end;

procedure TMainForm.BuildMenu;
var
  Icons: TImageList;
  Root, Item: TMenuItem;
  Popup: TPopupMenu;
begin
  Icons := CreateIconListForPpi(Self, Monitor.PixelsPerInch);
  FActions := TActionList.Create(Self);
  FActions.Images := Icons;
  FActions.OnUpdate := @ActionsUpdate;

  FActNewProject := NewAction('NewProject', 'Проект…', ICON_PROJECT_NEW,
    @ActNewProjectExecute);
  FActNewSequence := NewAction('NewSequence', 'Последовательность…', '',
    @ActNewSequenceExecute);
  FActNewSlicing := NewAction('NewSlicing', 'Слои…', '',
    @ActNewSlicingExecute);
  FActNewSynthesis := NewAction('NewSynthesis', 'Синтез…', '',
    @ActNewSynthesisExecute);
  FActNewProtocol := NewAction('NewProtocol', 'Протокол…', '',
    @ActNewProtocolExecute);
  FActOpenProject := NewAction('OpenProject', 'Открыть проект…',
    ICON_PROJECT_OPEN, @ActOpenProjectExecute);
  FActCloseProject := NewAction('CloseProject', 'Закрыть проект', ICON_CLOSE,
    @ActCloseProjectExecute);
  FActRefreshProject := NewAction('Refresh', 'Обновить', ICON_REFRESH,
    @ActRefreshProjectExecute);
  FActOpen := NewAction('Open', 'Открыть…', ICON_OPEN, @ActOpenExecute);
  FActSave := NewAction('Save', 'Сохранить', ICON_SAVE, @ActSaveExecute);
  FActExit := NewAction('Exit', 'Выход', ICON_EXIT, @ActExitExecute);
  FActTabSequences := NewAction('TabSequences', 'Последовательности', '',
    @ActTabExecute);
  FActTabSynthesis := NewAction('TabSynthesis', 'Синтез', '', @ActTabExecute);
  FActTabProtocol := NewAction('TabProtocol', 'Протокол', '', @ActTabExecute);
  FActTabManual := NewAction('TabManual', 'Ручное управление', '',
    @ActTabExecute);
  FActTabLog := NewAction('TabLog', 'Лог', '', @ActTabExecute);
  FActLaserParams := NewAction('LaserParams', 'Параметры лазера…',
    ICON_SETTINGS, @ActLaserParamsExecute);

  FMenu := TMainMenu.Create(Self);
  FMenu.Images := Icons;

  Root := AddMenu(FMenu.Items, 'File', 'Файл');
  Item := AddMenu(Root, 'New', 'Создать');
  AddItem(Item, FActNewProject);
  AddItem(Item, FActNewSequence);
  AddItem(Item, FActNewSlicing);
  AddItem(Item, FActNewSynthesis);
  AddItem(Item, FActNewProtocol);
  AddItem(Root, FActOpenProject);
  AddItem(Root, FActCloseProject);
  AddItem(Root, FActOpen);
  AddItem(Root, FActSave);
  Item := TMenuItem.Create(FMenu);
  Item.Caption := '-';
  Root.Add(Item);
  AddItem(Root, FActExit);

  Root := AddMenu(FMenu.Items, 'View', 'Вид');
  AddItem(Root, FActTabSequences);
  AddItem(Root, FActTabSynthesis);
  AddItem(Root, FActTabProtocol);
  AddItem(Root, FActTabLog);

  Root := AddMenu(FMenu.Items, 'Devices', 'Приборы');
  AddItem(Root, FActTabManual);

  Root := AddMenu(FMenu.Items, 'Tools', 'Инструменты');
  AddItem(Root, FActLaserParams);

  Menu := FMenu;

  // контекстное меню дерева: «Добавить в проект» на тех же действиях,
  // что и «Файл → Создать»
  Popup := TPopupMenu.Create(Self);
  Popup.Images := Icons;
  Item := AddMenu(Popup.Items, 'AddToProject', 'Добавить в проект');
  AddItem(Item, FActNewSequence);
  AddItem(Item, FActNewSlicing);
  AddItem(Item, FActNewSynthesis);
  AddItem(Popup.Items, FActRefreshProject);
  AddItem(Popup.Items, FActCloseProject);
  FProjectPanel.TreeMenu := Popup;
end;

procedure TMainForm.ActionsUpdate(AAction: TBasicAction; var Handled: Boolean);
// «Сохранить» относится к объекту активной вкладки (массив, протокол); синтез
// сохраняется сам; «Закрыть проект» - когда в дереве выделен проект
var
  ActiveDoc: TForm;
begin
  ActiveDoc := FHost.ActiveForm;
  if ActiveDoc = FComposition.SequencesForm then
    FActSave.Enabled := FComposition.SequencesForm.HasArray
  else if ActiveDoc = FComposition.ProtocolForm then
    FActSave.Enabled := FComposition.ProtocolForm.CanSave
  else
    FActSave.Enabled := False;
  FActCloseProject.Enabled := FProjectPanel.SelectedProjectIndex >= 0;
  FActTabSequences.Checked := ActiveDoc = FComposition.SequencesForm;
  FActTabSynthesis.Checked := ActiveDoc = FComposition.SynthesisForm;
  FActTabProtocol.Checked := ActiveDoc = FComposition.ProtocolForm;
  FActTabManual.Checked := ActiveDoc = FComposition.ManualForm;
  FActTabLog.Checked := Panel_Log.Visible;
  Handled := True;
end;

procedure TMainForm.ActNewProjectExecute(Sender: TObject);
// папка нового проекта <папка проектов>\<имя>
var
  Folder, ProjectName, ErrorText: string;
  NewProject: TProject;
begin
  // как при сохранении массива: папка проектов и имя по текущему времени
  Folder := ExcludeTrailingPathDelimiter(ProjectsDir);
  ProjectName := FormatDateTime(DEFAULT_NAME_FORMAT, Now);
  if not TArraySaveForm.ExecuteProject(Folder, ProjectName) then
    Exit;
  NewProject := CreateProject(Folder, ProjectName, ErrorText);
  if NewProject = nil then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  SequencesLog(ReadInterfaceString(MENU_SECTION, 'ProjectCreated',
    'Проект создан:') + ' ' + NewProject.Dir);
  FProjectPanel.AddProject(NewProject);
end;

procedure TMainForm.ActNewSequenceExecute(Sender: TObject);
// последовательность создаётся в выбранном проекте и сразу в нём сохраняется;
// в проекте один массив
var
  Project: TProject;
begin
  Project := ChooseProject('NeedProjectSequence',
    'Создайте проект, чтобы создать последовательность');
  if Project = nil then
    Exit;
  if Project.ArrayFile <> '' then
  begin
    ShowMessage(ReadInterfaceString(MENU_SECTION, 'ProjectHasArray',
      'В проекте уже есть последовательность:') + LineEnding +
      Project.ArrayFile);
    Exit;
  end;
  FHost.Open(FComposition.SequencesForm);
  FComposition.SequencesForm.CreateArrayInProject(Project.Dir);
  RefreshProjectTree;
end;

procedure TMainForm.ActNewSlicingExecute(Sender: TObject);
var
  Project: TProject;
begin
  Project := ChooseProject('NeedProjectSlicing',
    'Создайте проект, чтобы создать слайсинг');
  if Project = nil then
    Exit;
  if Project.ArrayFile = '' then
  begin
    ShowMessage(ReadInterfaceString(MENU_SECTION, 'ProjectHasNoArray',
      'В проекте нет последовательности. Создайте её сначала.'));
    Exit;
  end;
  if not EnsureArrayOpen(Project) then
    Exit;
  FHost.Open(FComposition.SequencesForm);
  FComposition.SequencesForm.SliceArray;
  RefreshProjectTree;
end;

procedure TMainForm.ActNewSynthesisExecute(Sender: TObject);
var
  Project: TProject;
begin
  Project := ChooseProject('NeedProjectSynthesis',
    'Создайте проект, чтобы создать синтез');
  if Project = nil then
    Exit;
  if Project.SlicingCount = 0 then
  begin
    ShowMessage(ReadInterfaceString(MENU_SECTION, 'ProjectHasNoSlicing',
      'В проекте нет слайсинга. Создайте его сначала.'));
    Exit;
  end;
  FSynthesisProjectDir := Project.Dir;
  try
    FHost.Open(FComposition.SynthesisForm);
    FComposition.SynthesisForm.NewSynthesis;
  finally
    FSynthesisProjectDir := '';
  end;
  RefreshProjectTree;
end;

procedure TMainForm.ActNewProtocolExecute(Sender: TObject);
begin
  FHost.Open(FComposition.ProtocolForm);
  FComposition.ProtocolForm.NewProtocol;
end;

procedure TMainForm.ActOpenExecute(Sender: TObject);
// один диалог на все типы; тип определяется по файлу
var
  Dlg: TOpenDialog;
  FileName: string;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter :=
      ReadInterfaceString(MENU_SECTION, 'FilterAll', 'Все файлы проекта') +
      '|*.csv;*.pro;' + SYNTHESIS_INFO_FILE + '|' +
      ReadInterfaceString(MENU_SECTION, 'FilterArray', 'Массив (*.csv)') +
      '|*.csv|' +
      ReadInterfaceString(MENU_SECTION, 'FilterProtocol', 'Протокол (*.pro)') +
      '|*.pro|' +
      ReadInterfaceString(MENU_SECTION, 'FilterSynthesis', 'Синтез') +
      '|' + SYNTHESIS_INFO_FILE;
    Dlg.InitialDir := ProjectsDir;
    if not Dlg.Execute then
      Exit;
    FileName := Dlg.FileName;
  finally
    Dlg.Free;
  end;
  // вкладка открывается, только если файл открыт
  case ProjectFileKindOf(FileName) of
    pfkArray:
      if FComposition.SequencesForm.OpenArrayFile(FileName) then
        FHost.Open(FComposition.SequencesForm);
    pfkProtocol:
      if FComposition.ProtocolForm.OpenProtocolFile(FileName) then
        FHost.Open(FComposition.ProtocolForm);
    pfkSynthesis:
      if FComposition.SynthesisForm.OpenSynthesisFile(FileName) then
        FHost.Open(FComposition.SynthesisForm);
  else
    ShowMessage(ReadInterfaceString(MENU_SECTION, 'UnknownFileType',
      'Неизвестный тип файла:') + ' ' + FileName);
  end;
end;

procedure TMainForm.ActSaveExecute(Sender: TObject);
var
  ActiveDoc: TForm;
begin
  ActiveDoc := FHost.ActiveForm;
  if ActiveDoc = FComposition.SequencesForm then
  begin
    FComposition.SequencesForm.SaveArrayToProject;
    RefreshProjectTree;
  end
  else if ActiveDoc = FComposition.ProtocolForm then
    FComposition.ProtocolForm.SaveCurrent;
end;

procedure TMainForm.ActExitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ActTabExecute(Sender: TObject);
// пункты «Вид» и «Приборы» открывают вкладку формы; «Лог» показывает и
// прячет нижнюю панель
begin
  if Sender = FActTabSequences then
    FHost.Open(FComposition.SequencesForm)
  else if Sender = FActTabSynthesis then
    FHost.Open(FComposition.SynthesisForm)
  else if Sender = FActTabProtocol then
    FHost.Open(FComposition.ProtocolForm)
  else if Sender = FActTabManual then
    FHost.Open(FComposition.ManualForm)
  else if Sender = FActTabLog then
  begin
    Panel_Log.Visible := not Panel_Log.Visible;
    Splitter_Log.Visible := Panel_Log.Visible;
  end;
end;

procedure TMainForm.ActLaserParamsExecute(Sender: TObject);
begin
  FComposition.LaserActions.EditLaserParams(Sender);
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  UpdateManualControlsWidth();
end;

procedure TMainForm.UpdateMinimumWindowWidth;
const
  FORM_NONCLIENT_CHROME_FALLBACK = 24;
var
  RequiredPanelWidth: Integer;
  RequiredClientWidth: Integer;
  RequiredFormWidth: Integer;
  FormChromeWidth: Integer;
begin
  if not Assigned(Panel1) then
    Exit;

  RequiredPanelWidth := MAIN_WINDOW_MIN_WIDTH + STATION_PANEL_CHROME;
  if Assigned(FProjectPanel) then
    RequiredPanelWidth := RequiredPanelWidth + FProjectPanel.Width +
      FProjectSplitter.Width;
  RequiredClientWidth := RequiredPanelWidth;

  FormChromeWidth := Width - ClientWidth;
  if FormChromeWidth < FORM_NONCLIENT_CHROME_FALLBACK then
    FormChromeWidth := FORM_NONCLIENT_CHROME_FALLBACK;
  RequiredFormWidth := RequiredClientWidth + FormChromeWidth;
  Constraints.MinWidth := RequiredFormWidth;
end;
procedure TMainForm.UpdateManualControlsWidth;
// страницы - по размеру панели
begin
  if not Assigned(Panel1) or not Assigned(PageControl1) then
    Exit;
  if (Panel1.ClientWidth <= 2) or (Panel1.ClientHeight <= 2) then
    Exit;
  PageControl1.SetBounds(1, 1, Panel1.ClientWidth - 2,
    Panel1.ClientHeight - 2);
end;

procedure TMainForm.SequencesLog(const AMsg: string);
begin
  Memo1.Lines.Add(AMsg);
end;

procedure TMainForm.Tmr_EzCADerTimer(Sender: TObject);
begin
  if not FComposition.EzCadWatcherTick then
    Tmr_EzCADer.Enabled:=False;
end;

procedure TMainForm.StartEzCadWatcher;
begin
  FComposition.EzCadWatcherStart;
  Tmr_EzCADer.Enabled:=True;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // порядок проверок (протокол, массив, синтез, станция) - в композиции
  if Assigned(FComposition) and not FComposition.CanCloseAll then
  begin
    CloseAction := caNone;
    Exit;
  end;

  FinalizeLocalization;
end;

destructor TMainForm.Destroy;
begin
  // Адаптеры принадлежат композиции и освобождаются после дочерних форм,
  // которым они делегируют вызовы.
  inherited Destroy;
  FreeAndNil(FHost);
  FreeAndNil(FComposition);
end;

procedure TMainForm.DispenserStationLogMessage(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);
  Memo1.SelStart := Length(Memo1.Text);
end;

procedure TMainForm.SynthesisClearLog(Sender: TObject);
begin
  Memo1.Clear;
end;

end.
