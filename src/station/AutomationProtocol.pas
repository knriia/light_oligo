unit AutomationProtocol;
// Команды шприцевой станции, построенные из операций SyrSt и из сценария
// (списка операций). Формат записи SyrSt описан в ProtocolFormat; здесь значения
// проверяются по конфигурации дозаторов и переводятся в шаги и скорость
// двигателя. Пауза между операциями - команда без дозаторов.

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, DispenserConfig, DispenserLimits, ProtocolFormat,
  ScenarioList;

type
  TAutomationProtocolTarget = record
    Config: TDispenserConfig;
    ValveChannel: Integer;
    VolumeNanoLiters: Int64;
    SpeedNanoLitersPerSecond: Int64;
    TotalSteps: Int64;
    MotorSpeed: Integer;
  end;

  TAutomationProtocolCommand = class
  public
    Number: Integer;      // порядковый номер команды станции в протоколе
    BlockName: string;    // блок протокола, из которого взята команда
    BlockIndex: Integer;  // номер блока (с нуля)
    LineNumber: Integer;  // строка операции SyrSt в файле
    PauseSeconds: Integer; // для паузы: сколько секунд ждать
    Targets: array of TAutomationProtocolTarget;
    // Команда без дозаторов - пауза.
    function IsPause: Boolean;
  end;

  TAutomationProtocol = class
  private
  FCommands: TObjectList;
  function GetCommand(Index: Integer): TAutomationProtocolCommand;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    // Добавляет команду; протокол становится её владельцем.
    procedure Add(ACommand: TAutomationProtocolCommand);
    property Count: Integer read GetCount;
    property Commands[Index: Integer]: TAutomationProtocolCommand
      read GetCommand; default;
  end;

const
  ALL_BLOCKS = -1;

// Строит команды станции из сценария: шприцевая станция - подача, пауза -
// ожидание. С AItemIndex - только одна выбранная операция станции. В
// сценарии должна быть хотя бы одна такая операция. Ошибка называет номер
// операции в списке (с 1).
function BuildScenarioProtocol(AScenarios: TScenarioList;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string;
  AItemIndex: Integer = ALL_BLOCKS): Boolean;

// Проверяет одну операцию SyrSt по конфигурации и строит из неё команду.
function BuildSyringeCommand(const AStep: TSyringeStep;
  AConfigurations: TDispenserConfigList;
  out ACommand: TAutomationProtocolCommand; out ErrorText: string): Boolean;

implementation

uses
  Math, StrUtils, DispenserResolution;

function TAutomationProtocolCommand.IsPause: Boolean;
begin
  Result := Length(Targets) = 0;
end;

constructor TAutomationProtocol.Create;
begin
  inherited Create;
  FCommands := TObjectList.Create(True);
end;

destructor TAutomationProtocol.Destroy;
begin
  FCommands.Free;
  inherited Destroy;
end;

procedure TAutomationProtocol.Add(ACommand: TAutomationProtocolCommand);
begin
  FCommands.Add(ACommand);
end;

function TAutomationProtocol.GetCommand(
  Index: Integer): TAutomationProtocolCommand;
begin
  Result := TAutomationProtocolCommand(FCommands[Index]);
end;

function TAutomationProtocol.GetCount: Integer;
begin
  Result := FCommands.Count;
end;

function ParsePositiveInteger(const AText: string;
  out AValue: Integer): Boolean;
var
  ValueText: string;
begin
  ValueText := Trim(AText);
  Result := TryStrToInt(ValueText, AValue) and (AValue > 0);
end;

function ParsePositiveDecimal(const AText: string; out AValue: Extended): Boolean;
var
  ValueText: string;
  FormatSettings: TFormatSettings;
  DotPosition: Integer;
  CommaPosition: Integer;
begin
  Result := False;
  AValue := 0;
  ValueText := Trim(AText);
  if ValueText = '' then
    Exit;

  DotPosition := Pos('.', ValueText);
  CommaPosition := Pos(',', ValueText);
  if (DotPosition > 0) and (CommaPosition > 0) then
    Exit;
  if (CommaPosition > 0) and (Pos(',', Copy(ValueText, CommaPosition + 1,
    MaxInt)) > 0) then
    Exit;
  if (DotPosition > 0) and (Pos('.', Copy(ValueText, DotPosition + 1,
    MaxInt)) > 0) then
    Exit;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.ThousandSeparator := #0;
  if DotPosition > 0 then
    ValueText := StringReplace(ValueText, '.', FormatSettings.DecimalSeparator,
      [rfReplaceAll])
  else if CommaPosition > 0 then
    ValueText := StringReplace(ValueText, ',', FormatSettings.DecimalSeparator,
      [rfReplaceAll]);

  Result := TryStrToFloat(ValueText, AValue, FormatSettings) and
    (AValue > 0) and not IsNan(AValue) and not IsInfinite(AValue);
end;

function ParseScaledPositiveValue(const AText: string; AScale: Int64;
  out AValue: Int64): Boolean;
var
  ParsedValue: Extended;
  ScaledValue: Extended;
  RoundedValue: Int64;
begin
  AValue := 0;
  Result := False;
  if not ParsePositiveDecimal(AText, ParsedValue) then
    Exit;
  ScaledValue := ParsedValue * AScale;
  if (ScaledValue < 1) or (ScaledValue > High(Int64)) then
    Exit;
  RoundedValue := Round(ScaledValue);
  if Abs(ScaledValue - RoundedValue) > 0.000001 then
    Exit;
  AValue := RoundedValue;
  Result := True;
end;

function FindConfiguration(const AName: string;
  AConfigurations: TDispenserConfigList; out AConfig: TDispenserConfig;
  out ErrorText: string): Boolean;
var
  I: Integer;
begin
  AConfig := nil;
  ErrorText := '';
  for I := 0 to AConfigurations.Count - 1 do
    if SameText(Trim(AConfigurations[I].Name), Trim(AName)) then
    begin
      if AConfig <> nil then
      begin
        ErrorText := 'Имя дозатора "' + AName + '" неоднозначно: в конфигурации есть дубликаты.';
        Exit(False);
      end;
      AConfig := AConfigurations[I];
    end;

  Result := AConfig <> nil;
  if not Result then
    ErrorText := 'Дозатор с именем "' + AName + '" не найден в конфигурации.';
end;

function ComputeTargetSteps(AVolumeNanoLiters: Int64;
  AConfig: TDispenserConfig; out ASteps: Int64): Boolean;
var
  EffectiveStepCount: Int64;
  Denominator: Int64;
  Numerator: Int64;
begin
  Result := False;
  ASteps := 0;
  if (AConfig = nil) or (AConfig.Volume <= 0) or
    (AVolumeNanoLiters <= 0) then
    Exit;

  EffectiveStepCount := EffectiveN1StepCount(AConfig.StepCount);
  Denominator := Int64(AConfig.Volume) * 1000;
  if (EffectiveStepCount <= 0) or (Denominator <= 0) or
    (AVolumeNanoLiters > High(Int64) div EffectiveStepCount) then
    Exit;

  Numerator := AVolumeNanoLiters * EffectiveStepCount;
  if Numerator > High(Int64) - Denominator div 2 then
    Exit;
  ASteps := (Numerator + Denominator div 2) div Denominator;
  Result := ASteps > 0;
end;

function BuildSyringeCommand(const AStep: TSyringeStep;
  AConfigurations: TDispenserConfigList;
  out ACommand: TAutomationProtocolCommand; out ErrorText: string): Boolean;
var
  FieldError: string;
  Names: TStringList;
  Channels: TStringList;
  Volumes: TStringList;
  Speeds: TStringList;
  Command: TAutomationProtocolCommand;
  Target: TAutomationProtocolTarget;
  I: Integer;
  TargetCount: Integer;
  ValueIndex: Integer;
  VolumeScale: Int64;
  SpeedScale: Int64;
  ParsedInteger: Integer;
  Config: TDispenserConfig;
  MotorSpeedValue: Extended;
  MaxFlowNanoLiters: Int64;
begin
  Result := False;
  ErrorText := '';
  ACommand := nil;
  if AConfigurations = nil then
  begin
    ErrorText := 'Не задан список дозаторов.';
    Exit;
  end;
  if not CheckSyringeStep(AStep, ErrorText) then
    Exit;
  VolumeUnitScale(AStep.VolumeUnit, VolumeScale);
  SpeedUnitScale(AStep.SpeedUnit, SpeedScale);

  Names := TStringList.Create;
  Channels := TStringList.Create;
  Volumes := TStringList.Create;
  Speeds := TStringList.Create;
  Command := nil;
  try
    SplitSlashValues(AStep.Dispensers, Names);
    SplitSlashValues(AStep.Valves, Channels);
    SplitSlashValues(AStep.Volumes, Volumes);
    SplitSlashValues(AStep.Speeds, Speeds);

    TargetCount := Names.Count;
    Command := TAutomationProtocolCommand.Create;
    SetLength(Command.Targets, TargetCount);
    for I := 0 to TargetCount - 1 do
    begin
      if not FindConfiguration(Names[I], AConfigurations, Config,
        FieldError) then
      begin
        ErrorText := FieldError;
        Exit;
      end;
      for ValueIndex := 0 to I - 1 do
        if Command.Targets[ValueIndex].Config = Config then
        begin
          ErrorText := 'Дозатор "' + Names[I] +
            '" указан в операции несколько раз.';
          Exit;
        end;

      Target.Config := Config;
      ValueIndex := 0;
      if Channels.Count > 1 then
        ValueIndex := I;
      if not ParsePositiveInteger(Channels[ValueIndex], ParsedInteger) or
        (ParsedInteger > Config.ChannelCount) then
      begin
        ErrorText := 'Дозатор "' + Config.Name + '": недопустимый канал клапана.';
        Exit;
      end;
      Target.ValveChannel := ParsedInteger;
      if Target.ValveChannel = Config.IntakeChannel then
      begin
        ErrorText := Format(
          'Для дозатора "%s" входной и выходной каналы совпадают. ' +
          'Измените номер канала в конфигураторе или протоколе.',
          [Config.Name]);
        Exit;
      end;

      ValueIndex := 0;
      if Volumes.Count > 1 then
        ValueIndex := I;
      if not ParseScaledPositiveValue(Volumes[ValueIndex], VolumeScale,
        Target.VolumeNanoLiters) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": объём должен быть положительным числом с точностью до 1 нл.';
        Exit;
      end;
      if not ComputeTargetSteps(Target.VolumeNanoLiters, Config,
        Target.TotalSteps) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": объём слишком мал для разрешения шприца или слишком велик.';
        Exit;
      end;

      ValueIndex := 0;
      if Speeds.Count > 1 then
        ValueIndex := I;
      if not ParseScaledPositiveValue(Speeds[ValueIndex], SpeedScale,
        Target.SpeedNanoLitersPerSecond) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": скорость должна быть положительной с точностью до 1 нл/с.';
        Exit;
      end;
      MaxFlowNanoLiters := Int64(Config.MaxFlowRate) * 1000;
      if (Config.MaxFlowRate <= 0) or
        (Target.SpeedNanoLitersPerSecond > MaxFlowNanoLiters) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": скорость превышает максимальную из конфигуратора (' +
          IntToStr(Config.MaxFlowRate) + ' мкл/с).';
        Exit;
      end;
      MotorSpeedValue := Extended(Target.SpeedNanoLitersPerSecond) *
        Config.StepCount / (Int64(Config.Volume) * 1000);
      if (MotorSpeedValue < MIN_SPEED) or (MotorSpeedValue > MAX_SPEED) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": скорость не поддерживается устройством.';
        Exit;
      end;
      Target.MotorSpeed := Round(MotorSpeedValue);
      if (Target.MotorSpeed < MIN_SPEED) or
        (Target.MotorSpeed > MAX_SPEED) then
      begin
        ErrorText := 'Дозатор "' + Config.Name +
          '": скорость не поддерживается устройством.';
        Exit;
      end;

      Command.Targets[I] := Target;
    end;

    ACommand := Command;
    Command := nil;
    Result := True;
  finally
    Command.Free;
    Speeds.Free;
    Volumes.Free;
    Channels.Free;
    Names.Free;
  end;
end;

function BuildScenarioProtocol(AScenarios: TScenarioList;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string;
  AItemIndex: Integer): Boolean;
var
  I: Integer;
  Item: TScenarioItem;
  Command: TAutomationProtocolCommand;
  CommandError: string;
  ScenarioCommands: Integer;
begin
  Result := False;
  ErrorText := '';
  AProtocol := nil;
  if AConfigurations = nil then
  begin
    ErrorText := 'Не задан список дозаторов.';
    Exit;
  end;
  if (AScenarios = nil) or (AScenarios.Count = 0) then
  begin
    ErrorText := 'В сценарии нет операций шприцевой станции.';
    Exit;
  end;
  if (AItemIndex <> ALL_BLOCKS) and
    ((AItemIndex < 0) or (AItemIndex >= AScenarios.Count)) then
  begin
    ErrorText := 'Выбранная операция не найдена в сценарии.';
    Exit;
  end;
  if (AItemIndex <> ALL_BLOCKS) and
    (AScenarios[AItemIndex].Kind <> sikSyringe) then
  begin
    ErrorText := 'Выбрана пауза. Запускать можно только операцию шприцевой станции.';
    Exit;
  end;

  AProtocol := TAutomationProtocol.Create;
  try
    ScenarioCommands := 0;
    for I := 0 to AScenarios.Count - 1 do
    begin
      if (AItemIndex <> ALL_BLOCKS) and (I <> AItemIndex) then
        Continue;
      Item := AScenarios[I];
      if not CheckScenarioItem(Item, CommandError) then
      begin
        ErrorText := 'Операция ' + IntToStr(I + 1) + ': ' + CommandError;
        Exit;
      end;
      if Item.Kind = sikPause then
      begin
        Command := TAutomationProtocolCommand.Create;
        Command.PauseSeconds := Item.PauseSeconds;
      end
      else
      begin
        if not BuildSyringeCommand(Item.Syringe, AConfigurations, Command,
          CommandError) then
        begin
          ErrorText := 'Операция ' + IntToStr(I + 1) + ': ' + CommandError;
          Exit;
        end;
        Inc(ScenarioCommands);
      end;
      Command.Number := AProtocol.Count + 1;
      Command.LineNumber := I + 1; // номер элемента в списке
      AProtocol.Add(Command);
    end;

    if ScenarioCommands = 0 then
    begin
      ErrorText := 'В сценарии нет операций шприцевой станции.';
      Exit;
    end;
    Result := True;
  finally
    if not Result then
    begin
      AProtocol.Free;
      AProtocol := nil;
    end;
  end;
end;

end.
