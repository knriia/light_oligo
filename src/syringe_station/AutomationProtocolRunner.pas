unit AutomationProtocolRunner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, AutomationProtocol, DispenserController,
  DispenserConfig, DispenserRuntimeState, DispenserTypes;

type
  TAutomationProtocolLogEvent = procedure(const Msg: string) of object;
  TAutomationProtocolStateEvent = procedure(Address: Integer) of object;
  TAutomationProtocolFinishedEvent = procedure(const MessageText: string;
    Failed: Boolean) of object;

  TAutomationProtocolRunner = class
  private
    FController: TDispenserController;
    FRuntimeStates: TDispenserRuntimeStates;
    FProtocol: TAutomationProtocol;
    FCommandIndex: Integer;
    FRemainingSteps: array of Int64;
    FLoadedSteps: array of Int64;
    FStageTargetIndexes: array of Integer;
    FStageSteps: array of Integer;
    FStageSpeeds: array of Integer;
    FStageValveSent: array of Boolean;
    FStageMovementSent: array of Boolean;
    FStageReady: array of Boolean;
    FStageIsFill: Boolean;
    FStageAspirate: Boolean;
    FStagePhase: Integer;
    FStagePollIndex: Integer;
    FStageStartedAt: QWord;
    FStageTimeoutMs: QWord;
    FIsRunning: Boolean;
    FOnLogMessage: TAutomationProtocolLogEvent;
    FOnStateChanged: TAutomationProtocolStateEvent;
    FOnFinished: TAutomationProtocolFinishedEvent;

    procedure Log(const Msg: string);
    procedure NotifyStateChanged(Address: Integer);
    procedure Finish(const MessageText: string; Failed: Boolean);
    procedure FailAndStop(const MessageText: string);
    procedure LoadCurrentCommand;
    procedure BeginNextAction;
    procedure StartStage(const TargetIndexes: array of Integer;
      const Steps: array of Integer; AIsFill: Boolean);
    procedure BeginStageMovement;
    procedure CompleteStage;
    procedure PollStage;
    function AllStageTargetsReady: Boolean;
    function CurrentCommand: TAutomationProtocolCommand;
    function GetIsRunning: Boolean;
    function NanolitersForSteps(ASteps: Int64;
      AConfig: TDispenserConfig): Int64;
    function StepsForNanoliters(ANanoliters: Int64;
      AConfig: TDispenserConfig): Int64;
    function RefreshPositionFromEncoder(AConfig: TDispenserConfig;
      out ErrorText: string): Boolean;
  public
    constructor Create(AController: TDispenserController;
      ARuntimeStates: TDispenserRuntimeStates);
    destructor Destroy; override;
    function Start(AProtocol: TAutomationProtocol;
      out ErrorText: string; ACommandReserved: Boolean = False): Boolean;
    procedure Poll;
    procedure Stop;
    property IsRunning: Boolean read GetIsRunning;
    property OnLogMessage: TAutomationProtocolLogEvent write FOnLogMessage;
    property OnStateChanged: TAutomationProtocolStateEvent
      write FOnStateChanged;
    property OnFinished: TAutomationProtocolFinishedEvent write FOnFinished;
  end;

implementation

uses
  Math, DispenserLimits, DispenserResolution;

const
  STAGE_SWITCHING_VALVE = 1;
  STAGE_MOVING_PLUNGER = 2;
  VALVE_TIMEOUT_MS = 30000;
  OPERATION_TIMEOUT_MARGIN_MS = 30000;

constructor TAutomationProtocolRunner.Create(AController: TDispenserController;
  ARuntimeStates: TDispenserRuntimeStates);
begin
  inherited Create;
  FController := AController;
  FRuntimeStates := ARuntimeStates;
  FProtocol := nil;
  FIsRunning := False;
  FStagePhase := 0;
end;

destructor TAutomationProtocolRunner.Destroy;
begin
  FProtocol.Free;
  inherited Destroy;
end;

procedure TAutomationProtocolRunner.Log(const Msg: string);
begin
  if Assigned(FOnLogMessage) then
    FOnLogMessage(Msg);
end;

procedure TAutomationProtocolRunner.NotifyStateChanged(Address: Integer);
begin
  if Assigned(FOnStateChanged) then
    FOnStateChanged(Address);
end;

function TAutomationProtocolRunner.GetIsRunning: Boolean;
begin
  Result := FIsRunning;
end;

function TAutomationProtocolRunner.CurrentCommand:
  TAutomationProtocolCommand;
begin
  Result := nil;
  if (FProtocol <> nil) and (FCommandIndex >= 0) and
    (FCommandIndex < FProtocol.Count) then
    Result := FProtocol[FCommandIndex];
end;

function TAutomationProtocolRunner.NanolitersForSteps(ASteps: Int64;
  AConfig: TDispenserConfig): Int64;
var
  EffectiveStepCount: Int64;
  Volume: Extended;
begin
  Result := 0;
  if (AConfig = nil) or (AConfig.Volume <= 0) then
    Exit;
  EffectiveStepCount := EffectiveN1StepCount(AConfig.StepCount);
  if EffectiveStepCount <= 0 then
    Exit;
  Volume := Extended(ASteps) * AConfig.Volume * 1000 /
    EffectiveStepCount;
  if Volume > High(Int64) then
    Exit;
  Result := Round(Volume);
end;

function TAutomationProtocolRunner.StepsForNanoliters(ANanoliters: Int64;
  AConfig: TDispenserConfig): Int64;
var
  EffectiveStepCount: Int64;
  Volume: Extended;
begin
  Result := 0;
  if (AConfig = nil) or (AConfig.Volume <= 0) or (ANanoliters <= 0) then
    Exit;
  EffectiveStepCount := EffectiveN1StepCount(AConfig.StepCount);
  if EffectiveStepCount <= 0 then
    Exit;
  Volume := Extended(ANanoliters) * EffectiveStepCount /
    (Int64(AConfig.Volume) * 1000);
  if Volume > High(Int64) then
    Exit;
  Result := Round(Volume);
end;

function TAutomationProtocolRunner.RefreshPositionFromEncoder(
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
    Log(Format('%s: перед протоколом модель показывала %s шагов, энкодер ' +
      'показал %s шагов; использую измеренное положение.',
      [AConfig.Name, IntToStr(PreviousPositionSteps),
      IntToStr(ActualPositionSteps)]));
  Result := True;
end;

function TAutomationProtocolRunner.Start(AProtocol: TAutomationProtocol;
  out ErrorText: string; ACommandReserved: Boolean): Boolean;
var
  I: Integer;
  J: Integer;
  Command: TAutomationProtocolCommand;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  LoadedSteps: Int64;
  Speed: Integer;
  SeenAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
begin
  Result := False;
  ErrorText := '';
  if FIsRunning then
  begin
    ErrorText := 'Протокол уже выполняется.';
    Exit;
  end;
  if (FController = nil) or not FController.IsConnected then
  begin
    ErrorText := 'Сначала подключите устройство.';
    Exit;
  end;
  if (FRuntimeStates = nil) or (AProtocol = nil) or
    (AProtocol.Count = 0) then
  begin
    ErrorText := 'Не задан протокол или состояние дозаторов.';
    Exit;
  end;

  for I := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    SeenAddresses[I] := False;
  for I := 0 to AProtocol.Count - 1 do
  begin
    Command := AProtocol[I];
    for J := 0 to High(Command.Targets) do
    begin
      Target := Command.Targets[J];
      State := FRuntimeStates.Items[Target.Config.Address];
      if (State = nil) or not State.IsInitializedFor(Target.Config) then
      begin
        ErrorText := Format('Команда %d: сначала инициализируйте дозатор %s.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      if State.OperationActive or
        ((State.CommandPending or State.ProtocolReserved) and
        not ACommandReserved) then
      begin
        ErrorText := Format('Команда %d: дозатор %s сейчас выполняет другую команду.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      if not FRuntimeStates.IsCurrentVolumeKnown(Target.Config.Address) then
      begin
        ErrorText := Format('Команда %d: текущий объём дозатора %s неизвестен.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      if State.ValveType = dvtUnknown then
      begin
        ErrorText := Format('Команда %d: не определён тип клапана дозатора %s.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      if (Target.Config.IntakeChannel < 1) or
        (Target.Config.IntakeChannel > Target.Config.ChannelCount) then
      begin
        ErrorText := Format('Команда %d: у дозатора %s некорректный канал забора из конфигурации.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      LoadedSteps := State.CurrentPositionSteps;
      if (LoadedSteps < 0) or
        (LoadedSteps > EffectiveN1StepCount(Target.Config.StepCount)) then
      begin
        ErrorText := Format('Команда %d: объём дозатора %s выходит за пределы шприца.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;
      if not ConvertVolumeRateToMotorSpeed(Target.Config.MaxFlowRate,
        MAX_SPEED, Target.Config.Volume, Target.Config.StepCount, Speed) then
      begin
        ErrorText := Format('Команда %d: некорректная скорость наполнения дозатора %s из конфигурации.',
          [Command.Number, Target.Config.Name]);
        Exit;
      end;

      if not SeenAddresses[Target.Config.Address] then
      begin
        if not RefreshPositionFromEncoder(Target.Config, ErrorText) then
        begin
          ErrorText := Format('Команда %d, дозатор %s: %s',
            [Command.Number, Target.Config.Name, ErrorText]);
          Exit;
        end;
        SeenAddresses[Target.Config.Address] := True;
      end;
    end;
  end;

  FProtocol.Free;
  FProtocol := AProtocol;
  FCommandIndex := 0;
  FIsRunning := True;
  LoadCurrentCommand;
  Log('Запущен протокол из ' + IntToStr(FProtocol.Count) + ' команд.');
  BeginNextAction;
  Result := True;
end;

procedure TAutomationProtocolRunner.LoadCurrentCommand;
var
  I: Integer;
  Target: TAutomationProtocolTarget;
begin
  if CurrentCommand = nil then
    Exit;
  SetLength(FRemainingSteps, Length(CurrentCommand.Targets));
  SetLength(FLoadedSteps, Length(CurrentCommand.Targets));
  for I := 0 to High(CurrentCommand.Targets) do
  begin
    Target := CurrentCommand.Targets[I];
    FRemainingSteps[I] := Target.TotalSteps;
    FLoadedSteps[I] := FRuntimeStates.GetCurrentPositionSteps(
      Target.Config.Address);
  end;
end;

procedure TAutomationProtocolRunner.BeginNextAction;
var
  I: Integer;
  Target: TAutomationProtocolTarget;
  NeededIndexes: array of Integer;
  NeededSteps: array of Integer;
  AvailableNanoliters: Int64;
  SegmentNanoliters: Int64;
  SegmentSteps: Int64;
  AvailableSteps: Int64;
begin
  NeededIndexes := nil;
  NeededSteps := nil;
  if not FIsRunning then
    Exit;
  if CurrentCommand = nil then
  begin
    Finish('Протокол завершён.', False);
    Exit;
  end;

  I := 0;
  while (I < Length(FRemainingSteps)) and (FRemainingSteps[I] <= 0) do
    Inc(I);
  if I >= Length(FRemainingSteps) then
  begin
    Log(Format('Команда %d завершена.', [CurrentCommand.Number]));
    Inc(FCommandIndex);
    if FCommandIndex >= FProtocol.Count then
    begin
      Finish('Протокол завершён.', False);
      Exit;
    end;
    LoadCurrentCommand;
    BeginNextAction;
    Exit;
  end;

  SetLength(NeededIndexes, 0);
  SetLength(NeededSteps, 0);
  for I := 0 to High(FRemainingSteps) do
    if (FRemainingSteps[I] > 0) and (FLoadedSteps[I] <= 0) then
    begin
      Target := CurrentCommand.Targets[I];
      AvailableSteps := EffectiveN1StepCount(Target.Config.StepCount);
      if AvailableSteps > FRemainingSteps[I] then
        AvailableSteps := FRemainingSteps[I];
      if AvailableSteps > High(Integer) then
      begin
        FailAndStop('Размер одного наполнения превышает ограничение протокола.');
        Exit;
      end;
      SetLength(NeededIndexes, Length(NeededIndexes) + 1);
      SetLength(NeededSteps, Length(NeededSteps) + 1);
      NeededIndexes[High(NeededIndexes)] := I;
      NeededSteps[High(NeededSteps)] := Integer(AvailableSteps);
    end;
  if Length(NeededIndexes) > 0 then
  begin
    StartStage(NeededIndexes, NeededSteps, True);
    Exit;
  end;

  SegmentNanoliters := High(Int64);
  for I := 0 to High(FRemainingSteps) do
    if FRemainingSteps[I] > 0 then
    begin
      AvailableSteps := FLoadedSteps[I];
      if AvailableSteps > FRemainingSteps[I] then
        AvailableSteps := FRemainingSteps[I];
      AvailableNanoliters := NanolitersForSteps(AvailableSteps,
        CurrentCommand.Targets[I].Config);
      if AvailableNanoliters < SegmentNanoliters then
        SegmentNanoliters := AvailableNanoliters;
    end;

  if (SegmentNanoliters <= 0) or (SegmentNanoliters = High(Int64)) then
  begin
    FailAndStop('Не удалось рассчитать общий сегмент дозирования.');
    Exit;
  end;

  SetLength(NeededIndexes, 0);
  SetLength(NeededSteps, 0);
  for I := 0 to High(FRemainingSteps) do
    if FRemainingSteps[I] > 0 then
    begin
      Target := CurrentCommand.Targets[I];
      AvailableSteps := FLoadedSteps[I];
      if AvailableSteps > FRemainingSteps[I] then
        AvailableSteps := FRemainingSteps[I];
      SegmentSteps := StepsForNanoliters(SegmentNanoliters, Target.Config);
      if SegmentSteps > AvailableSteps then
        SegmentSteps := AvailableSteps;
      if SegmentSteps <= 0 then
      begin
        FailAndStop(Format('Не удалось синхронизировать объём дозирования дозатора %s с разрешением шприца.',
          [Target.Config.Name]));
        Exit;
      end;
      if SegmentSteps > High(Integer) then
      begin
        FailAndStop('Размер одного сегмента дозирования превышает ограничение протокола.');
        Exit;
      end;
      SetLength(NeededIndexes, Length(NeededIndexes) + 1);
      SetLength(NeededSteps, Length(NeededSteps) + 1);
      NeededIndexes[High(NeededIndexes)] := I;
      NeededSteps[High(NeededSteps)] := Integer(SegmentSteps);
    end;

  StartStage(NeededIndexes, NeededSteps, False);
end;

procedure TAutomationProtocolRunner.StartStage(
  const TargetIndexes: array of Integer; const Steps: array of Integer;
  AIsFill: Boolean);
var
  I: Integer;
  Index: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  Channel: Integer;
  OperationKind: TDispenserOperationKind;
  ErrorText: string;
begin
  if Length(TargetIndexes) = 0 then
  begin
    FailAndStop('Для этапа протокола не выбраны дозаторы.');
    Exit;
  end;
  SetLength(FStageTargetIndexes, Length(TargetIndexes));
  SetLength(FStageSteps, Length(TargetIndexes));
  SetLength(FStageSpeeds, Length(TargetIndexes));
  SetLength(FStageValveSent, Length(TargetIndexes));
  SetLength(FStageMovementSent, Length(TargetIndexes));
  SetLength(FStageReady, Length(TargetIndexes));
  FStageIsFill := AIsFill;
  FStageAspirate := AIsFill;
  FStagePhase := STAGE_SWITCHING_VALVE;
  FStagePollIndex := 0;
  FStageStartedAt := GetTickCount64;
  FStageTimeoutMs := VALVE_TIMEOUT_MS;

  { Prepare the complete stage before issuing commands. Failure handling then
    has a valid target list even if the first command is rejected. }
  for I := 0 to High(TargetIndexes) do
  begin
    Index := TargetIndexes[I];
    FStageTargetIndexes[I] := Index;
    FStageSteps[I] := Steps[I];
    FStageValveSent[I] := False;
    FStageMovementSent[I] := False;
    FStageReady[I] := False;
  end;

  for I := 0 to High(TargetIndexes) do
  begin
    Index := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[Index];
    State := FRuntimeStates.Items[Target.Config.Address];
    if AIsFill then
    begin
      if not ConvertVolumeRateToMotorSpeed(Target.Config.MaxFlowRate,
        MAX_SPEED, Target.Config.Volume, Target.Config.StepCount,
        FStageSpeeds[I]) then
      begin
        FailAndStop(Format('Не удалось рассчитать скорость наполнения дозатора %s.',
          [Target.Config.Name]));
        Exit;
      end;
    end
    else
      FStageSpeeds[I] := Target.MotorSpeed;

    if AIsFill then
      OperationKind := dokFill
    else
      OperationKind := dokDispense;
    if not State.TryBeginOperation(dooProtocol, OperationKind,
      Target.Config.Name,
      Round(MicrolitersForN1Steps(Steps[I], Target.Config.Volume,
      Target.Config.StepCount)), Steps[I], FLoadedSteps[Index], ErrorText) then
    begin
      FailAndStop(Target.Config.Name + ': ' + ErrorText);
      Exit;
    end;
    NotifyStateChanged(Target.Config.Address);
  end;

  for I := 0 to High(TargetIndexes) do
  begin
    Index := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[Index];
    State := FRuntimeStates.Items[Target.Config.Address];
    if AIsFill then
      Channel := Target.Config.IntakeChannel
    else
      Channel := Target.ValveChannel;

    { A failed response can arrive after the device accepted the command. }
    FStageValveSent[I] := True;
    if not FController.SetValvePosition(Target.Config.Address, Channel,
      AIsFill, State.ValveType) then
    begin
      if FController.LastError <> '' then
        FailAndStop(Target.Config.Name + ': ' + FController.LastError)
      else
        FailAndStop(Target.Config.Name +
          ': устройство не подтвердило переключение клапана.');
      Exit;
    end;
  end;

  if AIsFill then
    Log(Format('Команда %d: клапаны переключаются перед набором.',
      [CurrentCommand.Number]))
  else
    Log(Format('Команда %d: клапаны переключаются перед дозированием.',
      [CurrentCommand.Number]));
end;

procedure TAutomationProtocolRunner.BeginStageMovement;
var
  I: Integer;
  Index: Integer;
  Target: TAutomationProtocolTarget;
  DurationMs: Extended;
  MaximumDurationMs: Extended;
begin
  MaximumDurationMs := 0;
  FStagePhase := STAGE_MOVING_PLUNGER;
  for I := 0 to High(FStageTargetIndexes) do
  begin
    Index := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[Index];
    { A failed response can arrive after the plunger has started moving. }
    FStageMovementSent[I] := True;
    if not FController.ExecutePlungerMovement(Target.Config.Address,
      FStageSteps[I], FStageSpeeds[I], FStageAspirate) then
    begin
      if FController.LastError <> '' then
        FailAndStop(Target.Config.Name + ': ' + FController.LastError)
      else
        FailAndStop(Target.Config.Name +
          ': устройство не подтвердило движение плунжера.');
      Exit;
    end;
    FStageReady[I] := False;
    if FStageIsFill then
      DurationMs := Extended(FStageSteps[I]) * Target.Config.Volume * 1000 /
        (EffectiveN1StepCount(Target.Config.StepCount) *
        Target.Config.MaxFlowRate)
    else
      DurationMs := Extended(NanolitersForSteps(FStageSteps[I],
        Target.Config)) * 1000 / Target.SpeedNanoLitersPerSecond;
    if DurationMs > MaximumDurationMs then
      MaximumDurationMs := DurationMs;
  end;

  FStagePollIndex := 0;
  FStageStartedAt := GetTickCount64;
  if MaximumDurationMs + OPERATION_TIMEOUT_MARGIN_MS > High(Int64) then
    FStageTimeoutMs := High(QWord)
  else
    FStageTimeoutMs := QWord(Ceil(MaximumDurationMs)) +
      OPERATION_TIMEOUT_MARGIN_MS;
  if FStageTimeoutMs < OPERATION_TIMEOUT_MARGIN_MS then
    FStageTimeoutMs := OPERATION_TIMEOUT_MARGIN_MS;
  if FStageIsFill then
    Log(Format('Команда %d: после переключения всех клапанов одновременно начат набор в %d дозаторах.',
      [CurrentCommand.Number, Length(FStageTargetIndexes)]))
  else
    Log(Format('Команда %d: после переключения всех клапанов одновременно начато дозирование в %d дозаторах.',
      [CurrentCommand.Number, Length(FStageTargetIndexes)]));
end;

function TAutomationProtocolRunner.AllStageTargetsReady: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to High(FStageReady) do
    if not FStageReady[I] then
      Exit(False);
end;

procedure TAutomationProtocolRunner.PollStage;
var
  I: Integer;
  CheckedIndex: Integer;
  TargetIndex: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  StatusCode: Byte;
  ErrorCode: Byte;
begin
  if (FStagePhase = 0) or (Length(FStageTargetIndexes) = 0) then
    Exit;
  if GetTickCount64 - FStageStartedAt >= FStageTimeoutMs then
  begin
    FailAndStop(Format('Команда %d: истекло время ожидания дозаторов.',
      [CurrentCommand.Number]));
    Exit;
  end;

  for I := 0 to High(FStageTargetIndexes) do
  begin
    State := FRuntimeStates.Items[
      CurrentCommand.Targets[FStageTargetIndexes[I]].Config.Address];
    if (State = nil) or not State.OperationActive then
    begin
      FailAndStop('Работа протокола прервана: один из дозаторов остановлен отдельно.');
      Exit;
    end;
  end;

  CheckedIndex := -1;
  for I := 0 to High(FStageReady) do
  begin
    TargetIndex := (FStagePollIndex + I) mod Length(FStageReady);
    if not FStageReady[TargetIndex] then
    begin
      CheckedIndex := TargetIndex;
      Break;
    end;
  end;
  if CheckedIndex < 0 then
  begin
    if FStagePhase = STAGE_SWITCHING_VALVE then
      BeginStageMovement
    else
      CompleteStage;
    Exit;
  end;

  TargetIndex := FStageTargetIndexes[CheckedIndex];
  Target := CurrentCommand.Targets[TargetIndex];
  if not FController.QueryStatusQuiet(Target.Config.Address, StatusCode) then
  begin
    FailAndStop(Target.Config.Name + ': ' + FController.LastError);
    Exit;
  end;
  ErrorCode := StatusCode and STATUS_ERROR_MASK;
  if ErrorCode <> 0 then
  begin
    FailAndStop(Format('%s: устройство вернуло ошибку 0x%s.',
      [Target.Config.Name, IntToHex(StatusCode, 2)]));
    Exit;
  end;

  if (StatusCode and STATUS_READY_MASK) <> 0 then
  begin
    FStageReady[CheckedIndex] := True;
    FStagePollIndex := (CheckedIndex + 1) mod Length(FStageReady);
  end
  else
    FStagePollIndex := (CheckedIndex + 1) mod Length(FStageReady);

  if AllStageTargetsReady then
  begin
    if FStagePhase = STAGE_SWITCHING_VALVE then
      BeginStageMovement
    else
      CompleteStage;
  end;
end;

procedure TAutomationProtocolRunner.CompleteStage;
var
  I: Integer;
  Index: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  ActualPositionSteps: array of Int64;
  StartingPositionSteps: Int64;
  RequestedDeltaSteps: Int64;
  ActualDeltaSteps: Int64;
  ActualDispensedSteps: Int64;
  MaximumPositionSteps: Int64;
  ErrorText: string;
begin
  ErrorText := '';
  ActualPositionSteps := nil;
  SetLength(ActualPositionSteps, Length(FStageTargetIndexes));
  for I := 0 to High(FStageTargetIndexes) do
  begin
    Index := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[Index];
    if not FController.QueryPlungerEncoderPosition(Target.Config.Address,
      ActualPositionSteps[I]) then
    begin
      ErrorText := Target.Config.Name + ': ' + FController.LastError;
      if FController.LastError = '' then
        ErrorText := Target.Config.Name +
          ': Не удалось прочитать положение энкодера после движения.';
      Break;
    end;

    MaximumPositionSteps := EffectiveN1StepCount(Target.Config.StepCount);
    if (ActualPositionSteps[I] < 0) or
      (ActualPositionSteps[I] > MaximumPositionSteps) then
    begin
      ErrorText := Target.Config.Name +
        ': положение энкодера выходит за калибровку шприца.';
      Break;
    end;
  end;
  if ErrorText <> '' then
  begin
    for I := 0 to High(FStageTargetIndexes) do
    begin
      Index := FStageTargetIndexes[I];
      Target := CurrentCommand.Targets[Index];
      State := FRuntimeStates.Items[Target.Config.Address];
      if State <> nil then
      begin
        State.MarkPositionUnknown(ErrorText);
        State.ClearOperation;
        NotifyStateChanged(Target.Config.Address);
      end;
      FStageMovementSent[I] := False;
    end;
    FailAndStop(ErrorText);
    Exit;
  end;

  for I := 0 to High(FStageTargetIndexes) do
  begin
    Index := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[Index];
    State := FRuntimeStates.Items[Target.Config.Address];
    StartingPositionSteps := State.OperationStartingPositionSteps;
    RequestedDeltaSteps := FStageSteps[I];
    if not FStageAspirate then
      RequestedDeltaSteps := -RequestedDeltaSteps;
    ActualDeltaSteps := ActualPositionSteps[I] - StartingPositionSteps;
    if not State.CompleteOperationFromEncoder(ActualPositionSteps[I],
      ErrorText) then
    begin
      FailAndStop(Target.Config.Name + ': ' + ErrorText);
      Exit;
    end;

    if not FStageIsFill then
    begin
      ActualDispensedSteps := StartingPositionSteps - ActualPositionSteps[I];
      if ActualDispensedSteps > 0 then
      begin
        if ActualDispensedSteps >= FRemainingSteps[Index] then
          FRemainingSteps[Index] := 0
        else
          Dec(FRemainingSteps[Index], ActualDispensedSteps);
      end;
    end;
    FLoadedSteps[Index] := State.CurrentPositionSteps;
    if ActualDeltaSteps = RequestedDeltaSteps then
      Log(Format('%s, команда %d: энкодер до операции %s, запрошено %s шагов, ' +
        'после операции %s; фактически перемещение %s шагов.',
        [Target.Config.Name, CurrentCommand.Number,
        IntToStr(StartingPositionSteps), IntToStr(RequestedDeltaSteps),
        IntToStr(ActualPositionSteps[I]), IntToStr(ActualDeltaSteps)]))
    else
      Log(Format('%s, команда %d: РАСХОЖДЕНИЕ ЭНКОДЕРА: до операции %s, ' +
        'запрошено %s шагов, после операции %s; фактически перемещение %s шагов.',
        [Target.Config.Name, CurrentCommand.Number,
        IntToStr(StartingPositionSteps), IntToStr(RequestedDeltaSteps),
        IntToStr(ActualPositionSteps[I]), IntToStr(ActualDeltaSteps)]));
    NotifyStateChanged(Target.Config.Address);
  end;

  if FStageIsFill then
    Log(Format('Команда %d: этап наполнения завершён.',
      [CurrentCommand.Number]))
  else
    Log(Format('Команда %d: этап дозирования завершён.',
      [CurrentCommand.Number]));
  FStagePhase := 0;
  SetLength(FStageTargetIndexes, 0);
  SetLength(FStageSteps, 0);
  SetLength(FStageSpeeds, 0);
  SetLength(FStageValveSent, 0);
  SetLength(FStageMovementSent, 0);
  SetLength(FStageReady, 0);
  BeginNextAction;
end;

procedure TAutomationProtocolRunner.Poll;
begin
  if not FIsRunning then
    Exit;
  if (FController = nil) or not FController.IsConnected then
  begin
    FailAndStop('Устройство отключено во время выполнения протокола.');
    Exit;
  end;
  PollStage;
end;

procedure TAutomationProtocolRunner.FailAndStop(const MessageText: string);
var
  I: Integer;
  TargetIndex: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  StopSucceeded: Boolean;
  StopError: string;
  FinalMessage: string;
begin
  if not FIsRunning then
    Exit;

  FinalMessage := MessageText;
  for I := 0 to High(FStageTargetIndexes) do
  begin
    TargetIndex := FStageTargetIndexes[I];
    Target := CurrentCommand.Targets[TargetIndex];
    State := FRuntimeStates.Items[Target.Config.Address];
    if State = nil then
      Continue;

    if FStageMovementSent[I] then
    begin
      StopSucceeded := False;
      if FController <> nil then
        if FController.IsConnected then
          StopSucceeded := FController.TerminateMovement(
            Target.Config.Address);
      if StopSucceeded then
      begin
        State.MarkInitializationFailed(MessageText);
        State.ClearOperation;
      end
      else
      begin
        if FController <> nil then
          StopError := FController.LastError
        else
          StopError := '';
        if StopError = '' then
          StopError := 'не получено подтверждение остановки';
        State.MarkPositionUnknown(MessageText + ': ' + StopError);
        FinalMessage := FinalMessage + LineEnding + Target.Config.Name +
          ': не удалось подтвердить остановку; движение остаётся активным.';
      end;
    end
    else if FStageValveSent[I] and
      (FStagePhase = STAGE_SWITCHING_VALVE) then
    begin
      State.MarkInitializationFailed(MessageText);
      State.ClearOperation;
    end
    else
    begin
      State.ClearOperation;
    end;
    NotifyStateChanged(Target.Config.Address);
  end;

  Log('Протокол остановлен: ' + FinalMessage);
  Finish('Протокол остановлен: ' + FinalMessage, True);
end;

procedure TAutomationProtocolRunner.Stop;
begin
  if not FIsRunning then
    Exit;
  FailAndStop('остановлен пользователем.');
end;

procedure TAutomationProtocolRunner.Finish(const MessageText: string;
  Failed: Boolean);
begin
  FIsRunning := False;
  FStagePhase := 0;
  SetLength(FStageTargetIndexes, 0);
  SetLength(FStageSteps, 0);
  SetLength(FStageSpeeds, 0);
  SetLength(FStageValveSent, 0);
  SetLength(FStageMovementSent, 0);
  SetLength(FStageReady, 0);
  FProtocol.Free;
  FProtocol := nil;
  if Assigned(FOnFinished) then
    FOnFinished(MessageText, Failed);
end;

end.
