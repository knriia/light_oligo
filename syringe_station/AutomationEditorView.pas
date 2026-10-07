unit AutomationEditorView;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Dialogs,
  WindowSettingsStorage, AutomationDocumentStorage;

type
  TAutomationRunProtocolEvent = procedure(Sender: TObject) of object;

  TAutomationEditorView = class(TTabSheet)
  private
    FInputPanel: TPanel;
    FTitleLabel: TLabel;
    FDispenserLabel: TLabel;
    FValveLabel: TLabel;
    FVolumeLabel: TLabel;
    FSpeedLabel: TLabel;
    FListHintLabel: TLabel;
    FScriptLabel: TLabel;
    FDocumentStatusLabel: TLabel;
    FDispenserEdit: TEdit;
    FValveEdit: TEdit;
    FVolumeEdit: TEdit;
    FVolumeUnitCombo: TComboBox;
    FSpeedEdit: TEdit;
    FSpeedUnitCombo: TComboBox;
    FAddCommandButton: TButton;
    FRunProtocolButton: TButton;
    FOpenButton: TButton;
    FSaveButton: TButton;
    FSaveAsButton: TButton;
    FCommandMemo: TMemo;
    FCommandCount: Integer;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FSettingsStorage: TWindowSettingsStorage;
    FCurrentFileName: string;
    FLastSavedContent: string;
    FOnRunProtocol: TAutomationRunProtocolEvent;

    procedure CreateEditorControls;
    procedure LayoutInputPanel(Sender: TObject);
    procedure AddCommandButtonClick(Sender: TObject);
    procedure RunProtocolButtonClick(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure SaveAsButtonClick(Sender: TObject);
    procedure CommandMemoChange(Sender: TObject);
    procedure UpdateDocumentStatus;
    procedure UpdateRunProtocolButton;
    function GetProtocolText: string;
    function IsModified: Boolean;
    function ConfirmUnsavedChanges(const AAction: string): Boolean;
    function SaveCurrentFile(ASaveAs: Boolean; out AErrorText: string): Boolean;
    procedure SetOpenedDocument(const AFileName: string;
      const AContent: UTF8String);
    function MaxCommandNumber(const AContent: string): Integer;
    function BuildCommandBlock(AIndex: Integer): string;
    function EscapeQuotedString(const AValue: string): string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadLastSavedFile(out AErrorText: string);
    function ConfirmClose: Boolean;
    property SettingsStorage: TWindowSettingsStorage
      read FSettingsStorage write FSettingsStorage;
    property ProtocolText: string read GetProtocolText;
    property OnRunProtocol: TAutomationRunProtocolEvent
      read FOnRunProtocol write FOnRunProtocol;
  end;

implementation

constructor TAutomationEditorView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Автоматизация';
  CreateEditorControls;
end;

procedure TAutomationEditorView.CreateEditorControls;
begin
  FInputPanel := TPanel.Create(Self);
  FInputPanel.Parent := Self;
  FInputPanel.Align := alTop;
  FInputPanel.Height := 214;
  FInputPanel.BevelOuter := bvNone;
  FInputPanel.Caption := '';

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := FInputPanel;
  FTitleLabel.Caption := 'Параметры команды';
  FTitleLabel.SetBounds(16, 10, 260, 18);

  FDispenserLabel := TLabel.Create(Self);
  FDispenserLabel.Parent := FInputPanel;
  FDispenserLabel.Caption := 'Имена дозаторов (через /)';

  FDispenserEdit := TEdit.Create(Self);
  FDispenserEdit.Parent := FInputPanel;
  FDispenserEdit.Text := 'Дозатор 1/Дозатор 2';
  FDispenserEdit.Hint := 'Например: Дозатор 1/Дозатор 2';
  FDispenserEdit.ShowHint := True;
  FDispenserEdit.TabOrder := 0;

  FValveLabel := TLabel.Create(Self);
  FValveLabel.Parent := FInputPanel;
  FValveLabel.Caption := 'Каналы клапанов';

  FValveEdit := TEdit.Create(Self);
  FValveEdit.Parent := FInputPanel;
  FValveEdit.Text := '1';
  FValveEdit.Hint := 'Одно значение для всех или значения через /';
  FValveEdit.ShowHint := True;
  FValveEdit.TabOrder := 1;

  FVolumeLabel := TLabel.Create(Self);
  FVolumeLabel.Parent := FInputPanel;
  FVolumeLabel.Caption := 'Объёмы дозирования';

  FVolumeEdit := TEdit.Create(Self);
  FVolumeEdit.Parent := FInputPanel;
  FVolumeEdit.Text := '500';
  FVolumeEdit.Hint := 'Одно значение для всех или значения через /';
  FVolumeEdit.ShowHint := True;
  FVolumeEdit.TabOrder := 2;

  FVolumeUnitCombo := TComboBox.Create(Self);
  FVolumeUnitCombo.Parent := FInputPanel;
  FVolumeUnitCombo.Style := csDropDownList;
  FVolumeUnitCombo.Items.Add('нл');
  FVolumeUnitCombo.Items.Add('мкл');
  FVolumeUnitCombo.Items.Add('мл');
  FVolumeUnitCombo.ItemIndex := 1;
  FVolumeUnitCombo.TabOrder := 3;

  FSpeedLabel := TLabel.Create(Self);
  FSpeedLabel.Parent := FInputPanel;
  FSpeedLabel.Caption := 'Скорость';

  FSpeedEdit := TEdit.Create(Self);
  FSpeedEdit.Parent := FInputPanel;
  FSpeedEdit.Text := '100';
  FSpeedEdit.Hint := 'Одно значение для всех или значения через /';
  FSpeedEdit.ShowHint := True;
  FSpeedEdit.TabOrder := 4;

  FSpeedUnitCombo := TComboBox.Create(Self);
  FSpeedUnitCombo.Parent := FInputPanel;
  FSpeedUnitCombo.Style := csDropDownList;
  FSpeedUnitCombo.Items.Add('нл/с');
  FSpeedUnitCombo.Items.Add('мкл/с');
  FSpeedUnitCombo.Items.Add('мл/с');
  FSpeedUnitCombo.ItemIndex := 1;
  FSpeedUnitCombo.TabOrder := 5;

  FListHintLabel := TLabel.Create(Self);
  FListHintLabel.Parent := FInputPanel;
  FListHintLabel.Caption :=
    'Одно значение применяется ко всем дозаторам; значения через / задаются по каждому.';

  FAddCommandButton := TButton.Create(Self);
  FAddCommandButton.Parent := FInputPanel;
  FAddCommandButton.Caption := 'Добавить команду';
  FAddCommandButton.TabOrder := 6;
  FAddCommandButton.OnClick := @AddCommandButtonClick;

  FRunProtocolButton := TButton.Create(Self);
  FRunProtocolButton.Parent := FInputPanel;
  FRunProtocolButton.Caption := 'Запустить протокол';
  FRunProtocolButton.Enabled := False;
  FRunProtocolButton.Hint := 'Выполнить команды протокола';
  FRunProtocolButton.ShowHint := True;
  FRunProtocolButton.TabOrder := 7;
  FRunProtocolButton.OnClick := @RunProtocolButtonClick;

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := FInputPanel;
  FOpenButton.Caption := 'Открыть';
  FOpenButton.TabOrder := 8;
  FOpenButton.OnClick := @OpenButtonClick;

  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := FInputPanel;
  FSaveButton.Caption := 'Сохранить';
  FSaveButton.TabOrder := 9;
  FSaveButton.OnClick := @SaveButtonClick;

  FSaveAsButton := TButton.Create(Self);
  FSaveAsButton.Parent := FInputPanel;
  FSaveAsButton.Caption := 'Сохранить как';
  FSaveAsButton.TabOrder := 10;
  FSaveAsButton.OnClick := @SaveAsButtonClick;

  FDocumentStatusLabel := TLabel.Create(Self);
  FDocumentStatusLabel.Parent := FInputPanel;
  FDocumentStatusLabel.Alignment := taRightJustify;
  FDocumentStatusLabel.ShowHint := True;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Title := 'Открыть сценарий автоматизации';
  FOpenDialog.Filter :=
    'Текстовые файлы (*.txt)|*.txt|Все файлы (*.*)|*.*';
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Title := 'Сохранить сценарий автоматизации';
  FSaveDialog.Filter :=
    'Текстовые файлы (*.txt)|*.txt|Все файлы (*.*)|*.*';
  FSaveDialog.DefaultExt := 'txt';
  FSaveDialog.Options := [ofPathMustExist, ofOverwritePrompt, ofEnableSizing];

  FScriptLabel := TLabel.Create(Self);
  FScriptLabel.Parent := Self;
  FScriptLabel.Align := alTop;
  FScriptLabel.Height := 26;
  FScriptLabel.Caption := 'Последовательность команд (текст можно редактировать вручную)';
  FScriptLabel.BorderSpacing.Left := 16;
  FScriptLabel.BorderSpacing.Top := 7;

  FCommandMemo := TMemo.Create(Self);
  FCommandMemo.Parent := Self;
  FCommandMemo.Align := alClient;
  FCommandMemo.ScrollBars := ssAutoBoth;
  FCommandMemo.WordWrap := False;
  FCommandMemo.TabOrder := 1;
  FCommandCount := 0;
  FCommandMemo.OnChange := @CommandMemoChange;
  FLastSavedContent := FCommandMemo.Text;

  FInputPanel.OnResize := @LayoutInputPanel;
  LayoutInputPanel(nil);
  UpdateDocumentStatus;
  UpdateRunProtocolButton;
end;

procedure TAutomationEditorView.LayoutInputPanel(Sender: TObject);
const
  MARGIN = 16;
  LABEL_WIDTH = 210;
  FIELD_GAP = 10;
  UNIT_WIDTH = 130;
  ROW_TOP = 36;
  ROW_GAP = 33;
  FIELD_HEIGHT = 25;
  BUTTON_WIDTH = 150;
  BUTTON_HEIGHT = 25;
  BUTTON_GAP = 6;
var
  FieldLeft: Integer;
  FieldWidth: Integer;
  ValueWidth: Integer;
  UnitLeft: Integer;
  RowTop: Integer;
  HintWidth: Integer;
  ButtonLeft: Integer;
  ButtonGroupWidth: Integer;
begin
  if FInputPanel = nil then
    Exit;

  FieldLeft := MARGIN + LABEL_WIDTH + FIELD_GAP;
  FieldWidth := FInputPanel.ClientWidth - FieldLeft - MARGIN;
  if FieldWidth < 80 then
    Exit;

  RowTop := ROW_TOP;
  FDispenserLabel.SetBounds(MARGIN, RowTop + 4, LABEL_WIDTH, 17);
  FDispenserEdit.SetBounds(FieldLeft, RowTop, FieldWidth, FIELD_HEIGHT);

  Inc(RowTop, ROW_GAP);
  FValveLabel.SetBounds(MARGIN, RowTop + 4, LABEL_WIDTH, 17);
  FValveEdit.SetBounds(FieldLeft, RowTop, FieldWidth, FIELD_HEIGHT);

  Inc(RowTop, ROW_GAP);
  FVolumeLabel.SetBounds(MARGIN, RowTop + 4, LABEL_WIDTH, 17);
  ValueWidth := FieldWidth - UNIT_WIDTH - FIELD_GAP;
  UnitLeft := FieldLeft + ValueWidth + FIELD_GAP;
  FVolumeEdit.SetBounds(FieldLeft, RowTop, ValueWidth, FIELD_HEIGHT);
  FVolumeUnitCombo.SetBounds(UnitLeft, RowTop, UNIT_WIDTH, FIELD_HEIGHT);

  Inc(RowTop, ROW_GAP);
  FSpeedLabel.SetBounds(MARGIN, RowTop + 4, LABEL_WIDTH, 17);
  FSpeedEdit.SetBounds(FieldLeft, RowTop, ValueWidth, FIELD_HEIGHT);
  FSpeedUnitCombo.SetBounds(UnitLeft, RowTop, UNIT_WIDTH, FIELD_HEIGHT);

  ButtonGroupWidth := (BUTTON_WIDTH * 5) + (BUTTON_GAP * 4);
  ButtonLeft := FInputPanel.ClientWidth - MARGIN - ButtonGroupWidth;
  FAddCommandButton.SetBounds(ButtonLeft, RowTop + ROW_GAP,
    BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ButtonLeft, BUTTON_WIDTH + BUTTON_GAP);
  FRunProtocolButton.SetBounds(ButtonLeft, RowTop + ROW_GAP,
    BUTTON_WIDTH, BUTTON_HEIGHT);
  Inc(ButtonLeft, BUTTON_WIDTH + BUTTON_GAP);
  FOpenButton.SetBounds(ButtonLeft, RowTop + ROW_GAP, BUTTON_WIDTH,
    BUTTON_HEIGHT);
  Inc(ButtonLeft, BUTTON_WIDTH + BUTTON_GAP);
  FSaveButton.SetBounds(ButtonLeft, RowTop + ROW_GAP, BUTTON_WIDTH,
    BUTTON_HEIGHT);
  Inc(ButtonLeft, BUTTON_WIDTH + BUTTON_GAP);
  FSaveAsButton.SetBounds(ButtonLeft, RowTop + ROW_GAP, BUTTON_WIDTH,
    BUTTON_HEIGHT);

  HintWidth := FInputPanel.ClientWidth - (MARGIN * 3) - ButtonGroupWidth;
  FListHintLabel.SetBounds(MARGIN, RowTop + ROW_GAP + 5, HintWidth, 26);
  FDocumentStatusLabel.SetBounds(MARGIN + 280, 10,
    FInputPanel.ClientWidth - MARGIN - (MARGIN + 280), 18);
end;

procedure TAutomationEditorView.AddCommandButtonClick(Sender: TObject);
var
  NewCommand: string;
begin
  Inc(FCommandCount);
  NewCommand := BuildCommandBlock(FCommandCount);
  if FCommandMemo.Text <> '' then
  begin
    FCommandMemo.Lines.Add('');
    FCommandMemo.Lines.Add(NewCommand);
  end
  else
    FCommandMemo.Text := NewCommand;
end;

procedure TAutomationEditorView.RunProtocolButtonClick(Sender: TObject);
begin
  if Assigned(FOnRunProtocol) then
    FOnRunProtocol(Self);
end;

procedure TAutomationEditorView.OpenButtonClick(Sender: TObject);
var
  SelectedFileName: string;
  ProtocolsPath: string;
  Content: UTF8String;
  ErrorText: string;
begin
  if not EnsureProtocolsDirectory(ParamStr(0), ProtocolsPath, ErrorText) then
  begin
    MessageDlg('Не удалось подготовить папку protocols: ' + ErrorText, mtError,
      [mbOK], 0);
    Exit;
  end;

  FOpenDialog.InitialDir := ProtocolsPath;
  FOpenDialog.FileName := '';
  if not FOpenDialog.Execute then
    Exit;

  if not ConfirmUnsavedChanges('открытием другого файла') then
    Exit;

  SelectedFileName := ExpandFileName(FOpenDialog.FileName);
  if not ReadAutomationTextFile(SelectedFileName, Content, ErrorText) then
  begin
    MessageDlg('Не удалось открыть сценарий: ' + ErrorText, mtError,
      [mbOK], 0);
    Exit;
  end;

  SetOpenedDocument(SelectedFileName, Content);
  if (FSettingsStorage <> nil) and
    not FSettingsStorage.SaveLastAutomationFile(FCurrentFileName) then
    MessageDlg('Сценарий открыт, но не удалось сохранить путь к последнему ' +
      'файлу в настройках.', mtWarning, [mbOK], 0);
end;

procedure TAutomationEditorView.SaveButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  if SaveCurrentFile(False, ErrorText) then
  begin
    if ErrorText <> '' then
      MessageDlg(ErrorText, mtWarning, [mbOK], 0);
  end
  else if ErrorText <> '' then
    MessageDlg(ErrorText, mtError, [mbOK], 0);
end;

procedure TAutomationEditorView.SaveAsButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  if SaveCurrentFile(True, ErrorText) then
  begin
    if ErrorText <> '' then
      MessageDlg(ErrorText, mtWarning, [mbOK], 0);
  end
  else if ErrorText <> '' then
    MessageDlg(ErrorText, mtError, [mbOK], 0);
end;

procedure TAutomationEditorView.CommandMemoChange(Sender: TObject);
var
  HighestCommandNumber: Integer;
begin
  HighestCommandNumber := MaxCommandNumber(FCommandMemo.Text);
  if HighestCommandNumber > FCommandCount then
    FCommandCount := HighestCommandNumber;
  UpdateDocumentStatus;
  UpdateRunProtocolButton;
end;

procedure TAutomationEditorView.UpdateRunProtocolButton;
begin
  if FRunProtocolButton <> nil then
    FRunProtocolButton.Enabled := Trim(FCommandMemo.Text) <> '';
end;

function TAutomationEditorView.GetProtocolText: string;
begin
  if FCommandMemo = nil then
    Result := ''
  else
    Result := FCommandMemo.Text;
end;

procedure TAutomationEditorView.UpdateDocumentStatus;
begin
  if FDocumentStatusLabel = nil then
    Exit;

  if FCurrentFileName = '' then
  begin
    FDocumentStatusLabel.Caption := 'Новый сценарий';
    FDocumentStatusLabel.Hint := '';
  end
  else
  begin
    FDocumentStatusLabel.Caption := ExtractFileName(FCurrentFileName);
    FDocumentStatusLabel.Hint := FCurrentFileName;
  end;

  if IsModified then
    FDocumentStatusLabel.Caption := FDocumentStatusLabel.Caption + ' *';
end;

function TAutomationEditorView.IsModified: Boolean;
begin
  Result := FCommandMemo.Text <> FLastSavedContent;
end;

function TAutomationEditorView.ConfirmUnsavedChanges(
  const AAction: string): Boolean;
var
  Choice: TModalResult;
  ErrorText: string;
begin
  if not IsModified then
    Exit(True);

  Choice := MessageDlg('В сценарии есть несохранённые изменения. ' +
    'Сохранить их перед ' + AAction + '?', mtConfirmation,
    [mbYes, mbNo, mbCancel], 0);
  case Choice of
    mrYes:
      begin
        Result := SaveCurrentFile(False, ErrorText);
        if ErrorText <> '' then
        begin
          if Result then
            MessageDlg(ErrorText, mtWarning, [mbOK], 0)
          else
            MessageDlg(ErrorText, mtError, [mbOK], 0);
        end;
      end;
    mrNo:
      Result := True;
  else
    Result := False;
  end;
end;

function TAutomationEditorView.SaveCurrentFile(ASaveAs: Boolean;
  out AErrorText: string): Boolean;
var
  TargetFileName: string;
  ProtocolsPath: string;
begin
  Result := False;
  AErrorText := '';
  TargetFileName := FCurrentFileName;

  if ASaveAs or (TargetFileName = '') then
  begin
    if not EnsureProtocolsDirectory(ParamStr(0), ProtocolsPath, AErrorText) then
    begin
      AErrorText := 'Не удалось подготовить папку protocols: ' + AErrorText;
      Exit;
    end;

    FSaveDialog.InitialDir := ProtocolsPath;
    if TargetFileName = '' then
      FSaveDialog.FileName := 'automation.txt'
    else
      FSaveDialog.FileName := ExtractFileName(TargetFileName);
    if not FSaveDialog.Execute then
      Exit;
    TargetFileName := FSaveDialog.FileName;
  end;

  if not WriteAutomationTextFile(TargetFileName, FCommandMemo.Text,
    AErrorText) then
  begin
    AErrorText := 'Не удалось сохранить сценарий: ' + AErrorText;
    Exit;
  end;

  FCurrentFileName := ExpandFileName(TargetFileName);
  FLastSavedContent := FCommandMemo.Text;
  UpdateDocumentStatus;
  Result := True;

  if (FSettingsStorage <> nil) and
    not FSettingsStorage.SaveLastAutomationFile(FCurrentFileName) then
    AErrorText := 'Файл сохранён, но не удалось запомнить его путь в настройках.';
end;

procedure TAutomationEditorView.SetOpenedDocument(const AFileName: string;
  const AContent: UTF8String);
begin
  FCommandMemo.OnChange := nil;
  try
    FCommandMemo.Text := AContent;
  finally
    FCommandMemo.OnChange := @CommandMemoChange;
  end;
  FCurrentFileName := ExpandFileName(AFileName);
  FLastSavedContent := FCommandMemo.Text;
  FCommandCount := MaxCommandNumber(FCommandMemo.Text);
  UpdateDocumentStatus;
  UpdateRunProtocolButton;
end;

function TAutomationEditorView.MaxCommandNumber(
  const AContent: string): Integer;
var
  Lines: TStringList;
  I: Integer;
  ColonPosition: Integer;
  CommandNumber: Integer;
  Line: string;
begin
  Result := 0;
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := TrimLeft(Lines[I]);
      if Copy(Line, 1, 8) <> 'command_' then
        Continue;
      ColonPosition := Pos(':', Line);
      if (ColonPosition <= 9) or
        not TryStrToInt(Copy(Line, 9, ColonPosition - 9), CommandNumber) then
        Continue;
      if CommandNumber > Result then
        Result := CommandNumber;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TAutomationEditorView.LoadLastSavedFile(out AErrorText: string);
var
  FileName: string;
  Content: UTF8String;
begin
  AErrorText := '';
  if FSettingsStorage = nil then
    Exit;

  FileName := FSettingsStorage.LoadLastAutomationFile;
  if FileName = '' then
    Exit;
  if not ReadAutomationTextFile(FileName, Content, AErrorText) then
  begin
    AErrorText := 'Не удалось открыть последний сценарий "' + FileName + '": ' +
      AErrorText;
    Exit;
  end;
  SetOpenedDocument(FileName, Content);
end;

function TAutomationEditorView.ConfirmClose: Boolean;
begin
  Result := ConfirmUnsavedChanges('закрытием приложения');
end;

function TAutomationEditorView.BuildCommandBlock(AIndex: Integer): string;
begin
  Result := 'command_' + IntToStr(AIndex) + ': {' + LineEnding +
    '  dispenser_names: "' + EscapeQuotedString(FDispenserEdit.Text) + '";' +
    LineEnding + '  valve_channels: "' + EscapeQuotedString(FValveEdit.Text) + '";' +
    LineEnding + '  volumes: "' + EscapeQuotedString(FVolumeEdit.Text) + '";' +
    LineEnding + '  volume_unit: "' + EscapeQuotedString(FVolumeUnitCombo.Text) + '";' +
    LineEnding + '  speeds: "' + EscapeQuotedString(FSpeedEdit.Text) + '";' +
    LineEnding + '  speed_unit: "' + EscapeQuotedString(FSpeedUnitCombo.Text) + '"' +
    LineEnding + '}';
end;

function TAutomationEditorView.EscapeQuotedString(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
end;

end.
