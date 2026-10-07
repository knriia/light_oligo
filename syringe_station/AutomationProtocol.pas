unit AutomationProtocol;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, DispenserConfig, DispenserLimits;

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
    Number: Integer;
    Targets: array of TAutomationProtocolTarget;
  end;

  TAutomationProtocol = class
  private
  FCommands: TObjectList;
  function GetCommand(Index: Integer): TAutomationProtocolCommand;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read GetCount;
    property Commands[Index: Integer]: TAutomationProtocolCommand
      read GetCommand; default;
  end;

function ParseAutomationProtocol(const AText: string;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;

implementation

uses
  Math, StrUtils, DispenserResolution;

const
  REQUIRED_FIELD_COUNT = 6;

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

function TAutomationProtocol.GetCommand(
  Index: Integer): TAutomationProtocolCommand;
begin
  Result := TAutomationProtocolCommand(FCommands[Index]);
end;

function TAutomationProtocol.GetCount: Integer;
begin
  Result := FCommands.Count;
end;

function ParseQuotedValue(const AText: string; out AValue,
  ErrorText: string): Boolean;
var
  I: Integer;
  Closed: Boolean;
  C: Char;
  Remainder: string;
begin
  Result := False;
  AValue := '';
  ErrorText := '';
  if (AText = '') or (AText[1] <> '"') then
  begin
    ErrorText := 'Значение поля должно быть заключено в двойные кавычки.';
    Exit;
  end;

  Closed := False;
  I := 2;
  while I <= Length(AText) do
  begin
    C := AText[I];
    if C = '"' then
    begin
      Closed := True;
      Inc(I);
      Break;
    end;

    if (C = '\') and (I < Length(AText)) then
    begin
      Inc(I);
      case AText[I] of
        '\': AValue := AValue + '\';
        '"': AValue := AValue + '"';
        'r': AValue := AValue + #13;
        'n': AValue := AValue + #10;
      else
        begin
          ErrorText := 'В значении поля обнаружена неизвестная escape-последовательность.';
          Exit;
        end;
      end;
    end
    else
      AValue := AValue + C;
    Inc(I);
  end;

  if not Closed then
  begin
    ErrorText := 'Не найдена закрывающая двойная кавычка.';
    Exit;
  end;

  Remainder := Trim(Copy(AText, I, MaxInt));
  if (Remainder <> '') and (Remainder <> ';') then
  begin
    ErrorText := 'После значения поля обнаружен лишний текст.';
    Exit;
  end;

  Result := True;
end;

function SplitSlashValues(const AText: string; AValues: TStrings): Boolean;
var
  StartAt: Integer;
  SlashAt: Integer;
  ValueText: string;
begin
  AValues.Clear;
  StartAt := 1;
  repeat
    SlashAt := PosEx('/', AText, StartAt);
    if SlashAt = 0 then
      ValueText := Copy(AText, StartAt, MaxInt)
    else
      ValueText := Copy(AText, StartAt, SlashAt - StartAt);
    ValueText := Trim(ValueText);
    if ValueText = '' then
      Exit(False);
    AValues.Add(ValueText);
    if SlashAt = 0 then
      Break;
    StartAt := SlashAt + 1;
  until False;
  Result := AValues.Count > 0;
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

function VolumeUnitScale(const AUnit: string; out AScale: Int64): Boolean;
begin
  AScale := 0;
  if SameText(Trim(AUnit), 'нл') then
    AScale := 1
  else if SameText(Trim(AUnit), 'мкл') then
    AScale := 1000
  else if SameText(Trim(AUnit), 'мл') then
    AScale := 1000000;
  Result := AScale > 0;
end;

function SpeedUnitScale(const AUnit: string; out AScale: Int64): Boolean;
begin
  AScale := 0;
  if SameText(Trim(AUnit), 'нл/с') then
    AScale := 1
  else if SameText(Trim(AUnit), 'мкл/с') then
    AScale := 1000
  else if SameText(Trim(AUnit), 'мл/с') then
    AScale := 1000000;
  Result := AScale > 0;
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

function ParseCommandBlock(ALines: TStrings; var ALineIndex: Integer;
  AConfigurations: TDispenserConfigList; AProtocol: TAutomationProtocol;
  ACommandNumbers: TStrings; out ErrorText: string): Boolean;
var
  Header: string;
  ColonAt: Integer;
  CommandNumber: Integer;
  CommandNumberText: string;
  FieldName: string;
  FieldValue: string;
  FieldError: string;
  Fields: TStringList;
  Names: TStringList;
  Channels: TStringList;
  Volumes: TStringList;
  Speeds: TStringList;
  Command: TAutomationProtocolCommand;
  Target: TAutomationProtocolTarget;
  I: Integer;
  TargetCount: Integer;
  ValueIndex: Integer;
  UnitScale: Int64;
  ParsedInteger: Integer;
  Config: TDispenserConfig;
  MotorSpeedValue: Extended;
  MaxFlowNanoLiters: Int64;
  FieldText: string;
begin
  Result := False;
  ErrorText := '';
  Header := Trim(ALines[ALineIndex]);
  if Copy(Header, 1, 8) <> 'command_' then
  begin
    ErrorText := 'Ожидалась строка с номером команды command_N.';
    Exit;
  end;

  ColonAt := Pos(':', Header);
  if ColonAt <= 9 then
  begin
    ErrorText := 'У команды должен быть задан номер и двоеточие.';
    Exit;
  end;
  CommandNumberText := Copy(Header, 9, ColonAt - 9);
  if not ParsePositiveInteger(CommandNumberText, CommandNumber) then
  begin
    ErrorText := 'Номер команды должен быть положительным целым числом.';
    Exit;
  end;
  if ACommandNumbers.IndexOf(IntToStr(CommandNumber)) >= 0 then
  begin
    ErrorText := 'Номер команды ' + IntToStr(CommandNumber) + ' повторяется.';
    Exit;
  end;
  if Trim(Copy(Header, ColonAt + 1, MaxInt)) <> '{' then
  begin
    ErrorText := 'После номера команды ожидается открывающая фигурная скобка.';
    Exit;
  end;

  ACommandNumbers.Add(IntToStr(CommandNumber));
  Fields := TStringList.Create;
  Names := TStringList.Create;
  Channels := TStringList.Create;
  Volumes := TStringList.Create;
  Speeds := TStringList.Create;
  Command := nil;
  try
    Fields.CaseSensitive := False;
    Inc(ALineIndex);
    while ALineIndex < ALines.Count do
    begin
      FieldText := Trim(ALines[ALineIndex]);
      if FieldText = '}' then
        Break;
      if FieldText = '' then
      begin
        Inc(ALineIndex);
        Continue;
      end;

      ColonAt := Pos(':', FieldText);
      if ColonAt <= 1 then
      begin
        ErrorText := 'Некорректная строка параметра команды ' +
          IntToStr(CommandNumber) + '.';
        Exit;
      end;
      FieldName := Trim(Copy(FieldText, 1, ColonAt - 1));
      if Fields.IndexOfName(FieldName) >= 0 then
      begin
        ErrorText := 'Параметр "' + FieldName + '" повторяется в команде ' +
          IntToStr(CommandNumber) + '.';
        Exit;
      end;
      if not ParseQuotedValue(Trim(Copy(FieldText, ColonAt + 1, MaxInt)),
        FieldValue, FieldError) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', параметр ' +
          FieldName + ': ' + FieldError;
        Exit;
      end;
      Fields.Values[FieldName] := FieldValue;
      Inc(ALineIndex);
    end;

    if ALineIndex >= ALines.Count then
    begin
      ErrorText := 'Команда ' + IntToStr(CommandNumber) +
        ' не закрыта фигурной скобкой.';
      Exit;
    end;
    if Fields.Count <> REQUIRED_FIELD_COUNT then
    begin
      ErrorText := 'В команде ' + IntToStr(CommandNumber) +
        ' должны быть заданы ровно шесть параметров.';
      Exit;
    end;
    if (Fields.IndexOfName('dispenser_names') < 0) or
      (Fields.IndexOfName('valve_channels') < 0) or
      (Fields.IndexOfName('volumes') < 0) or
      (Fields.IndexOfName('volume_unit') < 0) or
      (Fields.IndexOfName('speeds') < 0) or
      (Fields.IndexOfName('speed_unit') < 0) then
    begin
      ErrorText := 'В команде ' + IntToStr(CommandNumber) +
        ' отсутствует обязательный параметр.';
      Exit;
    end;
    for I := 0 to Fields.Count - 1 do
      if not (SameText(Fields.Names[I], 'dispenser_names') or
        SameText(Fields.Names[I], 'valve_channels') or
        SameText(Fields.Names[I], 'volumes') or
        SameText(Fields.Names[I], 'volume_unit') or
        SameText(Fields.Names[I], 'speeds') or
        SameText(Fields.Names[I], 'speed_unit')) then
      begin
        ErrorText := 'Неизвестный параметр "' + Fields.Names[I] +
          '" в команде ' + IntToStr(CommandNumber) + '.';
        Exit;
      end;

    if not SplitSlashValues(Fields.Values['dispenser_names'], Names) then
    begin
      ErrorText := 'В команде ' + IntToStr(CommandNumber) +
        ' не заданы имена дозаторов.';
      Exit;
    end;
    if not SplitSlashValues(Fields.Values['valve_channels'], Channels) or
      not SplitSlashValues(Fields.Values['volumes'], Volumes) or
      not SplitSlashValues(Fields.Values['speeds'], Speeds) then
    begin
      ErrorText := 'Списки каналов, объёмов и скоростей не должны содержать пустых значений.';
      Exit;
    end;

    TargetCount := Names.Count;
    if not (Channels.Count in [1, TargetCount]) or
      not (Volumes.Count in [1, TargetCount]) or
      not (Speeds.Count in [1, TargetCount]) then
    begin
      ErrorText := 'Количество значений каналов, объёмов и скоростей должно быть равно числу дозаторов или одному.';
      Exit;
    end;
    if not VolumeUnitScale(Fields.Values['volume_unit'], UnitScale) then
    begin
      ErrorText := 'Неизвестная единица объёма: "' +
        Fields.Values['volume_unit'] + '".';
      Exit;
    end;
    Command := TAutomationProtocolCommand.Create;
    Command.Number := CommandNumber;
    SetLength(Command.Targets, TargetCount);
    for I := 0 to TargetCount - 1 do
    begin
      if not FindConfiguration(Names[I], AConfigurations, Config,
        FieldError) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ': ' + FieldError;
        Exit;
      end;
      for ValueIndex := 0 to I - 1 do
        if Command.Targets[ValueIndex].Config = Config then
        begin
          ErrorText := 'Дозатор "' + Names[I] +
            '" указан в команде несколько раз.';
          Exit;
        end;

      Target.Config := Config;
      ValueIndex := 0;
      if Channels.Count > 1 then
        ValueIndex := I;
      if not ParsePositiveInteger(Channels[ValueIndex], ParsedInteger) or
        (ParsedInteger > Config.ChannelCount) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": недопустимый канал клапана.';
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
      if not ParseScaledPositiveValue(Volumes[ValueIndex], UnitScale,
        Target.VolumeNanoLiters) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": объём должен быть положительным числом с точностью до 1 нл.';
        Exit;
      end;
      if not ComputeTargetSteps(Target.VolumeNanoLiters, Config,
        Target.TotalSteps) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": объём слишком мал для разрешения шприца или слишком велик.';
        Exit;
      end;

      if not SpeedUnitScale(Fields.Values['speed_unit'], UnitScale) then
      begin
        ErrorText := 'Неизвестная единица скорости: "' +
          Fields.Values['speed_unit'] + '".';
        Exit;
      end;
      ValueIndex := 0;
      if Speeds.Count > 1 then
        ValueIndex := I;
      if not ParseScaledPositiveValue(Speeds[ValueIndex], UnitScale,
        Target.SpeedNanoLitersPerSecond) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": скорость должна быть положительной с точностью до 1 нл/с.';
        Exit;
      end;
      MaxFlowNanoLiters := Int64(Config.MaxFlowRate) * 1000;
      if (Config.MaxFlowRate <= 0) or
        (Target.SpeedNanoLitersPerSecond > MaxFlowNanoLiters) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": скорость превышает максимальную из конфигуратора (' +
          IntToStr(Config.MaxFlowRate) + ' мкл/с).';
        Exit;
      end;
      MotorSpeedValue := Extended(Target.SpeedNanoLitersPerSecond) *
        Config.StepCount / (Int64(Config.Volume) * 1000);
      if (MotorSpeedValue < MIN_SPEED) or (MotorSpeedValue > MAX_SPEED) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": скорость не поддерживается устройством.';
        Exit;
      end;
      Target.MotorSpeed := Round(MotorSpeedValue);
      if (Target.MotorSpeed < MIN_SPEED) or
        (Target.MotorSpeed > MAX_SPEED) then
      begin
        ErrorText := 'Команда ' + IntToStr(CommandNumber) + ', дозатор "' +
          Config.Name + '": скорость не поддерживается устройством.';
        Exit;
      end;

      Command.Targets[I] := Target;
    end;

    AProtocol.FCommands.Add(Command);
    Command := nil;
    Result := True;
  finally
    Command.Free;
    Speeds.Free;
    Volumes.Free;
    Channels.Free;
    Names.Free;
    Fields.Free;
  end;
end;

function ParseAutomationProtocol(const AText: string;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;
var
  Lines: TStringList;
  CommandNumbers: TStringList;
  LineIndex: Integer;
  LineText: string;
begin
  Result := False;
  ErrorText := '';
  AProtocol := nil;
  if AConfigurations = nil then
  begin
    ErrorText := 'Не задан список дозаторов.';
    Exit;
  end;

  AProtocol := TAutomationProtocol.Create;
  Lines := TStringList.Create;
  CommandNumbers := TStringList.Create;
  try
    Lines.Text := AText;
    LineIndex := 0;
    while LineIndex < Lines.Count do
    begin
      LineText := Trim(Lines[LineIndex]);
      if LineText = '' then
      begin
        Inc(LineIndex);
        Continue;
      end;
      if not ParseCommandBlock(Lines, LineIndex, AConfigurations, AProtocol,
        CommandNumbers, ErrorText) then
      begin
        ErrorText := 'Строка ' + IntToStr(LineIndex + 1) + ': ' + ErrorText;
        Exit;
      end;
      Inc(LineIndex);
    end;

    if AProtocol.Count = 0 then
    begin
      ErrorText := 'В протоколе нет команд.';
      Exit;
    end;
    Result := True;
  finally
    Lines.Free;
    CommandNumbers.Free;
    if not Result then
    begin
      AProtocol.Free;
      AProtocol := nil;
    end;
  end;
end;

end.
