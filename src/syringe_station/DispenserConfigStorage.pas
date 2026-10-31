unit DispenserConfigStorage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, IniFiles, DispenserConfig, DispenserConfigValidator,
  DispenserLimits, DispenserResolution;

type
  TDispenserConfigStorage = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string = '');
    function Load(out AConfigurations: TDispenserConfigList;
      out ErrorText: string): Boolean;
    function Save(AConfigurations: TDispenserConfigList;
      out ErrorText: string): Boolean;
    property FileName: string read FFileName;
  end;

implementation

const
  CONFIG_SECTION = 'Configuration';
  DISPENSER_SECTION_PREFIX = 'Dispenser';

function IsDispenserSection(const ASection: string): Boolean;
var
  SectionNumber: Integer;
begin
  Result := StartsText(DISPENSER_SECTION_PREFIX, ASection) and
    TryStrToInt(Copy(ASection, Length(DISPENSER_SECTION_PREFIX) + 1,
      MaxInt), SectionNumber) and (SectionNumber >= MIN_DISPENSER_VALUE);
end;

function TryReadIntegerOrDefault(Ini: TIniFile; const Section, Ident: string;
  ADefault: Integer; out AValue: Integer): Boolean;
var
  RawValue: string;
begin
  if not Ini.ValueExists(Section, Ident) then
  begin
    AValue := ADefault;
    Exit(True);
  end;

  RawValue := Trim(Ini.ReadString(Section, Ident, ''));
  Result := TryStrToInt(RawValue, AValue);
end;

constructor TDispenserConfigStorage.Create(const AFileName: string);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
      'syringe_pump.ini'
  else
    FFileName := AFileName;
end;

function TDispenserConfigStorage.Load(
  out AConfigurations: TDispenserConfigList; out ErrorText: string): Boolean;
var
  Ini: TIniFile;
  Count: Integer;
  I: Integer;
  Config: TDispenserConfig;
  Section: string;
  RowError: string;
  DefaultOperationVolumeRate: Integer;
  LegacyMotorSpeed: Integer;
  LegacyConfiguredMotorSpeed: Integer;
begin
  AConfigurations := nil;
  ErrorText := '';

  if not FileExists(FFileName) then
  begin
    AConfigurations := TDispenserConfigList.Create;
    Exit(True);
  end;

  try
    Ini := TIniFile.Create(FFileName);
    try
      if not TryReadIntegerOrDefault(Ini, CONFIG_SECTION, 'Count', 0, Count) then
        raise EConvertError.Create('некорректное значение Count');
      if (Count < 0) or (Count > MAX_DISPENSERS) then
      begin
        ErrorText := 'недопустимое количество дозаторов в файле настроек';
        Exit(False);
      end;

      AConfigurations := TDispenserConfigList.Create;
      for I := 1 to Count do
      begin
        Section := DISPENSER_SECTION_PREFIX + IntToStr(I);
        Config := AConfigurations.AddConfig;
        if not TryReadIntegerOrDefault(Ini, Section, 'Number', Config.Number,
          Config.Number) then
          raise EConvertError.CreateFmt('некорректное значение %s.Number',
            [Section]);
        Config.Name := Ini.ReadString(Section, 'Name', Config.Name);
        if not TryReadIntegerOrDefault(Ini, Section, 'Address', Config.Address,
          Config.Address) then
          raise EConvertError.CreateFmt('некорректное значение %s.Address',
            [Section]);
        if not TryReadIntegerOrDefault(Ini, Section, 'Volume', Config.Volume,
          Config.Volume) then
          raise EConvertError.CreateFmt('некорректное значение %s.Volume',
            [Section]);
        if not TryReadIntegerOrDefault(Ini, Section, 'ChannelCount',
          Config.ChannelCount, Config.ChannelCount) then
          raise EConvertError.CreateFmt(
            'некорректное значение %s.ChannelCount', [Section]);
        if not TryReadIntegerOrDefault(Ini, Section, 'StepCount',
          Config.StepCount, Config.StepCount) then
          raise EConvertError.CreateFmt('некорректное значение %s.StepCount',
            [Section]);
        if not TryReadIntegerOrDefault(Ini, Section, 'IntakeChannel',
          Config.IntakeChannel, Config.IntakeChannel) then
          raise EConvertError.CreateFmt(
            'некорректное значение %s.IntakeChannel', [Section]);
        Config.Bypass := Ini.ReadBool(Section, 'Bypass', Config.Bypass);

        DefaultOperationVolumeRate := MaximumVolumeRate(MAX_SPEED,
          Config.Volume, Config.StepCount);
        Config.MaxFlowRate := DefaultOperationVolumeRate;
        if Ini.ValueExists(Section,
          'MaximumSpeedMicrolitersPerSecond') then
        begin
          if not TryReadIntegerOrDefault(Ini, Section,
            'MaximumSpeedMicrolitersPerSecond', DefaultOperationVolumeRate,
            Config.MaxFlowRate) then
            raise EConvertError.CreateFmt(
              'некорректное значение %s.MaximumSpeedMicrolitersPerSecond',
              [Section]);
        end
        else if Ini.ValueExists(Section, 'Speed') then
        begin
          if not TryReadIntegerOrDefault(Ini, Section, 'Speed', MAX_SPEED,
            LegacyConfiguredMotorSpeed) then
            raise EConvertError.CreateFmt('некорректное значение %s.Speed',
              [Section]);
          Config.MaxFlowRate := MaximumVolumeRate(LegacyConfiguredMotorSpeed,
            Config.Volume, Config.StepCount);
        end;

        if not TryReadIntegerOrDefault(Ini, Section, 'OperationVolume',
          Config.Volume, Config.Operation.Volume) then
          Config.Operation.Volume := Config.Volume;
        DefaultOperationVolumeRate := Config.MaxFlowRate;
        Config.Operation.Speed := Config.MaxFlowRate;
        if Ini.ValueExists(Section, 'OperationSpeedMicrolitersPerSecond') then
        begin
          if not TryReadIntegerOrDefault(Ini, Section,
            'OperationSpeedMicrolitersPerSecond', DefaultOperationVolumeRate,
            Config.Operation.Speed) then
            Config.Operation.Speed := DefaultOperationVolumeRate;
        end
        else if Ini.ValueExists(Section, 'OperationSpeed') then
        begin
          if TryReadIntegerOrDefault(Ini, Section, 'OperationSpeed',
            MAX_SPEED, LegacyMotorSpeed) and
            (LegacyMotorSpeed > 0) then
          begin
            Config.Operation.Speed := ConvertMotorSpeedToVolumeRate(
              LegacyMotorSpeed, Config.Volume, Config.StepCount);
            if Config.Operation.Speed <= 0 then
              Config.Operation.Speed := MinimumVolumeRate(Config.Volume,
                Config.StepCount);
          end;
        end;
        if not TryReadIntegerOrDefault(Ini, Section, 'OperationChannel',
          MIN_CHANNEL_NUMBER, Config.Operation.Channel) then
          Config.Operation.Channel := MIN_CHANNEL_NUMBER;

        TDispenserConfigValidator.NormalizeOperation(Config);
      end;

      if not TDispenserConfigValidator.ValidateList(AConfigurations,
        RowError) then
      begin
        ErrorText := RowError;
        AConfigurations.Free;
        AConfigurations := nil;
        Exit(False);
      end;

      Result := True;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
    begin
      AConfigurations.Free;
      AConfigurations := nil;
      ErrorText := 'не удалось прочитать файл настроек: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TDispenserConfigStorage.Save(
  AConfigurations: TDispenserConfigList; out ErrorText: string): Boolean;
var
  Ini: TIniFile;
  Sections: TStringList;
  Directory: string;
  I: Integer;
  J: Integer;
  Config: TDispenserConfig;
  Section: string;
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

  if not TDispenserConfigValidator.ValidateList(AConfigurations,
    RowError) then
  begin
    ErrorText := RowError;
    Exit(False);
  end;

  try
    Directory := ExtractFileDir(FFileName);
    if (Directory <> '') and not DirectoryExists(Directory) then
      ForceDirectories(Directory);

    Ini := TIniFile.Create(FFileName);
    try
      Ini.WriteInteger(CONFIG_SECTION, 'Count', AConfigurations.Count);
      Sections := TStringList.Create;
      try
        Ini.ReadSections(Sections);
        for J := Sections.Count - 1 downto 0 do
          if IsDispenserSection(Sections[J]) then
            Ini.EraseSection(Sections[J]);
      finally
        Sections.Free;
      end;

      for I := 0 to AConfigurations.Count - 1 do
      begin
        Config := AConfigurations[I];
        Section := DISPENSER_SECTION_PREFIX + IntToStr(I + 1);
        Ini.WriteInteger(Section, 'Number', Config.Number);
        Ini.WriteString(Section, 'Name', Config.Name);
        Ini.WriteInteger(Section, 'Address', Config.Address);
        Ini.WriteInteger(Section, 'Volume', Config.Volume);
        Ini.WriteInteger(Section, 'ChannelCount', Config.ChannelCount);
        Ini.WriteInteger(Section, 'StepCount', Config.StepCount);
        Ini.WriteInteger(Section, 'IntakeChannel', Config.IntakeChannel);
        Ini.WriteInteger(Section, 'MaximumSpeedMicrolitersPerSecond',
          Config.MaxFlowRate);
        Ini.WriteBool(Section, 'Bypass', Config.Bypass);
        Ini.WriteInteger(Section, 'OperationVolume',
          Config.Operation.Volume);
        Ini.WriteInteger(Section, 'OperationSpeedMicrolitersPerSecond',
          Config.Operation.Speed);
        Ini.WriteInteger(Section, 'OperationChannel',
          Config.Operation.Channel);
      end;
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      ErrorText := 'не удалось сохранить файл настроек: ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
