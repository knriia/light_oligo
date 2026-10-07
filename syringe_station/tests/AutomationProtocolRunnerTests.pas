unit AutomationProtocolRunnerTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DispenserConfig,
  DispenserController, DispenserRuntimeState, DispenserTypes,
  DispenserOperationCoordinator, AutomationProtocol,
  AutomationProtocolRunner, DispenserLimits;

type
  TProtocolTestController = class(TDispenserController)
  private
    FActions: TStringList;
    FConnected: Boolean;
    FLastErrorText: string;
    FTerminateCount: Integer;
    FFailValveAddress: Integer;
    FFailMovementAddress: Integer;
    FFailTerminateAddress: Integer;
    FDelayedReadyAddress: Integer;
    FNotReadyPolls: Integer;
    FEncoderPositionSteps: array[MIN_DISPENSER_VALUE..
      MAX_DISPENSER_VALUE] of Int64;
    FEncoderQueryCalls: Integer;
  protected
    function GetIsConnected: Boolean; override;
    function GetLastError: string; override;
  public
    constructor Create;
    destructor Destroy; override;
    function QueryStatusQuiet(Address: Integer;
      out StatusCode: Byte): Boolean; override;
    function QueryPlungerEncoderPosition(Address: Integer;
      out PositionSteps: Int64): Boolean; override;
    function SetValvePosition(Address, Channel: Integer;
      AAspirate: Boolean; AValveType: TDispenserValveType): Boolean; override;
    function ExecutePlungerMovement(Address, Steps, Speed: Integer;
      AAspirate: Boolean): Boolean; override;
    function TerminateMovement(Address: Integer): Boolean; override;
    function CountActionsWithPrefix(const APrefix: string): Integer;
    procedure DelayReadyFor(Address, PollCount: Integer);
    property Actions: TStringList read FActions;
    property TerminateCount: Integer read FTerminateCount;
    property EncoderQueryCalls: Integer read FEncoderQueryCalls;
    property FailValveAddress: Integer read FFailValveAddress
      write FFailValveAddress;
    property FailMovementAddress: Integer read FFailMovementAddress
      write FFailMovementAddress;
    property FailTerminateAddress: Integer read FFailTerminateAddress
      write FFailTerminateAddress;
  end;

  TAutomationProtocolRunnerTests = class(TTestCase)
  private
    function CreateConfigurations: TDispenserConfigList;
    function Parse(const AText: string; AConfigurations: TDispenserConfigList;
      out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;
    function CreateInitializedStates(
      AConfigurations: TDispenserConfigList): TDispenserRuntimeStates;
    function BuildProtocolText(const ANames, AChannels, AVolumes,
      AVolumeUnit, ASpeeds, ASpeedUnit: string): string;
    procedure RunUntilFinished(ARunner: TAutomationProtocolRunner);
  published
    procedure SwitchesEveryGroupValveBeforeStartingPlungers;
    procedure UsesConfiguredIntakeAndProtocolOutputForNonDistributiveValve;
    procedure RepeatsFillAndDispenseUntilTotalVolumeIsDelivered;
    procedure InterruptedMovementRequiresInitialization;
    procedure RejectsUninitializedTargetBeforeSendingCommands;
    procedure ValveCommandFailureMarksOnlyAffectedDispenserUnknown;
    procedure MovementCommandFailureTerminatesUncertainMovement;
    procedure StopsBothTargetsWhenProtocolMovementStartPartiallyFails;
    procedure FailedProtocolStopRemainsTrackedForRetry;
  end;

implementation

constructor TProtocolTestController.Create;
begin
  inherited Create;
  FActions := TStringList.Create;
  FConnected := True;
  FLastErrorText := '';
  FTerminateCount := 0;
  FFailValveAddress := 0;
  FFailMovementAddress := 0;
  FFailTerminateAddress := 0;
  FDelayedReadyAddress := 0;
  FNotReadyPolls := 0;
end;

destructor TProtocolTestController.Destroy;
begin
  FActions.Free;
  inherited Destroy;
end;

function TProtocolTestController.GetIsConnected: Boolean;
begin
  Result := FConnected;
end;

function TProtocolTestController.GetLastError: string;
begin
  Result := FLastErrorText;
end;

function TProtocolTestController.QueryStatusQuiet(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  if (Address = FDelayedReadyAddress) and (FNotReadyPolls > 0) then
  begin
    Dec(FNotReadyPolls);
    StatusCode := 0;
  end
  else
    StatusCode := STATUS_READY_MASK;
  FLastErrorText := '';
  Result := True;
end;

function TProtocolTestController.QueryPlungerEncoderPosition(
  Address: Integer; out PositionSteps: Int64): Boolean;
begin
  Inc(FEncoderQueryCalls);
  PositionSteps := FEncoderPositionSteps[Address];
  FLastErrorText := '';
  Result := True;
end;

function TProtocolTestController.SetValvePosition(Address, Channel: Integer;
  AAspirate: Boolean; AValveType: TDispenserValveType): Boolean;
var
  Direction: Char;
begin
  if AAspirate then
    Direction := 'I'
  else
    Direction := 'O';
  FActions.Add('V' + IntToStr(Address) + Direction + IntToStr(Channel));
  Result := Address <> FFailValveAddress;
  if Result then
    FLastErrorText := ''
  else
    FLastErrorText := 'test valve response failure';
end;

function TProtocolTestController.ExecutePlungerMovement(Address, Steps,
  Speed: Integer; AAspirate: Boolean): Boolean;
var
  Direction: Char;
begin
  if AAspirate then
    Direction := 'P'
  else
    Direction := 'D';
  FActions.Add('M' + IntToStr(Address) + Direction + IntToStr(Steps) + '@' +
    IntToStr(Speed));
  Result := Address <> FFailMovementAddress;
  if Result then
  begin
    FLastErrorText := '';
    if AAspirate then
      Inc(FEncoderPositionSteps[Address], Steps)
    else
      Dec(FEncoderPositionSteps[Address], Steps);
  end
  else
    FLastErrorText := 'test movement response failure';
end;

function TProtocolTestController.TerminateMovement(Address: Integer): Boolean;
begin
  Inc(FTerminateCount);
  FActions.Add('T' + IntToStr(Address));
  Result := Address <> FFailTerminateAddress;
  if Result then
    FLastErrorText := ''
  else
    FLastErrorText := 'test terminate response failure';
end;

function TProtocolTestController.CountActionsWithPrefix(
  const APrefix: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FActions.Count - 1 do
    if Copy(FActions[I], 1, Length(APrefix)) = APrefix then
      Inc(Result);
end;

procedure TProtocolTestController.DelayReadyFor(Address, PollCount: Integer);
begin
  FDelayedReadyAddress := Address;
  FNotReadyPolls := PollCount;
end;

function TAutomationProtocolRunnerTests.CreateConfigurations:
  TDispenserConfigList;
var
  Config: TDispenserConfig;
begin
  Result := TDispenserConfigList.Create;
  Config := Result.AddConfig;
  Config.Name := 'Pump A';
  Config.Number := 1;
  Config.Address := 1;
  Config.Volume := 250;
  Config.ChannelCount := 2;
  Config.StepCount := 12000;
  Config.IntakeChannel := 1;
  Config.MaxFlowRate := 125;

  Config := Result.AddConfig;
  Config.Name := 'Pump B';
  Config.Number := 2;
  Config.Address := 2;
  Config.Volume := 1000;
  Config.ChannelCount := 4;
  Config.StepCount := 12000;
  Config.IntakeChannel := 1;
  Config.MaxFlowRate := 500;
end;

function TAutomationProtocolRunnerTests.Parse(const AText: string;
  AConfigurations: TDispenserConfigList;
  out AProtocol: TAutomationProtocol; out ErrorText: string): Boolean;
begin
  Result := ParseAutomationProtocol(AText, AConfigurations, AProtocol,
    ErrorText);
end;

function TAutomationProtocolRunnerTests.CreateInitializedStates(
  AConfigurations: TDispenserConfigList): TDispenserRuntimeStates;
var
  I: Integer;
  State: TDispenserRuntimeState;
begin
  Result := TDispenserRuntimeStates.Create;
  for I := 0 to AConfigurations.Count - 1 do
  begin
    State := Result.Items[AConfigurations[I].Address];
    State.ValveType := dvtDistributive;
    State.MarkInitialized(AConfigurations[I]);
  end;
end;

function TAutomationProtocolRunnerTests.BuildProtocolText(const ANames,
  AChannels, AVolumes, AVolumeUnit, ASpeeds, ASpeedUnit: string): string;
begin
  Result := 'command_1: {' + LineEnding +
    '  dispenser_names: "' + ANames + '";' + LineEnding +
    '  valve_channels: "' + AChannels + '";' + LineEnding +
    '  volumes: "' + AVolumes + '";' + LineEnding +
    '  volume_unit: "' + AVolumeUnit + '";' + LineEnding +
    '  speeds: "' + ASpeeds + '";' + LineEnding +
    '  speed_unit: "' + ASpeedUnit + '"' + LineEnding +
    '}';
end;

procedure TAutomationProtocolRunnerTests.RunUntilFinished(
  ARunner: TAutomationProtocolRunner);
var
  I: Integer;
begin
  for I := 1 to 1000 do
  begin
    if not ARunner.IsRunning then
      Exit;
    ARunner.Poll;
  end;
  Fail('Протокол не завершился за 1000 циклов опроса.');
end;

procedure TAutomationProtocolRunnerTests.SwitchesEveryGroupValveBeforeStartingPlungers;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
  I: Integer;
  MovementCount: Integer;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Controller.DelayReadyFor(2, 2);
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A/Pump B', '2/3', '500', 'мкл',
      '100', 'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;

    AssertEquals(2, Controller.Actions.Count);
    AssertEquals('V1I1', Controller.Actions[0]);
    AssertEquals('V2I1', Controller.Actions[1]);

    Runner.Poll;
    Runner.Poll;
    Runner.Poll;
    AssertEquals(0, Controller.CountActionsWithPrefix('M'));
    Runner.Poll;
    MovementCount := Controller.CountActionsWithPrefix('M');
    AssertEquals(2, MovementCount);
    AssertTrue(Copy(Controller.Actions[2], 1, 1) = 'M');
    AssertTrue(Copy(Controller.Actions[3], 1, 1) = 'M');

    RunUntilFinished(Runner);
    AssertEquals(2, Controller.CountActionsWithPrefix('M1P'));
    AssertEquals(1, Controller.CountActionsWithPrefix('M2P'));
    AssertEquals(2, Controller.CountActionsWithPrefix('M1D'));
    AssertEquals(2, Controller.CountActionsWithPrefix('M2D'));
    for I := 0 to Configurations.Count - 1 do
    begin
      AssertTrue(RuntimeStates.Items[Configurations[I].Address].
        IsInitializedFor(Configurations[I]));
      AssertTrue(RuntimeStates.IsCurrentVolumeKnown(
        Configurations[I].Address));
      AssertEquals(0, Round(RuntimeStates.GetCurrentVolume(
        Configurations[I].Address)));
    end;
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.UsesConfiguredIntakeAndProtocolOutputForNonDistributiveValve;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  Configurations[0].IntakeChannel := 2;
  RuntimeStates := CreateInitializedStates(Configurations);
  RuntimeStates.Items[1].ValveType := dvtNonDistributive;
  Controller := TProtocolTestController.Create;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '1', '250', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    AssertEquals('V1I2', Controller.Actions[0]);

    RunUntilFinished(Runner);

    AssertTrue(Controller.Actions.IndexOf('V1I2') >= 0);
    AssertTrue(Controller.Actions.IndexOf('V1O1') >
      Controller.Actions.IndexOf('V1I2'));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.RepeatsFillAndDispenseUntilTotalVolumeIsDelivered;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '2', '500', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    RunUntilFinished(Runner);

    AssertEquals(2, Controller.CountActionsWithPrefix('M1P'));
    AssertEquals(2, Controller.CountActionsWithPrefix('M1D'));
    AssertEquals(5, Controller.EncoderQueryCalls);
    AssertTrue(RuntimeStates.IsCurrentVolumeKnown(1));
    AssertEquals(0, Round(RuntimeStates.GetCurrentVolume(1)));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.InterruptedMovementRequiresInitialization;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '2', '250', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    Runner.Poll;
    AssertEquals(1, Controller.CountActionsWithPrefix('M'));
    AssertTrue(RuntimeStates.Items[1].OperationActive);

    Runner.Stop;

    AssertFalse(Runner.IsRunning);
    AssertEquals(1, Controller.TerminateCount);
    AssertTrue(RuntimeStates.Items[1].InitializationRequired);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.RejectsUninitializedTargetBeforeSendingCommands;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := TDispenserRuntimeStates.Create;
  Controller := TProtocolTestController.Create;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '2', '250', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertFalse(Runner.Start(Protocol, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertEquals(0, Controller.Actions.Count);
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.ValveCommandFailureMarksOnlyAffectedDispenserUnknown;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Controller.FailValveAddress := 1;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A/Pump B', '2', '100', 'мкл',
      '100', 'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;

    AssertFalse(Runner.IsRunning);
    AssertEquals(0, Controller.CountActionsWithPrefix('M'));
    AssertTrue(RuntimeStates.Items[1].InitializationRequired);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));
    AssertTrue(RuntimeStates.Items[2].IsInitializedFor(Configurations[1]));
    AssertTrue(RuntimeStates.IsCurrentVolumeKnown(2));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.MovementCommandFailureTerminatesUncertainMovement;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Controller.FailMovementAddress := 1;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '2', '250', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    Runner.Poll;

    AssertFalse(Runner.IsRunning);
    AssertEquals(1, Controller.TerminateCount);
    AssertTrue(RuntimeStates.Items[1].InitializationRequired);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.StopsBothTargetsWhenProtocolMovementStartPartiallyFails;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Controller.FailMovementAddress := 2;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A/Pump B', '2/3', '100/100',
      'мкл', '100/100', 'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    RunUntilFinished(Runner);

    AssertFalse(Runner.IsRunning);
    AssertEquals(2, Controller.CountActionsWithPrefix('M'));
    AssertEquals(2, Controller.TerminateCount);
    AssertFalse(RuntimeStates.Items[1].OperationActive);
    AssertFalse(RuntimeStates.Items[2].OperationActive);
    AssertTrue(RuntimeStates.Items[1].InitializationRequired);
    AssertTrue(RuntimeStates.Items[2].InitializationRequired);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(2));
  finally
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

procedure TAutomationProtocolRunnerTests.FailedProtocolStopRemainsTrackedForRetry;
var
  Configurations: TDispenserConfigList;
  RuntimeStates: TDispenserRuntimeStates;
  Controller: TProtocolTestController;
  Runner: TAutomationProtocolRunner;
  OperationCoordinator: TDispenserOperationCoordinator;
  Protocol: TAutomationProtocol;
  ErrorText: string;
begin
  Configurations := CreateConfigurations;
  RuntimeStates := CreateInitializedStates(Configurations);
  Controller := TProtocolTestController.Create;
  Controller.FailMovementAddress := 1;
  Controller.FailTerminateAddress := 1;
  Runner := TAutomationProtocolRunner.Create(Controller, RuntimeStates);
  OperationCoordinator := nil;
  Protocol := nil;
  try
    AssertTrue(Parse(BuildProtocolText('Pump A', '2', '100', 'мкл', '100',
      'мкл/с'), Configurations, Protocol, ErrorText));
    AssertTrue(ErrorText, Runner.Start(Protocol, ErrorText));
    Protocol := nil;
    RunUntilFinished(Runner);

    AssertFalse(Runner.IsRunning);
    AssertEquals(1, Controller.TerminateCount);
    AssertTrue(RuntimeStates.Items[1].OperationActive);
    AssertTrue(RuntimeStates.Items[1].InitializationRequired);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));

    OperationCoordinator := TDispenserOperationCoordinator.Create(Controller,
      RuntimeStates);
    AssertTrue(OperationCoordinator.HasActiveOperations);
    Controller.FailTerminateAddress := 0;
    AssertTrue(OperationCoordinator.StopActiveOperation(1, ErrorText));
    AssertFalse(RuntimeStates.Items[1].OperationActive);
    AssertFalse(RuntimeStates.IsCurrentVolumeKnown(1));
  finally
    OperationCoordinator.Free;
    Protocol.Free;
    Runner.Free;
    Controller.Free;
    RuntimeStates.Free;
    Configurations.Free;
  end;
end;

initialization
  RegisterTest(TAutomationProtocolRunnerTests);

end.
