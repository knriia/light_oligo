unit AutomationEditorView;
// Вкладка станции для запуска протокола синтеза (.pro).
// Протокол редактируется в главном окне программы; здесь он только
// открывается и показывается деревом. Станция выполняет операции SyrSt:
// весь протокол или один выбранный блок.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Dialogs,
  WindowSettingsStorage, AutomationDocumentStorage, AutomationProtocol;

type
  TAutomationRunProtocolEvent = procedure(Sender: TObject) of object;

  TAutomationEditorView = class(TTabSheet)
  private
    FButtonPanel: TPanel;
    FOpenButton: TButton;
    FReloadButton: TButton;
    FRunAllButton: TButton;
    FRunBlockButton: TButton;
    FDocumentStatusLabel: TLabel;
    FHintLabel: TLabel;
    FProtocolTree: TTreeView;
    FOpenDialog: TOpenDialog;
    FSettingsStorage: TWindowSettingsStorage;
    FCurrentFileName: string;
    FProtocolText: string;
    FRequestedBlockIndex: Integer;
    FOnRunProtocol: TAutomationRunProtocolEvent;

    procedure CreateControls;
    procedure LayoutButtonPanel(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure ReloadButtonClick(Sender: TObject);
    procedure RunAllButtonClick(Sender: TObject);
    procedure RunBlockButtonClick(Sender: TObject);
    procedure ProtocolTreeSelectionChanged(Sender: TObject);
    procedure UpdateControls;
    function SelectedBlockIndex: Integer;
    function OpenProtocolFile(const AFileName: string;
      out AErrorText: string): Boolean;
    procedure FireRun(ABlockIndex: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadLastSavedFile(out AErrorText: string);
    function ConfirmClose: Boolean;
    property SettingsStorage: TWindowSettingsStorage
      read FSettingsStorage write FSettingsStorage;
    // Текст открытого протокола.
    property ProtocolText: string read FProtocolText;
    // Какой блок запускать: ALL_BLOCKS или номер блока (с нуля).
    property RequestedBlockIndex: Integer read FRequestedBlockIndex;
    property OnRunProtocol: TAutomationRunProtocolEvent
      read FOnRunProtocol write FOnRunProtocol;
  end;

implementation

uses
  AppPaths;

function ToStoredProtocolPath(const AFileName: string): string;
// Файл из папки протоколов запоминаем относительным путём,
// чтобы программу можно было перенести в другую папку.
begin
  Result := MakePathRelative(GetProtocolsDirectory(ParamStr(0)), AFileName);
end;

function FromStoredProtocolPath(const AStoredName: string): string;
begin
  Result := ResolvePath(GetProtocolsDirectory(ParamStr(0)), AStoredName);
end;

constructor TAutomationEditorView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Протокол';
  FRequestedBlockIndex := ALL_BLOCKS;
  CreateControls;
end;

procedure TAutomationEditorView.CreateControls;
begin
  FButtonPanel := TPanel.Create(Self);
  FButtonPanel.Parent := Self;
  FButtonPanel.Align := alTop;
  FButtonPanel.Height := 70;
  FButtonPanel.BevelOuter := bvNone;
  FButtonPanel.Caption := '';

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := FButtonPanel;
  FOpenButton.Caption := 'Открыть протокол';
  FOpenButton.TabOrder := 0;
  FOpenButton.OnClick := @OpenButtonClick;

  FReloadButton := TButton.Create(Self);
  FReloadButton.Parent := FButtonPanel;
  FReloadButton.Caption := 'Перечитать';
  FReloadButton.Hint := 'Загрузить файл заново после правок в редакторе протокола';
  FReloadButton.ShowHint := True;
  FReloadButton.TabOrder := 1;
  FReloadButton.OnClick := @ReloadButtonClick;

  FRunAllButton := TButton.Create(Self);
  FRunAllButton.Parent := FButtonPanel;
  FRunAllButton.Caption := 'Запустить протокол';
  FRunAllButton.Hint := 'Выполнить все операции SyrSt протокола по порядку';
  FRunAllButton.ShowHint := True;
  FRunAllButton.TabOrder := 2;
  FRunAllButton.OnClick := @RunAllButtonClick;

  FRunBlockButton := TButton.Create(Self);
  FRunBlockButton.Parent := FButtonPanel;
  FRunBlockButton.Caption := 'Запустить блок';
  FRunBlockButton.Hint := 'Выполнить операции SyrSt только выбранного блока';
  FRunBlockButton.ShowHint := True;
  FRunBlockButton.TabOrder := 3;
  FRunBlockButton.OnClick := @RunBlockButtonClick;

  FDocumentStatusLabel := TLabel.Create(Self);
  FDocumentStatusLabel.Parent := FButtonPanel;
  FDocumentStatusLabel.ShowHint := True;

  FHintLabel := TLabel.Create(Self);
  FHintLabel.Parent := FButtonPanel;
  FHintLabel.Caption := 'Протокол редактируется в главном окне. ' +
    'Станция выполняет только операции SyrSt, остальные пропускает.';

  FProtocolTree := TTreeView.Create(Self);
  FProtocolTree.Parent := Self;
  FProtocolTree.Align := alClient;
  FProtocolTree.ReadOnly := True;
  FProtocolTree.HideSelection := False;
  FProtocolTree.TabOrder := 1;
  FProtocolTree.OnSelectionChanged := @ProtocolTreeSelectionChanged;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Title := 'Открыть протокол';
  FOpenDialog.Filter := 'Протокол (*.pro)|*.pro|Все файлы (*.*)|*.*';
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];

  FButtonPanel.OnResize := @LayoutButtonPanel;
  LayoutButtonPanel(nil);
  UpdateControls;
end;

procedure TAutomationEditorView.LayoutButtonPanel(Sender: TObject);
const
  MARGIN = 16;
  BUTTON_WIDTH = 150;
  BUTTON_HEIGHT = 25;
  BUTTON_GAP = 6;
  BUTTON_TOP = 8;
var
  ControlLeft: Integer;
begin
  if FButtonPanel = nil then
    Exit;
  ControlLeft := MARGIN;
  FOpenButton.SetBounds(ControlLeft, BUTTON_TOP, BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ControlLeft, BUTTON_WIDTH + BUTTON_GAP);
  FReloadButton.SetBounds(ControlLeft, BUTTON_TOP, BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ControlLeft, BUTTON_WIDTH + BUTTON_GAP);
  FRunAllButton.SetBounds(ControlLeft, BUTTON_TOP, BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ControlLeft, BUTTON_WIDTH + BUTTON_GAP);
  FRunBlockButton.SetBounds(ControlLeft, BUTTON_TOP, BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ControlLeft, BUTTON_WIDTH + BUTTON_GAP);
  FDocumentStatusLabel.SetBounds(ControlLeft, BUTTON_TOP + 4,
    FButtonPanel.ClientWidth - ControlLeft - MARGIN, 18);
  FHintLabel.SetBounds(MARGIN, BUTTON_TOP + BUTTON_HEIGHT + 10,
    FButtonPanel.ClientWidth - 2 * MARGIN, 18);
end;

procedure TAutomationEditorView.UpdateControls;
begin
  if FCurrentFileName = '' then
  begin
    FDocumentStatusLabel.Caption := 'Протокол не открыт';
    FDocumentStatusLabel.Hint := '';
  end
  else
  begin
    FDocumentStatusLabel.Caption := ExtractFileName(FCurrentFileName);
    FDocumentStatusLabel.Hint := FCurrentFileName;
  end;
  FReloadButton.Enabled := FCurrentFileName <> '';
  FRunAllButton.Enabled := Trim(FProtocolText) <> '';
  FRunBlockButton.Enabled := SelectedBlockIndex >= 0;
end;

function TAutomationEditorView.SelectedBlockIndex: Integer;
var
  Node: TTreeNode;
begin
  Result := -1;
  Node := FProtocolTree.Selected;
  if Node = nil then
    Exit;
  while Node.Parent <> nil do
    Node := Node.Parent;
  Result := Node.Index;
end;

procedure TAutomationEditorView.ProtocolTreeSelectionChanged(Sender: TObject);
begin
  UpdateControls;
end;

function TAutomationEditorView.OpenProtocolFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  Content: UTF8String;
  Stream: TStringStream;
begin
  Result := False;
  if not ReadAutomationTextFile(AFileName, Content, AErrorText) then
    Exit;

  FProtocolText := Content;
  FCurrentFileName := ExpandFileName(AFileName);
  Stream := TStringStream.Create(Content);
  try
    FProtocolTree.Items.Clear;
    FProtocolTree.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
  FProtocolTree.FullExpand;
  UpdateControls;
  Result := True;
end;

procedure TAutomationEditorView.OpenButtonClick(Sender: TObject);
var
  ProtocolsPath: string;
  ErrorText: string;
begin
  if not EnsureProtocolsDirectory(ParamStr(0), ProtocolsPath, ErrorText) then
  begin
    MessageDlg('Не удалось подготовить папку протоколов: ' + ErrorText,
      mtError, [mbOK], 0);
    Exit;
  end;

  FOpenDialog.InitialDir := ProtocolsPath;
  FOpenDialog.FileName := '';
  if not FOpenDialog.Execute then
    Exit;

  if not OpenProtocolFile(FOpenDialog.FileName, ErrorText) then
  begin
    MessageDlg('Не удалось открыть протокол: ' + ErrorText, mtError, [mbOK], 0);
    Exit;
  end;

  if (FSettingsStorage <> nil) and
    not FSettingsStorage.SaveLastAutomationFile(
      ToStoredProtocolPath(FCurrentFileName)) then
    MessageDlg('Протокол открыт, но не удалось сохранить путь к последнему ' +
      'файлу в настройках.', mtWarning, [mbOK], 0);
end;

procedure TAutomationEditorView.ReloadButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  if FCurrentFileName = '' then
    Exit;
  if not OpenProtocolFile(FCurrentFileName, ErrorText) then
    MessageDlg('Не удалось перечитать протокол: ' + ErrorText, mtError,
      [mbOK], 0);
end;

procedure TAutomationEditorView.FireRun(ABlockIndex: Integer);
begin
  FRequestedBlockIndex := ABlockIndex;
  if Assigned(FOnRunProtocol) then
    FOnRunProtocol(Self);
end;

procedure TAutomationEditorView.RunAllButtonClick(Sender: TObject);
begin
  FireRun(ALL_BLOCKS);
end;

procedure TAutomationEditorView.RunBlockButtonClick(Sender: TObject);
begin
  if SelectedBlockIndex < 0 then
  begin
    MessageDlg('Выберите блок в дереве протокола.', mtInformation, [mbOK], 0);
    Exit;
  end;
  FireRun(SelectedBlockIndex);
end;

procedure TAutomationEditorView.LoadLastSavedFile(out AErrorText: string);
var
  FileName: string;
begin
  AErrorText := '';
  if FSettingsStorage = nil then
    Exit;

  FileName := FromStoredProtocolPath(FSettingsStorage.LoadLastAutomationFile);
  if (FileName = '') or not FileExists(FileName) then
    Exit;
  if not OpenProtocolFile(FileName, AErrorText) then
    AErrorText := 'Не удалось открыть последний протокол "' + FileName + '": ' +
      AErrorText;
end;

function TAutomationEditorView.ConfirmClose: Boolean;
begin
  // Протокол здесь не редактируется, сохранять нечего.
  Result := True;
end;

end.
