unit DispenserView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Spin,
  LCLType, DispenserConfig, DispenserLayout, DispenserLimits,
  DispenserResolution, VolumeProgressBar, DispenserConfigValidator;

type
  TDispenserView = class;
  TDispenserViewEvent = procedure(AView: TDispenserView) of object;
  TDispenserViewBypassEvent = function(AView: TDispenserView;
    AEnabled: Boolean): Boolean of object;
  TDispenserViewWarningEvent = procedure(AView: TDispenserView;
    const AReason: string) of object;

  TDispenserView = class
  strict private
    FPanel: TPanel;
    FNumberLabel: TStaticText;
    FNameLabel: TStaticText;
    // Borrowed configuration; its owner must outlive this view.
    FConfig: TDispenserConfig;
    FLayout: TDispenserTableLayout;
    FBypassSupported: Boolean;
    FOperationsEnabled: Boolean;
    FOperationReady: Boolean;
    FOperationActive: Boolean;
    FCommandPending: Boolean;
    FProtocolReserved: Boolean;
    FProtocolActive: Boolean;
    FSelectedCheckBox: TCheckBox;
    FValvePanel: TPanel;
    FValveButtons: TList;
    FChannelLabels: TList;
    FFillButton: TButton;
    FEmptyButton: TButton;
    FStopButton: TButton;
    FInitializeButton: TButton;
    FAspirateButton: TButton;
    FDispenseButton: TButton;
    FBypassCheckBox: TCheckBox;
    FVolumeEdit: TSpinEdit;
    FSpeedEdit: TSpinEdit;
    FEditingControl: TCustomEdit;
    FEditingText: string;
    FEditCommitted: Boolean;
    FPreviousOperationSpeed: Integer;
    FCurrentProgressBar: TVolumeProgressBar;
    FOnSelect: TDispenserViewEvent;
    FOnOperationSettingsChanged: TDispenserViewEvent;
    FOnOperationSettingsWarning: TDispenserViewWarningEvent;
    FOnFill: TDispenserViewEvent;
    FOnEmpty: TDispenserViewEvent;
    FOnAspirate: TDispenserViewEvent;
    FOnDispense: TDispenserViewEvent;
    FOnStop: TDispenserViewEvent;
    FOnInitialize: TDispenserViewEvent;
    FOnBypassChanged: TDispenserViewBypassEvent;
    FChangingBypass: Boolean;
    function GetSelected: Boolean;
    function GetSelectedChannel: Integer;
    function GetBypassActive: Boolean;
    function GetOperationsEnabled: Boolean;
    procedure SelectionChanged(Sender: TObject);
    procedure ClearFocusOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure EditEnter(Sender: TObject);
    procedure EditChanged(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OperationSettingsChanged(Sender: TObject);
    function ValidateOperationSettings(out ErrorText: string): Boolean;
    procedure FillClicked(Sender: TObject);
    procedure EmptyClicked(Sender: TObject);
    procedure AspirateClicked(Sender: TObject);
    procedure DispenseClicked(Sender: TObject);
    procedure StopClicked(Sender: TObject);
    procedure InitializeClicked(Sender: TObject);
    procedure BypassChanged(Sender: TObject);
    procedure SetBypassChecked(AValue: Boolean);
    procedure UpdateBypassControls;
  public
    constructor Create(AParent: TWinControl; ATop: Integer;
      AConfig: TDispenserConfig; const ALayout: TDispenserTableLayout;
      AOnSelect, AOnFill, AOnEmpty,
      AOnAspirate, AOnDispense, AOnStop,
      AOnInitialize: TDispenserViewEvent;
      AOnBypassChanged: TDispenserViewBypassEvent;
      AOnOperationSettingsChanged: TDispenserViewEvent;
      AOnOperationSettingsWarning: TDispenserViewWarningEvent);
    destructor Destroy; override;
    procedure SetLayout(const ALayout: TDispenserTableLayout);
    function TryGetVolume(out AVolume: Integer): Boolean;
    function TryGetSpeed(out ASpeed: Integer): Boolean;
    procedure SaveOperationSettings;
    procedure SetOperationsEnabled(AEnabled: Boolean);
    procedure SetProtocolActive(AActive: Boolean);
    procedure SetOperationReady(AReady: Boolean);
    procedure SetOperationActive(AActive: Boolean);
    procedure SetCommandPending(APending: Boolean);
    procedure SetProtocolReserved(AReserved: Boolean);
    procedure SetBypassSupported(AEnabled: Boolean);
    procedure SetBypassActive(AEnabled: Boolean);
    procedure ShowCurrentVolume(AVolume: Double; AKnown: Boolean);
    property Config: TDispenserConfig read FConfig;
    property PreviousOperationSpeed: Integer read FPreviousOperationSpeed;
    property BypassActive: Boolean read GetBypassActive;
    property OperationsEnabled: Boolean read GetOperationsEnabled;
    property OperationReady: Boolean read FOperationReady;
    property Selected: Boolean read GetSelected;
    // Zero means that no channel is selected.
    property SelectedChannel: Integer read GetSelectedChannel;
  end;

implementation

constructor TDispenserView.Create(AParent: TWinControl; ATop: Integer;
  AConfig: TDispenserConfig; const ALayout: TDispenserTableLayout;
  AOnSelect, AOnFill, AOnEmpty,
  AOnAspirate, AOnDispense, AOnStop,
  AOnInitialize: TDispenserViewEvent;
  AOnBypassChanged: TDispenserViewBypassEvent;
  AOnOperationSettingsChanged: TDispenserViewEvent;
  AOnOperationSettingsWarning: TDispenserViewWarningEvent);
var
  NumberLabel: TStaticText;
  NameLabel: TStaticText;
  ChannelLabel: TStaticText;
  RadioButton: TRadioButton;
  ChannelCount: Integer;
  SegmentWidth: Integer;
  GroupLeft: Integer;
  RadioLeft: Integer;
  OperationChannel: Integer;
  I: Integer;
begin
  inherited Create;
  FConfig := AConfig;
  FProtocolActive := False;
  FPreviousOperationSpeed := FConfig.Operation.Speed;
  FOnSelect := AOnSelect;
  FOnOperationSettingsChanged := AOnOperationSettingsChanged;
  FOnOperationSettingsWarning := AOnOperationSettingsWarning;
  FOnFill := AOnFill;
  FOnEmpty := AOnEmpty;
  FOnAspirate := AOnAspirate;
  FOnDispense := AOnDispense;
  FOnStop := AOnStop;
  FOnInitialize := AOnInitialize;
  FOnBypassChanged := AOnBypassChanged;
  FChangingBypass := False;
  FBypassSupported := False;
  FOperationsEnabled := False;
  FOperationReady := False;
  FOperationActive := False;
  FCommandPending := False;
  FProtocolReserved := False;
  FLayout := ALayout;
  FValveButtons := TList.Create;
  FChannelLabels := TList.Create;

  FPanel := TPanel.Create(AParent);
  FPanel.Parent := AParent;
  FPanel.DoubleBuffered := True;
  FPanel.ParentDoubleBuffered := True;
  FPanel.Left := TABLE_ROW_LEFT;
  FPanel.Top := ATop;
  FPanel.Width := AParent.ClientWidth - TABLE_ROW_LEFT - TABLE_RIGHT_MARGIN;
  FPanel.Height := ROW_HEIGHT - 4;
  FPanel.Anchors := [akLeft, akTop, akRight];
  FPanel.Caption := '';
  FPanel.TabStop := True;
  FPanel.OnMouseDown := @ClearFocusOnMouseDown;
  FPanel.OnMouseUp := @ClearFocusOnMouseDown;

  NumberLabel := TStaticText.Create(FPanel);
  NumberLabel.Parent := FPanel;
  NumberLabel.Left := COL_NUMBER;
  NumberLabel.Top := (FPanel.Height - 22) div 2 + 2;
  NumberLabel.Width := WIDTH_NUMBER;
  NumberLabel.Height := 22;
  NumberLabel.Alignment := taCenter;
  NumberLabel.AutoSize := False;
  NumberLabel.BorderStyle := sbsNone;
  NumberLabel.Color := FPanel.Color;
  NumberLabel.Caption := IntToStr(FConfig.Number);
  FNumberLabel := NumberLabel;

  NameLabel := TStaticText.Create(FPanel);
  NameLabel.Parent := FPanel;
  NameLabel.Left := COL_NAME;
  NameLabel.Top := (FPanel.Height - 22) div 2 + 2;
  NameLabel.Width := WIDTH_NAME;
  NameLabel.Height := 22;
  NameLabel.Alignment := taCenter;
  NameLabel.AutoSize := False;
  NameLabel.BorderStyle := sbsNone;
  NameLabel.Color := FPanel.Color;
  NameLabel.Caption := FConfig.Name;
  FNameLabel := NameLabel;

  FSelectedCheckBox := TCheckBox.Create(FPanel);
  FSelectedCheckBox.Parent := FPanel;
  FSelectedCheckBox.Left := COL_SELECTED + (WIDTH_SELECTED - 20) div 2;
  FSelectedCheckBox.Top := (FPanel.Height - 20) div 2;
  FSelectedCheckBox.Width := 20;
  FSelectedCheckBox.Height := 20;
  FSelectedCheckBox.Caption := '';
  FSelectedCheckBox.OnChange := @SelectionChanged;

  FFillButton := TButton.Create(FPanel);
  FFillButton.Parent := FPanel;
  FFillButton.Left := COL_FILL + (WIDTH_FILL - 90) div 2;
  FFillButton.Top := (FPanel.Height - 25) div 2;
  FFillButton.Width := 90;
  FFillButton.Height := 25;
  FFillButton.Caption := 'Наполнить';
  FFillButton.OnClick := @FillClicked;

  FEmptyButton := TButton.Create(FPanel);
  FEmptyButton.Parent := FPanel;
  FEmptyButton.Left := COL_EMPTY + (WIDTH_EMPTY - 90) div 2;
  FEmptyButton.Top := (FPanel.Height - 25) div 2;
  FEmptyButton.Width := 90;
  FEmptyButton.Height := 25;
  FEmptyButton.Caption := 'Опустошить';
  FEmptyButton.OnClick := @EmptyClicked;

  FValvePanel := TPanel.Create(FPanel);
  FValvePanel.Parent := FPanel;
  FValvePanel.Left := COL_VALVE;
  FValvePanel.Top := 2;
  FValvePanel.Width := WIDTH_VALVE;
  FValvePanel.Height := FPanel.Height - 4;
  FValvePanel.Caption := '';
  FValvePanel.BevelOuter := bvNone;

  ChannelCount := FConfig.ChannelCount;
  if ChannelCount < MIN_CHANNEL_COUNT then
    ChannelCount := MIN_CHANNEL_COUNT;
  if ChannelCount > MAX_CHANNEL_COUNT then
    ChannelCount := MAX_CHANNEL_COUNT;
  OperationChannel := FConfig.Operation.Channel;
  if (OperationChannel < 1) or (OperationChannel > ChannelCount) then
    OperationChannel := 1;
  SegmentWidth := 14;
  GroupLeft := (WIDTH_VALVE - ChannelCount * SegmentWidth) div 2;

  for I := 1 to ChannelCount do
  begin
    RadioLeft := GroupLeft + (I - 1) * SegmentWidth;

    ChannelLabel := TStaticText.Create(FValvePanel);
    ChannelLabel.Parent := FValvePanel;
    ChannelLabel.Left := RadioLeft;
    ChannelLabel.Top := (FValvePanel.Height - 31) div 2;
    ChannelLabel.Width := 14;
    ChannelLabel.Height := 11;
    ChannelLabel.AutoSize := False;
    ChannelLabel.Alignment := taCenter;
    ChannelLabel.Font.Size := 7;
    ChannelLabel.BorderStyle := sbsNone;
    ChannelLabel.Color := FValvePanel.Color;
    ChannelLabel.Caption := IntToStr(I);
    FChannelLabels.Add(ChannelLabel);

    RadioButton := TRadioButton.Create(FValvePanel);
    RadioButton.Parent := FValvePanel;
    RadioButton.Left := RadioLeft;
    RadioButton.Top := ChannelLabel.Top + ChannelLabel.Height;
    RadioButton.Width := 14;
    RadioButton.Height := 20;
    RadioButton.Caption := '';
    RadioButton.Checked := I = OperationChannel;
    RadioButton.OnClick := @OperationSettingsChanged;
    FValveButtons.Add(RadioButton);
  end;

  FAspirateButton := TButton.Create(FPanel);
  FAspirateButton.Parent := FPanel;
  FAspirateButton.Left := COL_ASPIRATE + (WIDTH_ASPIRATE - 80) div 2;
  FAspirateButton.Top := (FPanel.Height - 25) div 2;
  FAspirateButton.Width := 80;
  FAspirateButton.Height := 25;
  FAspirateButton.Caption := 'Набрать';
  FAspirateButton.OnClick := @AspirateClicked;

  FDispenseButton := TButton.Create(FPanel);
  FDispenseButton.Parent := FPanel;
  FDispenseButton.Left := COL_DISPENSE + (WIDTH_DISPENSE - 90) div 2;
  FDispenseButton.Top := (FPanel.Height - 25) div 2;
  FDispenseButton.Width := 90;
  FDispenseButton.Height := 25;
  FDispenseButton.Caption := 'Дозировать';
  FDispenseButton.OnClick := @DispenseClicked;

  FBypassCheckBox := TCheckBox.Create(FPanel);
  FBypassCheckBox.Parent := FPanel;
  FBypassCheckBox.Left := COL_BYPASS + (WIDTH_BYPASS - 20) div 2;
  FBypassCheckBox.Top := (FPanel.Height - 20) div 2;
  FBypassCheckBox.Width := 20;
  FBypassCheckBox.Height := 20;
  FBypassCheckBox.Caption := 'Байпас';
  FBypassCheckBox.Checked := False;
  FBypassCheckBox.OnClick := @BypassChanged;
  FBypassCheckBox.Caption := '';

  FVolumeEdit := TSpinEdit.Create(FPanel);
  FVolumeEdit.Parent := FPanel;
  FVolumeEdit.Left := COL_VOLUME + (WIDTH_VOLUME - 68) div 2;
  FVolumeEdit.Top := (FPanel.Height - 24) div 2;
  FVolumeEdit.Width := 68;
  FVolumeEdit.Height := 24;
  FVolumeEdit.MinValue := 1;
  FVolumeEdit.MaxValue := FConfig.Volume;
  FVolumeEdit.Value := FConfig.Operation.Volume;
  FVolumeEdit.Alignment := taLeftJustify;
  FVolumeEdit.OnEnter := @EditEnter;
  FVolumeEdit.OnChange := @EditChanged;
  FVolumeEdit.OnKeyDown := @EditKeyDown;
  FVolumeEdit.OnExit := @OperationSettingsChanged;

  FSpeedEdit := TSpinEdit.Create(FPanel);
  FSpeedEdit.Parent := FPanel;
  FSpeedEdit.Left := COL_SPEED + (WIDTH_SPEED - 68) div 2;
  FSpeedEdit.Top := (FPanel.Height - 24) div 2;
  FSpeedEdit.Width := 68;
  FSpeedEdit.Height := 24;
  FSpeedEdit.MinValue := MinimumVolumeRate(FConfig.Volume, FConfig.StepCount);
  FSpeedEdit.MaxValue := FConfig.MaxFlowRate;
  FSpeedEdit.Value := FConfig.Operation.Speed;
  FSpeedEdit.Alignment := taLeftJustify;
  FSpeedEdit.OnEnter := @EditEnter;
  FSpeedEdit.OnChange := @EditChanged;
  FSpeedEdit.OnKeyDown := @EditKeyDown;
  FSpeedEdit.OnExit := @OperationSettingsChanged;

  FCurrentProgressBar := TVolumeProgressBar.Create(FPanel);
  FCurrentProgressBar.Parent := FPanel;
  FCurrentProgressBar.Left := COL_CURRENT + (WIDTH_CURRENT - 140) div 2;
  FCurrentProgressBar.Top := (FPanel.Height - 20) div 2;
  FCurrentProgressBar.Width := 140;
  FCurrentProgressBar.Height := 20;
  FCurrentProgressBar.Max := FConfig.Volume;
  FCurrentProgressBar.UnitCaption := 'мкл';

  FStopButton := TButton.Create(FPanel);
  FStopButton.Parent := FPanel;
  FStopButton.Top := (FPanel.Height - 25) div 2;
  FStopButton.Width := 82;
  FStopButton.Height := 25;
  FStopButton.Caption := 'Остановить';
  FStopButton.OnClick := @StopClicked;

  FInitializeButton := TButton.Create(FPanel);
  FInitializeButton.Parent := FPanel;
  FInitializeButton.Top := (FPanel.Height - 25) div 2;
  FInitializeButton.Width := 112;
  FInitializeButton.Height := 25;
  FInitializeButton.Caption := 'Инициализировать';
  FInitializeButton.OnClick := @InitializeClicked;

  UpdateBypassControls;
  SetLayout(ALayout);

  NumberLabel.BringToFront;
  NameLabel.BringToFront;
end;

procedure TDispenserView.SetLayout(const ALayout: TDispenserTableLayout);
var
  I: Integer;
  SegmentWidth: Integer;
  GroupLeft: Integer;
  ChannelLeft: Integer;
begin
  FLayout := ALayout;
  FPanel.Left := FLayout.RowLeft;
  FPanel.Width := FLayout.RowWidth;

  FNumberLabel.Left := FLayout.Columns[dcNumber].Left;
  FNumberLabel.Width := FLayout.Columns[dcNumber].Width;
  FNameLabel.Left := FLayout.Columns[dcName].Left;
  FNameLabel.Width := FLayout.Columns[dcName].Width;
  FSelectedCheckBox.Left := FLayout.Columns[dcSelected].Left +
    (FLayout.Columns[dcSelected].Width - FSelectedCheckBox.Width) div 2;
  FFillButton.Left := FLayout.Columns[dcFill].Left +
    (FLayout.Columns[dcFill].Width - FFillButton.Width) div 2;
  FEmptyButton.Left := FLayout.Columns[dcEmpty].Left +
    (FLayout.Columns[dcEmpty].Width - FEmptyButton.Width) div 2;
  FValvePanel.Left := FLayout.Columns[dcValve].Left;
  FValvePanel.Width := FLayout.Columns[dcValve].Width;
  FAspirateButton.Left := FLayout.Columns[dcAspirate].Left +
    (FLayout.Columns[dcAspirate].Width - FAspirateButton.Width) div 2;
  FDispenseButton.Left := FLayout.Columns[dcDispense].Left +
    (FLayout.Columns[dcDispense].Width - FDispenseButton.Width) div 2;
  FBypassCheckBox.Left := FLayout.Columns[dcBypass].Left +
    (FLayout.Columns[dcBypass].Width - FBypassCheckBox.Width) div 2;
  FVolumeEdit.Left := FLayout.Columns[dcVolume].Left +
    (FLayout.Columns[dcVolume].Width - FVolumeEdit.Width) div 2;
  FSpeedEdit.Left := FLayout.Columns[dcSpeed].Left +
    (FLayout.Columns[dcSpeed].Width - FSpeedEdit.Width) div 2;
  FCurrentProgressBar.Left := FLayout.Columns[dcCurrent].Left +
    (FLayout.Columns[dcCurrent].Width - FCurrentProgressBar.Width) div 2;
  FStopButton.Left := FLayout.Columns[dcStop].Left +
    (FLayout.Columns[dcStop].Width - FStopButton.Width) div 2;
  FInitializeButton.Left := FLayout.Columns[dcInitialize].Left +
    (FLayout.Columns[dcInitialize].Width - FInitializeButton.Width) div 2;

  SegmentWidth := 14;
  GroupLeft := (FValvePanel.Width - FChannelLabels.Count * SegmentWidth) div 2;
  for I := 0 to FChannelLabels.Count - 1 do
  begin
    ChannelLeft := GroupLeft + I * SegmentWidth;
    TStaticText(FChannelLabels[I]).Left := ChannelLeft;
    TRadioButton(FValveButtons[I]).Left := ChannelLeft;
  end;
end;

destructor TDispenserView.Destroy;
begin
  FChannelLabels.Free;
  FValveButtons.Free;
  FPanel.Free;
  inherited Destroy;
end;

function TDispenserView.GetSelected: Boolean;
begin
  Result := FSelectedCheckBox.Checked;
end;

function TDispenserView.GetSelectedChannel: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FValveButtons.Count - 1 do
    if TRadioButton(FValveButtons[I]).Checked then
      Exit(I + 1);
end;

function TDispenserView.TryGetVolume(out AVolume: Integer): Boolean;
begin
  AVolume := 0;
  Result := TryStrToInt(Trim(FVolumeEdit.Text), AVolume) and
    (AVolume > 0) and (AVolume <= FConfig.Volume);
end;

function TDispenserView.TryGetSpeed(out ASpeed: Integer): Boolean;
begin
  ASpeed := 0;
  Result := TryStrToInt(Trim(FSpeedEdit.Text), ASpeed) and
    (ASpeed >= MinimumVolumeRate(FConfig.Volume, FConfig.StepCount));
  if Result then
    Result := ASpeed <= FConfig.MaxFlowRate;
end;

procedure TDispenserView.SaveOperationSettings;
var
  Volume: Integer;
  Speed: Integer;
  Channel: Integer;
begin
  if TryGetVolume(Volume) then
    FConfig.Operation.Volume := Volume;
  FVolumeEdit.Text := IntToStr(FConfig.Operation.Volume);
  if TryGetSpeed(Speed) then
    FConfig.Operation.Speed := Speed;
  FSpeedEdit.Text := IntToStr(FConfig.Operation.Speed);

  Channel := GetSelectedChannel;
  if (Channel >= 1) and (Channel <= FConfig.ChannelCount) then
    FConfig.Operation.Channel := Channel;
end;

procedure TDispenserView.SetBypassChecked(AValue: Boolean);
begin
  if FBypassCheckBox.Checked = AValue then
    Exit;

  FChangingBypass := True;
  try
    FBypassCheckBox.Checked := AValue;
  finally
    FChangingBypass := False;
  end;
end;

procedure TDispenserView.SetOperationsEnabled(AEnabled: Boolean);
begin
  FOperationsEnabled := AEnabled;
  if not AEnabled then
    SetBypassChecked(False);
  UpdateBypassControls;
end;

procedure TDispenserView.SetProtocolActive(AActive: Boolean);
begin
  if FProtocolActive = AActive then
    Exit;
  FProtocolActive := AActive;
  UpdateBypassControls;
end;

procedure TDispenserView.SetOperationReady(AReady: Boolean);
begin
  FOperationReady := AReady;
  if not AReady then
    SetBypassChecked(False);
  UpdateBypassControls;
end;

procedure TDispenserView.SetOperationActive(AActive: Boolean);
begin
  FOperationActive := AActive;
  UpdateBypassControls;
end;

procedure TDispenserView.SetCommandPending(APending: Boolean);
begin
  FCommandPending := APending;
  UpdateBypassControls;
end;

procedure TDispenserView.SetProtocolReserved(AReserved: Boolean);
begin
  FProtocolReserved := AReserved;
  UpdateBypassControls;
end;

procedure TDispenserView.SetBypassSupported(AEnabled: Boolean);
begin
  FBypassSupported := AEnabled;
  if not AEnabled then
    SetBypassChecked(False);
  UpdateBypassControls;
end;

procedure TDispenserView.ShowCurrentVolume(AVolume: Double; AKnown: Boolean);
var
  CurrentVolume: Integer;
begin
  FCurrentProgressBar.Max := FConfig.Volume;
  FCurrentProgressBar.Known := AKnown;
  if not AKnown then
    Exit;

  CurrentVolume := Round(AVolume);
  if CurrentVolume < 0 then
    CurrentVolume := 0;
  if CurrentVolume > FCurrentProgressBar.Max then
    CurrentVolume := FCurrentProgressBar.Max;
  FCurrentProgressBar.Position := CurrentVolume;
end;

procedure TDispenserView.SelectionChanged(Sender: TObject);
begin
  if Assigned(FOnSelect) then
    FOnSelect(Self);
end;

procedure TDispenserView.ClearFocusOnMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TWinControl then
  begin
    TWinControl(Sender).TabStop := True;
    TWinControl(Sender).SetFocus;
  end;
end;

procedure TDispenserView.EditEnter(Sender: TObject);
begin
  if Sender is TCustomEdit then
  begin
    FEditingControl := TCustomEdit(Sender);
    FEditingText := FEditingControl.Text;
    FEditCommitted := False;
  end;
end;

procedure TDispenserView.EditChanged(Sender: TObject);
begin
  if Sender = FEditingControl then
    FEditCommitted := False;
end;

procedure TDispenserView.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if not (Sender is TCustomEdit) then
    Exit;

  if Key = VK_ESCAPE then
  begin
    if not FEditCommitted then
      TCustomEdit(Sender).Text := FEditingText;
    TWinControl(TCustomEdit(Sender).Parent).SetFocus;
    Key := 0;
    Exit;
  end;

  if Key = VK_RETURN then
  begin
    OperationSettingsChanged(Sender);
    FEditCommitted := True;
    FEditingText := TCustomEdit(Sender).Text;
    TCustomEdit(Sender).SelectAll;
    Key := 0;
  end;
end;

function TDispenserView.ValidateOperationSettings(
  out ErrorText: string): Boolean;
var
  Volume: Integer;
  Speed: Integer;
  MinimumVolumeRateValue: Integer;
  MaximumVolumeRateValue: Integer;
begin
  ErrorText := '';
  MinimumVolumeRateValue := MinimumVolumeRate(FConfig.Volume, FConfig.StepCount);
  MaximumVolumeRateValue := FConfig.MaxFlowRate;

  if not TryStrToInt(Trim(FVolumeEdit.Text), Volume) or (Volume <= 0) then
  begin
    ErrorText := 'Объём набора должен быть положительным целым числом.';
    Exit(False);
  end;

  if Volume > FConfig.Volume then
  begin
    ErrorText := Format(
      'Объём набора не может превышать объём шприца (%d мкл).',
      [FConfig.Volume]);
    Exit(False);
  end;

  if not TryStrToInt(Trim(FSpeedEdit.Text), Speed) or
    (Speed < MinimumVolumeRateValue) then
  begin
    ErrorText := Format('Скорость должна быть целым числом от %d до %d мкл/с.',
      [MinimumVolumeRateValue, MaximumVolumeRateValue]);
    Exit(False);
  end;

  if Speed > MaximumVolumeRateValue then
  begin
    ErrorText := Format(
      'Скорость не может быть выше максимальной скорости дозатора (%d мкл/с).',
      [MaximumVolumeRateValue]);
    Exit(False);
  end;

  Result := True;
end;

procedure TDispenserView.OperationSettingsChanged(Sender: TObject);
var
  ErrorText: string;
  Speed: Integer;
  AdjustedSpeed: Integer;
begin
  if FEditCommitted then
    Exit;

  if TryStrToInt(Trim(FSpeedEdit.Text), Speed) then
  begin
    AdjustedSpeed := ClampVolumeRateToMaximum(Speed, FConfig.MaxFlowRate);
    if AdjustedSpeed <> Speed then
      FSpeedEdit.Text := IntToStr(AdjustedSpeed);
  end;

  FPreviousOperationSpeed := FConfig.Operation.Speed;
  if ValidateOperationSettings(ErrorText) then
  begin
    SaveOperationSettings;
    if Assigned(FOnOperationSettingsChanged) then
      FOnOperationSettingsChanged(Self);
  end
  else
  begin
    SaveOperationSettings;
    if Assigned(FOnOperationSettingsWarning) then
      FOnOperationSettingsWarning(Self, ErrorText);
  end;
  FEditCommitted := True;
  if Sender is TCustomEdit then
    FEditingText := TCustomEdit(Sender).Text;
end;

procedure TDispenserView.FillClicked(Sender: TObject);
begin
  if Assigned(FOnFill) then
    FOnFill(Self);
end;

procedure TDispenserView.EmptyClicked(Sender: TObject);
begin
  if Assigned(FOnEmpty) then
    FOnEmpty(Self);
end;

procedure TDispenserView.AspirateClicked(Sender: TObject);
begin
  if Assigned(FOnAspirate) then
    FOnAspirate(Self);
end;

procedure TDispenserView.DispenseClicked(Sender: TObject);
begin
  if Assigned(FOnDispense) then
    FOnDispense(Self);
end;

procedure TDispenserView.StopClicked(Sender: TObject);
begin
  if Assigned(FOnStop) then
    FOnStop(Self);
end;

procedure TDispenserView.InitializeClicked(Sender: TObject);
begin
  if Assigned(FOnInitialize) then
    FOnInitialize(Self);
end;

function TDispenserView.GetBypassActive: Boolean;
begin
  Result := FBypassCheckBox.Checked;
end;

function TDispenserView.GetOperationsEnabled: Boolean;
begin
  Result := FOperationsEnabled and FOperationReady and not FOperationActive and
    not FCommandPending and not FProtocolReserved;
end;

procedure TDispenserView.SetBypassActive(AEnabled: Boolean);
begin
  SetBypassChecked(AEnabled);
  UpdateBypassControls;
end;

procedure TDispenserView.UpdateBypassControls;
var
  CanRequestOperation: Boolean;
  CanOperate: Boolean;
  CanChangeOperation: Boolean;
begin
  CanRequestOperation := FOperationsEnabled;
  CanOperate := FOperationsEnabled;
  CanChangeOperation := CanRequestOperation;
  FPanel.Enabled := True;
  FSelectedCheckBox.Enabled := CanRequestOperation;
  FVolumeEdit.Enabled := CanChangeOperation;
  FSpeedEdit.Enabled := CanOperate;
  FBypassCheckBox.Enabled := CanRequestOperation and FOperationReady and
    FBypassSupported;
  FFillButton.Enabled := CanRequestOperation and not FBypassCheckBox.Checked;
  FEmptyButton.Enabled := CanRequestOperation and not FBypassCheckBox.Checked;
  FAspirateButton.Enabled := CanRequestOperation and not FBypassCheckBox.Checked;
  FDispenseButton.Enabled := CanRequestOperation and not FBypassCheckBox.Checked;
  FValvePanel.Enabled := CanChangeOperation and not FBypassCheckBox.Checked;
  FStopButton.Enabled := FOperationsEnabled and FOperationActive;
  FInitializeButton.Enabled := True;
end;

procedure TDispenserView.BypassChanged(Sender: TObject);
var
  ErrorText: string;
  Accepted: Boolean;
begin
  if FChangingBypass then
    Exit;

  if FBypassCheckBox.Checked then
  begin
    if not TDispenserConfigValidator.CanEnableBypass(FConfig,
      GetSelectedChannel, FBypassSupported, ErrorText) then
    begin
      SetBypassChecked(False);
      if Assigned(FOnOperationSettingsWarning) then
        FOnOperationSettingsWarning(Self, ErrorText);
      UpdateBypassControls;
      Exit;
    end;
  end;

  Accepted := True;
  if Assigned(FOnBypassChanged) then
    Accepted := FOnBypassChanged(Self, FBypassCheckBox.Checked);
  if not Accepted then
  begin
    SetBypassChecked(not FBypassCheckBox.Checked);
    if Assigned(FOnOperationSettingsWarning) then
      FOnOperationSettingsWarning(Self, 'Дозатор отклонил изменение состояния байпаса.');
  end;
  UpdateBypassControls;
end;
end.
