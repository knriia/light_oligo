unit DispenserConfigValidator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DispenserConfig, DispenserLimits, DispenserResolution;

type
  TDispenserConfigValidator = class
  public
    class procedure NormalizeOperation(AConfig: TDispenserConfig); static;
    class function Validate(const AConfig: TDispenserConfig;
      out ErrorText: string): Boolean; static;
    class function CanEnableBypass(const AConfig: TDispenserConfig;
      ASelectedChannel: Integer; ABypassSupported: Boolean;
      out ErrorText: string): Boolean; static;
    class function ValidateList(AConfigurations: TDispenserConfigList;
      out ErrorText: string): Boolean; static;
  end;

implementation

class procedure TDispenserConfigValidator.NormalizeOperation(
  AConfig: TDispenserConfig);
var
  MinimumVolumeRateValue: Integer;
  MaximumVolumeRateValue: Integer;
begin
  if AConfig = nil then
    Exit;

  if AConfig.Operation.Volume <= 0 then
    AConfig.Operation.Volume := AConfig.Volume;
  if AConfig.Operation.Volume > AConfig.Volume then
    AConfig.Operation.Volume := AConfig.Volume;
  MinimumVolumeRateValue := MinimumVolumeRate(AConfig.Volume, AConfig.StepCount);
  MaximumVolumeRateValue := AConfig.MaxFlowRate;
  if MaximumVolumeRateValue < MinimumVolumeRateValue then
    AConfig.Operation.Speed := 0
  else if (AConfig.Operation.Speed < MinimumVolumeRateValue) or
    (AConfig.Operation.Speed > MaximumVolumeRateValue) then
    AConfig.Operation.Speed := MaximumVolumeRateValue;
  if (AConfig.Operation.Channel < MIN_CHANNEL_NUMBER) or
    (AConfig.Operation.Channel > AConfig.ChannelCount) then
    AConfig.Operation.Channel := MIN_CHANNEL_NUMBER;
end;

class function TDispenserConfigValidator.Validate(
  const AConfig: TDispenserConfig; out ErrorText: string): Boolean;
var
  MinimumOperationRate: Integer;
  MaximumOperationRate: Integer;
begin
  ErrorText := '';
  if AConfig = nil then
  begin
    ErrorText := 'конфигурация не задана';
    Exit(False);
  end;

  if not (AConfig.Number in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
  begin
    ErrorText := 'порядковый номер должен быть от 1 до 15';
    Exit(False);
  end;

  if Trim(AConfig.Name) = '' then
  begin
    ErrorText := 'не задано имя';
    Exit(False);
  end;

  if not (AConfig.Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
  begin
    ErrorText := 'адрес должен быть от 1 до 15';
    Exit(False);
  end;

  if AConfig.Volume <= 0 then
  begin
    ErrorText := 'объём должен быть больше нуля';
    Exit(False);
  end;

  if (AConfig.ChannelCount < MIN_CHANNEL_COUNT) or
    (AConfig.ChannelCount > MAX_CHANNEL_COUNT) then
  begin
    ErrorText := Format('количество каналов должно быть от %d до %d',
      [MIN_CHANNEL_COUNT, MAX_CHANNEL_COUNT]);
    Exit(False);
  end;

  if AConfig.StepCount <= 0 then
  begin
    ErrorText := 'количество шагов должно быть больше нуля';
    Exit(False);
  end;

  if (AConfig.IntakeChannel < 1) or
    (AConfig.IntakeChannel > AConfig.ChannelCount) then
  begin
    ErrorText := 'канал забора выходит за диапазон каналов';
    Exit(False);
  end;

  MinimumOperationRate := MinimumVolumeRate(AConfig.Volume, AConfig.StepCount);
  MaximumOperationRate := MaximumVolumeRate(MAX_SPEED, AConfig.Volume,
    AConfig.StepCount);
  if (MinimumOperationRate <= 0) or
    (MaximumOperationRate < MinimumOperationRate) or
    (AConfig.MaxFlowRate < MinimumOperationRate) or
    (AConfig.MaxFlowRate > MaximumOperationRate) then
  begin
    ErrorText := Format(
      'максимальная скорость должна быть в диапазоне %d..%d мкл/с',
      [MinimumOperationRate, MaximumOperationRate]);
    Exit(False);
  end;

  if AConfig.Operation.Volume <= 0 then
  begin
    ErrorText := 'объём операции должен быть больше нуля';
    Exit(False);
  end;

  if AConfig.Operation.Volume > AConfig.Volume then
  begin
    ErrorText := 'объём операции не может превышать вместимость шприца';
    Exit(False);
  end;

  if AConfig.Operation.Speed < MinimumOperationRate then
  begin
    ErrorText := Format('скорость операции должна быть не менее %d мкл/с',
      [MinimumOperationRate]);
    Exit(False);
  end;

  if AConfig.Operation.Speed > AConfig.MaxFlowRate then
  begin
    ErrorText := Format('скорость операции не может превышать %d мкл/с',
      [AConfig.MaxFlowRate]);
    Exit(False);
  end;

  if (AConfig.Operation.Channel < MIN_CHANNEL_NUMBER) or
    (AConfig.Operation.Channel > AConfig.ChannelCount) then
  begin
    ErrorText := 'канал операции выходит за диапазон каналов';
    Exit(False);
  end;

  Result := True;
end;

class function TDispenserConfigValidator.CanEnableBypass(
  const AConfig: TDispenserConfig; ASelectedChannel: Integer;
  ABypassSupported: Boolean;
  out ErrorText: string): Boolean;
begin
  ErrorText := '';
  if AConfig = nil then
  begin
    ErrorText := 'Конфигурация дозатора не задана.';
    Exit(False);
  end;

  if not ABypassSupported then
  begin
    ErrorText := 'Байпас не поддерживается этим клапаном.';
    Exit(False);
  end;

  if (ASelectedChannel < MIN_CHANNEL_NUMBER) or
    (ASelectedChannel > AConfig.ChannelCount) then
  begin
    ErrorText := 'Нельзя включить байпас: выбран некорректный канал.';
    Exit(False);
  end;

  if ASelectedChannel = AConfig.IntakeChannel then
  begin
    ErrorText := 'Нельзя включить байпас: канал забора совпадает с выбранным каналом.';
    Exit(False);
  end;

  Result := True;
end;

class function TDispenserConfigValidator.ValidateList(
  AConfigurations: TDispenserConfigList; out ErrorText: string): Boolean;
var
  I, J: Integer;
  RowError: string;
begin
  ErrorText := '';
  if AConfigurations = nil then
  begin
    ErrorText := 'список конфигураций не задан';
    Exit(False);
  end;

  if AConfigurations.Count > MAX_DISPENSERS then
  begin
    ErrorText := 'поддерживается не более 15 дозаторов';
    Exit(False);
  end;

  for I := 0 to AConfigurations.Count - 1 do
  begin
    if not Validate(AConfigurations[I], RowError) then
    begin
      ErrorText := Format('Дозатор %d: %s', [I + 1, RowError]);
      Exit(False);
    end;

    for J := 0 to I - 1 do
    begin
      if AConfigurations[J].Number = AConfigurations[I].Number then
      begin
        ErrorText := Format('Дублируется порядковый номер %d.',
          [AConfigurations[I].Number]);
        Exit(False);
      end;

      if AConfigurations[J].Address = AConfigurations[I].Address then
      begin
        ErrorText := Format('Дублируется адрес %d.',
          [AConfigurations[I].Address]);
        Exit(False);
      end;

      if SameText(Trim(AConfigurations[J].Name),
        Trim(AConfigurations[I].Name)) then
      begin
        ErrorText := Format('Дублируется имя "%s".',
          [Trim(AConfigurations[I].Name)]);
        Exit(False);
      end;
    end;
  end;

  Result := True;
end;

end.
