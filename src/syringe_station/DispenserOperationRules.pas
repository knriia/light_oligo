unit DispenserOperationRules;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DispenserConfig, DispenserLimits, DispenserResolution,
  DispenserTypes;

type
  TDispenserOperationPlan = record
    Channel: Integer;
    Volume: Integer;
    Steps: Integer;
    ActualVolume: Double;
    // Converted device speed in N1 half-step pulses per second.
    MotorSpeed: Integer;
    Aspirate: Boolean;
  end;

function CalculateOperationSteps(AVolume, ASyringeVolume,
  AStepCount: Integer): Integer;
function BuildOperationPlan(AConfig: TDispenserConfig;
  AKind: TDispenserOperationKind; ASelectedChannel: Integer;
  ACurrentVolume: Double; ACurrentVolumeKnown, ABypassActive: Boolean;
  out APlan: TDispenserOperationPlan; out ErrorText: string): Boolean;
function BuildOperationPlanAtPosition(AConfig: TDispenserConfig;
  AKind: TDispenserOperationKind; ASelectedChannel: Integer;
  ACurrentPositionSteps: Int64; ACurrentVolumeKnown, ABypassActive: Boolean;
  out APlan: TDispenserOperationPlan; out ErrorText: string): Boolean;
function OperationKindDescription(AKind: TDispenserOperationKind): string;

implementation

function CalculateOperationSteps(AVolume, ASyringeVolume,
  AStepCount: Integer): Integer;
var
  Numerator: Int64;
  EffectiveStepCount: Int64;
  StepResult: Int64;
begin
  Result := 0;
  if (AVolume <= 0) or (ASyringeVolume <= 0) or (AStepCount <= 0) then
    Exit;

  EffectiveStepCount := EffectiveN1StepCount(AStepCount);
  if EffectiveStepCount <= 0 then
    Exit;
  if Int64(AVolume) > High(Int64) div EffectiveStepCount then
    Exit;

  Numerator := Int64(AVolume) * EffectiveStepCount;
  if Numerator > High(Int64) - ASyringeVolume div 2 then
    Exit;
  StepResult := (Numerator + ASyringeVolume div 2) div ASyringeVolume;
  if StepResult > High(Integer) then
    Exit;
  if StepResult < 1 then
    StepResult := 1;
  Result := Integer(StepResult);
end;

function ValidChannel(AChannel, AChannelCount: Integer): Boolean;
begin
  Result := (AChannel >= MIN_CHANNEL_NUMBER) and
    (AChannel <= AChannelCount);
end;

function BuildOperationPlan(AConfig: TDispenserConfig;
  AKind: TDispenserOperationKind; ASelectedChannel: Integer;
  ACurrentVolume: Double; ACurrentVolumeKnown, ABypassActive: Boolean;
  out APlan: TDispenserOperationPlan; out ErrorText: string): Boolean;
var
  CurrentPositionSteps: Int64;
begin
  if (AConfig = nil) or not ACurrentVolumeKnown then
    Exit(BuildOperationPlanAtPosition(AConfig, AKind, ASelectedChannel, 0,
      ACurrentVolumeKnown, ABypassActive, APlan, ErrorText));

  if not N1StepsForMicroliters(ACurrentVolume, AConfig.Volume,
    AConfig.StepCount, CurrentPositionSteps) then
  begin
    FillChar(APlan, SizeOf(APlan), 0);
    ErrorText := 'Не удалось преобразовать текущий объём в шаги шприца.';
    Exit(False);
  end;

  Result := BuildOperationPlanAtPosition(AConfig, AKind, ASelectedChannel,
    CurrentPositionSteps, ACurrentVolumeKnown, ABypassActive, APlan,
    ErrorText);
end;

function BuildOperationPlanAtPosition(AConfig: TDispenserConfig;
  AKind: TDispenserOperationKind; ASelectedChannel: Integer;
  ACurrentPositionSteps: Int64; ACurrentVolumeKnown,
  ABypassActive: Boolean; out APlan: TDispenserOperationPlan;
  out ErrorText: string): Boolean;
var
  MaximumPositionSteps: Int64;
  PlannedSteps: Int64;
  CurrentVolume: Double;
  RequestedVolume: Integer;
  MinimumVolumeRateValue: Integer;
  MaximumVolumeRateValue: Integer;
  OperationSpeedValue: Integer;
begin
  FillChar(APlan, SizeOf(APlan), 0);
  ErrorText := '';
  Result := False;

  if AConfig = nil then
  begin
    ErrorText := 'Конфигурация дозатора не задана.';
    Exit;
  end;

  if ABypassActive then
  begin
    ErrorText := 'Операция недоступна: включён байпас.';
    Exit;
  end;

  if not ACurrentVolumeKnown then
  begin
    ErrorText := 'Текущий объём неизвестен. Требуется повторная инициализация.';
    Exit;
  end;

  MaximumPositionSteps := EffectiveN1StepCount(AConfig.StepCount);
  if (MaximumPositionSteps <= 0) or (ACurrentPositionSteps < 0) or
    (ACurrentPositionSteps > MaximumPositionSteps) then
  begin
    ErrorText := 'Текущий объём дозатора выходит за пределы вместимости шприца.';
    Exit;
  end;
  CurrentVolume := MicrolitersForN1Steps(ACurrentPositionSteps,
    AConfig.Volume, AConfig.StepCount);

  MinimumVolumeRateValue := MinimumVolumeRate(AConfig.Volume, AConfig.StepCount);
  MaximumVolumeRateValue := MaximumVolumeRate(MAX_SPEED, AConfig.Volume,
    AConfig.StepCount);
  if (MaximumVolumeRateValue < MinimumVolumeRateValue) or
    (AConfig.MaxFlowRate < MinimumVolumeRateValue) or
    (AConfig.MaxFlowRate > MaximumVolumeRateValue) then
  begin
    ErrorText := Format(
      'Максимальная скорость дозатора должна быть в диапазоне %d..%d мкл/с.',
      [MinimumVolumeRateValue, MaximumVolumeRateValue]);
    Exit;
  end;

  if AKind = dokFill then
    OperationSpeedValue := AConfig.MaxFlowRate
  else
  OperationSpeedValue := AConfig.Operation.Speed;

  if (OperationSpeedValue < MinimumVolumeRateValue) or
    (OperationSpeedValue > AConfig.MaxFlowRate) or
    not ConvertVolumeRateToMotorSpeed(OperationSpeedValue, MAX_SPEED,
      AConfig.Volume, AConfig.StepCount, APlan.MotorSpeed) then
  begin
    ErrorText := Format(
      'Скорость операции должна быть в диапазоне %d..%d мкл/с.',
      [MinimumVolumeRateValue, AConfig.MaxFlowRate]);
    Exit;
  end;

  PlannedSteps := 0;
  case AKind of
    dokFill:
      begin
        APlan.Channel := AConfig.IntakeChannel;
        APlan.Aspirate := True;
        if not ValidChannel(APlan.Channel, AConfig.ChannelCount) then
        begin
          ErrorText := 'Канал забора выходит за диапазон каналов дозатора.';
          Exit;
        end;
        PlannedSteps := MaximumPositionSteps - ACurrentPositionSteps;
        if PlannedSteps <= 0 then
        begin
          ErrorText := 'Дозатор уже наполнен.';
          Exit;
        end;
      end;

    dokEmpty:
      begin
        APlan.Channel := ASelectedChannel;
        APlan.Aspirate := False;
        if not ValidChannel(APlan.Channel, AConfig.ChannelCount) then
        begin
          ErrorText := 'Выберите канал для опустошения дозатора.';
          Exit;
        end;
        PlannedSteps := ACurrentPositionSteps;
        if PlannedSteps <= 0 then
        begin
          ErrorText := 'Дозатор уже пуст.';
          Exit;
        end;
      end;

    dokAspirate:
      begin
        APlan.Channel := ASelectedChannel;
        RequestedVolume := AConfig.Operation.Volume;
        APlan.Volume := RequestedVolume;
        APlan.Aspirate := True;
        if not ValidChannel(APlan.Channel, AConfig.ChannelCount) then
        begin
          ErrorText := 'Выберите канал для набора жидкости.';
          Exit;
        end;
        if (RequestedVolume <= 0) or (RequestedVolume > AConfig.Volume) then
        begin
          ErrorText := 'Недопустимый объём набора жидкости.';
          Exit;
        end;
        PlannedSteps := CalculateOperationSteps(RequestedVolume,
          AConfig.Volume, AConfig.StepCount);
        if (PlannedSteps <= 0) or
          (ACurrentPositionSteps + PlannedSteps > MaximumPositionSteps) then
        begin
          ErrorText := Format(
            'Нельзя набрать %d мкл: вместимость шприца будет превышена.',
            [RequestedVolume]);
          Exit;
        end;
      end;

    dokDispense:
      begin
        APlan.Channel := ASelectedChannel;
        RequestedVolume := AConfig.Operation.Volume;
        APlan.Volume := RequestedVolume;
        APlan.Aspirate := False;
        if not ValidChannel(APlan.Channel, AConfig.ChannelCount) then
        begin
          ErrorText := 'Выберите канал для дозирования жидкости.';
          Exit;
        end;
        if (RequestedVolume <= 0) or (RequestedVolume > AConfig.Volume) then
        begin
          ErrorText := 'Недопустимый объём дозирования.';
          Exit;
        end;
        PlannedSteps := CalculateOperationSteps(RequestedVolume,
          AConfig.Volume, AConfig.StepCount);
        if (PlannedSteps <= 0) or (ACurrentPositionSteps < PlannedSteps) then
        begin
          ErrorText := Format(
            'Нельзя дозировать %d мкл: в шприце только %d мкл.',
            [RequestedVolume, Round(CurrentVolume)]);
          Exit;
        end;
      end;
  end;

  if (PlannedSteps <= 0) or (PlannedSteps > High(Integer)) then
  begin
    ErrorText := 'Не удалось рассчитать количество шагов операции.';
    Exit;
  end;
  APlan.Steps := Integer(PlannedSteps);
  APlan.ActualVolume := MicrolitersForN1Steps(PlannedSteps,
    AConfig.Volume, AConfig.StepCount);
  if AKind in [dokFill, dokEmpty] then
    APlan.Volume := Round(APlan.ActualVolume);

  Result := True;
end;


function OperationKindDescription(AKind: TDispenserOperationKind): string;
begin
  case AKind of
    dokFill: Result := 'наполнение';
    dokEmpty: Result := 'опустошение';
    dokAspirate: Result := 'набор';
    dokDispense: Result := 'дозирование';
  end;
end;

end.
