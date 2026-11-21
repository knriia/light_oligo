unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons, Menus, ActnList,
  DispenserLayout, Localization, AppComposition, AppPaths, ProjectModel,
  SynthesisFolder, UiIcons, UiIconNames;


type

  { TMainForm }

  TMainForm = class(TForm)
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Log: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FComposition: TAppComposition;
    FActions: TActionList;
    FMenu: TMainMenu;
    FActNewProject, FActNewSequence, FActNewSlicing, FActNewSynthesis, FActNewProtocol,
      FActOpen, FActSave, FActExit: TAction;
    FActTabSequences, FActTabSynthesis, FActTabProtocol, FActTabManual,
      FActTabLog: TAction;
    FActLaserParams: TAction;
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
  FComposition := TAppComposition.Create(Self, TS_Manual, TS_Protocol,
    TS_Synthesis, TS_Sequences, @SequencesLog, @SequencesLog,
    @SequencesLog, @SequencesLog,
    @SynthesisClearLog, @DispenserStationLogMessage, @StartEzCadWatcher);
  // данные, папки и настройки программы
  FComposition.Initialize;

  MainForm.Caption:=ReadInterfaceString('Main','MainForm','LightOligo');
  TS_Manual.Caption:=ReadInterfaceString('Main','TS_Manual','Manual');
  TS_Sequences.Caption:=ReadInterfaceString('Main','TS_Sequences','Sequence');
  TS_Protocol.Caption:=ReadInterfaceString('Main','TS_Protocol','Protocol');
  TS_Synthesis.Caption:=ReadInterfaceString('Main','TS_Synthesis','Synthesis');
  TS_Log.Caption:=ReadInterfaceString('Main','TS_Log','Лог');

  // формы вкладок, адаптеры и связи между ними
  FComposition.Build;
  BuildMenu;
  Randomize();
  UpdateMinimumWindowWidth();
  UpdateManualControlsWidth();

  // при запуске всегда открываем первую вкладку (последовательности),
  // независимо от того, какая вкладка сохранена в дизайнере
  PageControl1.ActivePage:=TS_Sequences;
end;

{ГЛАВНОЕ МЕНЮ}

const
  MENU_SECTION = 'Menu';

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
  AddItem(Root, FActTabManual);
  AddItem(Root, FActTabLog);

  Root := AddMenu(FMenu.Items, 'Tools', 'Инструменты');
  AddItem(Root, FActLaserParams);

  Menu := FMenu;
end;

procedure TMainForm.ActionsUpdate(AAction: TBasicAction; var Handled: Boolean);
// «Слои» - нужен массив; «Сохранить» относится к объекту активной вкладки
// (массив, протокол); синтез сохраняется сам
begin
  FActNewSlicing.Enabled := FComposition.SequencesForm.HasArray;
  if PageControl1.ActivePage = TS_Sequences then
    FActSave.Enabled := FComposition.SequencesForm.HasArray
  else if PageControl1.ActivePage = TS_Protocol then
    FActSave.Enabled := FComposition.ProtocolForm.CanSave
  else
    FActSave.Enabled := False;
  FActTabSequences.Checked := PageControl1.ActivePage = TS_Sequences;
  FActTabSynthesis.Checked := PageControl1.ActivePage = TS_Synthesis;
  FActTabProtocol.Checked := PageControl1.ActivePage = TS_Protocol;
  FActTabManual.Checked := PageControl1.ActivePage = TS_Manual;
  FActTabLog.Checked := PageControl1.ActivePage = TS_Log;
  Handled := True;
end;

procedure TMainForm.ActNewProjectExecute(Sender: TObject);
// папка нового проекта <папка проектов>\<имя>
var
  ProjectName, ErrorText: string;
  NewProject: TProject;
begin
  ProjectName := '';
  if not InputQuery(FActNewProject.Caption,
    ReadInterfaceString(MENU_SECTION, 'PromptProjectName', 'Имя проекта:'),
    ProjectName) then
    Exit;
  NewProject := CreateProject(ProjectsDir, Trim(ProjectName), ErrorText);
  if NewProject = nil then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  try
    SequencesLog(ReadInterfaceString(MENU_SECTION, 'ProjectCreated',
      'Проект создан:') + ' ' + NewProject.Dir);
  finally
    NewProject.Free;
  end;
end;

procedure TMainForm.ActNewSequenceExecute(Sender: TObject);
begin
  PageControl1.ActivePage := TS_Sequences;
  FComposition.SequencesForm.CreateArray;
end;

procedure TMainForm.ActNewSlicingExecute(Sender: TObject);
begin
  PageControl1.ActivePage := TS_Sequences;
  FComposition.SequencesForm.SliceArray;
end;

procedure TMainForm.ActNewSynthesisExecute(Sender: TObject);
begin
  PageControl1.ActivePage := TS_Synthesis;
  FComposition.SynthesisForm.NewSynthesis;
end;

procedure TMainForm.ActNewProtocolExecute(Sender: TObject);
begin
  PageControl1.ActivePage := TS_Protocol;
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
  // вкладка переключается, только если файл открыт
  case ProjectFileKindOf(FileName) of
    pfkArray:
      if FComposition.SequencesForm.OpenArrayFile(FileName) then
        PageControl1.ActivePage := TS_Sequences;
    pfkProtocol:
      if FComposition.ProtocolForm.OpenProtocolFile(FileName) then
        PageControl1.ActivePage := TS_Protocol;
    pfkSynthesis:
      if FComposition.SynthesisForm.OpenSynthesisFile(FileName) then
        PageControl1.ActivePage := TS_Synthesis;
  else
    ShowMessage(ReadInterfaceString(MENU_SECTION, 'UnknownFileType',
      'Неизвестный тип файла:') + ' ' + FileName);
  end;
end;

procedure TMainForm.ActSaveExecute(Sender: TObject);
begin
  if PageControl1.ActivePage = TS_Sequences then
    FComposition.SequencesForm.SaveArrayToProject
  else if PageControl1.ActivePage = TS_Protocol then
    FComposition.ProtocolForm.SaveCurrent;
end;

procedure TMainForm.ActExitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ActTabExecute(Sender: TObject);
begin
  if Sender = FActTabSequences then
    PageControl1.ActivePage := TS_Sequences
  else if Sender = FActTabSynthesis then
    PageControl1.ActivePage := TS_Synthesis
  else if Sender = FActTabProtocol then
    PageControl1.ActivePage := TS_Protocol
  else if Sender = FActTabManual then
    PageControl1.ActivePage := TS_Manual
  else if Sender = FActTabLog then
    PageControl1.ActivePage := TS_Log;
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
  FreeAndNil(FComposition);
end;

procedure TMainForm.DispenserStationLogMessage(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);
  Memo1.SelStart := Length(Memo1.Text);
end;

{ВКЛАДКА Manual}

{ВКЛАДКА Sequence}
 
{ВКЛАДКА Protocol}

{ВКЛАДКА Synthesis}

procedure TMainForm.SynthesisClearLog(Sender: TObject);
begin
  Memo1.Clear;
end;

end.

