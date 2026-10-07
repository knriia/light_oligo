unit DispenserCapacityValidator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DispenserConfig;

type
  TDispenserVolumeProvider = function(AAddress: Integer): Double of object;
  TDispenserVolumeKnownProvider = function(AAddress: Integer): Boolean of object;

  TDispenserCapacityValidator = class
  private
    class function FindConfigByAddress(AConfigurations:
      TDispenserConfigList; AAddress: Integer): TDispenserConfig; static;
    class function FindConfigByNumber(AConfigurations:
      TDispenserConfigList; ANumber: Integer): TDispenserConfig; static;
    class function FindPreviousConfig(AConfigurations: TDispenserConfigList;
      const AConfig: TDispenserConfig): TDispenserConfig; static;
  public
    class function ValidateChange(AOldConfigurations,
      ANewConfigurations: TDispenserConfigList;
      AVolumeProvider: TDispenserVolumeProvider;
      out ErrorText: string): Boolean; static;
  end;

implementation

class function TDispenserCapacityValidator.FindConfigByAddress(
  AConfigurations: TDispenserConfigList;
  AAddress: Integer): TDispenserConfig;
var
  I: Integer;
begin
  Result := nil;
  if AConfigurations = nil then
    Exit;

  for I := 0 to AConfigurations.Count - 1 do
    if AConfigurations[I].Address = AAddress then
      Exit(AConfigurations[I]);
end;

class function TDispenserCapacityValidator.FindConfigByNumber(
  AConfigurations: TDispenserConfigList;
  ANumber: Integer): TDispenserConfig;
var
  I: Integer;
begin
  Result := nil;
  if AConfigurations = nil then
    Exit;

  for I := 0 to AConfigurations.Count - 1 do
    if AConfigurations[I].Number = ANumber then
      Exit(AConfigurations[I]);
end;

class function TDispenserCapacityValidator.FindPreviousConfig(
  AConfigurations: TDispenserConfigList;
  const AConfig: TDispenserConfig): TDispenserConfig;
var
  I: Integer;
begin
  Result := nil;
  if (AConfigurations = nil) or (AConfig = nil) then
    Exit;

  for I := 0 to AConfigurations.Count - 1 do
    if AConfigurations[I].Address = AConfig.Address then
      Exit(AConfigurations[I]);

  for I := 0 to AConfigurations.Count - 1 do
    if AConfigurations[I].Number = AConfig.Number then
      Exit(AConfigurations[I]);
end;

class function TDispenserCapacityValidator.ValidateChange(
  AOldConfigurations, ANewConfigurations: TDispenserConfigList;
  AVolumeProvider: TDispenserVolumeProvider;
  out ErrorText: string): Boolean;
var
  I: Integer;
  PreviousConfig: TDispenserConfig;
  NewConfigByAddress: TDispenserConfig;
  NewConfigByNumber: TDispenserConfig;
  CurrentVolume: Double;
begin
  ErrorText := '';
  if ANewConfigurations = nil then
  begin
    ErrorText := 'новая конфигурация не задана';
    Exit(False);
  end;

  if not Assigned(AVolumeProvider) then
  begin
    ErrorText := 'невозможно проверить текущий объём дозаторов';
    Exit(False);
  end;

  if AOldConfigurations <> nil then
    for I := 0 to AOldConfigurations.Count - 1 do
    begin
      CurrentVolume := AVolumeProvider(AOldConfigurations[I].Address);
      if CurrentVolume <= 0 then
        Continue;

      NewConfigByAddress := FindConfigByAddress(ANewConfigurations,
        AOldConfigurations[I].Address);
      NewConfigByNumber := FindConfigByNumber(ANewConfigurations,
        AOldConfigurations[I].Number);

      if (NewConfigByNumber <> nil) and
        (NewConfigByNumber.Address <> AOldConfigurations[I].Address) then
      begin
        ErrorText := Format(
          '%s: нельзя изменить адрес с %d на %d, пока в дозаторе есть жидкость (%.0f мкл).',
          [AOldConfigurations[I].Name, AOldConfigurations[I].Address,
          NewConfigByNumber.Address, CurrentVolume]);
        Exit(False);
      end;

      if NewConfigByAddress = nil then
      begin
        ErrorText := Format(
          '%s: нельзя удалить дозатор, пока в нём есть жидкость (%.0f мкл).',
          [AOldConfigurations[I].Name, CurrentVolume]);
        Exit(False);
      end;
    end;

  for I := 0 to ANewConfigurations.Count - 1 do
  begin
    if ANewConfigurations[I].Operation.Volume >
      ANewConfigurations[I].Volume then
    begin
      ErrorText := Format(
        '%s: объём операции %d мкл превышает вместимость шприца %d мкл.',
        [ANewConfigurations[I].Name,
        ANewConfigurations[I].Operation.Volume,
        ANewConfigurations[I].Volume]);
      Exit(False);
    end;

    PreviousConfig := FindPreviousConfig(AOldConfigurations,
      ANewConfigurations[I]);
    if PreviousConfig = nil then
      Continue;

    CurrentVolume := AVolumeProvider(PreviousConfig.Address);
    if CurrentVolume > ANewConfigurations[I].Volume then
    begin
      ErrorText := Format(
        '%s: Сначала опустошите дозатор. Текущий объём %.0f мкл превышает новую вместимость %d мкл.',
        [ANewConfigurations[I].Name, CurrentVolume,
        ANewConfigurations[I].Volume]);
      Exit(False);
    end;
  end;

  Result := True;
end;

end.
