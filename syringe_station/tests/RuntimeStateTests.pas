unit RuntimeStateTests;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, testregistry, DispenserLimits, DispenserRuntimeState,
  DispenserTypes, DispenserConfig;

type
  TDispenserRuntimeStateTests = class(TTestCase)
  published
    procedure NewStatesHaveDocumentedDefaults;
    procedure SetVolumeClampsNegativeValuesAndMarksKnown;
    procedure PositionStepsAndVolumeUseTheCalibration;
    procedure LifecycleTransitionsGuardOperationBoundsAndUnknownPosition;
    procedure UnknownVolumePreservesLastValue;
    procedure InitializationUsesAConfigurationSnapshot;
    procedure InitializationFailureMakesVolumeUnknown;
    procedure InvalidAddressesReturnSafeDefaults;
    procedure ResetClearsEveryAddressAndOperationField;
  end;

implementation

procedure TDispenserRuntimeStateTests.NewStatesHaveDocumentedDefaults;
var
  States: TDispenserRuntimeStates;
  State: TDispenserRuntimeState;
begin
  States := TDispenserRuntimeStates.Create;
  try
    State := States.Items[MIN_DISPENSER_VALUE];
    AssertNotNull(State);
    AssertEquals(0.0, State.CurrentVolume, 0.001);
    AssertFalse(State.CurrentVolumeKnown);
    AssertEquals(Ord(dvtUnknown), Ord(State.ValveType));
    AssertFalse(State.OperationActive);
    AssertEquals(Ord(dooNone), Ord(State.OperationOwner));
    AssertFalse(State.CommandPending);
    AssertFalse(State.ProtocolReserved);
    AssertEquals(Ord(dokFill), Ord(State.OperationKind));
    AssertEquals('', State.OperationName);
    AssertEquals(0, State.OperationVolume);
    AssertEquals(0.0, State.OperationStartingVolume, 0.001);
    AssertFalse(States.IsCurrentVolumeKnown(MIN_DISPENSER_VALUE));
    AssertEquals(0.0, States.GetCurrentVolume(MIN_DISPENSER_VALUE), 0.001);
  finally
    States.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.InitializationUsesAConfigurationSnapshot;
var
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
begin
  State := TDispenserRuntimeState.Create;
  Config := TDispenserConfig.Create;
  try
    Config.Number := 1;
    Config.Name := 'Pump A';
    Config.Address := 1;
    Config.Volume := 1000;
    Config.ChannelCount := 4;
    Config.StepCount := 10000;
    Config.IntakeChannel := 1;
    Config.MaxFlowRate := 12;
    Config.Operation.Speed := 10;

    State.MarkInitialized(Config);
    AssertTrue(State.CurrentVolumeKnown);
    AssertEquals(0.0, State.CurrentVolume, 0.001);
    AssertTrue(State.IsInitializedFor(Config));

    Config.Operation.Speed := 11;
    AssertTrue(State.IsInitializedFor(Config));
    Config.StepCount := 9000;
    AssertFalse(State.IsInitializedFor(Config));
    AssertFalse(State.InitializationRequired);
  finally
    Config.Free;
    State.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.InitializationFailureMakesVolumeUnknown;
var
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
begin
  State := TDispenserRuntimeState.Create;
  Config := TDispenserConfig.Create;
  try
    Config.Number := 1;
    Config.Name := 'Pump A';
    Config.Address := 1;
    Config.Volume := 1000;
    Config.ChannelCount := 4;
    Config.StepCount := 10000;
    Config.IntakeChannel := 1;
    Config.MaxFlowRate := 12;
    State.MarkInitialized(Config);
    State.MarkInitializationFailed('mock failure');

    AssertTrue(State.InitializationRequired);
    AssertEquals('mock failure', State.InitializationError);
    AssertFalse(State.CurrentVolumeKnown);
    AssertFalse(State.IsInitializedFor(Config));
  finally
    Config.Free;
    State.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.SetVolumeClampsNegativeValuesAndMarksKnown;
var
  States: TDispenserRuntimeStates;
begin
  States := TDispenserRuntimeStates.Create;
  try
    States.SetCurrentVolume(MIN_DISPENSER_VALUE, -5.5);
    AssertEquals(0.0, States.GetCurrentVolume(MIN_DISPENSER_VALUE), 0.001);
    AssertTrue(States.IsCurrentVolumeKnown(MIN_DISPENSER_VALUE));

    States.SetCurrentVolume(MAX_DISPENSER_VALUE, 42.5);
    AssertEquals(42.5, States.GetCurrentVolume(MAX_DISPENSER_VALUE), 0.001);
    AssertTrue(States.IsCurrentVolumeKnown(MAX_DISPENSER_VALUE));
  finally
    States.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.PositionStepsAndVolumeUseTheCalibration;
var
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
begin
  State := TDispenserRuntimeState.Create;
  Config := TDispenserConfig.Create;
  try
    Config.Number := 1;
    Config.Name := 'Pump A';
    Config.Address := 1;
    Config.Volume := 5000;
    Config.ChannelCount := 4;
    Config.StepCount := 12000;
    Config.IntakeChannel := 1;
    Config.MaxFlowRate := 12;
    Config.Operation.Speed := 1;
    State.MarkInitialized(Config);

    State.CurrentPositionSteps := 19;
    AssertEquals(19, State.CurrentPositionSteps);
    AssertEquals(19.0 * 5000.0 / 96000.0, State.CurrentVolume, 0.000001);

    State.CurrentVolume := 1.0;
    AssertEquals(19, State.CurrentPositionSteps);
    AssertTrue(State.CurrentVolumeKnown);
  finally
    Config.Free;
    State.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.LifecycleTransitionsGuardOperationBoundsAndUnknownPosition;
var
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
  ErrorText: string;
begin
  State := TDispenserRuntimeState.Create;
  Config := TDispenserConfig.Create;
  try
    Config.Number := 1;
    Config.Name := 'Pump A';
    Config.Address := 1;
    Config.Volume := 5000;
    Config.ChannelCount := 4;
    Config.StepCount := 12000;
    Config.IntakeChannel := 1;
    Config.MaxFlowRate := 12;
    Config.Operation.Speed := 1;

    AssertEquals(Ord(dlsUninitialized), Ord(State.LifecycleState));
    State.MarkInitialized(Config);
    AssertEquals(Ord(dlsReady), Ord(State.LifecycleState));

    AssertTrue(State.TryBeginOperation(dooManual, dokAspirate, 'Pump A',
      1, 19, 0, ErrorText));
    AssertEquals(Ord(dlsOperating), Ord(State.LifecycleState));
    AssertFalse(State.TryBeginOperation(dooManual, dokAspirate, 'Pump A',
      1, 19, 0, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(State.OperationActive);

    AssertTrue(State.CompleteOperation(ErrorText));
    AssertEquals(19, State.CurrentPositionSteps);
    AssertEquals(Ord(dlsReady), Ord(State.LifecycleState));

    AssertFalse(State.TryBeginOperation(dooManual, dokDispense, 'Pump A',
      1, 20, 19, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertEquals(Ord(dlsReady), Ord(State.LifecycleState));

    AssertTrue(State.TryBeginOperation(dooManual, dokDispense, 'Pump A',
      1, 19, 19, ErrorText));
    AssertTrue(State.CompleteOperation(ErrorText));
    AssertEquals(0, State.CurrentPositionSteps);

    AssertFalse(State.TryBeginOperation(dooManual, dokAspirate, 'Pump A',
      1, 96001, 0, ErrorText));
    State.MarkPositionUnknown('encoder mismatch');
    AssertEquals(Ord(dlsPositionUnknown), Ord(State.LifecycleState));
    AssertFalse(State.CurrentVolumeKnown);
    AssertFalse(State.TryBeginOperation(dooManual, dokAspirate, 'Pump A',
      1, 19, 0, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    Config.Free;
    State.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.UnknownVolumePreservesLastValue;
var
  States: TDispenserRuntimeStates;
begin
  States := TDispenserRuntimeStates.Create;
  try
    States.SetCurrentVolume(3, 120.0);
    States.MarkCurrentVolumeUnknown(3);

    AssertEquals(120.0, States.GetCurrentVolume(3), 0.001);
    AssertFalse(States.IsCurrentVolumeKnown(3));
  finally
    States.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.InvalidAddressesReturnSafeDefaults;
var
  States: TDispenserRuntimeStates;
begin
  States := TDispenserRuntimeStates.Create;
  try
    AssertNull(States.Items[MIN_DISPENSER_VALUE - 1]);
    AssertNull(States.Items[MAX_DISPENSER_VALUE + 1]);
    AssertEquals(0.0, States.GetCurrentVolume(MIN_DISPENSER_VALUE - 1), 0.001);
    AssertEquals(0.0, States.GetCurrentVolume(MAX_DISPENSER_VALUE + 1), 0.001);
    AssertFalse(States.IsCurrentVolumeKnown(MIN_DISPENSER_VALUE - 1));
    AssertFalse(States.IsCurrentVolumeKnown(MAX_DISPENSER_VALUE + 1));

    States.SetCurrentVolume(MIN_DISPENSER_VALUE - 1, 20.0);
    States.SetCurrentVolume(MAX_DISPENSER_VALUE + 1, 20.0);
    States.MarkCurrentVolumeUnknown(MIN_DISPENSER_VALUE - 1);
    States.MarkCurrentVolumeUnknown(MAX_DISPENSER_VALUE + 1);
    AssertEquals(0.0, States.GetCurrentVolume(MIN_DISPENSER_VALUE), 0.001);
    AssertEquals(0.0, States.GetCurrentVolume(MAX_DISPENSER_VALUE), 0.001);
  finally
    States.Free;
  end;
end;

procedure TDispenserRuntimeStateTests.ResetClearsEveryAddressAndOperationField;
var
  States: TDispenserRuntimeStates;
  Address: Integer;
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
  ErrorText: string;
begin
  States := TDispenserRuntimeStates.Create;
  try
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      State := States.Items[Address];
      Config := TDispenserConfig.Create;
      Config.Number := Address;
      Config.Name := 'Pump';
      Config.Address := Address;
      Config.Volume := 1000;
      Config.ChannelCount := 4;
      Config.StepCount := 10000;
      Config.IntakeChannel := 1;
      Config.MaxFlowRate := 12;
      Config.Operation.Speed := 1;
      State.MarkInitialized(Config);
      Config.Free;
      State.CurrentVolume := Address * 10;
      State.ValveType := dvtNonDistributive;
      State.CommandPending := True;
      State.ProtocolReserved := True;
      AssertTrue(State.TryBeginOperation(dooProtocol, dokDispense,
        'operation', Address, 1, State.CurrentPositionSteps, ErrorText));
    end;

    States.Reset;

    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      State := States.Items[Address];
      AssertEquals(0.0, State.CurrentVolume, 0.001);
      AssertFalse(State.CurrentVolumeKnown);
      AssertEquals(Ord(dvtUnknown), Ord(State.ValveType));
      AssertFalse(State.OperationActive);
      AssertEquals(Ord(dooNone), Ord(State.OperationOwner));
      AssertFalse(State.CommandPending);
      AssertFalse(State.ProtocolReserved);
      AssertEquals(Ord(dokFill), Ord(State.OperationKind));
      AssertEquals('', State.OperationName);
      AssertEquals(0, State.OperationVolume);
      AssertEquals(0.0, State.OperationStartingVolume, 0.001);
    end;
  finally
    States.Free;
  end;
end;

initialization
  RegisterTest(TDispenserRuntimeStateTests);

end.
