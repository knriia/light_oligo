unit ProtocolStartPlanTests;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Contnrs, fpcunit, testregistry, DispenserConfig, DispenserLimits,
  DispenserRuntimeState, DispenserTypes, AutomationProtocol,
  ProtocolStartPlan;

type
  TProtocolStartPlanTests = class(TTestCase)
  private
    FStates: TDispenserRuntimeStates;
    FProtocol: TAutomationProtocol;
    FConfigs: TObjectList;
    function MakeConfig(AAddress: Integer): TDispenserConfig;
    procedure AddCommand(const AConfigs: array of TDispenserConfig);
    procedure MarkInitialized(AConfig: TDispenserConfig);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InitializedDispenserNeedsNoInitialization;
    procedure UninitializedDispenserIsPlannedForInitialization;
    procedure ChangedConfigurationNeedsInitialization;
    procedure RepeatedAddressIsPlannedOnce;
    procedure BusyOperationRejectsPlan;
    procedure PendingCommandRejectsPlan;
    procedure ReservedDispenserRejectsPlan;
    procedure MissingStateRejectsPlan;
    procedure PauseOnlyProtocolHasEmptyPlan;
    procedure TakeInitializationTargetsTransfersOwnership;
    procedure TargetsAreClones;
    procedure SameAddressWithDifferentConfigsUsesFirst;
    procedure TwoTargetsInOneCommandArePlanned;
    procedure MixedInitializationKeepsOrder;
    procedure UnknownPositionNeedsInitialization;
    procedure BusySecondTargetRejectsWholePlan;
    procedure RejectedPlanHasEmptyLists;
  end;

implementation

procedure TProtocolStartPlanTests.SetUp;
begin
  inherited SetUp;
  FStates := TDispenserRuntimeStates.Create;
  FProtocol := TAutomationProtocol.Create;
  FConfigs := TObjectList.Create(True);
end;

procedure TProtocolStartPlanTests.TearDown;
begin
  FProtocol.Free;
  FConfigs.Free;
  FStates.Free;
  inherited TearDown;
end;

function TProtocolStartPlanTests.MakeConfig(
  AAddress: Integer): TDispenserConfig;
begin
  Result := TDispenserConfig.Create;
  Result.Number := AAddress;
  Result.Name := 'Pump ' + IntToStr(AAddress);
  Result.Address := AAddress;
  Result.Volume := 1000;
  Result.ChannelCount := 4;
  Result.StepCount := 10000;
  Result.IntakeChannel := 1;
  Result.MaxFlowRate := 12;
  FConfigs.Add(Result);
end;

procedure TProtocolStartPlanTests.AddCommand(
  const AConfigs: array of TDispenserConfig);
var
  Command: TAutomationProtocolCommand;
  I: Integer;
begin
  Command := TAutomationProtocolCommand.Create;
  Command.Number := FProtocol.Count + 1;
  SetLength(Command.Targets, Length(AConfigs));
  for I := 0 to High(AConfigs) do
    Command.Targets[I].Config := AConfigs[I];
  FProtocol.Add(Command);
end;

procedure TProtocolStartPlanTests.MarkInitialized(AConfig: TDispenserConfig);
begin
  FStates.Items[AConfig.Address].MarkInitialized(AConfig);
end;

procedure TProtocolStartPlanTests.InitializedDispenserNeedsNoInitialization;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  MarkInitialized(Config);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.Targets.Count);
    AssertEquals(0, Plan.InitializationTargets.Count);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.UninitializedDispenserIsPlannedForInitialization;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.Targets.Count);
    AssertEquals(1, Plan.InitializationTargets.Count);
    AssertEquals(1, Plan.InitializationTargets[0].Address);
    AssertEquals(1, Plan.InitializationDescriptions.Count);
    AssertEquals('- Pump 1 (адрес 1)', Plan.InitializationDescriptions[0]);
    AssertTrue(Plan.InitializationTargets[0] <> Config);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.ChangedConfigurationNeedsInitialization;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  MarkInitialized(Config);
  Config.Volume := 2000;
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.InitializationTargets.Count);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.RepeatedAddressIsPlannedOnce;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  AddCommand([Config]);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.Targets.Count);
    AssertEquals(1, Plan.InitializationTargets.Count);
    AssertEquals(1, Plan.InitializationDescriptions.Count);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.BusyOperationRejectsPlan;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
  Error: string;
begin
  Config := MakeConfig(1);
  MarkInitialized(Config);
  AssertTrue(FStates.Items[1].TryBeginOperation(dooManual, dokFill,
    Config.Name, 100, 1000, 0, Error));
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsDispenserBusy);
    AssertEquals('Pump 1: дозатор сейчас выполняет другую команду.',
      Plan.ErrorText);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.PendingCommandRejectsPlan;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(2);
  FStates.Items[2].CommandPending := True;
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsDispenserBusy);
    AssertEquals('Pump 2: дозатор сейчас выполняет другую команду.',
      Plan.ErrorText);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.ReservedDispenserRejectsPlan;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(3);
  FStates.Items[3].ProtocolReserved := True;
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsDispenserBusy);
    AssertEquals('Pump 3: дозатор сейчас выполняет другую команду.',
      Plan.ErrorText);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.MissingStateRejectsPlan;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(MAX_DISPENSER_VALUE + 1);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsStateUnavailable);
    AssertEquals('Pump ' + IntToStr(MAX_DISPENSER_VALUE + 1) +
      ': не удалось получить состояние дозатора.', Plan.ErrorText);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.PauseOnlyProtocolHasEmptyPlan;
var
  Plan: TProtocolStartPlan;
begin
  AddCommand([]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(0, Plan.Targets.Count);
    AssertEquals(0, Plan.InitializationTargets.Count);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.TakeInitializationTargetsTransfersOwnership;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
  Taken: TDispenserConfigList;
begin
  Config := MakeConfig(1);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    Taken := Plan.TakeInitializationTargets;
    try
      AssertEquals(1, Taken.Count);
      AssertTrue(Plan.InitializationTargets = nil);
      AssertEquals(1, Plan.Targets.Count);
    finally
      Taken.Free;
    end;
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.TargetsAreClones;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertEquals(1, Plan.Targets.Count);
    AssertTrue(Plan.Targets[0] <> Config);
    AssertEquals(1, Plan.Targets[0].Address);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.SameAddressWithDifferentConfigsUsesFirst;
var
  First: TDispenserConfig;
  Second: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  First := MakeConfig(1);
  Second := MakeConfig(1);
  Second.Name := 'Other';
  AddCommand([First]);
  AddCommand([Second]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.Targets.Count);
    AssertEquals('Pump 1', Plan.Targets[0].Name);
    AssertEquals('- Pump 1 (адрес 1)', Plan.InitializationDescriptions[0]);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.TwoTargetsInOneCommandArePlanned;
var
  A: TDispenserConfig;
  B: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  A := MakeConfig(1);
  B := MakeConfig(2);
  AddCommand([A, B]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(2, Plan.Targets.Count);
    AssertEquals(1, Plan.Targets[0].Address);
    AssertEquals(2, Plan.Targets[1].Address);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.MixedInitializationKeepsOrder;
var
  A: TDispenserConfig;
  B: TDispenserConfig;
  C: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  A := MakeConfig(1);
  B := MakeConfig(2);
  C := MakeConfig(3);
  MarkInitialized(B);
  AddCommand([A, B]);
  AddCommand([C]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(3, Plan.Targets.Count);
    AssertEquals(2, Plan.InitializationTargets.Count);
    AssertEquals(1, Plan.InitializationTargets[0].Address);
    AssertEquals(3, Plan.InitializationTargets[1].Address);
    AssertEquals('- Pump 1 (адрес 1)', Plan.InitializationDescriptions[0]);
    AssertEquals('- Pump 3 (адрес 3)', Plan.InitializationDescriptions[1]);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.UnknownPositionNeedsInitialization;
var
  Config: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  Config := MakeConfig(1);
  MarkInitialized(Config);
  FStates.Items[1].MarkPositionUnknown('потеря позиции');
  AddCommand([Config]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsReady);
    AssertEquals(1, Plan.InitializationTargets.Count);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.BusySecondTargetRejectsWholePlan;
var
  A: TDispenserConfig;
  B: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  A := MakeConfig(1);
  B := MakeConfig(2);
  FStates.Items[2].CommandPending := True;
  AddCommand([A, B]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status = ppsDispenserBusy);
    AssertEquals('Pump 2: дозатор сейчас выполняет другую команду.',
      Plan.ErrorText);
  finally
    Plan.Free;
  end;
end;

procedure TProtocolStartPlanTests.RejectedPlanHasEmptyLists;
var
  A: TDispenserConfig;
  B: TDispenserConfig;
  Plan: TProtocolStartPlan;
begin
  A := MakeConfig(1);
  B := MakeConfig(2);
  FStates.Items[2].ProtocolReserved := True;
  AddCommand([A, B]);
  Plan := PlanProtocolStart(FProtocol, FStates);
  try
    AssertTrue(Plan.Status <> ppsReady);
    AssertEquals(0, Plan.Targets.Count);
    AssertEquals(0, Plan.InitializationTargets.Count);
    AssertEquals(0, Plan.InitializationDescriptions.Count);
  finally
    Plan.Free;
  end;
end;

initialization
  RegisterTest(TProtocolStartPlanTests);
end.
