unit AutomationEditorView;
// Вкладка станции «Автоматизация»: сценарий - список операций, которые
// станция выполняет сверху вниз. Операция - шприцевая станция (подача из
// дозаторов, из нескольких одновременно или из одного) или пауза в секундах.
// Сценарий открывается из файла и сохраняется в файл (data\automation),
// операции можно добавлять, менять, удалять и переставлять. Список показан
// деревом: у операции станции видны её параметры.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Dialogs,
  Graphics, WindowSettingsStorage, AutomationDocumentStorage,
  AutomationProtocol, ScenarioList, ProtocolFormat;

type
  TAutomationRunEvent = procedure(Sender: TObject) of object;

  TAutomationEditorView = class(TTabSheet)
  private
    FButtonPanel: TPanel;
    FNewButton: TButton;
    FOpenButton: TButton;
    FSaveButton: TButton;
    FRunButton: TButton;
    FAddButton: TButton;
    FDeleteButton: TButton;
    FMoveUpButton: TButton;
    FMoveDownButton: TButton;
    FDocumentStatusLabel: TLabel;
    FTree: TTreeView;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FSettingsStorage: TWindowSettingsStorage;
    FScenarios: TScenarioList;
    FCurrentFileName: string;
    FModified: Boolean;    // список менялся после открытия или сохранения
    FRequestedItemIndex: Integer;
    FOnRun: TAutomationRunEvent;

    function AddButton(const ACaption, AHint: string;
      AHandler: TNotifyEvent): TButton;
    procedure CreateControls;
    procedure LayoutButtonPanel(Sender: TObject);
    procedure NewButtonClick(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure RunButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure EditItem(AIndex: Integer);
    procedure DeleteButtonClick(Sender: TObject);
    procedure MoveUpButtonClick(Sender: TObject);
    procedure MoveDownButtonClick(Sender: TObject);
    procedure TreeSelectionChanged(Sender: TObject);
    procedure TreeDoubleClick(Sender: TObject);
    procedure UpdateControls;
    procedure FillTree;
    procedure SelectItem(AIndex: Integer);
    procedure ListChanged(ASelectIndex: Integer);
    function SelectedItemIndex: Integer;
    function InsertPosition: Integer;
    function PrepareAutomationFolder: Boolean;
    function SaveScenario: Boolean;
    function ConfirmSaveChanges: Boolean;
    procedure ClearScenario;
    function OpenScenarioFile(const AFileName: string;
      out AErrorText: string): Boolean;
    procedure RememberFile;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadLastSavedFile(out AErrorText: string);
    function ConfirmClose: Boolean;
    property SettingsStorage: TWindowSettingsStorage
      read FSettingsStorage write FSettingsStorage;
    // Открытый сценарий.
    property Scenarios: TScenarioList read FScenarios;
    // Что запускать: ALL_BLOCKS - весь сценарий или номер операции (с нуля).
    property RequestedItemIndex: Integer read FRequestedItemIndex;
    property OnRun: TAutomationRunEvent read FOnRun write FOnRun;
  end;

implementation

uses
  AppPaths, UOperationForm;

const
  // В сценарии станции бывают только эти операции.
  SCENARIO_KINDS = [pskSyringe, pskPause];

function ToStoredPath(const AFileName: string): string;
// Файл из папки сценариев запоминаем относительным путём,
// чтобы программу можно было перенести в другую папку.
begin
  Result := MakePathRelative(AutomationDir(ParamStr(0)), AFileName);
end;

function FromStoredPath(const AStoredName: string): string;
begin
  Result := ResolvePath(AutomationDir(ParamStr(0)), AStoredName);
end;

constructor TAutomationEditorView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Автоматизация';
  FScenarios := TScenarioList.Create;
  FRequestedItemIndex := ALL_BLOCKS;
  CreateControls;
end;

destructor TAutomationEditorView.Destroy;
begin
  FScenarios.Free;
  inherited Destroy;
end;

function TAutomationEditorView.AddButton(const ACaption, AHint: string;
  AHandler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FButtonPanel;
  Result.Caption := ACaption;
  Result.Hint := AHint;
  Result.ShowHint := AHint <> '';
  Result.OnClick := AHandler;
end;

procedure TAutomationEditorView.CreateControls;
begin
  FButtonPanel := TPanel.Create(Self);
  FButtonPanel.Parent := Self;
  FButtonPanel.Align := alTop;
  FButtonPanel.Height := 66;
  FButtonPanel.BevelOuter := bvNone;
  FButtonPanel.Caption := '';

  FNewButton := AddButton('Создать', 'Начать новый пустой сценарий',
    @NewButtonClick);
  FOpenButton := AddButton('Открыть', 'Открыть сценарий из файла',
    @OpenButtonClick);
  FSaveButton := AddButton('Сохранить', 'Сохранить сценарий в файл',
    @SaveButtonClick);
  FRunButton := AddButton('Запустить',
    'Выполнить весь сценарий сверху вниз, с паузами', @RunButtonClick);
  FAddButton := AddButton('Добавить операцию',
    'Новая операция после выбранной', @AddButtonClick);
  FDeleteButton := AddButton('Удалить', 'Удалить выбранную операцию',
    @DeleteButtonClick);
  FMoveUpButton := AddButton('Вверх', 'Поднять выбранную операцию',
    @MoveUpButtonClick);
  FMoveDownButton := AddButton('Вниз', 'Опустить выбранную операцию',
    @MoveDownButtonClick);

  FDocumentStatusLabel := TLabel.Create(Self);
  FDocumentStatusLabel.Parent := FButtonPanel;
  FDocumentStatusLabel.ShowHint := True;

  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.ReadOnly := True;
  FTree.HideSelection := False;
  FTree.TabOrder := 1;
  FTree.OnSelectionChanged := @TreeSelectionChanged;
  FTree.OnDblClick := @TreeDoubleClick;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Title := 'Открыть сценарий';
  FOpenDialog.Filter := 'Сценарии (*' + SCENARIO_FILE_EXT + ')|*' +
    SCENARIO_FILE_EXT + '|Все файлы (*.*)|*.*';
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Title := 'Сохранить сценарий';
  FSaveDialog.Filter := FOpenDialog.Filter;
  FSaveDialog.DefaultExt := Copy(SCENARIO_FILE_EXT, 2, MaxInt);
  FSaveDialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];

  FButtonPanel.OnResize := @LayoutButtonPanel;
  LayoutButtonPanel(nil);
  UpdateControls;
end;

procedure TAutomationEditorView.LayoutButtonPanel(Sender: TObject);
// Кнопки в один ряд слева направо, ширина по надписи; ниже - имя файла.
const
  MARGIN = 16;
  BUTTON_TOP = 8;
  BUTTON_HEIGHT = 25;
  BUTTON_GAP = 6;
  TEXT_PADDING = 28;
  STATUS_TOP = 42;
var
  Buttons: array[0..7] of TButton;
  I, ControlLeft, ButtonWidth: Integer;
  Measure: TBitmap;
begin
  if FButtonPanel = nil then
    Exit;
  Buttons[0] := FNewButton;
  Buttons[1] := FOpenButton;
  Buttons[2] := FSaveButton;
  Buttons[3] := FRunButton;
  Buttons[4] := FAddButton;
  Buttons[5] := FDeleteButton;
  Buttons[6] := FMoveUpButton;
  Buttons[7] := FMoveDownButton;
  // Холст панели недоступен, пока у неё нет окна (вкладка создаётся до
  // показа), поэтому текст измеряем на отдельном холсте.
  Measure := TBitmap.Create;
  try
    Measure.Canvas.Font.Assign(FButtonPanel.Font);
    ControlLeft := MARGIN;
    for I := 0 to High(Buttons) do
    begin
      ButtonWidth := Measure.Canvas.TextWidth(Buttons[I].Caption) + TEXT_PADDING;
      Buttons[I].SetBounds(ControlLeft, BUTTON_TOP, ButtonWidth, BUTTON_HEIGHT);
      Inc(ControlLeft, ButtonWidth + BUTTON_GAP);
    end;
  finally
    Measure.Free;
  end;
  FDocumentStatusLabel.SetBounds(MARGIN, STATUS_TOP,
    FButtonPanel.ClientWidth - 2 * MARGIN, 18);
end;

procedure TAutomationEditorView.UpdateControls;
var
  Selected: Integer;
  StatusText: string;
begin
  if FCurrentFileName <> '' then
  begin
    StatusText := ExtractFileName(FCurrentFileName);
    FDocumentStatusLabel.Hint := FCurrentFileName;
  end
  else
  begin
    StatusText := 'Сценарий без файла';
    FDocumentStatusLabel.Hint := '';
  end;
  if FModified then
    StatusText := StatusText + ' (изменён)';
  FDocumentStatusLabel.Caption := StatusText;

  Selected := SelectedItemIndex;
  FSaveButton.Enabled := FModified or ((FCurrentFileName = '') and
    (FScenarios.Count > 0));
  FRunButton.Enabled := FScenarios.SyringeCount > 0;
  FDeleteButton.Enabled := Selected >= 0;
  FMoveUpButton.Enabled := Selected > 0;
  FMoveDownButton.Enabled := (Selected >= 0) and
    (Selected < FScenarios.Count - 1);
end;

procedure TAutomationEditorView.FillTree;
// Верхний уровень - операции по порядку; у шприцевой станции ниже параметры.
var
  I, J: Integer;
  Node: TTreeNode;
  Params: TStringArray;
begin
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    for I := 0 to FScenarios.Count - 1 do
      if FScenarios[I].Kind = sikPause then
        FTree.Items.Add(nil, IntToStr(I + 1) + '. Пауза: ' +
          IntToStr(FScenarios[I].PauseSeconds) + ' с')
      else
      begin
        Node := FTree.Items.Add(nil, IntToStr(I + 1) +
          '. Шприцевая станция: ' + FScenarios[I].Syringe.Dispensers);
        Params := SyringeStepParamLines(FScenarios[I].Syringe);
        for J := 0 to High(Params) do
          FTree.Items.AddChild(Node, Params[J]);
      end;
  finally
    FTree.Items.EndUpdate;
  end;
  FTree.FullExpand;
end;

procedure TAutomationEditorView.SelectItem(AIndex: Integer);
var
  Node: TTreeNode;
  I: Integer;
begin
  Node := FTree.Items.GetFirstNode;
  for I := 1 to AIndex do
    if Node <> nil then
      Node := Node.GetNextSibling;
  FTree.Selected := Node;
end;

procedure TAutomationEditorView.ListChanged(ASelectIndex: Integer);
// Список изменили: перестраиваем дерево и выделяем нужную операцию.
begin
  FModified := True;
  FillTree;
  if (ASelectIndex >= 0) and (ASelectIndex < FScenarios.Count) then
    SelectItem(ASelectIndex);
  UpdateControls;
end;

function TAutomationEditorView.SelectedItemIndex: Integer;
var
  Node: TTreeNode;
begin
  Result := -1;
  Node := FTree.Selected;
  if Node = nil then
    Exit;
  while Node.Parent <> nil do
    Node := Node.Parent;
  Result := Node.Index;
  if Result >= FScenarios.Count then
    Result := -1;
end;

function TAutomationEditorView.InsertPosition: Integer;
// Новая операция идёт после выбранной, а без выбора - в конец.
begin
  Result := SelectedItemIndex;
  if Result < 0 then
    Result := FScenarios.Count
  else
    Inc(Result);
end;

procedure TAutomationEditorView.TreeSelectionChanged(Sender: TObject);
begin
  UpdateControls;
end;

procedure TAutomationEditorView.TreeDoubleClick(Sender: TObject);
// Двойной щелчок по операции или по любой строке её параметров открывает окно
// операции; по пустому месту ничего не происходит
var
  Point: TPoint;
  Node: TTreeNode;
begin
  Point := FTree.ScreenToClient(Mouse.CursorPos);
  Node := FTree.GetNodeAt(Point.X, Point.Y);
  if Node = nil then
    Exit;
  while Node.Parent <> nil do
    Node := Node.Parent;
  if Node.Index < FScenarios.Count then
    EditItem(Node.Index);
end;

function TAutomationEditorView.PrepareAutomationFolder: Boolean;
var
  Directory, ErrorText: string;
begin
  Directory := AutomationDir(ParamStr(0));
  Result := EnsureAutomationDirectory(Directory, ErrorText);
  if not Result then
    MessageDlg('Не удалось подготовить папку сценариев: ' + ErrorText,
      mtError, [mbOK], 0)
  else
  begin
    FOpenDialog.InitialDir := Directory;
    FSaveDialog.InitialDir := Directory;
  end;
end;

procedure TAutomationEditorView.RememberFile;
begin
  if (FSettingsStorage <> nil) and
    not FSettingsStorage.SaveLastAutomationFile(
      ToStoredPath(FCurrentFileName)) then
    MessageDlg('Файл сценария обработан, но не удалось сохранить путь к ' +
      'нему в настройках.', mtWarning, [mbOK], 0);
end;

function TAutomationEditorView.SaveScenario: Boolean;
// Сохраняет в текущий файл, а если файла ещё нет - спрашивает имя.
var
  FileName, ErrorText: string;
begin
  Result := False;
  FileName := FCurrentFileName;
  if FileName = '' then
  begin
    if not PrepareAutomationFolder then
      Exit;
    FSaveDialog.FileName := '';
    if not FSaveDialog.Execute then
      Exit;
    FileName := FSaveDialog.FileName;
  end;
  if not SaveScenarioFile(FileName, FScenarios, ErrorText) then
  begin
    MessageDlg(ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  FCurrentFileName := ExpandFileName(FileName);
  FModified := False;
  RememberFile;
  UpdateControls;
  Result := True;
end;

function TAutomationEditorView.ConfirmSaveChanges: Boolean;
// True - можно продолжать: изменений нет, их сохранили или от них отказались.
begin
  Result := True;
  if not FModified then
    Exit;
  case MessageDlg('Сценарий изменён. Сохранить изменения?', mtConfirmation,
    [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SaveScenario;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TAutomationEditorView.ClearScenario;
begin
  FScenarios.Clear;
  FCurrentFileName := '';
  FModified := False;
  FillTree;
  UpdateControls;
end;

function TAutomationEditorView.OpenScenarioFile(const AFileName: string;
  out AErrorText: string): Boolean;
begin
  Result := LoadScenarioFile(AFileName, FScenarios, AErrorText);
  if not Result then
    Exit;
  FCurrentFileName := ExpandFileName(AFileName);
  FModified := False;
  FillTree;
  UpdateControls;
end;

procedure TAutomationEditorView.NewButtonClick(Sender: TObject);
begin
  if ConfirmSaveChanges then
    ClearScenario;
end;

procedure TAutomationEditorView.OpenButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  if not ConfirmSaveChanges then
    Exit;
  if not PrepareAutomationFolder then
    Exit;
  FOpenDialog.FileName := '';
  if not FOpenDialog.Execute then
    Exit;
  if not OpenScenarioFile(FOpenDialog.FileName, ErrorText) then
  begin
    MessageDlg(ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  RememberFile;
end;

procedure TAutomationEditorView.SaveButtonClick(Sender: TObject);
begin
  SaveScenario;
end;

procedure TAutomationEditorView.AddButtonClick(Sender: TObject);
var
  Step: TProtocolStep;
  Position: Integer;
begin
  Step := DefaultOperation(pskSyringe);
  if not EditOperation('Добавление операции', SCENARIO_KINDS, Step) then
    Exit;
  Position := InsertPosition;
  FScenarios.Insert(Position, ScenarioItemFromStep(Step));
  ListChanged(Position);
end;

procedure TAutomationEditorView.EditItem(AIndex: Integer);
var
  Step: TProtocolStep;
begin
  Step := ScenarioItemToStep(FScenarios[AIndex]);
  if not EditOperation('Изменение операции', SCENARIO_KINDS, Step) then
    Exit;
  FScenarios.Replace(AIndex, ScenarioItemFromStep(Step));
  ListChanged(AIndex);
end;

procedure TAutomationEditorView.DeleteButtonClick(Sender: TObject);
var
  Selected: Integer;
begin
  Selected := SelectedItemIndex;
  if Selected < 0 then
    Exit;
  if MessageDlg('Удалить операцию ' + IntToStr(Selected + 1) + ' (' +
    ScenarioItemSummary(FScenarios[Selected]) + ')?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FScenarios.Delete(Selected);
  if Selected >= FScenarios.Count then
    Selected := FScenarios.Count - 1;
  ListChanged(Selected);
end;

procedure TAutomationEditorView.MoveUpButtonClick(Sender: TObject);
var
  Selected: Integer;
begin
  Selected := SelectedItemIndex;
  if Selected <= 0 then
    Exit;
  FScenarios.Move(Selected, Selected - 1);
  ListChanged(Selected - 1);
end;

procedure TAutomationEditorView.MoveDownButtonClick(Sender: TObject);
var
  Selected: Integer;
begin
  Selected := SelectedItemIndex;
  if (Selected < 0) or (Selected >= FScenarios.Count - 1) then
    Exit;
  FScenarios.Move(Selected, Selected + 1);
  ListChanged(Selected + 1);
end;

procedure TAutomationEditorView.RunButtonClick(Sender: TObject);
begin
  FRequestedItemIndex := ALL_BLOCKS;
  if Assigned(FOnRun) then
    FOnRun(Self);
end;

procedure TAutomationEditorView.LoadLastSavedFile(out AErrorText: string);
var
  FileName: string;
begin
  AErrorText := '';
  if FSettingsStorage = nil then
    Exit;

  FileName := FromStoredPath(FSettingsStorage.LoadLastAutomationFile);
  if (FileName = '') or not FileExists(FileName) then
    Exit;
  if not OpenScenarioFile(FileName, AErrorText) then
    AErrorText := 'Не удалось открыть последний сценарий: ' + AErrorText;
end;

function TAutomationEditorView.ConfirmClose: Boolean;
begin
  Result := ConfirmSaveChanges;
end;

end.
