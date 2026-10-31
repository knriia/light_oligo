unit ConfigurationTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry,
  DispenserConfig, DispenserConfigValidator, DispenserConfigStorage,
  DispenserLimits, DispenserCapacityValidator, WindowSettingsStorage,
  DispenserOperationRules, DispenserController, DispenserResolution,
  DispenserTypes, DispenserLayout, AutomationDocumentStorage,
  AutomationProtocol;

type
  TDispenserOperationRulesTests = class(TTestCase)
  private
    function CreateConfig: TDispenserConfig;
  published
    procedure CalculatesProportionalSteps;
    procedure CalculatesFixedN1Steps;
    procedure ConvertsVolumeRateForDifferentSyringes;
    procedure ClampsVolumeRateToMaximum;
    procedure RejectsInvalidStepInputsAndOverflow;
    procedure FillUsesConfiguredIntakeChannel;
    procedure FillUsesMaximumSpeedEvenWhenTableSpeedIsInvalid;
    procedure AspirateUsesSelectedChannel;
    procedure EmptyUsesSelectedChannel;
    procedure DispenseUsesSelectedChannel;
    procedure RejectsOperationWhenBypassActive;
    procedure RejectsAspirateAboveCapacity;
    procedure RejectsDispenseAboveCurrentVolume;
    procedure RejectsUnknownCurrentVolume;
    procedure RejectsEveryRemainingPlanBranch;
    procedure RejectsInvalidChannelsAndOperationVolumes;
    procedure RejectsPlanWhenStepCalculationFails;
  end;

  TDispenserConfigModelTests = class(TTestCase)
  published
    procedure NewConfigurationDefaultsToMaximumCalibratedVolumeRate;
    procedure CloneCopiesEveryConfigurationFieldIndependently;
    procedure CloneOfEmptyListIsEmpty;
    procedure CloneOfListCopiesEveryConfigurationIndependently;
  end;

  TDispenserLayoutTests = class(TTestCase)
  published
    procedure NarrowLayoutClampsToMinimumAndSkipsExtraSpacing;
    procedure WideLayoutDistributesExtraSpacingAcrossColumns;
  end;

  TDispenserCommandTests = class(TTestCase)
  published
    procedure BuildsNonDistributiveChannelOneAspirate;
    procedure BuildsNonDistributiveChannelTwoDispense;
    procedure BuildsDistributiveChannelCommand;
    procedure RejectsUnsupportedNonDistributiveChannel;
    procedure BuildsNonDistributiveBypassCommand;
    procedure BuildsNonDistributiveRestoreCommand;
    procedure BuildsPlungerOnlyDispenseCommand;
    procedure BuildsPlungerOnlyAspirateCommand;
    procedure RejectsDistributiveValveCommand;
    procedure RejectsUnsupportedNonDistributiveValveChannel;
  end;

  TAutomationProtocolTests = class(TTestCase)
  private
    function CreateConfigurations: TDispenserConfigList;
    function Parse(const AText: string; AConfigurations: TDispenserConfigList;
      out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;
  published
    procedure ParsesSingleCommandAndConvertsUnits;
    procedure AcceptsOutputChannelDifferentFromIntakeChannel;
    procedure RejectsOutputChannelMatchingIntakeChannel;
    procedure BroadcastsSharedValuesToSeveralDispensers;
    procedure ParsesDifferentValuesForEachDispenser;
    procedure AcceptsDecimalComma;
    procedure RejectsUnknownDispenser;
    procedure RejectsMismatchedValueCount;
    procedure RejectsUnknownUnits;
    procedure RejectsSpeedAboveConfiguredMaximum;
    procedure RejectsVolumeBelowStepResolution;
    procedure RejectsDuplicateCommandNumbers;
    procedure RejectsMissingFieldsAndEmptyProtocol;
  end;

  TDispenserConfigValidatorTests = class(TTestCase)
  published
    procedure AcceptsValidConfig;
    procedure AllowsBypassWhenChannelsDiffer;
    procedure RejectsBypassWhenUnsupported;
    procedure RejectsBypassWhenIntakeMatchesSelected;
    procedure RejectsBypassForNilConfigAndInvalidChannel;
    procedure AcceptsBoundaryValues;
    procedure RejectsCalibrationBelowOneWholeMicroliterPerSecond;
    procedure AcceptsEmptyList;
    procedure AcceptsMaximumDispenserCount;
    procedure RejectsNilConfig;
    procedure RejectsNilList;
    procedure RejectsInvalidNumber;
    procedure RejectsNumberAboveMaximum;
    procedure RejectsAddressAboveMaximum;
    procedure RejectsAddressBelowMinimum;
    procedure RejectsEmptyName;
    procedure RejectsNonPositiveVolume;
    procedure RejectsChannelCountBelowMinimum;
    procedure RejectsChannelCountAboveMaximum;
    procedure RejectsNonPositiveStepCount;
    procedure RejectsNonPositiveSpeed;
    procedure RejectsDuplicateNumber;
    procedure RejectsDuplicateAddress;
    procedure RejectsDuplicateName;
    procedure RejectsInvalidOperationValues;
    procedure NormalizesOperationValuesAboveHardwareLimits;
    procedure NormalizesOperationValuesBelowMinimums;
    procedure RejectsInvalidIntakeChannel;
    procedure RejectsIntakeChannelBelowMinimum;
    procedure RejectsTooManyConfigurations;
  end;

  TWindowSettingsStorageTests = class(TTestCase)
  private
    FFileName: string;
    FStorage: TWindowSettingsStorage;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MissingFileUsesDefaults;
    procedure WindowSizeRoundTrip;
    procedure MissingFileUsesEmptyLastPort;
    procedure LastPortRoundTrip;
    procedure CustomSectionRoundTrip;
    procedure PreservesConfigurationSection;
    procedure DefaultConstructorUsesApplicationConfigPath;
    procedure MalformedDimensionsUseDefaults;
    procedure SaveErrorsAreReported;
    procedure LockedSettingsFileUsesDefaults;
    procedure SaveMethodsCreateMissingDirectories;
    procedure MissingFileUsesEmptyLastAutomationFile;
    procedure LastAutomationFileRoundTrip;
    procedure LastAutomationFileSurvivesWindowSizeSave;
  end;

  TAutomationDocumentStorageTests = class(TTestCase)
  private
    FDirectory: string;
    FExecutableFileName: string;
    FProtocolsDirectory: string;
    procedure EnsureTestProtocolsDirectory;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ProtocolsDirectoryIsNextToExecutable;
    procedure CreatesProtocolsDirectoryWhenMissing;
    procedure RoundTripPreservesUtf8Scenario;
    procedure ReadsUtf8Bom;
    procedure MissingScenarioFileReturnsError;
  end;

  TDispenserCapacityValidatorTests = class(TTestCase)
  private
    FCurrentVolume: Double;
    function ReadCurrentVolume(AAddress: Integer): Double;
    function CreateSingleConfig(ANumber, AAddress, AVolume: Integer):
      TDispenserConfigList;
  published
    procedure AllowsEqualCapacity;
    procedure AllowsCapacityIncrease;
    procedure RejectsDecreaseWhenLiquidExceedsCapacity;
    procedure RejectsOperationAboveCapacity;
    procedure RejectsRemovingDispenserWithLiquid;
    procedure RejectsChangingAddressWithLiquid;
    procedure RejectsMissingNewListAndVolumeProvider;
    procedure AllowsNilOldListAndZeroCurrentVolume;
    procedure MatchesPreviousConfigurationByNumber;
    procedure DetectsLiquidInUnmatchedRemovedConfiguration;
  end;

  TDispenserConfigStorageTests = class(TTestCase)
  private
    FFileName: string;
    FNestedDirectory: string;
    FStorage: TDispenserConfigStorage;
    function CreateSourceConfigurations: TDispenserConfigList;
    procedure WriteValidIniWithoutOperation;
    procedure WriteValidIniWithInvalidOperation;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MissingFileLoadsEmptyList;
    procedure EmptyListRoundTrip;
    procedure ConfigurationRoundTripPreservesOperation;
    procedure RoundTripPreservesOrderAndCyrillicName;
    procedure MaximumDispenserCountRoundTrip;
    procedure LegacyFileUsesOperationDefaults;
    procedure LegacyMotorSpeedIsMigratedToVolumeRate;
    procedure InvalidOperationValuesUseDefaults;
    procedure RejectsNonNumericCount;
    procedure RejectsNonNumericHardwareValue;
    procedure PreservesWindowSettingsSection;
    procedure RemovesStaleDispenserSections;
    procedure CreatesMissingDirectory;
    procedure RejectsInvalidListOnSave;
    procedure RejectsNilListOnSave;
    procedure RejectsTooManyConfigurationsOnSave;
    procedure RejectsNegativeDispenserCount;
    procedure RejectsTooManyDispenserSections;
    procedure RejectsNonnumericHardwareFields;
    procedure RejectsNumericallyValidButInvalidConfiguration;
    procedure SaveFailureReturnsError;
    procedure DefaultConstructorUsesApplicationConfigPath;
  end;

implementation

procedure TDispenserCommandTests.BuildsNonDistributiveChannelOneAspirate;
begin
  AssertEquals('/1Iv900V6000P12000R',
    BuildDispenserMovementCommand(1, 1, 12000, 6000, True, True));
end;

procedure TDispenserCommandTests.BuildsNonDistributiveChannelTwoDispense;
begin
  AssertEquals('/1Ov900V6000D12000R',
    BuildDispenserMovementCommand(1, 2, 12000, 6000, False, True));
end;

procedure TDispenserCommandTests.BuildsDistributiveChannelCommand;
begin
  AssertEquals('/2I3v100V100P250R',
    BuildDispenserMovementCommand(2, 3, 250, 100, True, False));
end;

procedure TDispenserCommandTests.RejectsUnsupportedNonDistributiveChannel;
begin
  AssertEquals('', BuildDispenserMovementCommand(1, 3, 250, 100, True, True));
end;

procedure TDispenserCommandTests.BuildsNonDistributiveBypassCommand;
begin
  AssertEquals('/1BR', BuildDispenserValveCommand(1, 2, True, True));
end;

procedure TDispenserCommandTests.BuildsNonDistributiveRestoreCommand;
begin
  AssertEquals('/1OR', BuildDispenserValveCommand(1, 2, False, True));
end;

procedure TDispenserCommandTests.BuildsPlungerOnlyDispenseCommand;
begin
  AssertEquals('/1v900V4800D24000R',
    BuildDispenserPlungerCommand(1, 24000, 4800, False));
end;

procedure TDispenserCommandTests.BuildsPlungerOnlyAspirateCommand;
begin
  AssertEquals('/2v750V750P1200R',
    BuildDispenserPlungerCommand(2, 1200, 750, True));
end;

procedure TDispenserCommandTests.RejectsDistributiveValveCommand;
begin
  AssertEquals('', BuildDispenserValveCommand(1, 1, True, False));
end;

procedure TDispenserCommandTests.RejectsUnsupportedNonDistributiveValveChannel;
begin
  AssertEquals('', BuildDispenserValveCommand(1, 3, False, True));
end;

function TAutomationProtocolTests.CreateConfigurations:
  TDispenserConfigList;
var
  Config: TDispenserConfig;
begin
  Result := TDispenserConfigList.Create;
  Config := Result.AddConfig;
  Config.Name := 'Дозатор 1';
  Config.Number := 1;
  Config.Address := 1;
  Config.Volume := 250;
  Config.ChannelCount := 2;
  Config.StepCount := 12000;
  Config.IntakeChannel := 1;
  Config.MaxFlowRate := 125;

  Config := Result.AddConfig;
  Config.Name := 'Дозатор 2';
  Config.Number := 2;
  Config.Address := 2;
  Config.Volume := 1000;
  Config.ChannelCount := 4;
  Config.StepCount := 12000;
  Config.IntakeChannel := 1;
  Config.MaxFlowRate := 500;
end;

function TAutomationProtocolTests.Parse(const AText: string;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;
begin
  Result := ParseAutomationProtocol(AText, AConfigurations, AProtocol,
    ErrorText);
end;

procedure TAutomationProtocolTests.ParsesSingleCommandAndConvertsUnits;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Text: string;
  Success: Boolean;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  Text := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1";' + LineEnding +
    '  valve_channels: "2";' + LineEnding +
    '  volumes: "500";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "100";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    Success := Parse(Text, Configurations, Protocol, ErrorText);
    AssertTrue(ErrorText, Success);
    try
      AssertEquals(1, Protocol.Count);
      AssertEquals(1, Protocol[0].Number);
      AssertEquals('Дозатор 1', Protocol[0].Targets[0].Config.Name);
      AssertEquals(2, Protocol[0].Targets[0].ValveChannel);
      AssertEquals(500000, Protocol[0].Targets[0].VolumeNanoLiters);
      AssertEquals(100000, Protocol[0].Targets[0].SpeedNanoLitersPerSecond);
      AssertEquals(192000, Protocol[0].Targets[0].TotalSteps);
      AssertEquals(4800, Protocol[0].Targets[0].MotorSpeed);
    finally
      Protocol.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.AcceptsOutputChannelDifferentFromIntakeChannel;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Text: string;
begin
  Configurations := CreateConfigurations;
  Configurations[0].IntakeChannel := 2;
  Protocol := nil;
  Text := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1";' + LineEnding +
    '  valve_channels: "1";' + LineEnding +
    '  volumes: "500";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "100";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    AssertTrue(Parse(Text, Configurations, Protocol, ErrorText));
    try
      AssertEquals(2, Protocol[0].Targets[0].Config.IntakeChannel);
      AssertEquals(1, Protocol[0].Targets[0].ValveChannel);
    finally
      Protocol.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsOutputChannelMatchingIntakeChannel;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1";' + LineEnding +
      '  valve_channels: "1";' + LineEnding +
      '  volumes: "500";' + LineEnding +
      '  volume_unit: "мкл";' + LineEnding +
      '  speeds: "100";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('Для дозатора "Дозатор 1" входной и выходной каналы совпадают',
      ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.BroadcastsSharedValuesToSeveralDispensers;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Text: string;
  Success: Boolean;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  Text := 'command_7: {' + LineEnding +
    '  dispenser_names: "Дозатор 1/Дозатор 2";' + LineEnding +
    '  valve_channels: "2";' + LineEnding +
    '  volumes: "500";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "100";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    Success := Parse(Text, Configurations, Protocol, ErrorText);
    AssertTrue(ErrorText, Success);
    try
      AssertEquals(2, Length(Protocol[0].Targets));
      AssertEquals(2, Protocol[0].Targets[0].ValveChannel);
      AssertEquals(2, Protocol[0].Targets[1].ValveChannel);
      AssertEquals(500000, Protocol[0].Targets[1].VolumeNanoLiters);
      AssertEquals(100000, Protocol[0].Targets[1].SpeedNanoLitersPerSecond);
      AssertEquals(48000, Protocol[0].Targets[1].TotalSteps);
      AssertEquals(1200, Protocol[0].Targets[1].MotorSpeed);
    finally
      Protocol.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.ParsesDifferentValuesForEachDispenser;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Text: string;
  Success: Boolean;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  Text := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1/Дозатор 2";' + LineEnding +
    '  valve_channels: "2/4";' + LineEnding +
    '  volumes: "500/250";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "100/50";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    Success := Parse(Text, Configurations, Protocol, ErrorText);
    AssertTrue(ErrorText, Success);
    try
      AssertEquals(2, Protocol[0].Targets[0].ValveChannel);
      AssertEquals(4, Protocol[0].Targets[1].ValveChannel);
      AssertEquals(500000, Protocol[0].Targets[0].VolumeNanoLiters);
      AssertEquals(250000, Protocol[0].Targets[1].VolumeNanoLiters);
      AssertEquals(600, Protocol[0].Targets[1].MotorSpeed);
    finally
      Protocol.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.AcceptsDecimalComma;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Text: string;
  Success: Boolean;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  Text := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1";' + LineEnding +
    '  valve_channels: "2";' + LineEnding +
    '  volumes: "0,5";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "0,5";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    Success := Parse(Text, Configurations, Protocol, ErrorText);
    AssertTrue(ErrorText, Success);
    try
      AssertEquals(500, Protocol[0].Targets[0].VolumeNanoLiters);
      AssertEquals(500, Protocol[0].Targets[0].SpeedNanoLitersPerSecond);
      AssertEquals(192, Protocol[0].Targets[0].TotalSteps);
      AssertEquals(24, Protocol[0].Targets[0].MotorSpeed);
    finally
      Protocol.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsUnknownDispenser;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Missing";' + LineEnding +
      '  valve_channels: "1";' + LineEnding +
      '  volumes: "10";' + LineEnding +
      '  volume_unit: "мкл";' + LineEnding +
      '  speeds: "10";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('не найден', ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsMismatchedValueCount;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1/Дозатор 2";' + LineEnding +
      '  valve_channels: "1/2";' + LineEnding +
      '  volumes: "10/20/30";' + LineEnding +
      '  volume_unit: "мкл";' + LineEnding +
      '  speeds: "10";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsUnknownUnits;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1";' + LineEnding +
      '  valve_channels: "2";' + LineEnding +
      '  volumes: "10";' + LineEnding +
      '  volume_unit: "ul";' + LineEnding +
      '  speeds: "10";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('единица объёма', ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsSpeedAboveConfiguredMaximum;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1";' + LineEnding +
      '  valve_channels: "2";' + LineEnding +
      '  volumes: "10";' + LineEnding +
      '  volume_unit: "мкл";' + LineEnding +
      '  speeds: "126";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('максимальную', ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsVolumeBelowStepResolution;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1";' + LineEnding +
      '  valve_channels: "2";' + LineEnding +
      '  volumes: "1";' + LineEnding +
      '  volume_unit: "нл";' + LineEnding +
      '  speeds: "10";' + LineEnding +
      '  speed_unit: "мкл/с"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('разрешения шприца', ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsDuplicateCommandNumbers;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  Block: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  Block := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1";' + LineEnding +
    '  valve_channels: "2";' + LineEnding +
    '  volumes: "10";' + LineEnding +
    '  volume_unit: "мкл";' + LineEnding +
    '  speeds: "10";' + LineEnding +
    '  speed_unit: "мкл/с"' + LineEnding +
    '}';
  try
    AssertFalse(Parse(Block + LineEnding + LineEnding + Block,
      Configurations, Protocol, ErrorText));
    AssertTrue(Pos('повторяется', ErrorText) > 0);
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolTests.RejectsMissingFieldsAndEmptyProtocol;
var
  Configurations: TDispenserConfigList;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Protocol := nil;
  try
    AssertFalse(Parse('', Configurations, Protocol, ErrorText));
    AssertTrue(Pos('нет команд', ErrorText) > 0);
    AssertFalse(Parse(
      'command_1: {' + LineEnding +
      '  dispenser_names: "Дозатор 1";' + LineEnding +
      '  valve_channels: "1"' + LineEnding +
      '}', Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Protocol.Free;
    Configurations.Free;
  end;
end;

function TDispenserOperationRulesTests.CreateConfig:
  TDispenserConfig;
begin
  Result := TDispenserConfig.Create;
  Result.Name := 'Test dispenser';
  Result.Volume := 5000;
  Result.ChannelCount := 10;
  Result.StepCount := 12000;
  Result.IntakeChannel := 3;
  Result.MaxFlowRate := 2500;
  Result.Operation.Volume := 500;
  Result.Operation.Speed := 100;
  Result.Operation.Channel := 2;
end;

procedure TDispenserOperationRulesTests.CalculatesProportionalSteps;
begin
  AssertEquals(9600, CalculateOperationSteps(500, 5000, 12000));
  AssertEquals(1, CalculateOperationSteps(1, 5000, 1));
  AssertEquals(0, CalculateOperationSteps(0, 5000, 12000));
end;

procedure TDispenserOperationRulesTests.CalculatesFixedN1Steps;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertTrue(BuildOperationPlan(Config, dokFill, 2, 0, True, False,
      Plan, ErrorText));
    AssertEquals(96000, Plan.Steps);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.ConvertsVolumeRateForDifferentSyringes;
var
  FirstMotorSpeed: Integer;
  SecondMotorSpeed: Integer;
  FirstOperationSteps: Integer;
  SecondOperationSteps: Integer;
begin
  AssertEquals(125, MaximumVolumeRate(6000, 250, 12000));
  AssertEquals(600, MaximumVolumeRate(6000, 100, 1000));
  AssertEquals(1, MinimumVolumeRate(5000, 12000));
  AssertEquals(2500, MinimumVolumeRate(5000, 1));
  AssertEquals(2500, MaximumVolumeRate(6000, 5000, 12000));
  AssertTrue(ConvertVolumeRateToMotorSpeed(10, 6000, 5000, 12000,
    FirstMotorSpeed));
  AssertTrue(ConvertVolumeRateToMotorSpeed(10, 6000, 250, 12000,
    SecondMotorSpeed));
  AssertEquals(24, FirstMotorSpeed);
  AssertEquals(480, SecondMotorSpeed);
  AssertEquals(10, ConvertMotorSpeedToVolumeRate(FirstMotorSpeed,
    5000, 12000));
  AssertEquals(10, ConvertMotorSpeedToVolumeRate(SecondMotorSpeed,
    250, 12000));
  FirstOperationSteps := CalculateOperationSteps(250, 5000, 12000);
  SecondOperationSteps := CalculateOperationSteps(250, 250, 12000);
  AssertEquals(4800, FirstOperationSteps);
  AssertEquals(96000, SecondOperationSteps);
  AssertEquals(25, FirstOperationSteps div
    (FirstMotorSpeed * N1_STEP_MULTIPLIER));
  AssertEquals(25, SecondOperationSteps div
    (SecondMotorSpeed * N1_STEP_MULTIPLIER));
  AssertTrue(ConvertVolumeRateToMotorSpeed(2500, 6000, 5000, 1,
    FirstMotorSpeed));
  AssertEquals(1, FirstMotorSpeed);
  AssertFalse(ConvertVolumeRateToMotorSpeed(2501, 6000, 5000, 12000,
    FirstMotorSpeed));
end;

procedure TDispenserOperationRulesTests.ClampsVolumeRateToMaximum;
begin
  AssertEquals(125, ClampVolumeRateToMaximum(500, 125));
  AssertEquals(125, ClampVolumeRateToMaximum(125, 125));
  AssertEquals(10, ClampVolumeRateToMaximum(10, 125));
  AssertEquals(500, ClampVolumeRateToMaximum(500, 0));
end;

procedure TDispenserOperationRulesTests.RejectsInvalidStepInputsAndOverflow;
begin
  AssertEquals(0, CalculateOperationSteps(-1, 5000, 12000));
  AssertEquals(0, CalculateOperationSteps(1, 0, 12000));
  AssertEquals(0, CalculateOperationSteps(1, 5000, -1));
  AssertEquals(3435974,
    CalculateOperationSteps(1, 5000, High(Integer)));
  AssertEquals(0, CalculateOperationSteps(High(Integer), 1, 1));
  AssertEquals(0, CalculateOperationSteps(High(Integer), 1,
    High(Integer)));
end;

procedure TDispenserOperationRulesTests.FillUsesConfiguredIntakeChannel;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    Config.MaxFlowRate := 1000;
    AssertTrue(BuildOperationPlan(Config, dokFill, 7, 1000, True, False,
      Plan, ErrorText));
    AssertEquals(3, Plan.Channel);
    AssertEquals(4000, Plan.Volume);
    AssertEquals(76800, Plan.Steps);
    AssertEquals(2400, Plan.MotorSpeed);
    AssertTrue(Plan.Aspirate);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.AspirateUsesSelectedChannel;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertTrue(BuildOperationPlan(Config, dokAspirate, 7, 0, True, False,
      Plan, ErrorText));
    AssertEquals(7, Plan.Channel);
    AssertEquals(500, Plan.Volume);
    AssertEquals(9600, Plan.Steps);
    AssertTrue(Plan.Aspirate);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.EmptyUsesSelectedChannel;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertTrue(BuildOperationPlan(Config, dokEmpty, 4, 1000, True, False,
      Plan, ErrorText));
    AssertEquals(4, Plan.Channel);
    AssertEquals(1000, Plan.Volume);
    AssertEquals(19200, Plan.Steps);
    AssertFalse(Plan.Aspirate);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.DispenseUsesSelectedChannel;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertTrue(BuildOperationPlan(Config, dokDispense, 7, 1000, True, False,
      Plan, ErrorText));
    AssertEquals(7, Plan.Channel);
    AssertEquals(500, Plan.Volume);
    AssertEquals(9600, Plan.Steps);
    AssertFalse(Plan.Aspirate);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsOperationWhenBypassActive;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 0, True, True,
      Plan, ErrorText));
    AssertTrue(Pos('байпас', LowerCase(ErrorText)) > 0);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsAspirateAboveCapacity;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 4600, True, False,
      Plan, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsDispenseAboveCurrentVolume;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokDispense, 2, 100, True, False,
      Plan, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsUnknownCurrentVolume;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokFill, 3, 0, False, False,
      Plan, ErrorText));
    AssertTrue(Pos('неизвестен', LowerCase(ErrorText)) > 0);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsEveryRemainingPlanBranch;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  AssertFalse(BuildOperationPlan(nil, dokFill, 1, 0, True, False,
    Plan, ErrorText));
  AssertTrue(ErrorText <> '');

  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, -1, True, False,
      Plan, ErrorText));
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, 5001, True, False,
      Plan, ErrorText));

    Config.Operation.Speed := 0;
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 0, True, False,
      Plan, ErrorText));
    Config.Operation.Speed := MAX_SPEED + 1;
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 0, True, False,
      Plan, ErrorText));
    Config.Operation.Speed := 100;

    Config.IntakeChannel := 0;
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, 0, True, False,
      Plan, ErrorText));
    Config.IntakeChannel := Config.ChannelCount + 1;
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, 0, True, False,
      Plan, ErrorText));
    Config.IntakeChannel := 3;
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, 5000, True, False,
      Plan, ErrorText));

    AssertFalse(BuildOperationPlan(Config, dokEmpty, 0, 100, True, False,
      Plan, ErrorText));
    AssertFalse(BuildOperationPlan(Config, dokEmpty, 1, 0, True, False,
      Plan, ErrorText));
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsInvalidChannelsAndOperationVolumes;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 0, 0, True, False,
      Plan, ErrorText));
    Config.Operation.Volume := 0;
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 0, True, False,
      Plan, ErrorText));
    Config.Operation.Volume := Config.Volume + 1;
    AssertFalse(BuildOperationPlan(Config, dokAspirate, 2, 0, True, False,
      Plan, ErrorText));
    Config.Operation.Volume := 500;

    AssertFalse(BuildOperationPlan(Config, dokDispense, Config.ChannelCount + 1,
      1000, True, False, Plan, ErrorText));
    Config.Operation.Volume := 0;
    AssertFalse(BuildOperationPlan(Config, dokDispense, 2, 1000, True, False,
      Plan, ErrorText));
    Config.Operation.Volume := Config.Volume + 1;
    AssertFalse(BuildOperationPlan(Config, dokDispense, 2, 1000, True, False,
      Plan, ErrorText));
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.RejectsPlanWhenStepCalculationFails;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    Config.StepCount := 0;
    AssertFalse(BuildOperationPlan(Config, dokFill, 1, 0, True, False,
      Plan, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigModelTests.NewConfigurationDefaultsToMaximumCalibratedVolumeRate;
var
  Config: TDispenserConfig;
begin
  Config := TDispenserConfig.Create;
  try
    AssertEquals(125, Config.MaxFlowRate);
    AssertEquals(Config.MaxFlowRate, Config.Operation.Speed);
  finally
    Config.Free;
  end;
end;

procedure TDispenserOperationRulesTests.FillUsesMaximumSpeedEvenWhenTableSpeedIsInvalid;
var
  Config: TDispenserConfig;
  Plan: TDispenserOperationPlan;
  ErrorText: string;
begin
  Config := CreateConfig;
  try
    Config.MaxFlowRate := 1200;
    Config.Operation.Speed := 0;
    AssertTrue(BuildOperationPlan(Config, dokFill, 2, 0, True, False,
      Plan, ErrorText));
    AssertEquals(2880, Plan.MotorSpeed);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigModelTests.CloneCopiesEveryConfigurationFieldIndependently;
var
  Config: TDispenserConfig;
  Cloned: TDispenserConfig;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Number := 4;
    Config.Name := 'Model test';
    Config.Address := 9;
    Config.Volume := 700;
    Config.ChannelCount := 5;
    Config.StepCount := 17000;
    Config.IntakeChannel := 3;
    Config.MaxFlowRate := 20;
    Config.Bypass := True;
    Config.Operation.Volume := 250;
    Config.Operation.Speed := 10;
    Config.Operation.Channel := 4;

    Cloned := Config.Clone;
    try
      AssertTrue(Cloned <> Config);
      AssertEquals(Config.Number, Cloned.Number);
      AssertEquals(Config.Name, Cloned.Name);
      AssertEquals(Config.Address, Cloned.Address);
      AssertEquals(Config.Volume, Cloned.Volume);
      AssertEquals(Config.ChannelCount, Cloned.ChannelCount);
      AssertEquals(Config.StepCount, Cloned.StepCount);
      AssertEquals(Config.IntakeChannel, Cloned.IntakeChannel);
      AssertEquals(Config.MaxFlowRate, Cloned.MaxFlowRate);
      AssertEquals(Ord(Config.Bypass), Ord(Cloned.Bypass));
      AssertEquals(Config.Operation.Volume, Cloned.Operation.Volume);
      AssertEquals(Config.Operation.Speed, Cloned.Operation.Speed);
      AssertEquals(Config.Operation.Channel, Cloned.Operation.Channel);
      Cloned.Name := 'Changed clone';
      AssertEquals('Model test', Config.Name);
    finally
      Cloned.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigModelTests.CloneOfEmptyListIsEmpty;
var
  Configurations: TDispenserConfigList;
  Cloned: TDispenserConfigList;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Cloned := Configurations.Clone;
    try
      AssertEquals(0, Cloned.Count);
    finally
      Cloned.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigModelTests.CloneOfListCopiesEveryConfigurationIndependently;
var
  Configurations: TDispenserConfigList;
  Cloned: TDispenserConfigList;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Configurations.AddConfig.Number := 2;
    Configurations.AddConfig.Number := 5;
    Cloned := Configurations.Clone;
    try
      AssertEquals(2, Cloned.Count);
      AssertTrue(Configurations[0] <> Cloned[0]);
      AssertTrue(Configurations[1] <> Cloned[1]);
      AssertEquals(2, Cloned[0].Number);
      AssertEquals(5, Cloned[1].Number);
      Cloned[0].Number := 9;
      AssertEquals(2, Configurations[0].Number);
    finally
      Cloned.Free;
    end;
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserLayoutTests.NarrowLayoutClampsToMinimumAndSkipsExtraSpacing;
var
  Layout: TDispenserTableLayout;
begin
  Layout := BuildDispenserTableLayout(300);
  AssertEquals(TABLE_ROW_LEFT, Layout.RowLeft);
  AssertEquals(TABLE_CONTENT_RIGHT + TABLE_ROW_LEFT, Layout.RowWidth);
  AssertEquals(COL_NUMBER, Layout.Columns[dcNumber].Left);
  AssertEquals(WIDTH_NUMBER, Layout.Columns[dcNumber].Width);
  AssertEquals(COL_CURRENT, Layout.Columns[dcCurrent].Left);
  AssertEquals(COL_STOP, Layout.Columns[dcStop].Left);
  AssertEquals(WIDTH_STOP, Layout.Columns[dcStop].Width);
  AssertEquals(COL_INITIALIZE, Layout.Columns[dcInitialize].Left);
  AssertEquals(WIDTH_INITIALIZE, Layout.Columns[dcInitialize].Width);
  AssertEquals(COL_INITIALIZE + WIDTH_INITIALIZE, TABLE_CONTENT_RIGHT);
end;

procedure TDispenserLayoutTests.WideLayoutDistributesExtraSpacingAcrossColumns;
var
  Layout: TDispenserTableLayout;
begin
  Layout := BuildDispenserTableLayout(1500);
  AssertEquals(1484, Layout.RowWidth);
  AssertEquals(WIDTH_CURRENT, Layout.Columns[dcCurrent].Width);
  AssertTrue(Layout.Columns[dcCurrent].Left > COL_CURRENT);
  AssertTrue(Layout.Columns[dcSelected].Left > COL_SELECTED);
end;

procedure TDispenserConfigValidatorTests.AcceptsValidConfig;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    AssertTrue(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertEquals('', ErrorText);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.AllowsBypassWhenChannelsDiffer;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.IntakeChannel := 1;
    Config.Operation.Channel := 2;
    AssertTrue(TDispenserConfigValidator.CanEnableBypass(Config, 2, True,
      ErrorText));
    AssertEquals('', ErrorText);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsBypassWhenUnsupported;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    AssertFalse(TDispenserConfigValidator.CanEnableBypass(Config, 2, False,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsBypassWhenIntakeMatchesSelected;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.IntakeChannel := 2;
    AssertFalse(TDispenserConfigValidator.CanEnableBypass(Config, 2, True,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsBypassForNilConfigAndInvalidChannel;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  AssertFalse(TDispenserConfigValidator.CanEnableBypass(nil, 1, True,
    ErrorText));
  AssertTrue(ErrorText <> '');

  Config := TDispenserConfig.Create;
  try
    AssertFalse(TDispenserConfigValidator.CanEnableBypass(Config, 0, True,
      ErrorText));
    AssertTrue(ErrorText <> '');
    AssertFalse(TDispenserConfigValidator.CanEnableBypass(Config,
      Config.ChannelCount + 1, True, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.AcceptsBoundaryValues;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Number := MIN_DISPENSER_VALUE;
    Config.Address := MIN_DISPENSER_VALUE;
    Config.Volume := 8;
    Config.ChannelCount := MIN_CHANNEL_COUNT;
    Config.IntakeChannel := MIN_CHANNEL_NUMBER;
    Config.StepCount := 1;
    Config.MaxFlowRate := MaximumVolumeRate(MAX_SPEED, Config.Volume,
      Config.StepCount);
    Config.Operation.Volume := Config.Volume;
    Config.Operation.Speed := MinimumVolumeRate(Config.Volume,
      Config.StepCount);
    Config.Operation.Channel := Config.IntakeChannel;
    AssertTrue(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Number := MAX_DISPENSER_VALUE;
    Config.Address := MAX_DISPENSER_VALUE;
    Config.ChannelCount := MAX_CHANNEL_COUNT;
    Config.IntakeChannel := MAX_CHANNEL_COUNT;
    AssertTrue(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertEquals('', ErrorText);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsCalibrationBelowOneWholeMicroliterPerSecond;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Volume := 1;
    Config.StepCount := High(Integer);
    Config.MaxFlowRate := 1;
    Config.Operation.Speed := 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(Pos('мкл/с', ErrorText) > 0);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.AcceptsMaximumDispenserCount;
var
  Configurations: TDispenserConfigList;
  I: Integer;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    for I := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      with Configurations.AddConfig do
      begin
        Number := I;
        Address := I;
        Name := 'Dispenser ' + IntToStr(I);
      end;
    end;
    AssertEquals(MAX_DISPENSERS, Configurations.Count);
    AssertTrue(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.AcceptsEmptyList;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    AssertTrue(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
    AssertEquals('', ErrorText);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsNilConfig;
var
  ErrorText: string;
begin
  AssertFalse(TDispenserConfigValidator.Validate(nil, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TDispenserConfigValidatorTests.RejectsNilList;
var
  ErrorText: string;
begin
  AssertFalse(TDispenserConfigValidator.ValidateList(nil, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TDispenserConfigValidatorTests.RejectsInvalidNumber;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Number := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsNumberAboveMaximum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Number := MAX_DISPENSER_VALUE + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsAddressAboveMaximum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Address := MAX_DISPENSER_VALUE + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsAddressBelowMinimum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Address := MIN_DISPENSER_VALUE - 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsEmptyName;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Name := '  ';
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsNonPositiveVolume;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Volume := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
    Config.Volume := -1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsChannelCountBelowMinimum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.ChannelCount := MIN_CHANNEL_COUNT - 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertEquals(Format('количество каналов должно быть от %d до %d',
      [MIN_CHANNEL_COUNT, MAX_CHANNEL_COUNT]), ErrorText);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsChannelCountAboveMaximum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.ChannelCount := MAX_CHANNEL_COUNT + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertEquals(Format('количество каналов должно быть от %d до %d',
      [MIN_CHANNEL_COUNT, MAX_CHANNEL_COUNT]), ErrorText);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsNonPositiveStepCount;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.StepCount := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
    Config.StepCount := -1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsNonPositiveSpeed;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.MaxFlowRate := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');

    Config.MaxFlowRate := -1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');

    Config.MaxFlowRate := MaximumVolumeRate(MAX_SPEED, Config.Volume,
      Config.StepCount) + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsDuplicateNumber;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Configurations.AddConfig;
    Configurations.AddConfig.Address := 2;
    Configurations[1].Number := Configurations[0].Number;
    AssertFalse(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsDuplicateAddress;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Configurations.AddConfig;
    Configurations.AddConfig.Number := 2;
    Configurations[1].Address := Configurations[0].Address;
    AssertFalse(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsDuplicateName;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Configurations.AddConfig;
    Configurations.AddConfig.Number := 2;
    Configurations[1].Address := 2;
    Configurations[1].Name := '  ' + LowerCase(Configurations[0].Name) + '  ';
    AssertFalse(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsInvalidOperationValues;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Operation.Volume := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Volume := Config.Volume;

    Config.Operation.Volume := Config.Volume + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Volume := Config.Volume;

    Config.Operation.Speed := -1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Speed := Config.MaxFlowRate;

    Config.Operation.Speed := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Speed := Config.MaxFlowRate;

    Config.Operation.Speed := Config.MaxFlowRate + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Speed := Config.MaxFlowRate;

    Config.Operation.Channel := Config.ChannelCount + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    Config.Operation.Channel := MIN_CHANNEL_NUMBER - 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.NormalizesOperationValuesAboveHardwareLimits;
var
  Config: TDispenserConfig;
begin
  TDispenserConfigValidator.NormalizeOperation(nil);
  Config := TDispenserConfig.Create;
  try
    Config.Volume := 500;
    Config.MaxFlowRate := 10;
    Config.ChannelCount := 4;
    Config.Operation.Volume := 501;
    Config.Operation.Speed := Config.MaxFlowRate + 1;
    Config.Operation.Channel := 0;
    TDispenserConfigValidator.NormalizeOperation(Config);
    AssertEquals(500, Config.Operation.Volume);
    AssertEquals(Config.MaxFlowRate, Config.Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Config.Operation.Channel);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.NormalizesOperationValuesBelowMinimums;
var
  Config: TDispenserConfig;
begin
  Config := TDispenserConfig.Create;
  try
    Config.Volume := 500;
    Config.MaxFlowRate := 10;
    Config.ChannelCount := 4;

    Config.Operation.Volume := 0;
    Config.Operation.Speed := MIN_SPEED - 1;
    Config.Operation.Channel := MIN_CHANNEL_NUMBER;
    TDispenserConfigValidator.NormalizeOperation(Config);
    AssertEquals(Config.Volume, Config.Operation.Volume);
    AssertEquals(Config.MaxFlowRate, Config.Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Config.Operation.Channel);

    Config.Operation.Volume := -1;
    Config.Operation.Speed := -1;
    Config.Operation.Channel := Config.ChannelCount + 1;
    TDispenserConfigValidator.NormalizeOperation(Config);
    AssertEquals(Config.Volume, Config.Operation.Volume);
    AssertEquals(Config.MaxFlowRate, Config.Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Config.Operation.Channel);
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsInvalidIntakeChannel;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.IntakeChannel := Config.ChannelCount + 1;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsTooManyConfigurations;
var
  Configurations: TDispenserConfigList;
  I: Integer;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    for I := 1 to MAX_DISPENSERS + 1 do
    begin
      with Configurations.AddConfig do
      begin
        Number := I;
        Address := I;
      end;
    end;
    AssertFalse(TDispenserConfigValidator.ValidateList(Configurations,
      ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Configurations.Free;
  end;
end;

procedure TWindowSettingsStorageTests.SetUp;
begin
  inherited SetUp;
  FFileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_pump_window_test_' + IntToStr(GetTickCount64) + '.ini';
  DeleteFile(FFileName);
  FStorage := TWindowSettingsStorage.Create(FFileName);
end;

procedure TWindowSettingsStorageTests.TearDown;
begin
  FStorage.Free;
  DeleteFile(FFileName);
  inherited TearDown;
end;

procedure TWindowSettingsStorageTests.MissingFileUsesDefaults;
var
  Width: Integer;
  Height: Integer;
begin
  FStorage.Load(640, 480, Width, Height);
  AssertEquals(640, Width);
  AssertEquals(480, Height);
end;

procedure TWindowSettingsStorageTests.WindowSizeRoundTrip;
var
  Width: Integer;
  Height: Integer;
begin
  AssertTrue(FStorage.Save(900, 700));
  FStorage.Load(640, 480, Width, Height);
  AssertEquals(900, Width);
  AssertEquals(700, Height);
end;

procedure TWindowSettingsStorageTests.MissingFileUsesEmptyLastPort;
begin
  AssertEquals('', FStorage.LoadLastPort);
end;

procedure TWindowSettingsStorageTests.LastPortRoundTrip;
begin
  AssertTrue(FStorage.SaveLastPort(' COM5 '));
  AssertEquals('COM5', FStorage.LoadLastPort);
end;

procedure TWindowSettingsStorageTests.MissingFileUsesEmptyLastAutomationFile;
begin
  AssertEquals('', FStorage.LoadLastAutomationFile);
end;

procedure TWindowSettingsStorageTests.LastAutomationFileRoundTrip;
begin
  AssertTrue(FStorage.SaveLastAutomationFile(' C:\protocols\run.txt '));
  AssertEquals('C:\protocols\run.txt', FStorage.LoadLastAutomationFile);
end;

procedure TWindowSettingsStorageTests.LastAutomationFileSurvivesWindowSizeSave;
begin
  AssertTrue(FStorage.SaveLastAutomationFile('C:\protocols\run.txt'));
  AssertTrue(FStorage.Save(900, 700));
  AssertEquals('C:\protocols\run.txt', FStorage.LoadLastAutomationFile);
end;

procedure TWindowSettingsStorageTests.CustomSectionRoundTrip;
var
  Storage: TWindowSettingsStorage;
  Width: Integer;
  Height: Integer;
begin
  Storage := TWindowSettingsStorage.Create(FFileName, 'MainWindow');
  try
    AssertTrue(Storage.Save(1200, 800));
    Storage.Load(640, 480, Width, Height);
    AssertEquals(1200, Width);
    AssertEquals(800, Height);
  finally
    Storage.Free;
  end;
end;

procedure TWindowSettingsStorageTests.PreservesConfigurationSection;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Configuration', 'Count', 1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  AssertTrue(FStorage.Save(900, 700));

  Ini := TIniFile.Create(FFileName);
  try
    AssertEquals(1, Ini.ReadInteger('Configuration', 'Count', 0));
    AssertEquals(900, Ini.ReadInteger('ConfigurationWindow', 'Width', 0));
    AssertEquals(700, Ini.ReadInteger('ConfigurationWindow', 'Height', 0));
  finally
    Ini.Free;
  end;
end;

function TDispenserCapacityValidatorTests.ReadCurrentVolume(
  AAddress: Integer): Double;
begin
  Result := FCurrentVolume;
end;

function TDispenserCapacityValidatorTests.CreateSingleConfig(ANumber,
  AAddress, AVolume: Integer): TDispenserConfigList;
begin
  Result := TDispenserConfigList.Create;
  with Result.AddConfig do
  begin
    Number := ANumber;
    Address := AAddress;
    Name := Format('Дозатор %d', [ANumber]);
    Volume := AVolume;
    Operation.Volume := AVolume;
  end;
end;

procedure TDispenserCapacityValidatorTests.AllowsEqualCapacity;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(1, 1, 100);
  try
    FCurrentVolume := 100;
    AssertTrue(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertEquals('', ErrorText);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.AllowsCapacityIncrease;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 100);
  NewConfigurations := CreateSingleConfig(1, 1, 250);
  try
    FCurrentVolume := 100;
    AssertTrue(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertEquals('', ErrorText);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.RejectsDecreaseWhenLiquidExceedsCapacity;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(1, 1, 100);
  try
    FCurrentVolume := 101;
    AssertFalse(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(Pos('Сначала опустошите дозатор', ErrorText) > 0);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.RejectsOperationAboveCapacity;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(1, 1, 100);
  try
    NewConfigurations[0].Operation.Volume := 101;
    FCurrentVolume := 0;
    AssertFalse(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(Pos('превышает вместимость шприца', ErrorText) > 0);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.RejectsRemovingDispenserWithLiquid;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := TDispenserConfigList.Create;
  try
    FCurrentVolume := 10;
    AssertFalse(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(Pos('нельзя удалить дозатор', LowerCase(ErrorText)) > 0);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.RejectsChangingAddressWithLiquid;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(1, 2, 250);
  try
    FCurrentVolume := 10;
    AssertFalse(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(Pos('нельзя изменить адрес', LowerCase(ErrorText)) > 0);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserConfigValidatorTests.RejectsIntakeChannelBelowMinimum;
var
  Config: TDispenserConfig;
  ErrorText: string;
begin
  Config := TDispenserConfig.Create;
  try
    Config.IntakeChannel := 0;
    AssertFalse(TDispenserConfigValidator.Validate(Config, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
  end;
end;

procedure TWindowSettingsStorageTests.DefaultConstructorUsesApplicationConfigPath;
var
  Storage: TWindowSettingsStorage;
begin
  Storage := TWindowSettingsStorage.Create('', '');
  try
    AssertTrue(Storage.FileName <> '');
    AssertTrue(Pos('syringe_pump.ini', Storage.FileName) > 0);
  finally
    Storage.Free;
  end;
end;

procedure TWindowSettingsStorageTests.MalformedDimensionsUseDefaults;
var
  Ini: TIniFile;
  Width: Integer;
  Height: Integer;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteString('ConfigurationWindow', 'Width', 'invalid');
    Ini.WriteInteger('ConfigurationWindow', 'Height', 900);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  FStorage.Load(640, 480, Width, Height);
  AssertEquals(640, Width);
  AssertEquals(900, Height);
end;

procedure TWindowSettingsStorageTests.SaveErrorsAreReported;
var
  Storage: TWindowSettingsStorage;
  DirectoryPath: string;
begin
  DirectoryPath := IncludeTrailingPathDelimiter(GetTempDir(False));
  Storage := TWindowSettingsStorage.Create(DirectoryPath);
  try
    AssertFalse(Storage.Save(800, 600));
    AssertFalse(Storage.SaveLastPort('COM9'));
  finally
    Storage.Free;
  end;
end;

procedure TWindowSettingsStorageTests.LockedSettingsFileUsesDefaults;
var
  LockedFile: TFileStream;
  Width: Integer;
  Height: Integer;
begin
  LockedFile := TFileStream.Create(FFileName, fmCreate or fmShareExclusive);
  try
    FStorage.Load(640, 480, Width, Height);
    AssertEquals(640, Width);
    AssertEquals(480, Height);
    AssertEquals('', FStorage.LoadLastPort);
  finally
    LockedFile.Free;
  end;
end;

procedure TWindowSettingsStorageTests.SaveMethodsCreateMissingDirectories;
var
  FirstDirectory: string;
  SecondDirectory: string;
  FirstFile: string;
  SecondFile: string;
  FirstStorage: TWindowSettingsStorage;
  SecondStorage: TWindowSettingsStorage;
begin
  FirstDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_window_save_' + IntToStr(GetTickCount64);
  SecondDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_window_port_' + IntToStr(GetTickCount64);
  FirstFile := IncludeTrailingPathDelimiter(FirstDirectory) + 'window.ini';
  SecondFile := IncludeTrailingPathDelimiter(SecondDirectory) + 'window.ini';
  FirstStorage := TWindowSettingsStorage.Create(FirstFile);
  SecondStorage := TWindowSettingsStorage.Create(SecondFile);
  try
    AssertTrue(FirstStorage.Save(800, 600));
    AssertTrue(FirstStorage.SaveLastAutomationFile('C:\protocols\scenario.txt'));
    AssertEquals('C:\protocols\scenario.txt',
      FirstStorage.LoadLastAutomationFile);
    AssertTrue(SecondStorage.SaveLastPort('COM7'));
    AssertEquals('COM7', SecondStorage.LoadLastPort);
  finally
    FirstStorage.Free;
    SecondStorage.Free;
    DeleteFile(FirstFile);
    DeleteFile(SecondFile);
    RemoveDir(FirstDirectory);
    RemoveDir(SecondDirectory);
  end;
end;

procedure TAutomationDocumentStorageTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_automation_storage_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
  FExecutableFileName := IncludeTrailingPathDelimiter(FDirectory) +
    'syringe_pump.exe';
  FProtocolsDirectory := IncludeTrailingPathDelimiter(FDirectory) +
    'protocols';
end;

procedure TAutomationDocumentStorageTests.TearDown;
begin
  DeleteFile(IncludeTrailingPathDelimiter(FProtocolsDirectory) +
    'scenario.txt');
  DeleteFile(IncludeTrailingPathDelimiter(FProtocolsDirectory) +
    'bom.txt');
  RemoveDir(FProtocolsDirectory);
  RemoveDir(FDirectory);
  inherited TearDown;
end;

procedure TAutomationDocumentStorageTests.EnsureTestProtocolsDirectory;
var
  Directory: string;
  ErrorText: string;
begin
  AssertTrue(EnsureProtocolsDirectory(FExecutableFileName, Directory,
    ErrorText));
  AssertEquals(FProtocolsDirectory, Directory);
end;

procedure TAutomationDocumentStorageTests.ProtocolsDirectoryIsNextToExecutable;
begin
  AssertEquals(FProtocolsDirectory,
    GetProtocolsDirectory(FExecutableFileName));
end;

procedure TAutomationDocumentStorageTests.CreatesProtocolsDirectoryWhenMissing;
begin
  AssertFalse(DirectoryExists(FProtocolsDirectory));
  EnsureTestProtocolsDirectory;
  AssertTrue(DirectoryExists(FProtocolsDirectory));
end;

procedure TAutomationDocumentStorageTests.RoundTripPreservesUtf8Scenario;
var
  FileName: string;
  Content: UTF8String;
  LoadedContent: UTF8String;
  ErrorText: string;
begin
  EnsureTestProtocolsDirectory;
  FileName := IncludeTrailingPathDelimiter(FProtocolsDirectory) +
    'scenario.txt';
  Content := 'command_1: {' + LineEnding +
    '  dispenser_names: "Дозатор 1";' + LineEnding + '}';
  AssertTrue(WriteAutomationTextFile(FileName, Content, ErrorText));
  AssertTrue(ReadAutomationTextFile(FileName, LoadedContent, ErrorText));
  AssertEquals(Content, LoadedContent);
end;

procedure TAutomationDocumentStorageTests.ReadsUtf8Bom;
var
  FileName: string;
  Stream: TFileStream;
  Payload: UTF8String;
  LoadedContent: UTF8String;
  ExpectedContent: UTF8String;
  ErrorText: string;
  Bom: array[0..2] of Byte;
begin
  EnsureTestProtocolsDirectory;
  FileName := IncludeTrailingPathDelimiter(FProtocolsDirectory) + 'bom.txt';
  Bom[0] := $EF;
  Bom[1] := $BB;
  Bom[2] := $BF;
  Payload := 'Протокол';
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(Bom, SizeOf(Bom));
    Stream.WriteBuffer(Payload[1], Length(Payload));
  finally
    Stream.Free;
  end;

  AssertTrue(ReadAutomationTextFile(FileName, LoadedContent, ErrorText));
  ExpectedContent := 'Протокол';
  AssertEquals(ExpectedContent, LoadedContent);
end;

procedure TAutomationDocumentStorageTests.MissingScenarioFileReturnsError;
var
  Content: UTF8String;
  ErrorText: string;
begin
  EnsureTestProtocolsDirectory;
  AssertFalse(ReadAutomationTextFile(
    IncludeTrailingPathDelimiter(FProtocolsDirectory) + 'missing.txt',
    Content, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TDispenserCapacityValidatorTests.RejectsMissingNewListAndVolumeProvider;
var
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  NewConfigurations := CreateSingleConfig(1, 1, 250);
  try
    AssertFalse(TDispenserCapacityValidator.ValidateChange(nil, nil,
      @ReadCurrentVolume, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertFalse(TDispenserCapacityValidator.ValidateChange(nil,
      NewConfigurations, nil, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.AllowsNilOldListAndZeroCurrentVolume;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := TDispenserConfigList.Create;
  try
    FCurrentVolume := 0;
    AssertTrue(TDispenserCapacityValidator.ValidateChange(nil,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.MatchesPreviousConfigurationByNumber;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(1, 2, 300);
  try
    FCurrentVolume := 0;
    AssertTrue(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertEquals('', ErrorText);
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserCapacityValidatorTests.DetectsLiquidInUnmatchedRemovedConfiguration;
var
  OldConfigurations: TDispenserConfigList;
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  OldConfigurations := CreateSingleConfig(1, 1, 250);
  NewConfigurations := CreateSingleConfig(2, 2, 250);
  try
    FCurrentVolume := 10;
    AssertFalse(TDispenserCapacityValidator.ValidateChange(OldConfigurations,
      NewConfigurations, @ReadCurrentVolume, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    OldConfigurations.Free;
    NewConfigurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.SetUp;
begin
  inherited SetUp;
  FFileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_pump_storage_test_' + IntToStr(GetTickCount64) + '.ini';
  FNestedDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'syringe_pump_storage_nested_' + IntToStr(GetTickCount64);
  DeleteFile(FFileName);
  if DirectoryExists(FNestedDirectory) then
    RemoveDir(FNestedDirectory);
  FStorage := TDispenserConfigStorage.Create(FFileName);
end;

procedure TDispenserConfigStorageTests.TearDown;
begin
  FStorage.Free;
  DeleteFile(FFileName);
  if DirectoryExists(FNestedDirectory) then
    RemoveDir(FNestedDirectory);
  inherited TearDown;
end;

function TDispenserConfigStorageTests.CreateSourceConfigurations:
  TDispenserConfigList;
var
  Config: TDispenserConfig;
begin
  Result := TDispenserConfigList.Create;
  Config := Result.AddConfig;
  Config.Number := 3;
  Config.Name := 'Test dispenser';
  Config.Address := 7;
  Config.Volume := 5000;
  Config.ChannelCount := 4;
  Config.StepCount := 23000;
  Config.IntakeChannel := 2;
  Config.MaxFlowRate := 80;
  Config.Bypass := True;
  Config.Operation.Volume := 125;
  Config.Operation.Speed := 1;
  Config.Operation.Channel := 4;
end;

procedure TDispenserConfigStorageTests.WriteValidIniWithoutOperation;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Configuration', 'Count', 1);
    Ini.WriteInteger('Dispenser1', 'Number', 2);
    Ini.WriteString('Dispenser1', 'Name', 'Legacy dispenser');
    Ini.WriteInteger('Dispenser1', 'Address', 6);
    Ini.WriteInteger('Dispenser1', 'Volume', 4000);
    Ini.WriteInteger('Dispenser1', 'ChannelCount', 3);
    Ini.WriteInteger('Dispenser1', 'StepCount', 18000);
    Ini.WriteInteger('Dispenser1', 'IntakeChannel', 2);
    Ini.WriteInteger('Dispenser1', 'Speed', 700);
    Ini.WriteBool('Dispenser1', 'Bypass', False);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TDispenserConfigStorageTests.WriteValidIniWithInvalidOperation;
var
  Ini: TIniFile;
begin
  WriteValidIniWithoutOperation;
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Dispenser1', 'OperationVolume', 0);
    Ini.WriteInteger('Dispenser1', 'OperationSpeed', -1);
    Ini.WriteInteger('Dispenser1', 'OperationChannel', MAX_CHANNEL_COUNT + 1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TDispenserConfigStorageTests.MissingFileLoadsEmptyList;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := nil;
  try
    AssertTrue(FStorage.Load(Configurations, ErrorText));
    AssertEquals(0, Configurations.Count);
    AssertEquals('', ErrorText);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.EmptyListRoundTrip;
var
  Source: TDispenserConfigList;
  Loaded: TDispenserConfigList;
  Ini: TIniFile;
  ErrorText: string;
begin
  Source := TDispenserConfigList.Create;
  Loaded := nil;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
    Ini := TIniFile.Create(FFileName);
    try
      AssertFalse(Ini.ValueExists('Dispenser1', 'CurrentVolume'));
    finally
      Ini.Free;
    end;
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(0, Loaded.Count);
  finally
    Source.Free;
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.ConfigurationRoundTripPreservesOperation;
var
  Source: TDispenserConfigList;
  Loaded: TDispenserConfigList;
  Ini: TIniFile;
  ErrorText: string;
begin
  Source := CreateSourceConfigurations;
  Loaded := nil;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
    Ini := TIniFile.Create(FFileName);
    try
      AssertTrue(Ini.ValueExists('Dispenser1',
        'MaximumSpeedMicrolitersPerSecond'));
      AssertFalse(Ini.ValueExists('Dispenser1', 'Speed'));
      AssertTrue(Ini.ValueExists('Dispenser1',
        'OperationSpeedMicrolitersPerSecond'));
      AssertFalse(Ini.ValueExists('Dispenser1', 'OperationSpeed'));
    finally
      Ini.Free;
    end;
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(1, Loaded.Count);
    AssertEquals(Source[0].Number, Loaded[0].Number);
    AssertEquals(Source[0].Name, Loaded[0].Name);
    AssertEquals(Source[0].Address, Loaded[0].Address);
    AssertEquals(Source[0].Volume, Loaded[0].Volume);
    AssertEquals(Source[0].ChannelCount, Loaded[0].ChannelCount);
    AssertEquals(Source[0].StepCount, Loaded[0].StepCount);
    AssertEquals(Source[0].IntakeChannel, Loaded[0].IntakeChannel);
    AssertEquals(Source[0].MaxFlowRate, Loaded[0].MaxFlowRate);
    AssertEquals(Source[0].Bypass, Loaded[0].Bypass);
    AssertEquals(Source[0].Operation.Volume, Loaded[0].Operation.Volume);
    AssertEquals(Source[0].Operation.Speed, Loaded[0].Operation.Speed);
    AssertEquals(Source[0].Operation.Channel, Loaded[0].Operation.Channel);
  finally
    Source.Free;
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RoundTripPreservesOrderAndCyrillicName;
var
  Source: TDispenserConfigList;
  Loaded: TDispenserConfigList;
  ErrorText: string;
begin
  Source := TDispenserConfigList.Create;
  with Source.AddConfig do
  begin
    Number := 2;
    Address := 8;
    Name := 'Дозатор №2';
  end;
  with Source.AddConfig do
  begin
    Number := 1;
    Address := 4;
    Name := 'Дозатор №1';
  end;
  Loaded := nil;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(2, Loaded.Count);
    AssertEquals(2, Loaded[0].Number);
    AssertEquals(8, Loaded[0].Address);
    AssertEquals('Дозатор №2', Loaded[0].Name);
    AssertEquals(1, Loaded[1].Number);
    AssertEquals(4, Loaded[1].Address);
    AssertEquals('Дозатор №1', Loaded[1].Name);
  finally
    Source.Free;
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.MaximumDispenserCountRoundTrip;
var
  Source: TDispenserConfigList;
  Loaded: TDispenserConfigList;
  I: Integer;
  ErrorText: string;
begin
  Source := TDispenserConfigList.Create;
  for I := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    with Source.AddConfig do
    begin
      Number := I;
      Address := I;
      Name := 'Dispenser ' + IntToStr(I);
    end;
  end;
  Loaded := nil;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(MAX_DISPENSERS, Loaded.Count);
    AssertEquals(MAX_DISPENSER_VALUE, Loaded[MAX_DISPENSERS - 1].Number);
    AssertEquals(MAX_DISPENSER_VALUE, Loaded[MAX_DISPENSERS - 1].Address);
  finally
    Source.Free;
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.LegacyFileUsesOperationDefaults;
var
  Loaded: TDispenserConfigList;
  ErrorText: string;
begin
  WriteValidIniWithoutOperation;
  Loaded := nil;
  try
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(1, Loaded.Count);
    AssertEquals(Loaded[0].Volume, Loaded[0].Operation.Volume);
    AssertEquals(MaximumVolumeRate(700, Loaded[0].Volume,
      Loaded[0].StepCount), Loaded[0].MaxFlowRate);
    AssertEquals(Loaded[0].MaxFlowRate, Loaded[0].Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Loaded[0].Operation.Channel);
  finally
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.LegacyMotorSpeedIsMigratedToVolumeRate;
var
  Ini: TIniFile;
  Loaded: TDispenserConfigList;
  ErrorText: string;
begin
  WriteValidIniWithoutOperation;
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Dispenser1', 'OperationSpeed', 360);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Loaded := nil;
  try
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(80, Loaded[0].Operation.Speed);
  finally
    Loaded.Free;
  end;

  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Dispenser1', 'OperationSpeed', 1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  Loaded := nil;
  try
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(MinimumVolumeRate(Loaded[0].Volume, Loaded[0].StepCount),
      Loaded[0].Operation.Speed);
  finally
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.InvalidOperationValuesUseDefaults;
var
  Ini: TIniFile;
  Loaded: TDispenserConfigList;
  ErrorText: string;
begin
  WriteValidIniWithInvalidOperation;
  Loaded := nil;
  try
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(1, Loaded.Count);
    AssertEquals(Loaded[0].Volume, Loaded[0].Operation.Volume);
    AssertEquals(Loaded[0].MaxFlowRate, Loaded[0].Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Loaded[0].Operation.Channel);
  finally
    Loaded.Free;
  end;

  WriteValidIniWithoutOperation;
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteString('Dispenser1', 'OperationVolume', 'invalid');
    Ini.WriteString('Dispenser1', 'OperationSpeedMicrolitersPerSecond',
      'invalid');
    Ini.WriteString('Dispenser1', 'OperationChannel', 'invalid');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  Loaded := nil;
  try
    AssertTrue(FStorage.Load(Loaded, ErrorText));
    AssertEquals(1, Loaded.Count);
    AssertEquals(Loaded[0].Volume, Loaded[0].Operation.Volume);
    AssertEquals(Loaded[0].MaxFlowRate, Loaded[0].Operation.Speed);
    AssertEquals(MIN_CHANNEL_NUMBER, Loaded[0].Operation.Channel);
  finally
    Loaded.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsNonNumericCount;
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteString('Configuration', 'Count', 'many');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Configurations := nil;
  try
    AssertFalse(FStorage.Load(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(Configurations = nil);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsNonNumericHardwareValue;
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  WriteValidIniWithoutOperation;
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteString('Dispenser1', 'Number', 'three');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Configurations := nil;
  try
    AssertFalse(FStorage.Load(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(Configurations = nil);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.PreservesWindowSettingsSection;
var
  Ini: TIniFile;
  Source: TDispenserConfigList;
  ErrorText: string;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('ConfigurationWindow', 'Width', 777);
    Ini.WriteInteger('ConfigurationWindow', 'Height', 555);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Source := CreateSourceConfigurations;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
  finally
    Source.Free;
  end;

  Ini := TIniFile.Create(FFileName);
  try
    AssertEquals(777, Ini.ReadInteger('ConfigurationWindow', 'Width', 0));
    AssertEquals(555, Ini.ReadInteger('ConfigurationWindow', 'Height', 0));
  finally
    Ini.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RemovesStaleDispenserSections;
var
  Ini: TIniFile;
  Source: TDispenserConfigList;
  ErrorText: string;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Dispenser2', 'Number', 2);
    Ini.WriteInteger('Dispenser16', 'Number', 16);
    Ini.WriteInteger('DispenserX', 'Number', 20);
    Ini.WriteInteger('Dispenser0', 'Number', 0);
    Ini.WriteInteger('OtherDispenser1', 'Number', 1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Source := CreateSourceConfigurations;
  try
    AssertTrue(FStorage.Save(Source, ErrorText));
  finally
    Source.Free;
  end;

  Ini := TIniFile.Create(FFileName);
  try
    AssertFalse(Ini.SectionExists('Dispenser2'));
    AssertFalse(Ini.SectionExists('Dispenser16'));
    AssertTrue(Ini.SectionExists('DispenserX'));
    AssertTrue(Ini.SectionExists('Dispenser0'));
    AssertTrue(Ini.SectionExists('OtherDispenser1'));
    AssertTrue(Ini.SectionExists('Dispenser1'));
  finally
    Ini.Free;
  end;
end;

procedure TDispenserConfigStorageTests.CreatesMissingDirectory;
var
  NestedFileName: string;
  NestedStorage: TDispenserConfigStorage;
  Source: TDispenserConfigList;
  ErrorText: string;
begin
  NestedFileName := IncludeTrailingPathDelimiter(FNestedDirectory) +
    'settings.ini';
  NestedStorage := TDispenserConfigStorage.Create(NestedFileName);
  Source := CreateSourceConfigurations;
  try
    AssertTrue(NestedStorage.Save(Source, ErrorText));
    AssertTrue(DirectoryExists(FNestedDirectory));
    AssertTrue(FileExists(NestedFileName));
  finally
    Source.Free;
    NestedStorage.Free;
    DeleteFile(NestedFileName);
  end;
end;

procedure TDispenserConfigStorageTests.RejectsInvalidListOnSave;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Configurations := TDispenserConfigList.Create;
  try
    Configurations.AddConfig.Number := 0;
    AssertFalse(FStorage.Save(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertFalse(FileExists(FFileName));
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsNilListOnSave;
var
  ErrorText: string;
begin
  AssertFalse(FStorage.Save(nil, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertFalse(FileExists(FFileName));
end;

procedure TDispenserConfigStorageTests.RejectsNegativeDispenserCount;
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Configuration', 'Count', -1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Configurations := nil;
  try
    AssertFalse(FStorage.Load(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(Configurations = nil);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsTooManyDispenserSections;
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Configuration', 'Count', 16);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Configurations := nil;
  try
    AssertFalse(FStorage.Load(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(Configurations = nil);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsTooManyConfigurationsOnSave;
var
  Configurations: TDispenserConfigList;
  ErrorText: string;
  I: Integer;
begin
  Configurations := TDispenserConfigList.Create;
  try
    for I := 1 to MAX_DISPENSERS + 1 do
      Configurations.AddConfig;
    AssertFalse(FStorage.Save(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertFalse(FileExists(FFileName));
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsNonnumericHardwareFields;
const
  HardwareFields: array[0..7] of string = (
    'Address', 'Volume', 'ChannelCount', 'StepCount',
    'IntakeChannel', 'Speed', 'Number',
    'MaximumSpeedMicrolitersPerSecond');
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
  I: Integer;
begin
  for I := Low(HardwareFields) to High(HardwareFields) do
  begin
    DeleteFile(FFileName);
    WriteValidIniWithoutOperation;
    Ini := TIniFile.Create(FFileName);
    try
      Ini.WriteString('Dispenser1', HardwareFields[I], 'not-a-number');
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;

    Configurations := nil;
    try
      AssertFalse('Field: ' + HardwareFields[I],
        FStorage.Load(Configurations, ErrorText));
      AssertTrue(ErrorText <> '');
      AssertTrue(Configurations = nil);
    finally
      Configurations.Free;
    end;
  end;
end;

procedure TDispenserConfigStorageTests.RejectsNumericallyValidButInvalidConfiguration;
var
  Ini: TIniFile;
  Configurations: TDispenserConfigList;
  ErrorText: string;
begin
  WriteValidIniWithoutOperation;
  Ini := TIniFile.Create(FFileName);
  try
    Ini.WriteInteger('Dispenser1', 'ChannelCount', MIN_CHANNEL_COUNT - 1);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  Configurations := nil;
  try
    AssertFalse(FStorage.Load(Configurations, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(Configurations = nil);
  finally
    Configurations.Free;
  end;
end;

procedure TDispenserConfigStorageTests.SaveFailureReturnsError;
var
  DirectoryStorage: TDispenserConfigStorage;
  Source: TDispenserConfigList;
  ErrorText: string;
begin
  AssertTrue(ForceDirectories(FNestedDirectory));
  DirectoryStorage := TDispenserConfigStorage.Create(FNestedDirectory);
  Source := CreateSourceConfigurations;
  try
    AssertFalse(DirectoryStorage.Save(Source, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Source.Free;
    DirectoryStorage.Free;
  end;
end;

procedure TDispenserConfigStorageTests.DefaultConstructorUsesApplicationConfigPath;
var
  Storage: TDispenserConfigStorage;
begin
  Storage := TDispenserConfigStorage.Create('');
  try
    AssertTrue(Storage.FileName <> '');
    AssertTrue(Pos('syringe_pump.ini', Storage.FileName) > 0);
  finally
    Storage.Free;
  end;
end;

initialization
  RegisterTest(TDispenserCommandTests);
  RegisterTest(TAutomationProtocolTests);
  RegisterTest(TDispenserOperationRulesTests);
  RegisterTest(TDispenserConfigModelTests);
  RegisterTest(TDispenserLayoutTests);
  RegisterTest(TDispenserConfigValidatorTests);
  RegisterTest(TWindowSettingsStorageTests);
  RegisterTest(TAutomationDocumentStorageTests);
  RegisterTest(TDispenserCapacityValidatorTests);
  RegisterTest(TDispenserConfigStorageTests);

end.
