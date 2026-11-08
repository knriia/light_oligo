unit DispenserOperationCoordinator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DispenserController, DispenserConfig, DispenserOperationRules,
  DispenserRuntimeState, DispenserTypes, DispenserLimits, DispenserResolution;

type
  TDispenserOperationRequest = record
    Config: TDispenserConfig;
    SelectedChannel: Integer;
    BypassActive: Boolean;
  end;

  TDispenserOperationRequestArray = array of TDispenserOperationRequest;

  TDispenserOperationStartResult = (dosrStarted, dosrRejected, dosrBusy,
    dosrCommandFailed);
  TDispenserGroupStartResult = (dgsStarted, dgsRejected,
    dgsStoppedOnCommandError);

  TDispenserOperationLogEvent = procedure(const Msg: string) of object;
  TDispenserOperationStateChangedEvent = procedure(Address: Integer) of object;
  TDispenserOperationFailureEvent = procedure(Address: Integer;
    const MessageText: string; UpdateAndSaveVolume: Boolean) of object;

  TDispenserOperationCoordinator = class
  private
    FController: TDispenserController;
    FRuntimeStates: TDispenserRuntimeStates;
    FPollAddress: Integer;
    FOnLogMessage: TDispenserOperationLogEvent;
    FOnStateChanged: TDispenserOperationStateChangedEvent;
    FOnFailure: TDispenserOperationFailureEvent;
    function StartPreparedOperation(AConfig: TDispenserConfig;
      AKind: TDispenserOperationKind; const APlan: TDispenserOperationPlan;
      ACurrentPositionSteps: Int64; out ErrorText: string): Boolean;
    procedure CompleteOperation(Address: Integer);
    procedure FailOperation(Address: Integer; const Reason: string);
    function RefreshPositionFromEncoder(AConfig: TDispenserConfig;
      out ErrorText: string): Boolean;
    procedure PollNextOperationForOwner(AOwner: TDispenserOperationOwner);
    procedure NotifyStateChanged(Address: Integer);
    procedure Log(const Msg: string);
  public
    constructor Create(AController: TDispenserController;
      ARuntimeStates: TDispenserRuntimeStates);

    function StartSingle(AConfig: TDispenserConfig; AKind: TDispenserOperationKind;
      ASelectedChannel: Integer; ABypassActive: Boolean;
      out ErrorText: string): TDispenserOperationStartResult;
    function StartGroup(AKind: TDispenserOperationKind;
      const Requests: array of TDispenserOperationRequest;
      out ErrorText: string): TDispenserGroupStartResult;
    function ChangeActiveSpeed(AConfig: TDispenserConfig; AVolumeRate: Integer;
      out ErrorText: string): Boolean;
    function StopActiveOperation(Address: Integer;
      out ErrorText: string): Boolean;
    function StopAllActiveOperations(out ErrorText: string): Boolean;
    function HasActiveOperations: Boolean;
    procedure PollNextOperation;
    procedure PollNextProtocolOperation;

    property OnLogMessage: TDispenserOperationLogEvent write FOnLogMessage;
    property OnStateChanged: TDispenserOperationStateChangedEvent
      write FOnStateChanged;
    property OnFailure: TDispenserOperationFailureEvent write FOnFailure;
  end;

implementation

type
  TPreparedDispenserOperation = record
    Config: TDispenserConfig;
    Plan: TDispenserOperationPlan;
    CurrentPositionSteps: Int64;
  end;

constructor TDispenserOperationCoordinator.Create(
  AController: TDispenserController; ARuntimeStates: TDispenserRuntimeStates);
begin
  inherited Create;
  FController := AController;
  FRuntimeStates := ARuntimeStates;
  FPollAddress := MIN_DISPENSER_VALUE;
end;

procedure TDispenserOperationCoordinator.Log(const Msg: string);
begin
  if Assigned(FOnLogMessage) then
    FOnLogMessage(Msg);
end;

procedure TDispenserOperationCoordinator.NotifyStateChanged(Address: Integer);
begin
  if Assigned(FOnStateChanged) then
    FOnStateChanged(Address);
end;

function TDispenserOperationCoordinator.RefreshPositionFromEncoder(
  AConfig: TDispenserConfig; out ErrorText: string): Boolean;
var
  State: TDispenserRuntimeState;
  PreviousPositionSteps: Int64;
  ActualPositionSteps: Int64;
begin
  Result := False;
  ErrorText := '';
  State := FRuntimeStates.Items[AConfig.Address];
  PreviousPositionSteps := State.CurrentPositionSteps;
  if not FController.QueryPlungerEncoderPosition(AConfig.Address,
    ActualPositionSteps) then
  begin
    ErrorText := FController.LastError;
    if ErrorText = '' then
      ErrorText := 'Не удалось прочитать положение энкодера.';
    State.MarkPositionUnknown(ErrorText);
    NotifyStateChanged(AConfig.Address);
    Exit;
  end;

  if not State.UpdatePositionFromEncoder(ActualPositionSteps, ErrorText) then
  begin
    ErrorText := 'Положение энкодера дозатора ' + AConfig.Name + ': ' +
      ErrorText;
    NotifyStateChanged(AConfig.Address);
    Exit;
  end;

  if PreviousPositionSteps <> ActualPositionSteps then
    Log(Format('%s: перед операцией модель показывала %s шагов, энкодер ' +
      'показал %s шагов; использую измеренное положение.',
      [AConfig.Name, IntToStr(PreviousPositionSteps),
      IntToStr(ActualPositionSteps)]));
  Result := True;
end;

function TDispenserOperationCoordinator.StartSingle(AConfig: TDispenserConfig;
  AKind: TDispenserOperationKind; ASelectedChannel: Integer;
  ABypassActive: Boolean; out ErrorText: string):
  TDispenserOperationStartResult;
var
  State: TDispenserRuntimeState;
  CurrentPositionSteps: Int64;
  Plan: TDispenserOperationPlan;
begin
  ErrorText := '';
  if (FController = nil) or not FController.IsConnected then
  begin
    ErrorText := 'Дозатор не подключён.';
    Exit(dosrRejected);
  end;

  if (AConfig = nil) or (FRuntimeStates = nil) then
  begin
    ErrorText := 'Не заданы конфигурация или состояние дозатора.';
    Exit(dosrRejected);
  end;

  State := FRuntimeStates.Items[AConfig.Address];
  if (State = nil) or State.OperationActive then
    Exit(dosrBusy);
  if not State.IsInitializedFor(AConfig) then
  begin
    ErrorText := 'Требуется инициализация дозатора.';
    Exit(dosrRejected);
  end;

  if not RefreshPositionFromEncoder(AConfig, ErrorText) then
    Exit(dosrCommandFailed);

  CurrentPositionSteps := FRuntimeStates.GetCurrentPositionSteps(
    AConfig.Address);
  if not BuildOperationPlanAtPosition(AConfig, AKind, ASelectedChannel,
    CurrentPositionSteps,
    FRuntimeStates.IsCurrentVolumeKnown(AConfig.Address), ABypassActive, Plan,
    ErrorText) then
    Exit(dosrRejected);

  if StartPreparedOperation(AConfig, AKind, Plan, CurrentPositionSteps,
    ErrorText) then
    Result := dosrStarted
  else
    Result := dosrCommandFailed;
end;

function TDispenserOperationCoordinator.StartGroup(
  AKind: TDispenserOperationKind;
  const Requests: array of TDispenserOperationRequest;
  out ErrorText: string): TDispenserGroupStartResult;
var
  Prepared: array of TPreparedDispenserOperation;
  SeenAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
  I: Integer;
  J: Integer;
  Address: Integer;
  State: TDispenserRuntimeState;
  CurrentPositionSteps: Int64;
  OperationText: string;
  StopError: string;
begin
  Result := dgsRejected;
  ErrorText := '';

  if (FController = nil) or not FController.IsConnected then
  begin
    ErrorText := 'Дозаторы не подключены.';
    Exit;
  end;

  if FRuntimeStates = nil then
  begin
    ErrorText := 'Не задано состояние дозаторов.';
    Exit;
  end;

  if Length(Requests) = 0 then
  begin
    ErrorText := 'Выберите хотя бы один дозатор.';
    Exit;
  end;

  SetLength(Prepared, Length(Requests));
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    SeenAddresses[Address] := False;
  for I := 0 to High(Requests) do
  begin
    if Requests[I].Config = nil then
    begin
      ErrorText := 'Не задана конфигурация одного из дозаторов.';
      Exit;
    end;

    Address := Requests[I].Config.Address;
    if not (Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
    begin
      ErrorText := Requests[I].Config.Name + ': некорректный адрес дозатора.';
      Exit;
    end;
    if SeenAddresses[Address] then
    begin
      ErrorText := Requests[I].Config.Name +
        ': один дозатор указан в групповой операции больше одного раза.';
      Exit;
    end;
    SeenAddresses[Address] := True;

    State := FRuntimeStates.Items[Address];
    if (State = nil) or State.OperationActive then
    begin
      ErrorText := Requests[I].Config.Name + ': операция уже выполняется.';
      Exit;
    end;
    if not State.IsInitializedFor(Requests[I].Config) then
    begin
      ErrorText := Requests[I].Config.Name +
        ': требуется инициализация дозатора.';
      Exit;
    end;

    if not RefreshPositionFromEncoder(Requests[I].Config, ErrorText) then
    begin
      ErrorText := Requests[I].Config.Name + ': ' + ErrorText;
      Exit;
    end;

    CurrentPositionSteps := FRuntimeStates.GetCurrentPositionSteps(
      Requests[I].Config.Address);
    if not BuildOperationPlanAtPosition(Requests[I].Config, AKind,
      Requests[I].SelectedChannel, CurrentPositionSteps,
      FRuntimeStates.IsCurrentVolumeKnown(Requests[I].Config.Address),
      Requests[I].BypassActive, Prepared[I].Plan, ErrorText) then
    begin
      ErrorText := Requests[I].Config.Name + ': ' + ErrorText;
      Exit;
    end;

    Prepared[I].Config := Requests[I].Config;
    Prepared[I].CurrentPositionSteps := CurrentPositionSteps;
  end;

  OperationText := OperationKindDescription(AKind);
  for I := 0 to High(Prepared) do
    if not StartPreparedOperation(Prepared[I].Config, AKind,
      Prepared[I].Plan, Prepared[I].CurrentPositionSteps, ErrorText) then
    begin
      for J := I - 1 downto 0 do
      begin
        Address := Prepared[J].Config.Address;
        State := FRuntimeStates.Items[Address];
        if (State = nil) or not State.OperationActive then
          Continue;
        StopError := '';
        if not StopActiveOperation(Address, StopError) then
        begin
          if ErrorText <> '' then
            ErrorText := ErrorText + LineEnding;
          ErrorText := ErrorText + Format(
            'Не удалось остановить ранее запущенный дозатор %s: %s',
            [Prepared[J].Config.Name, StopError]);
        end;
      end;
      Log(Format('Групповая операция %s остановлена после ошибки запуска дозатора %s.',
        [OperationText, Prepared[I].Config.Name]));
      Exit(dgsStoppedOnCommandError);
    end;
  Result := dgsStarted;
end;

function TDispenserOperationCoordinator.StartPreparedOperation(
  AConfig: TDispenserConfig; AKind: TDispenserOperationKind;
  const APlan: TDispenserOperationPlan;
  ACurrentPositionSteps: Int64; out ErrorText: string): Boolean;
var
  State: TDispenserRuntimeState;
  OperationText: string;
  FailureMessage: string;
begin
  Result := False;
  ErrorText := '';
  State := FRuntimeStates.Items[AConfig.Address];
  if not State.TryBeginOperation(dooManual, AKind, AConfig.Name,
    Round(APlan.ActualVolume), APlan.Steps, ACurrentPositionSteps,
    ErrorText) then
    Exit;

  if not FController.ExecuteMovement(AConfig.Address, APlan.Channel,
    APlan.Steps, APlan.MotorSpeed, APlan.Aspirate, State.ValveType) then
  begin
    ErrorText := FController.LastError;
    if ErrorText = '' then
      ErrorText := 'Устройство не подтвердило запуск движения.';
    if FController.IsConnected then
      FController.TerminateMovement(AConfig.Address);
    State.MarkInitializationFailed(ErrorText);
    FailureMessage := AConfig.Name + ': ' + ErrorText;
    if Assigned(FOnFailure) then
      FOnFailure(AConfig.Address, FailureMessage, True);
    NotifyStateChanged(AConfig.Address);
    Exit;
  end;

  OperationText := OperationKindDescription(AKind);
  if APlan.Aspirate then
    Log(Format('%s: запущено %s, набор %d мкл из канала %d',
      [AConfig.Name, OperationText, APlan.Volume, APlan.Channel]))
  else
    Log(Format('%s: запущено %s, выдача %d мкл в канал %d',
      [AConfig.Name, OperationText, APlan.Volume, APlan.Channel]));

  NotifyStateChanged(AConfig.Address);
  Result := True;
end;

function TDispenserOperationCoordinator.ChangeActiveSpeed(
  AConfig: TDispenserConfig; AVolumeRate: Integer;
  out ErrorText: string): Boolean;
var
  State: TDispenserRuntimeState;
  MotorSpeed: Integer;
  MinimumRate: Integer;
begin
  Result := False;
  ErrorText := '';

  if (AConfig = nil) or (FController = nil) or (FRuntimeStates = nil) then
  begin
    ErrorText := 'Не заданы контроллер или конфигурация дозатора.';
    Exit;
  end;

  if not FController.IsConnected then
  begin
    ErrorText := 'Устройство не подключено.';
    Exit;
  end;

  State := FRuntimeStates.Items[AConfig.Address];
  if (State = nil) or not State.OperationActive then
  begin
    ErrorText := 'У дозатора нет активной операции.';
    Exit;
  end;

  MinimumRate := MinimumVolumeRate(AConfig.Volume, AConfig.StepCount);
  if (AVolumeRate < MinimumRate) or (AVolumeRate > AConfig.MaxFlowRate) or
    not ConvertVolumeRateToMotorSpeed(AVolumeRate, MAX_SPEED,
      AConfig.Volume, AConfig.StepCount, MotorSpeed) then
  begin
    ErrorText := Format(
      'Скорость должна быть в диапазоне %d..%d мкл/с.',
      [MinimumRate, AConfig.MaxFlowRate]);
    Exit;
  end;

  if not FController.ChangeMovementSpeed(AConfig.Address, MotorSpeed) then
  begin
    ErrorText := FController.LastError;
    if ErrorText = '' then
      ErrorText := 'Устройство не подтвердило изменение скорости.';
    Exit;
  end;

  Log(Format('%s: скорость активной операции изменена на %d мкл/с',
    [AConfig.Name, AVolumeRate]));
  Result := True;
end;

function TDispenserOperationCoordinator.StopActiveOperation(Address: Integer;
  out ErrorText: string): Boolean;
var
  State: TDispenserRuntimeState;
  OperationName: string;
begin
  Result := False;
  ErrorText := '';

  if (FController = nil) or (FRuntimeStates = nil) then
  begin
    ErrorText := 'Не заданы контроллер или состояние дозатора.';
    Exit;
  end;

  if not FController.IsConnected then
  begin
    ErrorText := 'Устройство не подключено.';
    Exit;
  end;

  State := FRuntimeStates.Items[Address];
  if (State = nil) or not State.OperationActive then
  begin
    ErrorText := 'У дозатора нет активной операции для остановки.';
    Exit;
  end;

  if not FController.TerminateMovement(Address) then
  begin
    ErrorText := FController.LastError;
    if ErrorText = '' then
      ErrorText := 'Устройство не подтвердило остановку дозатора.';
    State.MarkPositionUnknown(ErrorText);
    NotifyStateChanged(Address);
    Exit;
  end;

  OperationName := State.OperationName;
  State.CancelOperation('Движение остановлено; требуется повторная инициализация.');
  if OperationName <> '' then
    Log(OperationName + ': движение остановлено; сначала инициализируйте дозатор')
  else
    Log(Format('Дозатор %d: движение остановлено; сначала инициализируйте дозатор',
      [Address]));
  NotifyStateChanged(Address);
  Result := True;
end;

function TDispenserOperationCoordinator.StopAllActiveOperations(
  out ErrorText: string): Boolean;
var
  Address: Integer;
  State: TDispenserRuntimeState;
  CurrentError: string;
begin
  Result := True;
  ErrorText := '';
  if (FController = nil) or (FRuntimeStates = nil) then
  begin
    ErrorText := 'Не заданы контроллер или состояние дозаторов.';
    Exit(False);
  end;

  if not FController.IsConnected then
  begin
    ErrorText := 'Сначала подключите устройство.';
    Exit(False);
  end;

  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    State := FRuntimeStates.Items[Address];
    if (State = nil) or not State.OperationActive then
      Continue;

    CurrentError := '';
    if not StopActiveOperation(Address, CurrentError) then
    begin
      Result := False;
      if ErrorText <> '' then
        ErrorText := ErrorText + LineEnding;
      ErrorText := ErrorText + Format('Дозатор %d: %s',
        [Address, CurrentError]);
    end;
  end;
end;

function TDispenserOperationCoordinator.HasActiveOperations: Boolean;
var
  Address: Integer;
begin
  Result := False;
  if FRuntimeStates = nil then
    Exit;

  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FRuntimeStates.Items[Address].OperationActive and
      not FRuntimeStates.Items[Address].CommandPending then
      Exit(True);
end;

procedure TDispenserOperationCoordinator.PollNextOperation;
begin
  PollNextOperationForOwner(dooManual);
end;

procedure TDispenserOperationCoordinator.PollNextProtocolOperation;
begin
  PollNextOperationForOwner(dooProtocol);
end;

procedure TDispenserOperationCoordinator.PollNextOperationForOwner(
  AOwner: TDispenserOperationOwner);
var
  I: Integer;
  Address: Integer;
  PolledAddress: Integer;
  StatusCode: Byte;
  ErrorCode: Byte;
begin
  if (FController = nil) or (FRuntimeStates = nil) then
    Exit;

  Address := FPollAddress;
  for I := 0 to MAX_DISPENSER_VALUE - MIN_DISPENSER_VALUE do
  begin
    if FRuntimeStates.Items[Address].OperationActive and
      (FRuntimeStates.Items[Address].OperationOwner = AOwner) and
      not FRuntimeStates.Items[Address].CommandPending then
    begin
      PolledAddress := Address;
      Inc(Address);
      if Address > MAX_DISPENSER_VALUE then
        Address := MIN_DISPENSER_VALUE;
      FPollAddress := Address;

      if not FController.QueryStatusQuiet(PolledAddress, StatusCode) then
      begin
        FailOperation(PolledAddress, FController.LastError);
        Exit;
      end;

      ErrorCode := StatusCode and STATUS_ERROR_MASK;
      if ErrorCode <> 0 then
      begin
        FailOperation(PolledAddress,
          Format('код ошибки 0x%s', [IntToHex(StatusCode, 2)]));
        Exit;
      end;

      if (StatusCode and STATUS_READY_MASK) <> 0 then
        CompleteOperation(PolledAddress);
      Exit;
    end;

    Inc(Address);
    if Address > MAX_DISPENSER_VALUE then
      Address := MIN_DISPENSER_VALUE;
  end;
end;

procedure TDispenserOperationCoordinator.CompleteOperation(Address: Integer);
var
  State: TDispenserRuntimeState;
  NewVolume: Double;
  OperationName: string;
  OperationKind: TDispenserOperationKind;
  OperationVolume: Integer;
  StartingPositionSteps: Int64;
  RequestedDeltaSteps: Int64;
  ActualPositionSteps: Int64;
  ActualDeltaSteps: Int64;
  ErrorText: string;
begin
  State := FRuntimeStates.Items[Address];
  if (State = nil) or not State.OperationActive then
    Exit;

  OperationName := State.OperationName;
  OperationKind := State.OperationKind;
  OperationVolume := State.OperationVolume;
  StartingPositionSteps := State.OperationStartingPositionSteps;
  RequestedDeltaSteps := State.OperationStepCount;
  if OperationKind in [dokEmpty, dokDispense] then
    RequestedDeltaSteps := -RequestedDeltaSteps;

  if not FController.QueryPlungerEncoderPosition(Address,
    ActualPositionSteps) then
  begin
    FailOperation(Address, FController.LastError);
    Exit;
  end;

  if not State.CompleteOperationFromEncoder(ActualPositionSteps, ErrorText) then
  begin
    if OperationName <> '' then
      Log(OperationName +
        ': завершение движения подтверждено, положение неизвестно: ' +
        ErrorText)
    else
      Log(Format(
        'Дозатор %d: завершение движения подтверждено, положение неизвестно: %s',
        [Address, ErrorText]));
    NotifyStateChanged(Address);
    Exit;
  end;
  ActualDeltaSteps := ActualPositionSteps - StartingPositionSteps;
  if ActualDeltaSteps = RequestedDeltaSteps then
    Log(Format('%s: encoder до операции %s, запрошено %s шагов, ' +
      'после операции %s; фактически перемещение %s шагов.',
      [OperationName, IntToStr(StartingPositionSteps),
      IntToStr(RequestedDeltaSteps), IntToStr(ActualPositionSteps),
      IntToStr(ActualDeltaSteps)]))
  else
    Log(Format('%s: РАСХОЖДЕНИЕ ЭНКОДЕРА: до операции %s, запрошено %s ' +
      'шагов, после операции %s; фактически перемещение %s шагов.',
      [OperationName, IntToStr(StartingPositionSteps),
      IntToStr(RequestedDeltaSteps), IntToStr(ActualPositionSteps),
      IntToStr(ActualDeltaSteps)]));
  NewVolume := State.CurrentVolume;

  if OperationKind = dokFill then
    Log(Format('%s: наполнен, текущий объём %d мкл',
      [OperationName, Round(NewVolume)]))
  else if OperationKind = dokEmpty then
    Log(OperationName + ': опустошён')
  else if OperationKind = dokAspirate then
    Log(Format('%s: набрано %d мкл, текущий объём %d мкл',
      [OperationName, OperationVolume, Round(NewVolume)]))
  else
    Log(Format('%s: выдано %d мкл, текущий объём %d мкл',
      [OperationName, OperationVolume, Round(NewVolume)]));

  NotifyStateChanged(Address);
end;

procedure TDispenserOperationCoordinator.FailOperation(Address: Integer;
  const Reason: string);
var
  State: TDispenserRuntimeState;
  MessageText: string;
begin
  State := FRuntimeStates.Items[Address];
  if (State = nil) or not State.OperationActive then
    Exit;

  State.MarkInitializationFailed(Reason);
  if State.OperationName <> '' then
    MessageText := State.OperationName + ': операция не завершена: ' + Reason
  else
    MessageText := 'Дозатор ' + IntToStr(Address) +
      ': операция не завершена: ' + Reason;

  Log(MessageText);
  if Assigned(FOnFailure) then
    FOnFailure(Address, MessageText, False);
  NotifyStateChanged(Address);
end;

end.
