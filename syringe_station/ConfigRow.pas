unit ConfigRow;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Dialogs, Spin,
  LCLType, DispenserConfig, DispenserConfigValidator, DispenserLimits,
  DispenserResolution, DispenserRuntimeState;

type
  TConfigRow = class
  private
    FIsNew: Boolean;
    FOperation: TDispenserOperationSettings;
    FOnChanged: TNotifyEvent;
    FEditingControl: TCustomEdit;
    FEditingText: string;
    FEditCommitted: Boolean;
    FUpdatingSpeedBounds: Boolean;
    FConnected: Boolean;
    FReadOnly: Boolean;
    FRuntimeStates: TDispenserRuntimeStates;
    FOriginalAddress: Integer;
    FRestoringEdit: Boolean;
    FLiquidWarningShown: Boolean;
    function AddLabel(const ACaption: string; ALeft, ATop, AWidth: Integer): TLabel;
    function AddEdit(const AText: string; ALeft, ATop, AWidth: Integer): TEdit;
    function AddSpinEdit(AValue, AMinValue, AMaxValue,
      ALeft, ATop, AWidth: Integer): TSpinEdit;
    procedure ConfigureEditable(AEdit: TCustomEdit);
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ClearFocusOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Changed(Sender: TObject);
    procedure ChannelCountChanged(Sender: TObject);
    procedure UpdateSpeedBounds;
    function HasKnownLiquid: Boolean;
    function RejectChange(Sender: TObject): Boolean;
    procedure RefreshEditability;
  public
    Panel: TPanel;
    EditNumber: TSpinEdit;
    EditName: TEdit;
    EditAddress: TEdit;
    EditVolume: TSpinEdit;
    EditChannelCount: TSpinEdit;
    EditStepCount: TSpinEdit;

    EditIntakeChannel: TSpinEdit;
    EditSpeed: TSpinEdit;
    MoveUpButton: TButton;
    MoveDownButton: TButton;
    DeleteButton: TButton;

    constructor Create(AParent: TWinControl; AIndex: Integer;
      AConfig: TDispenserConfig; AIsNew: Boolean; AOnDelete, AOnMoveUp,
      AOnMoveDown, AOnChanged: TNotifyEvent; AConnected: Boolean;
      ARuntimeStates: TDispenserRuntimeStates);
    procedure SetReadOnly(AReadOnly: Boolean);
    function CanDelete: Boolean;
    function ReadInto(AConfig: TDispenserConfig; out ErrorText: string): Boolean;
  end;

const
  CONFIG_ROW_HEIGHT = 270;
  CONFIG_ROW_SPACING = 8;

implementation

const
  FIELD_LEFT = 175;
  FIELD_WIDTH = 120;
  ACTION_LEFT = 390;
  ACTION_WIDTH = 110;
  ACTION_HEIGHT = 25;
  ACTION_GAP = 5;

function TConfigRow.AddLabel(const ACaption: string; ALeft, ATop,
  AWidth: Integer): TLabel;
begin
  Result := TLabel.Create(Panel);
  Result.Parent := Panel;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Caption := ACaption;
end;

function TConfigRow.AddEdit(const AText: string; ALeft, ATop,
  AWidth: Integer): TEdit;
begin
  Result := TEdit.Create(Panel);
  Result.Parent := Panel;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := 23;
  Result.Alignment := taLeftJustify;
  Result.Text := AText;
end;

function TConfigRow.AddSpinEdit(AValue, AMinValue, AMaxValue, ALeft, ATop,
  AWidth: Integer): TSpinEdit;
begin
  Result := TSpinEdit.Create(Panel);
  Result.Parent := Panel;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := 23;
  Result.Alignment := taLeftJustify;
  Result.MinValue := AMinValue;
  Result.MaxValue := AMaxValue;
  if AValue < Result.MinValue then
    AValue := Result.MinValue;
  if AValue > Result.MaxValue then
    AValue := Result.MaxValue;
  Result.Value := AValue;
end;

procedure TConfigRow.ConfigureEditable(AEdit: TCustomEdit);
begin
  AEdit.OnEnter := @EditEnter;
  AEdit.OnExit := @EditExit;
  AEdit.OnKeyDown := @EditKeyDown;
end;

procedure TConfigRow.ClearFocusOnMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TWinControl then
  begin
    TWinControl(Sender).TabStop := True;
    TWinControl(Sender).SetFocus;
  end;
end;

procedure TConfigRow.EditEnter(Sender: TObject);
begin
  if Sender is TCustomEdit then
  begin
    FEditingControl := TCustomEdit(Sender);
    FEditingText := FEditingControl.Text;
    FEditCommitted := False;
    FLiquidWarningShown := False;
  end;
end;

procedure TConfigRow.EditExit(Sender: TObject);
begin
  if Sender = FEditingControl then
  begin
    FEditingControl := nil;
    FLiquidWarningShown := False;
  end;
end;

procedure TConfigRow.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  ParentControl: TWinControl;
begin
  if not (Sender is TCustomEdit) then
    Exit;

  if Key = VK_ESCAPE then
  begin
    if not FEditCommitted then
    begin
      TCustomEdit(Sender).Text := FEditingText;
      Changed(Sender);
    end;
    ParentControl := TWinControl(TCustomEdit(Sender).Parent);
    ParentControl.SetFocus;
    Key := 0;
    Exit;
  end;

  if Key = VK_RETURN then
  begin
    Changed(Sender);
    FEditCommitted := True;
    FEditingText := TCustomEdit(Sender).Text;
    TCustomEdit(Sender).SelectAll;
    Key := 0;
  end;
end;

constructor TConfigRow.Create(AParent: TWinControl; AIndex: Integer;
  AConfig: TDispenserConfig; AIsNew: Boolean; AOnDelete, AOnMoveUp,
  AOnMoveDown, AOnChanged: TNotifyEvent; AConnected: Boolean;
  ARuntimeStates: TDispenserRuntimeStates);
var
  ActionTop: Integer;
begin
  FIsNew := AIsNew;
  FOperation := AConfig.Operation;
  FOnChanged := AOnChanged;
  FConnected := AConnected;
  FRuntimeStates := ARuntimeStates;
  FOriginalAddress := AConfig.Address;
  Panel := TPanel.Create(AParent);
  Panel.Parent := AParent;
  Panel.DoubleBuffered := True;
  Panel.ParentDoubleBuffered := True;
  Panel.Left := 8;
  Panel.Top := 0;
  Panel.Width := AParent.ClientWidth - 16;
  Panel.Height := CONFIG_ROW_HEIGHT;
  Panel.Anchors := [akLeft, akTop, akRight];
  Panel.Caption := '';
  Panel.TabStop := True;
  Panel.OnMouseDown := @ClearFocusOnMouseDown;
  Panel.OnMouseUp := @ClearFocusOnMouseDown;

  AddLabel('Порядковый номер', 12, 12, 130);
  EditNumber := AddSpinEdit(AConfig.Number, MIN_DISPENSER_VALUE,
    MAX_DISPENSER_VALUE, FIELD_LEFT, 8, FIELD_WIDTH);
  ConfigureEditable(EditNumber);
  EditNumber.OnChange := @Changed;

  AddLabel('Адрес', 12, 44, 130);
  EditAddress := AddEdit(IntToStr(AConfig.Address), FIELD_LEFT, 40, FIELD_WIDTH);
  ConfigureEditable(EditAddress);
  EditAddress.OnChange := @Changed;

  AddLabel('Имя', 12, 76, 130);
  EditName := AddEdit(AConfig.Name, FIELD_LEFT, 72, FIELD_WIDTH);
  ConfigureEditable(EditName);
  EditName.OnChange := @Changed;

  AddLabel('Объём шприца (мкл)', 12, 108, 130);
  EditVolume := AddSpinEdit(AConfig.Volume, 1, High(Integer),
    FIELD_LEFT, 104, FIELD_WIDTH);
  EditVolume.Increment := 50;
  ConfigureEditable(EditVolume);
  EditVolume.OnChange := @Changed;

  AddLabel('Количество шагов', 12, 140, 130);
  EditStepCount := AddSpinEdit(AConfig.StepCount, 1, High(Integer),
    FIELD_LEFT, 136, FIELD_WIDTH);
  ConfigureEditable(EditStepCount);
  EditStepCount.OnChange := @Changed;

  AddLabel('Макс. скорость (мкл/с)', 12, 172, 155);
  EditSpeed := AddSpinEdit(AConfig.MaxFlowRate,
    MinimumVolumeRate(AConfig.Volume, AConfig.StepCount),
    MaximumVolumeRate(MAX_SPEED, AConfig.Volume, AConfig.StepCount),
    FIELD_LEFT, 168, FIELD_WIDTH);
  ConfigureEditable(EditSpeed);
  EditSpeed.OnChange := @Changed;

  AddLabel('Количество каналов', 12, 204, 130);
  EditChannelCount := AddSpinEdit(AConfig.ChannelCount, MIN_CHANNEL_COUNT,
    MAX_CHANNEL_COUNT, FIELD_LEFT, 200, FIELD_WIDTH);
  ConfigureEditable(EditChannelCount);
  EditChannelCount.OnChange := @ChannelCountChanged;

  AddLabel('Канал забора в шприц', 12, 236, 130);
  EditIntakeChannel := AddSpinEdit(AConfig.IntakeChannel, MIN_CHANNEL_NUMBER,
    MAX_CHANNEL_COUNT, FIELD_LEFT, 232, FIELD_WIDTH);
  ConfigureEditable(EditIntakeChannel);
  EditIntakeChannel.OnChange := @Changed;
  EditIntakeChannel.MaxValue := EditChannelCount.Value;
  if EditIntakeChannel.Value > EditIntakeChannel.MaxValue then
    EditIntakeChannel.Value := EditIntakeChannel.MaxValue;

  ActionTop := (Panel.Height - (3 * ACTION_HEIGHT + 2 * ACTION_GAP)) div 2;

  MoveUpButton := TButton.Create(Panel);
  MoveUpButton.Parent := Panel;
  MoveUpButton.Left := ACTION_LEFT;
  MoveUpButton.Top := ActionTop;
  MoveUpButton.Width := ACTION_WIDTH;
  MoveUpButton.Height := ACTION_HEIGHT;
  MoveUpButton.Caption := 'Вверх';
  MoveUpButton.Tag := AIndex;
  MoveUpButton.OnClick := AOnMoveUp;

  MoveDownButton := TButton.Create(Panel);
  MoveDownButton.Parent := Panel;
  MoveDownButton.Left := ACTION_LEFT;
  MoveDownButton.Top := ActionTop + 2 * (ACTION_HEIGHT + ACTION_GAP);
  MoveDownButton.Width := ACTION_WIDTH;
  MoveDownButton.Height := ACTION_HEIGHT;
  MoveDownButton.Caption := 'Вниз';
  MoveDownButton.Tag := AIndex;
  MoveDownButton.OnClick := AOnMoveDown;

  DeleteButton := TButton.Create(Panel);
  DeleteButton.Parent := Panel;
  DeleteButton.Left := ACTION_LEFT;
  DeleteButton.Top := ActionTop + ACTION_HEIGHT + ACTION_GAP;
  DeleteButton.Width := ACTION_WIDTH;
  DeleteButton.Height := ACTION_HEIGHT;
  DeleteButton.Caption := 'Удалить';
  DeleteButton.Tag := AIndex;
  DeleteButton.OnClick := AOnDelete;

  RefreshEditability;
end;

function TConfigRow.HasKnownLiquid: Boolean;
var
  Address: Integer;
  State: TDispenserRuntimeState;
begin
  Result := False;
  if not FConnected or (FRuntimeStates = nil) then
    Exit;

  State := FRuntimeStates.Items[FOriginalAddress];
  if (State <> nil) and State.CurrentVolumeKnown and
    (State.CurrentVolume > 0) then
    Exit(True);

  if TryStrToInt(Trim(EditAddress.Text), Address) and
    (Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) and
    (Address <> FOriginalAddress) then
  begin
    State := FRuntimeStates.Items[Address];
    Result := (State <> nil) and State.CurrentVolumeKnown and
      (State.CurrentVolume > 0);
  end;
end;

function TConfigRow.CanDelete: Boolean;
begin
  Result := not HasKnownLiquid;
  if not Result then
    ShowMessage('Сначала опустошите дозатор или переинициализируйте его.');
end;

function TConfigRow.RejectChange(Sender: TObject): Boolean;
begin
  Result := HasKnownLiquid and not FRestoringEdit;
  if not Result then
    Exit;

  if not FLiquidWarningShown then
  begin
    ShowMessage('Сначала опустошите дозатор или переинициализируйте его.');
    FLiquidWarningShown := True;
  end;

  if Sender is TCustomEdit then
  begin
    FRestoringEdit := True;
    try
      TCustomEdit(Sender).Text := FEditingText;
    finally
      FRestoringEdit := False;
    end;
  end;
end;

procedure TConfigRow.RefreshEditability;
begin
  EditNumber.Enabled := not FReadOnly;
  EditName.Enabled := not FReadOnly;
  EditAddress.Enabled := not FReadOnly;
  EditVolume.Enabled := not FReadOnly;
  EditChannelCount.Enabled := not FReadOnly;
  EditStepCount.Enabled := not FReadOnly;
  EditIntakeChannel.Enabled := not FReadOnly;
  EditSpeed.Enabled := not FReadOnly;
  DeleteButton.Enabled := not FReadOnly and not HasKnownLiquid;
end;

procedure TConfigRow.Changed(Sender: TObject);
begin
  if FUpdatingSpeedBounds or FRestoringEdit then
    Exit;
  if RejectChange(Sender) then
    Exit;
  if Sender = FEditingControl then
    FEditCommitted := False;
  if (Sender = EditVolume) or (Sender = EditStepCount) then
    UpdateSpeedBounds;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TConfigRow.UpdateSpeedBounds;
var
  SyringeVolume: Integer;
  StepCount: Integer;
  MinimumRate: Integer;
  MaximumRate: Integer;
begin
  if not TryStrToInt(Trim(EditVolume.Text), SyringeVolume) or
    not TryStrToInt(Trim(EditStepCount.Text), StepCount) or
    (SyringeVolume <= 0) or (StepCount <= 0) then
    Exit;

  MinimumRate := MinimumVolumeRate(SyringeVolume, StepCount);
  MaximumRate := MaximumVolumeRate(MAX_SPEED, SyringeVolume, StepCount);
  if MaximumRate < MinimumRate then
    MaximumRate := MinimumRate;

  FUpdatingSpeedBounds := True;
  try
    EditSpeed.MaxValue := MaximumRate;
    EditSpeed.MinValue := MinimumRate;
    EditSpeed.Value := MaximumRate;
  finally
    FUpdatingSpeedBounds := False;
  end;
end;

procedure TConfigRow.SetReadOnly(AReadOnly: Boolean);
begin
  FReadOnly := AReadOnly;
  MoveUpButton.Enabled := not AReadOnly and MoveUpButton.Enabled;
  MoveDownButton.Enabled := not AReadOnly and MoveDownButton.Enabled;
  RefreshEditability;
end;

procedure TConfigRow.ChannelCountChanged(Sender: TObject);
begin
  if RejectChange(Sender) then
    Exit;
  if EditIntakeChannel = nil then
    Exit;

  EditIntakeChannel.MaxValue := EditChannelCount.Value;
  if EditIntakeChannel.Value > EditIntakeChannel.MaxValue then
    EditIntakeChannel.Value := EditIntakeChannel.MaxValue;
  Changed(Sender);
end;
function TConfigRow.ReadInto(AConfig: TDispenserConfig;
  out ErrorText: string): Boolean;
var
  Value: Integer;
  MinimumRate: Integer;
  MaximumRate: Integer;
begin
  ErrorText := '';

  if not TryStrToInt(Trim(EditNumber.Text), Value) then
  begin
    ErrorText := 'порядковый номер должен быть от 1 до 15';
    Exit(False);
  end;
  AConfig.Number := Value;

  AConfig.Name := Trim(EditName.Text);

  if not TryStrToInt(Trim(EditAddress.Text), Value) then
  begin
    ErrorText := 'адрес должен быть от 1 до 15';
    Exit(False);
  end;
  AConfig.Address := Value;

  if not TryStrToInt(Trim(EditVolume.Text), Value) then
  begin
    ErrorText := 'объём должен быть больше нуля';
    Exit(False);
  end;
  AConfig.Volume := Value;

  if not TryStrToInt(Trim(EditChannelCount.Text), Value) then
  begin
    ErrorText := 'количество каналов должно быть от 1 до 11';
    Exit(False);
  end;
  AConfig.ChannelCount := Value;

  if not TryStrToInt(Trim(EditStepCount.Text), Value) then
  begin
    ErrorText := 'количество шагов должно быть больше нуля';
    Exit(False);
  end;
  AConfig.StepCount := Value;

  if not TryStrToInt(Trim(EditIntakeChannel.Text), Value) then
  begin
    ErrorText := 'канал забора выходит за диапазон каналов';
    Exit(False);
  end;
  AConfig.IntakeChannel := Value;

  MinimumRate := MinimumVolumeRate(AConfig.Volume, AConfig.StepCount);
  MaximumRate := MaximumVolumeRate(MAX_SPEED, AConfig.Volume,
    AConfig.StepCount);
  if not TryStrToInt(Trim(EditSpeed.Text), Value) or
    (Value < MinimumRate) or (Value > MaximumRate) then
  begin
    ErrorText := Format(
      'максимальная скорость должна быть в диапазоне %d..%d мкл/с',
      [MinimumRate, MaximumRate]);
    Exit(False);
  end;
  AConfig.MaxFlowRate := Value;
  AConfig.Operation := FOperation;

  if FIsNew then
  begin
    AConfig.Operation.Volume := AConfig.Volume;
    AConfig.Operation.Speed := AConfig.MaxFlowRate;
    AConfig.Operation.Channel := 1;
  end
  else
  begin
    if AConfig.Volume < AConfig.Operation.Volume then
      AConfig.Operation.Volume := AConfig.Volume;
  end;

  TDispenserConfigValidator.NormalizeOperation(AConfig);

  Result := True;
end;

end.
