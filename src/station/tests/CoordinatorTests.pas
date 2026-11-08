unit CoordinatorTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DispenserConfig,
  DispenserConnectionCoordinator, DispenserController,
  DispenserOperationCoordinator,
  DispenserRuntimeState, DispenserTypes, DispenserLimits;

type
  TMockDispenserController = class(TDispenserController)
  private
    function CallSucceeded(DefaultResult: Boolean; CallIndex,
      FailAtCall: Integer): Boolean;
  protected
    function GetIsConnected: Boolean; override;
    function GetIsReady: Boolean; override;
    function GetLastError: string; override;
  public
    Ready: Boolean;
    Connected: Boolean;
    ConnectResult: Boolean;
    QueryStatusResult: Boolean;
    QueryStatusValue: Byte;
    QueryQuietResult: Boolean;
    QueryEncoderResult: Boolean;
    MovementEncoderAdjustmentSteps: Integer;
    QuietStatusValues: array[0..15] of Byte;
    RuntimeStates: TDispenserRuntimeStates;
    FailQueryEncoderAtCall: Integer;
    InitializeValveResult: Boolean;
    WaitForIdleResult: Boolean;
    InitializePlungerResult: Boolean;
    SetFinePositioningModeResult: Boolean;
    DetectValveTypeResult: Boolean;
    ValveTypeToDetect: TDispenserValveType;
    ExecuteMovementResult: Boolean;
    ChangeMovementSpeedResult: Boolean;
    TerminateMovementResult: Boolean;
    FailQueryAtCall: Integer;
    FailQuietAtCall: Integer;
    FailInitializeValveAtCall: Integer;
    FailWaitForIdleAtCall: Integer;
    FailInitializePlungerAtCall: Integer;
    FailSetFinePositioningModeAtCall: Integer;
    FailDetectValveTypeAtCall: Integer;
    FailExecuteMovementAtCall: Integer;
    FailChangeMovementSpeedAtCall: Integer;
    FailTerminateMovementAtCall: Integer;
    LastErrorText: string;
    ConnectCalls: Integer;
    DisconnectCalls: Integer;
    QueryStatusCalls: Integer;
    QueryQuietCalls: Integer;
    QueryEncoderCalls: Integer;
    InitializeValveCalls: Integer;
    WaitForIdleCalls: Integer;
    InitializePlungerCalls: Integer;
    SetFinePositioningModeCalls: Integer;
    DetectValveTypeCalls: Integer;
    ExecuteMovementCalls: Integer;
    ChangeMovementSpeedCalls: Integer;
    TerminateMovementCalls: Integer;
    LastPolledAddress: Integer;
    LastMovementAddress: Integer;
    LastMovementChannel: Integer;
    LastMovementSteps: Integer;
    LastMovementSpeed: Integer;
    LastChangedMotorSpeed: Integer;
    LastTerminatedAddress: Integer;
    LastMovementAspirate: Boolean;
    NextEncoderPositionSteps: array[MIN_DISPENSER_VALUE..
      MAX_DISPENSER_VALUE] of Int64;
    EncoderMovementPending: array[MIN_DISPENSER_VALUE..
      MAX_DISPENSER_VALUE] of Boolean;
    ValveCallsAtFirstQuiet: Integer;
    PlungerCallsAtFirstPlungerPoll: Integer;

    constructor Create;
    function Connect(const APortName: string): Boolean; override;
    procedure Disconnect; override;
    function QueryStatus(Address: Integer; out StatusCode: Byte): Boolean; override;
    function QueryStatusWithoutDetails(Address: Integer;
      out StatusCode: Byte): Boolean; override;
    function QueryStatusQuiet(Address: Integer; out StatusCode: Byte): Boolean; override;
    function QueryPlungerEncoderPosition(Address: Integer;
      out PositionSteps: Int64): Boolean; override;
    function DetectValveType(Address: Integer;
      out AValveType: TDispenserValveType): Boolean; override;
    function InitializeValve(Address, IntakeChannel: Integer): Boolean; override;
    function InitializePlunger(Address: Integer): Boolean; override;
    function SetFinePositioningMode(Address: Integer): Boolean; override;
    function ExecuteMovement(Address, Channel, Steps, Speed: Integer;
      AAspirate: Boolean; AValveType: TDispenserValveType): Boolean; override;
    function ChangeMovementSpeed(Address, Speed: Integer): Boolean; override;
    function TerminateMovement(Address: Integer): Boolean; override;
    function WaitForIdle(Address: Integer; AllowNotInitialized: Boolean;
      const PhaseName: string; LogReady: Boolean = True;
      TimeoutMs: QWord = INITIALIZE_TIMEOUT_MS): Boolean; override;
  end;

  TDispenserOperationCoordinatorTests = class(TTestCase)
  private
    FController: TMockDispenserController;
    FStates: TDispenserRuntimeStates;
    FConfig: TDispenserConfig;
    FLogs: TStringList;
    FChangedAddresses: TStringList;
    FFailureMessages: TStringList;
    FFailureSaveFlags: TStringList;
    procedure BeginMockOperation(AAddress: Integer;
      AOwner: TDispenserOperationOwner; const AName: string);
    procedure CaptureLog(const Msg: string);
    procedure CaptureStateChanged(Address: Integer);
    procedure CaptureFailure(Address: Integer; const MessageText: string;
      UpdateAndSaveVolume: Boolean);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure RejectsUnavailableAndInvalidRequests;
    procedure RejectsBusyAndInvalidPlans;
    procedure AllowsAnotherDispenserWhileOneIsRunning;
    procedure PollSkipsProtocolAndPendingDispenserOperations;
    procedure StartsSingleAndCompletesAspirate;
    procedure StopMarksVolumeUnknownAndRequiresInitialization;
    procedure FailedStopKeepsVolumeUnknownAfterOperationCompletes;
    procedure RejectsStopWhenNoOperationIsActive;
    procedure SpeedChangedDuringOperationAppliesImmediatelyAndNextMovement;
    procedure RejectsLiveSpeedChangeWhenDeviceRejectsIt;
    procedure ConvertsAndSendsHighLiveSpeedFromMicrolitersPerSecond;
    procedure ReportsSingleCommandFailure;
    procedure HandlesFailuresWithoutOptionalCallbacks;
    procedure RejectsGroupRequestsBeforeSendingCommands;
    procedure RejectsDuplicateAddressesBeforeStartingGroup;
    procedure StartsGroupAndPollsAddressesRoundRobin;
    procedure StopsEarlierGroupStartsWhenLaterCommandFails;
    procedure StopAllContinuesAfterOneDispenserRejectsStop;
    procedure PollFailuresMarkVolumeUnknown;
    procedure PollDoesNothingWithoutActiveOperations;
    procedure CompletesEveryOperationKind;
    procedure TracksStepsAcrossRepeatedSmallAspirateAndDispenseOperations;
    procedure EncoderFeedbackRecordsMeasuredMovement;
    procedure EncoderQueryFailurePreventsMovementAndInvalidatesPosition;
    procedure StartGroupRejectsMissingDependenciesAndBusyState;
    procedure PollWrapsFromMaximumAddressAndReportsUnnamedFailure;
  end;

  TDispenserConnectionCoordinatorTests = class(TTestCase)
  private
    FController: TMockDispenserController;
    FStates: TDispenserRuntimeStates;
    FConfigurations: TDispenserConfigList;
    FLogs: TStringList;
    procedure CaptureLog(const Msg: string);
    procedure AddConfiguration(ANumber, AAddress: Integer);
    function CompleteInitialization(
      Coordinator: TDispenserConnectionCoordinator;
      Configurations: TDispenserConfigList; Failures: TStrings): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ConnectOnlyOpensPortWithoutInitializingDevices;
    procedure RejectsInvalidRequests;
    procedure ReportsPortOpenFailure;
    procedure AbortsWhenStatusQueryFailsOrDeviceReportsError;
    procedure AbortsWhenDeviceIsBusy;
    procedure AllowsNotInitializedStatusDuringConnection;
    procedure AbortsAtEveryInitializationPhase;
    procedure InitializesAllDevicesAndMarksEmptyVolumeKnown;
    procedure InitializeDispensersStartsEachMotorPhaseForAllDevices;
    procedure AllowsAnotherAddressToInitializeWhileFirstIsActive;
    procedure InitializationPollAdvancesWithoutWaitingForIdle;
    procedure InitializeDispensersKeepsSuccessfulDevicesWhenOneFails;
    procedure DisconnectResetsControllerAndRuntimeState;
  end;

implementation

function TMockDispenserController.CallSucceeded(DefaultResult: Boolean;
  CallIndex, FailAtCall: Integer): Boolean;
begin
  Result := DefaultResult and ((FailAtCall = 0) or (CallIndex <> FailAtCall));
end;

constructor TMockDispenserController.Create;
var
  I: Integer;
begin
  inherited Create;
  Ready := False;
  Connected := False;
  ConnectResult := True;
  QueryStatusResult := True;
  QueryStatusValue := STATUS_READY_MASK;
  QueryQuietResult := True;
  QueryEncoderResult := True;
  for I := Low(QuietStatusValues) to High(QuietStatusValues) do
    QuietStatusValues[I] := STATUS_READY_MASK;
  InitializeValveResult := True;
  WaitForIdleResult := True;
  InitializePlungerResult := True;
  SetFinePositioningModeResult := True;
  DetectValveTypeResult := True;
  ValveTypeToDetect := dvtDistributive;
  ExecuteMovementResult := True;
  ChangeMovementSpeedResult := True;
  TerminateMovementResult := True;
  LastErrorText := 'mock controller error';
end;

function TMockDispenserController.GetIsConnected: Boolean;
begin
  Result := Connected;
end;

function TMockDispenserController.GetIsReady: Boolean;
begin
  Result := Ready;
end;

function TMockDispenserController.GetLastError: string;
begin
  Result := LastErrorText;
end;

function TMockDispenserController.Connect(const APortName: string): Boolean;
begin
  Inc(ConnectCalls);
  Result := ConnectResult;
  Connected := Result;
end;

procedure TMockDispenserController.Disconnect;
begin
  Inc(DisconnectCalls);
  Connected := False;
  Ready := False;
end;

function TMockDispenserController.QueryStatus(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  Inc(QueryStatusCalls);
  StatusCode := QueryStatusValue;
  Result := CallSucceeded(QueryStatusResult, QueryStatusCalls,
    FailQueryAtCall);
  if Result then
    Ready := ((StatusCode and STATUS_READY_MASK) <> 0) and
      ((StatusCode and STATUS_ERROR_MASK) = 0);
end;

function TMockDispenserController.QueryStatusWithoutDetails(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  Result := QueryStatus(Address, StatusCode);
end;

function TMockDispenserController.QueryStatusQuiet(Address: Integer;
  out StatusCode: Byte): Boolean;
var
  Index: Integer;
begin
  Inc(QueryQuietCalls);
  LastPolledAddress := Address;
  Index := QueryQuietCalls;
  if QueryQuietCalls = 1 then
    ValveCallsAtFirstQuiet := InitializeValveCalls;
  if QueryQuietCalls = 3 then
    PlungerCallsAtFirstPlungerPoll := InitializePlungerCalls;
  if Index > High(QuietStatusValues) then
    Index := High(QuietStatusValues);
  StatusCode := QuietStatusValues[Index];
  Result := CallSucceeded(QueryQuietResult, QueryQuietCalls,
    FailQuietAtCall);
end;

function TMockDispenserController.QueryPlungerEncoderPosition(
  Address: Integer; out PositionSteps: Int64): Boolean;
begin
  Inc(QueryEncoderCalls);
  if EncoderMovementPending[Address] then
  begin
    PositionSteps := NextEncoderPositionSteps[Address];
    EncoderMovementPending[Address] := False;
  end
  else if RuntimeStates <> nil then
    PositionSteps := RuntimeStates.GetCurrentPositionSteps(Address)
  else
    PositionSteps := 0;
  Result := CallSucceeded(QueryEncoderResult, QueryEncoderCalls,
    FailQueryEncoderAtCall);
  if Result then
    LastErrorText := ''
  else
    LastErrorText := 'mock encoder query failure';
end;

function TMockDispenserController.DetectValveType(Address: Integer;
  out AValveType: TDispenserValveType): Boolean;
begin
  Inc(DetectValveTypeCalls);
  Result := CallSucceeded(DetectValveTypeResult, DetectValveTypeCalls,
    FailDetectValveTypeAtCall);
  AValveType := ValveTypeToDetect;
end;

function TMockDispenserController.InitializeValve(Address,
  IntakeChannel: Integer): Boolean;
begin
  Inc(InitializeValveCalls);
  Result := CallSucceeded(InitializeValveResult, InitializeValveCalls,
    FailInitializeValveAtCall);
end;

function TMockDispenserController.InitializePlunger(Address: Integer): Boolean;
begin
  Inc(InitializePlungerCalls);
  Result := CallSucceeded(InitializePlungerResult, InitializePlungerCalls,
    FailInitializePlungerAtCall);
end;

function TMockDispenserController.SetFinePositioningMode(
  Address: Integer): Boolean;
begin
  Inc(SetFinePositioningModeCalls);
  Result := CallSucceeded(SetFinePositioningModeResult,
    SetFinePositioningModeCalls, FailSetFinePositioningModeAtCall);
end;

function TMockDispenserController.ExecuteMovement(Address, Channel, Steps,
  Speed: Integer; AAspirate: Boolean;
  AValveType: TDispenserValveType): Boolean;
begin
  Inc(ExecuteMovementCalls);
  LastMovementAddress := Address;
  LastMovementChannel := Channel;
  LastMovementSteps := Steps;
  LastMovementSpeed := Speed;
  LastMovementAspirate := AAspirate;
  Result := CallSucceeded(ExecuteMovementResult, ExecuteMovementCalls,
    FailExecuteMovementAtCall);
  if Result then
  begin
    if RuntimeStates <> nil then
      NextEncoderPositionSteps[Address] :=
        RuntimeStates.GetCurrentPositionSteps(Address)
    else
      NextEncoderPositionSteps[Address] := 0;
    if AAspirate then
      Inc(NextEncoderPositionSteps[Address], Steps)
    else
      Dec(NextEncoderPositionSteps[Address], Steps);
    Inc(NextEncoderPositionSteps[Address],
      MovementEncoderAdjustmentSteps);
    EncoderMovementPending[Address] := True;
  end;
end;

function TMockDispenserController.ChangeMovementSpeed(Address,
  Speed: Integer): Boolean;
begin
  Inc(ChangeMovementSpeedCalls);
  LastChangedMotorSpeed := Speed;
  Result := CallSucceeded(ChangeMovementSpeedResult, ChangeMovementSpeedCalls,
    FailChangeMovementSpeedAtCall);
end;

function TMockDispenserController.TerminateMovement(Address: Integer): Boolean;
begin
  Inc(TerminateMovementCalls);
  LastTerminatedAddress := Address;
  Result := CallSucceeded(TerminateMovementResult, TerminateMovementCalls,
    FailTerminateMovementAtCall);
end;

function TMockDispenserController.WaitForIdle(Address: Integer;
  AllowNotInitialized: Boolean; const PhaseName: string; LogReady: Boolean;
  TimeoutMs: QWord): Boolean;
begin
  Inc(WaitForIdleCalls);
  Result := CallSucceeded(WaitForIdleResult, WaitForIdleCalls,
    FailWaitForIdleAtCall);
end;

procedure TDispenserOperationCoordinatorTests.SetUp;
begin
  inherited SetUp;
  FController := TMockDispenserController.Create;
  FController.Connected := True;
  FController.Ready := True;
  FStates := TDispenserRuntimeStates.Create;
  FController.RuntimeStates := FStates;
  FConfig := TDispenserConfig.Create;
  FConfig.Name := 'Pump A';
  FConfig.Address := 1;
  FConfig.Volume := 1000;
  FConfig.ChannelCount := 4;
  FConfig.StepCount := 10000;
  FConfig.IntakeChannel := 1;
  FConfig.MaxFlowRate := 12;
  FConfig.Operation.Volume := 100;
  FConfig.Operation.Speed := 10;
  FConfig.Operation.Channel := 2;
  FStates.Items[FConfig.Address].MarkInitialized(FConfig);
  FStates.SetCurrentVolume(FConfig.Address, 250);
  FLogs := TStringList.Create;
  FChangedAddresses := TStringList.Create;
  FFailureMessages := TStringList.Create;
  FFailureSaveFlags := TStringList.Create;
end;

procedure TDispenserOperationCoordinatorTests.TearDown;
begin
  FFailureSaveFlags.Free;
  FFailureMessages.Free;
  FChangedAddresses.Free;
  FLogs.Free;
  FConfig.Free;
  FStates.Free;
  FController.Free;
  inherited TearDown;
end;

procedure TDispenserOperationCoordinatorTests.CaptureLog(const Msg: string);
begin
  FLogs.Add(Msg);
end;

procedure TDispenserOperationCoordinatorTests.CaptureStateChanged(
  Address: Integer);
begin
  FChangedAddresses.Add(IntToStr(Address));
end;

procedure TDispenserOperationCoordinatorTests.CaptureFailure(Address: Integer;
  const MessageText: string; UpdateAndSaveVolume: Boolean);
begin
  FFailureMessages.Add(IntToStr(Address) + ':' + MessageText);
  if UpdateAndSaveVolume then
    FFailureSaveFlags.Add('save')
  else
    FFailureSaveFlags.Add('no-save');
end;

procedure TDispenserOperationCoordinatorTests.BeginMockOperation(
  AAddress: Integer; AOwner: TDispenserOperationOwner; const AName: string);
var
  State: TDispenserRuntimeState;
  Config: TDispenserConfig;
  ErrorText: string;
begin
  State := FStates.Items[AAddress];
  AssertNotNull(State);
  Config := FConfig.Clone;
  try
    Config.Number := AAddress;
    Config.Address := AAddress;
    Config.Name := 'Pump ' + IntToStr(AAddress);
    if State.LifecycleState in [dlsUninitialized, dlsPositionUnknown] then
      State.MarkInitialized(Config);
  finally
    Config.Free;
  end;

  AssertTrue(State.TryBeginOperation(AOwner, dokAspirate, AName, 1, 1,
    State.CurrentPositionSteps, ErrorText));
end;

procedure TDispenserOperationCoordinatorTests.RejectsUnavailableAndInvalidRequests;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
begin
  Coordinator := TDispenserOperationCoordinator.Create(nil, FStates);
  try
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    AssertTrue(ErrorText <> '');
  finally
    Coordinator.Free;
  end;

  FController.Connected := False;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
  finally
    Coordinator.Free;
  end;

  FController.Connected := True;
  Coordinator := TDispenserOperationCoordinator.Create(FController, nil);
  try
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
  finally
    Coordinator.Free;
  end;

  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(nil,
      dokFill, 1, False, ErrorText)));
    FConfig.Address := MAX_DISPENSER_VALUE + 1;
    AssertEquals(Ord(dosrBusy), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.RejectsBusyAndInvalidPlans;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    BeginMockOperation(FConfig.Address, dooManual, FConfig.Name);
    AssertEquals(Ord(dosrBusy), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    FStates.Items[FConfig.Address].ClearOperation;

    FStates.MarkCurrentVolumeUnknown(FConfig.Address);
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    FStates.SetCurrentVolume(FConfig.Address, FConfig.Volume);
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    FStates.SetCurrentVolume(FConfig.Address, 250);
    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, True, ErrorText)));
    AssertEquals(0, FController.ExecuteMovementCalls);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.AllowsAnotherDispenserWhileOneIsRunning;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  SecondConfig: TDispenserConfig;
begin
  SecondConfig := FConfig.Clone;
  try
    SecondConfig.Number := 2;
    SecondConfig.Address := 2;
    SecondConfig.Name := 'Pump B';
    FStates.Items[SecondConfig.Address].MarkInitialized(SecondConfig);
    FStates.SetCurrentVolume(SecondConfig.Address, 100);

    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
        dokAspirate, 2, False, ErrorText)));
      AssertTrue(FStates.Items[FConfig.Address].OperationActive);

      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(SecondConfig,
        dokAspirate, 2, False, ErrorText)));
      AssertTrue(FStates.Items[SecondConfig.Address].OperationActive);
      AssertEquals(2, FController.ExecuteMovementCalls);

      AssertEquals(Ord(dosrBusy), Ord(Coordinator.StartSingle(FConfig,
        dokAspirate, 2, False, ErrorText)));
      AssertTrue(ErrorText = '');
      AssertEquals(2, FController.ExecuteMovementCalls);
    finally
      Coordinator.Free;
    end;
  finally
    SecondConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.PollSkipsProtocolAndPendingDispenserOperations;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  SecondConfig: TDispenserConfig;
  ProtocolState: TDispenserRuntimeState;
  ManualState: TDispenserRuntimeState;
begin
  SecondConfig := FConfig.Clone;
  try
    SecondConfig.Number := 2;
    SecondConfig.Address := 2;
    SecondConfig.Name := 'Pump B';
    FStates.Items[SecondConfig.Address].MarkInitialized(SecondConfig);
    FStates.SetCurrentVolume(SecondConfig.Address, 100);

    ProtocolState := FStates.Items[FConfig.Address];
    BeginMockOperation(FConfig.Address, dooProtocol, 'protocol');
    ManualState := FStates.Items[SecondConfig.Address];

    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(SecondConfig,
        dokAspirate, 2, False, ErrorText)));
      ManualState.CommandPending := True;

      AssertTrue(Coordinator.HasActiveOperations);
      Coordinator.PollNextOperation;
      AssertEquals(0, FController.QueryQuietCalls);

      ManualState.CommandPending := False;
      AssertTrue(Coordinator.HasActiveOperations);
      Coordinator.PollNextOperation;
      AssertEquals(SecondConfig.Address, FController.LastPolledAddress);
      AssertFalse(ManualState.OperationActive);
      AssertTrue(ProtocolState.OperationActive);
      AssertEquals(1, FController.QueryQuietCalls);
    finally
      Coordinator.Free;
      ProtocolState.ClearOperation;
    end;
  finally
    SecondConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StartsSingleAndCompletesAspirate;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    Coordinator.OnLogMessage := @CaptureLog;
    Coordinator.OnStateChanged := @CaptureStateChanged;
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals('', ErrorText);
    AssertEquals(1, FController.ExecuteMovementCalls);
    AssertEquals(FConfig.Address, FController.LastMovementAddress);
    AssertEquals(3, FController.LastMovementChannel);
    AssertEquals(8000, FController.LastMovementSteps);
    AssertEquals(100, FController.LastMovementSpeed);
    AssertTrue(FController.LastMovementAspirate);

    State := FStates.Items[FConfig.Address];
    AssertTrue(State.OperationActive);
    AssertEquals(Ord(dokAspirate), Ord(State.OperationKind));
    AssertEquals(100, State.OperationVolume);
    AssertEquals(250.0, State.OperationStartingVolume, 0.001);
    AssertTrue(Coordinator.HasActiveOperations);

    Coordinator.PollNextOperation;
    AssertFalse(State.OperationActive);
    AssertTrue(State.CurrentVolumeKnown);
    AssertEquals(350.0, State.CurrentVolume, 0.001);
    AssertEquals(2, FChangedAddresses.Count);
    AssertEquals(3, FLogs.Count);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StopMarksVolumeUnknownAndRequiresInitialization;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    State := FStates.Items[FConfig.Address];
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals(1, FController.ExecuteMovementCalls);
    AssertTrue(State.OperationActive);

    AssertTrue(Coordinator.StopActiveOperation(FConfig.Address, ErrorText));
    AssertEquals('', ErrorText);
    AssertEquals(1, FController.TerminateMovementCalls);
    AssertEquals(FConfig.Address, FController.LastTerminatedAddress);
    AssertFalse(State.OperationActive);
    AssertTrue(State.InitializationRequired);
    AssertFalse(State.CurrentVolumeKnown);
    AssertFalse(Coordinator.HasActiveOperations);

    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertTrue(ErrorText <> '');
    AssertEquals(1, FController.ExecuteMovementCalls);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.FailedStopKeepsVolumeUnknownAfterOperationCompletes;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    State := FStates.Items[FConfig.Address];
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    FController.TerminateMovementResult := False;

    AssertFalse(Coordinator.StopActiveOperation(FConfig.Address, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(State.OperationActive);
    AssertTrue(State.InitializationRequired);
    AssertFalse(State.CurrentVolumeKnown);

    Coordinator.PollNextOperation;
    AssertFalse(State.OperationActive);
    AssertTrue(State.InitializationRequired);
    AssertFalse(State.CurrentVolumeKnown);
    AssertEquals(250.0, State.CurrentVolume, 0.001);

    AssertEquals(Ord(dosrRejected), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals(1, FController.ExecuteMovementCalls);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.RejectsStopWhenNoOperationIsActive;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertFalse(Coordinator.StopActiveOperation(FConfig.Address, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertEquals(0, FController.TerminateMovementCalls);
    AssertTrue(FStates.Items[FConfig.Address].IsInitializedFor(FConfig));
    AssertTrue(FStates.IsCurrentVolumeKnown(FConfig.Address));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.SpeedChangedDuringOperationAppliesImmediatelyAndNextMovement;
var
  Coordinator: TDispenserOperationCoordinator;
  State: TDispenserRuntimeState;
  ErrorText: string;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    State := FStates.Items[FConfig.Address];
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals(100, FController.LastMovementSpeed);
    AssertTrue(State.OperationActive);

    // Editing the configured rate sends a V command to the active movement.
    FConfig.Operation.Speed := 11;
    AssertTrue(Coordinator.ChangeActiveSpeed(FConfig,
      FConfig.Operation.Speed, ErrorText));
    AssertEquals(1, FController.ChangeMovementSpeedCalls);
    AssertEquals(110, FController.LastChangedMotorSpeed);
    AssertEquals(1, FController.ExecuteMovementCalls);
    AssertEquals(100, FController.LastMovementSpeed);

    Coordinator.PollNextOperation;
    AssertFalse(State.OperationActive);
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals(2, FController.ExecuteMovementCalls);
    AssertEquals(110, FController.LastMovementSpeed);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.RejectsLiveSpeedChangeWhenDeviceRejectsIt;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    State := FStates.Items[FConfig.Address];
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    FController.ChangeMovementSpeedResult := False;

    FConfig.Operation.Speed := 11;
    AssertFalse(Coordinator.ChangeActiveSpeed(FConfig,
      FConfig.Operation.Speed, ErrorText));
    AssertEquals(1, FController.ChangeMovementSpeedCalls);
    AssertEquals(110, FController.LastChangedMotorSpeed);
    AssertTrue(ErrorText <> '');
    AssertTrue(State.OperationActive);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.ConvertsAndSendsHighLiveSpeedFromMicrolitersPerSecond;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  FConfig.MaxFlowRate := 600;
  FConfig.Operation.Speed := 200;
  FStates.Items[FConfig.Address].MarkInitialized(FConfig);
  FStates.SetCurrentVolume(FConfig.Address, 250);
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    State := FStates.Items[FConfig.Address];
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    FConfig.Operation.Speed := 480;
    AssertTrue(Coordinator.ChangeActiveSpeed(FConfig,
      FConfig.Operation.Speed, ErrorText));
    AssertEquals(1, FController.ChangeMovementSpeedCalls);
    AssertEquals(4800, FController.LastChangedMotorSpeed);
    AssertTrue(State.OperationActive);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.ReportsSingleCommandFailure;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  FController.ExecuteMovementResult := False;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    Coordinator.OnFailure := @CaptureFailure;
    Coordinator.OnStateChanged := @CaptureStateChanged;
    AssertEquals(Ord(dosrCommandFailed), Ord(Coordinator.StartSingle(FConfig,
      dokDispense, 2, False, ErrorText)));
    State := FStates.Items[FConfig.Address];
    AssertFalse(State.OperationActive);
    AssertFalse(State.CurrentVolumeKnown);
    AssertEquals(1, FFailureMessages.Count);
    AssertEquals('save', FFailureSaveFlags[0]);
    AssertEquals(1, FChangedAddresses.Count);
    AssertFalse(Coordinator.HasActiveOperations);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.HandlesFailuresWithoutOptionalCallbacks;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  State := FStates.Items[FConfig.Address];
  FController.ExecuteMovementResult := False;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrCommandFailed), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    AssertFalse(State.OperationActive);
    AssertFalse(State.CurrentVolumeKnown);
  finally
    Coordinator.Free;
  end;

  FController.ExecuteMovementResult := True;
  FController.QueryQuietResult := False;
  FStates.Items[FConfig.Address].MarkInitialized(FConfig);
  FStates.SetCurrentVolume(FConfig.Address, 250);
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    Coordinator.PollNextOperation;
    AssertFalse(State.OperationActive);
    AssertFalse(State.CurrentVolumeKnown);
  finally
    Coordinator.Free;
    FController.QueryQuietResult := True;
  end;
end;

procedure TDispenserOperationCoordinatorTests.RejectsGroupRequestsBeforeSendingCommands;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  Requests: array[0..0] of TDispenserOperationRequest;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill, [],
      ErrorText)));

    Requests[0].Config := nil;
    Requests[0].SelectedChannel := 1;
    Requests[0].BypassActive := False;
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      Requests, ErrorText)));

    Requests[0].Config := FConfig;
    Requests[0].BypassActive := True;
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      Requests, ErrorText)));
    AssertEquals(0, FController.ExecuteMovementCalls);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.RejectsDuplicateAddressesBeforeStartingGroup;
var
  Coordinator: TDispenserOperationCoordinator;
  DuplicateConfig: TDispenserConfig;
  ErrorText: string;
  Requests: array[0..1] of TDispenserOperationRequest;
begin
  DuplicateConfig := FConfig.Clone;
  try
    DuplicateConfig.Number := 2;
    DuplicateConfig.Name := 'Duplicate pump';
    Requests[0].Config := FConfig;
    Requests[0].SelectedChannel := 2;
    Requests[0].BypassActive := False;
    Requests[1].Config := DuplicateConfig;
    Requests[1].SelectedChannel := 2;
    Requests[1].BypassActive := False;

    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokAspirate,
        Requests, ErrorText)));
      AssertTrue(ErrorText <> '');
      AssertEquals(0, FController.ExecuteMovementCalls);
      AssertFalse(FStates.Items[1].OperationActive);
    finally
      Coordinator.Free;
    end;
  finally
    DuplicateConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StartsGroupAndPollsAddressesRoundRobin;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  SecondConfig: TDispenserConfig;
  Requests: array[0..1] of TDispenserOperationRequest;
begin
  SecondConfig := FConfig.Clone;
  try
    SecondConfig.Number := 2;
    SecondConfig.Address := 2;
    SecondConfig.Name := 'Pump B';
    FStates.Items[SecondConfig.Address].MarkInitialized(SecondConfig);
    FStates.SetCurrentVolume(SecondConfig.Address, 100);
    Requests[0].Config := FConfig;
    Requests[0].SelectedChannel := 2;
    Requests[0].BypassActive := False;
    Requests[1].Config := SecondConfig;
    Requests[1].SelectedChannel := 3;
    Requests[1].BypassActive := False;
    FController.QuietStatusValues[1] := 0;
    FController.QuietStatusValues[2] := STATUS_READY_MASK;
    FController.QuietStatusValues[3] := STATUS_READY_MASK;

    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      Coordinator.OnLogMessage := @CaptureLog;
      AssertEquals(Ord(dgsStarted), Ord(Coordinator.StartGroup(dokAspirate,
        Requests, ErrorText)));
      AssertTrue(FStates.Items[1].OperationActive);
      AssertTrue(FStates.Items[2].OperationActive);
      AssertEquals(2, FController.ExecuteMovementCalls);

      Coordinator.PollNextOperation;
      AssertTrue(FStates.Items[1].OperationActive);
      AssertTrue(FStates.Items[2].OperationActive);
      AssertEquals(1, FController.LastPolledAddress);

      Coordinator.PollNextOperation;
      AssertTrue(FStates.Items[1].OperationActive);
      AssertFalse(FStates.Items[2].OperationActive);
      AssertEquals(200.0, FStates.GetCurrentVolume(2), 0.001);

      Coordinator.PollNextOperation;
      AssertFalse(FStates.Items[1].OperationActive);
      AssertEquals(350.0, FStates.GetCurrentVolume(1), 0.001);
      AssertFalse(Coordinator.HasActiveOperations);
      AssertEquals(3, FController.QueryQuietCalls);
    finally
      Coordinator.Free;
    end;
  finally
    SecondConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StopsEarlierGroupStartsWhenLaterCommandFails;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  SecondConfig: TDispenserConfig;
  Requests: array[0..1] of TDispenserOperationRequest;
begin
  SecondConfig := FConfig.Clone;
  try
    SecondConfig.Number := 2;
    SecondConfig.Address := 2;
    SecondConfig.Name := 'Pump B';
    FStates.Items[SecondConfig.Address].MarkInitialized(SecondConfig);
    FStates.SetCurrentVolume(2, 100);
    Requests[0].Config := FConfig;
    Requests[0].SelectedChannel := 2;
    Requests[0].BypassActive := False;
    Requests[1].Config := SecondConfig;
    Requests[1].SelectedChannel := 2;
    Requests[1].BypassActive := False;
    FController.FailExecuteMovementAtCall := 2;

    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      Coordinator.OnFailure := @CaptureFailure;
      Coordinator.OnStateChanged := @CaptureStateChanged;
      Coordinator.OnLogMessage := @CaptureLog;
      AssertEquals(Ord(dgsStoppedOnCommandError), Ord(Coordinator.StartGroup(
        dokAspirate, Requests, ErrorText)));
      AssertFalse(FStates.Items[1].OperationActive);
      AssertFalse(FStates.Items[2].OperationActive);
      AssertFalse(FStates.IsCurrentVolumeKnown(1));
      AssertFalse(FStates.IsCurrentVolumeKnown(2));
      AssertEquals(2, FController.TerminateMovementCalls);
      AssertEquals(1, FController.LastTerminatedAddress);
      AssertEquals(1, FFailureMessages.Count);
      AssertEquals('save', FFailureSaveFlags[0]);
      AssertEquals(3, FChangedAddresses.Count);
      AssertEquals(3, FLogs.Count);
    finally
      Coordinator.Free;
    end;
  finally
    SecondConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StopAllContinuesAfterOneDispenserRejectsStop;
var
  Coordinator: TDispenserOperationCoordinator;
  SecondConfig: TDispenserConfig;
  ErrorText: string;
begin
  SecondConfig := FConfig.Clone;
  try
    SecondConfig.Number := 2;
    SecondConfig.Address := 2;
    SecondConfig.Name := 'Pump B';
    FStates.Items[2].MarkInitialized(SecondConfig);
    FStates.SetCurrentVolume(2, 100);
    Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
    try
      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
        dokAspirate, 2, False, ErrorText)));
      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(
        SecondConfig, dokAspirate, 2, False, ErrorText)));
      FController.FailTerminateMovementAtCall := 1;
      AssertFalse(Coordinator.StopAllActiveOperations(ErrorText));
      AssertTrue(Pos('Дозатор 1', ErrorText) > 0);
      AssertEquals(2, FController.TerminateMovementCalls);
      AssertTrue(FStates.Items[1].OperationActive);
      AssertTrue(FStates.Items[1].InitializationRequired);
      AssertFalse(FStates.IsCurrentVolumeKnown(1));
      AssertFalse(FStates.Items[2].OperationActive);
      AssertFalse(FStates.IsCurrentVolumeKnown(2));
      AssertTrue(Coordinator.HasActiveOperations);
    finally
      Coordinator.Free;
    end;
  finally
    SecondConfig.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.PollFailuresMarkVolumeUnknown;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    Coordinator.OnFailure := @CaptureFailure;
    Coordinator.OnStateChanged := @CaptureStateChanged;
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    FController.QueryQuietResult := False;
    Coordinator.PollNextOperation;
    AssertFalse(FStates.Items[1].OperationActive);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
    AssertEquals('no-save', FFailureSaveFlags[0]);
  finally
    Coordinator.Free;
  end;

  FController.QueryQuietResult := True;
  FController.QuietStatusValues[2] := $22;
  FController.FailExecuteMovementAtCall := 0;
  FController.EncoderMovementPending[1] := False;
  FStates.Items[1].MarkInitialized(FConfig);
  FStates.SetCurrentVolume(1, 200);
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokFill, 1, False, ErrorText)));
    Coordinator.PollNextOperation;
    AssertFalse(FStates.Items[1].OperationActive);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.StartGroupRejectsMissingDependenciesAndBusyState;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  Request: TDispenserOperationRequest;
begin
  Request.Config := FConfig;
  Request.SelectedChannel := 2;
  Request.BypassActive := False;

  Coordinator := TDispenserOperationCoordinator.Create(nil, FStates);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      [Request], ErrorText)));
    AssertTrue(ErrorText <> '');
  finally
    Coordinator.Free;
  end;

  FController.Connected := False;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      [Request], ErrorText)));
    AssertTrue(ErrorText <> '');
  finally
    Coordinator.Free;
  end;
  FController.Connected := True;

  Coordinator := TDispenserOperationCoordinator.Create(FController, nil);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      [Request], ErrorText)));
    AssertTrue(ErrorText <> '');
  finally
    Coordinator.Free;
  end;

  BeginMockOperation(FConfig.Address, dooManual, FConfig.Name);
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      [Request], ErrorText)));
    AssertTrue(ErrorText <> '');
  finally
    Coordinator.Free;
  end;

  FStates.Items[FConfig.Address].ClearOperation;
  FConfig.Address := MAX_DISPENSER_VALUE + 1;
  Request.Config := FConfig;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dgsRejected), Ord(Coordinator.StartGroup(dokFill,
      [Request], ErrorText)));
    AssertTrue(ErrorText <> '');
    AssertEquals(0, FController.ExecuteMovementCalls);
  finally
    Coordinator.Free;
    FConfig.Address := 1;
  end;
end;

procedure TDispenserOperationCoordinatorTests.PollWrapsFromMaximumAddressAndReportsUnnamedFailure;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  FConfig.Address := MAX_DISPENSER_VALUE;
  FStates.Items[MAX_DISPENSER_VALUE].MarkInitialized(FConfig);
  FStates.SetCurrentVolume(MAX_DISPENSER_VALUE, 250);
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 2, False, ErrorText)));
    FController.QuietStatusValues[1] := STATUS_READY_MASK;
    Coordinator.PollNextOperation;
    AssertEquals(MAX_DISPENSER_VALUE, FController.LastPolledAddress);
    AssertFalse(FStates.Items[MAX_DISPENSER_VALUE].OperationActive);

    State := FStates.Items[MIN_DISPENSER_VALUE];
    BeginMockOperation(MIN_DISPENSER_VALUE, dooManual, '');
    FController.QueryQuietResult := False;
    Coordinator.OnFailure := @CaptureFailure;
    Coordinator.PollNextOperation;
    AssertFalse(State.OperationActive);
    AssertFalse(State.CurrentVolumeKnown);
    AssertEquals(1, FFailureMessages.Count);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.PollDoesNothingWithoutActiveOperations;
var
  Coordinator: TDispenserOperationCoordinator;
  StateOnlyCoordinator: TDispenserOperationCoordinator;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertFalse(Coordinator.HasActiveOperations);
    Coordinator.PollNextOperation;
    AssertEquals(0, FController.QueryQuietCalls);
  finally
    Coordinator.Free;
  end;

  BeginMockOperation(1, dooManual, 'Pump A');
  StateOnlyCoordinator := TDispenserOperationCoordinator.Create(nil, FStates);
  try
    AssertTrue(StateOnlyCoordinator.HasActiveOperations);
    StateOnlyCoordinator.PollNextOperation;
  finally
    StateOnlyCoordinator.Free;
  end;

  StateOnlyCoordinator := TDispenserOperationCoordinator.Create(FController,
    nil);
  try
    AssertFalse(StateOnlyCoordinator.HasActiveOperations);
  finally
    StateOnlyCoordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.CompletesEveryOperationKind;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  Kind: TDispenserOperationKind;
  InitialVolume: Integer;
  ExpectedVolume: Integer;
begin
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    for Kind := Low(TDispenserOperationKind) to High(TDispenserOperationKind) do
    begin
      case Kind of
        dokFill: InitialVolume := 250;
        dokEmpty: InitialVolume := 500;
        dokAspirate: InitialVolume := 250;
        dokDispense: InitialVolume := 500;
      end;
      FStates.SetCurrentVolume(1, InitialVolume);
      FConfig.Operation.Volume := 100;
      AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
        Kind, 2, False, ErrorText)));
      Coordinator.PollNextOperation;

      if Kind in [dokFill, dokAspirate] then
        ExpectedVolume := InitialVolume + FStates.Items[1].OperationVolume
      else
        ExpectedVolume := InitialVolume - FStates.Items[1].OperationVolume;
      AssertEquals(ExpectedVolume, Round(FStates.GetCurrentVolume(1)));
      AssertFalse(FStates.Items[1].OperationActive);
    end;
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.TracksStepsAcrossRepeatedSmallAspirateAndDispenseOperations;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
begin
  FConfig.Volume := 5000;
  FConfig.StepCount := 12000;
  FConfig.MaxFlowRate := 12;
  FConfig.Operation.Volume := 1;
  FConfig.Operation.Speed := 1;
  FStates.Items[FConfig.Address].MarkInitialized(FConfig);
  State := FStates.Items[FConfig.Address];
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 2, False, ErrorText)));
    AssertEquals(19, FController.LastMovementSteps);
    AssertEquals(0, State.CurrentPositionSteps);
    AssertEquals(0, State.OperationStartingPositionSteps);
    AssertEquals(19, State.OperationStepCount);
    Coordinator.PollNextOperation;
    AssertEquals(19, State.CurrentPositionSteps);

    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 2, False, ErrorText)));
    AssertEquals(19, FController.LastMovementSteps);
    AssertEquals(19, State.OperationStartingPositionSteps);
    AssertEquals(19, State.OperationStepCount);
    Coordinator.PollNextOperation;
    AssertEquals(38, State.CurrentPositionSteps);

    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokDispense, 2, False, ErrorText)));
    AssertEquals(19, FController.LastMovementSteps);
    AssertFalse(FController.LastMovementAspirate);
    AssertEquals(38, State.OperationStartingPositionSteps);
    Coordinator.PollNextOperation;
    AssertEquals(19, State.CurrentPositionSteps);
    AssertEquals(19.0 * 5000.0 / 96000.0, State.CurrentVolume, 0.000001);
    AssertTrue(State.CurrentVolumeKnown);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.SetUp;
begin
  inherited SetUp;
  FController := TMockDispenserController.Create;
  FStates := TDispenserRuntimeStates.Create;
  FConfigurations := TDispenserConfigList.Create;
  FLogs := TStringList.Create;
  AddConfiguration(1, 1);
end;

procedure TDispenserConnectionCoordinatorTests.TearDown;
begin
  FLogs.Free;
  FConfigurations.Free;
  FStates.Free;
  FController.Free;
  inherited TearDown;
end;

procedure TDispenserConnectionCoordinatorTests.CaptureLog(const Msg: string);
begin
  FLogs.Add(Msg);
end;

procedure TDispenserConnectionCoordinatorTests.ConnectOnlyOpensPortWithoutInitializingDevices;
var
  Coordinator: TDispenserConnectionCoordinator;
  ErrorText: string;
begin
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dcrConnected), Ord(Coordinator.ConnectPort('COM1',
      ErrorText)));
    AssertEquals('', ErrorText);
    AssertTrue(FController.IsConnected);
    AssertEquals(1, FController.ConnectCalls);
    AssertEquals(0, FController.QueryStatusCalls);
    AssertEquals(0, FController.InitializeValveCalls);
    AssertEquals(0, FController.InitializePlungerCalls);
    AssertTrue(FStates.Items[1].InitializationRequired);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AddConfiguration(ANumber,
  AAddress: Integer);
var
  Config: TDispenserConfig;
begin
  Config := FConfigurations.AddConfig;
  Config.Number := ANumber;
  Config.Address := AAddress;
  Config.Name := 'Pump ' + IntToStr(ANumber);
  Config.Volume := 1000;
  Config.ChannelCount := 4;
  Config.StepCount := 10000;
  Config.IntakeChannel := 1;
  Config.MaxFlowRate := 12;
  Config.Operation.Volume := 100;
  Config.Operation.Speed := 10;
  Config.Operation.Channel := 2;
end;

function TDispenserConnectionCoordinatorTests.CompleteInitialization(
  Coordinator: TDispenserConnectionCoordinator;
  Configurations: TDispenserConfigList; Failures: TStrings): Boolean;
var
  PollCount: Integer;
begin
  Result := Coordinator.InitializeDispensers(Configurations, Failures);
  if not Result then
    Exit;
  PollCount := 0;
  while Coordinator.HasActiveInitialization and (PollCount < 100) do
  begin
    Coordinator.PollInitialization;
    Inc(PollCount);
  end;
  if Coordinator.HasActiveInitialization then
  begin
    Failures.Add('Инициализация не завершилась за 100 опросов.');
    Result := False;
    Exit;
  end;
  Coordinator.GetInitializationResults(Failures, Result);
end;

procedure TDispenserOperationCoordinatorTests.EncoderFeedbackRecordsMeasuredMovement;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
  State: TDispenserRuntimeState;
  I: Integer;
  FoundMismatch: Boolean;
begin
  FController.MovementEncoderAdjustmentSteps := -2;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    Coordinator.OnLogMessage := @CaptureLog;
    AssertEquals(Ord(dosrStarted), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertEquals(1, FController.QueryEncoderCalls);

    Coordinator.PollNextOperation;

    State := FStates.Items[FConfig.Address];
    AssertEquals(2, FController.QueryEncoderCalls);
    AssertFalse(State.OperationActive);
    AssertTrue(State.CurrentVolumeKnown);
    AssertEquals(27998, State.CurrentPositionSteps);
    AssertEquals(349.975, State.CurrentVolume, 0.001);
    FoundMismatch := False;
    for I := 0 to FLogs.Count - 1 do
      if Pos('РАСХОЖДЕНИЕ ЭНКОДЕРА', FLogs[I]) > 0 then
        FoundMismatch := True;
    AssertTrue('encoder mismatch should be reported', FoundMismatch);
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserOperationCoordinatorTests.EncoderQueryFailurePreventsMovementAndInvalidatesPosition;
var
  Coordinator: TDispenserOperationCoordinator;
  ErrorText: string;
begin
  FController.QueryEncoderResult := False;
  Coordinator := TDispenserOperationCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dosrCommandFailed), Ord(Coordinator.StartSingle(FConfig,
      dokAspirate, 3, False, ErrorText)));
    AssertTrue(ErrorText <> '');
    AssertEquals(0, FController.ExecuteMovementCalls);
    AssertTrue(FStates.Items[FConfig.Address].InitializationRequired);
    AssertFalse(FStates.IsCurrentVolumeKnown(FConfig.Address));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.RejectsInvalidRequests;
var
  Coordinator: TDispenserConnectionCoordinator;
  ErrorText: string;
  EmptyConfigurations: TDispenserConfigList;
  Failures: TStringList;
begin
  Failures := TStringList.Create;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dcrInvalidRequest), Ord(Coordinator.ConnectPort(
      '  ', ErrorText)));
    AssertFalse(Coordinator.InitializeDispensers(nil, Failures));
    AssertTrue(Failures.Count > 0);
    EmptyConfigurations := TDispenserConfigList.Create;
    try
      AssertFalse(Coordinator.InitializeDispensers(EmptyConfigurations,
        Failures));
    finally
      EmptyConfigurations.Free;
    end;
  finally
    Coordinator.Free;
    Failures.Free;
  end;

  Coordinator := TDispenserConnectionCoordinator.Create(nil, FStates);
  try
    AssertEquals(Ord(dcrInvalidRequest), Ord(Coordinator.ConnectPort(
      'COM1', ErrorText)));
  finally
    Coordinator.Free;
  end;

  Coordinator := TDispenserConnectionCoordinator.Create(FController, nil);
  try
    AssertEquals(Ord(dcrInvalidRequest), Ord(Coordinator.ConnectPort(
      'COM1', ErrorText)));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.ReportsPortOpenFailure;
var
  Coordinator: TDispenserConnectionCoordinator;
  ErrorText: string;
begin
  FController.ConnectResult := False;
  FStates.SetCurrentVolume(1, 50);
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertEquals(Ord(dcrPortOpenFailed), Ord(Coordinator.ConnectPort(
      'COM1', ErrorText)));
    AssertEquals(FController.LastErrorText, ErrorText);
    AssertEquals(0, FController.DisconnectCalls);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
  finally
    Coordinator.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AbortsWhenStatusQueryFailsOrDeviceReportsError;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
begin
  Failures := TStringList.Create;
  FController.FailQueryAtCall := 1;
  FController.Connected := True;
  FStates.SetCurrentVolume(1, 75);
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertFalse(CompleteInitialization(Coordinator, FConfigurations, Failures));
    AssertEquals(1, Failures.Count);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
    AssertEquals(0, FController.DisconnectCalls);
  finally
    Coordinator.Free;
  end;

  FController.FailQueryAtCall := 0;
  FController.QueryStatusCalls := 0;
  FController.QueryStatusValue := $22;
  FStates.SetCurrentVolume(1, 75);
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    Coordinator.OnLogMessage := @CaptureLog;
    AssertFalse(CompleteInitialization(Coordinator, FConfigurations, Failures));
    AssertEquals(1, Failures.Count);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
    AssertEquals(0, FController.DisconnectCalls);
    AssertTrue(FLogs.Count > 0);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AbortsWhenDeviceIsBusy;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
begin
  Failures := TStringList.Create;
  FController.QueryStatusValue := 0;
  FController.Ready := False;
  FController.Connected := True;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    Coordinator.OnLogMessage := @CaptureLog;
    AssertFalse(CompleteInitialization(Coordinator, FConfigurations, Failures));
    AssertEquals(1, Failures.Count);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
    AssertEquals(0, FController.DisconnectCalls);
    AssertEquals(1, FController.QueryStatusCalls);
    AssertTrue(FLogs.Count > 0);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AllowsNotInitializedStatusDuringConnection;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
begin
  Failures := TStringList.Create;
  FController.QueryStatusValue := STATUS_NOT_INITIALIZED;
  FController.Ready := False;
  FController.Connected := True;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertTrue(CompleteInitialization(Coordinator, FConfigurations, Failures));
    AssertEquals(0, Failures.Count);
    AssertEquals(1, FController.InitializeValveCalls);
    AssertEquals(1, FController.InitializePlungerCalls);
    AssertEquals(2, FController.QueryQuietCalls);
    AssertEquals(0, FController.WaitForIdleCalls);
    AssertEquals(1, FController.SetFinePositioningModeCalls);
    AssertEquals(1, FController.DetectValveTypeCalls);
    AssertTrue(FStates.IsCurrentVolumeKnown(1));
    AssertEquals(0.0, FStates.GetCurrentVolume(1), 0.001);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AbortsAtEveryInitializationPhase;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
  Phase: Integer;
begin
  Failures := TStringList.Create;
  for Phase := 1 to 6 do
  begin
    FController.DisconnectCalls := 0;
    FController.Ready := False;
    FController.QueryStatusValue := STATUS_READY_MASK;
    FController.FailInitializeValveAtCall := 0;
    FController.FailWaitForIdleAtCall := 0;
    FController.FailQuietAtCall := 0;
    FController.FailInitializePlungerAtCall := 0;
    FController.FailSetFinePositioningModeAtCall := 0;
    FController.FailDetectValveTypeAtCall := 0;
    FController.InitializeValveCalls := 0;
    FController.WaitForIdleCalls := 0;
    FController.InitializePlungerCalls := 0;
    FController.SetFinePositioningModeCalls := 0;
    FController.DetectValveTypeCalls := 0;
    FController.QueryStatusCalls := 0;
    FController.ConnectCalls := 0;
    FController.Connected := True;
    FController.QueryQuietCalls := 0;
    FStates.SetCurrentVolume(1, 45);
    case Phase of
      1: FController.FailInitializeValveAtCall := 1;
      2: FController.FailQuietAtCall := 1;
      3: FController.FailInitializePlungerAtCall := 1;
      4: FController.FailQuietAtCall := 2;
      5: FController.FailSetFinePositioningModeAtCall := 1;
      6: FController.FailDetectValveTypeAtCall := 1;
    end;

    Coordinator := TDispenserConnectionCoordinator.Create(FController,
      FStates);
    try
      AssertFalse('phase ' + IntToStr(Phase), CompleteInitialization(
        Coordinator, FConfigurations, Failures));
      AssertEquals('phase ' + IntToStr(Phase), 1, Failures.Count);
      AssertFalse(FStates.IsCurrentVolumeKnown(1));
      AssertEquals(0, FController.DisconnectCalls);
      Failures.Clear;
    finally
      Coordinator.Free;
    end;
  end;
  Failures.Free;
end;

procedure TDispenserConnectionCoordinatorTests.InitializesAllDevicesAndMarksEmptyVolumeKnown;
var
  Coordinator: TDispenserConnectionCoordinator;
  ErrorText: string;
  Failures: TStringList;
begin
  AddConfiguration(2, 2);
  FController.QueryStatusValue := STATUS_READY_MASK;
  FController.ValveTypeToDetect := dvtNonDistributive;
  FStates.SetCurrentVolume(1, 80);
  FStates.SetCurrentVolume(2, 90);
  Failures := TStringList.Create;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    Coordinator.OnLogMessage := @CaptureLog;
    AssertEquals(Ord(dcrConnected), Ord(Coordinator.ConnectPort(
      'COM3', ErrorText)));
    AssertTrue(CompleteInitialization(Coordinator, FConfigurations, Failures));
    AssertEquals(0, Failures.Count);
    AssertEquals(1, FController.ConnectCalls);
    AssertEquals(2, FController.QueryStatusCalls);
    AssertEquals(2, FController.InitializeValveCalls);
    AssertEquals(0, FController.WaitForIdleCalls);
    AssertEquals(2, FController.InitializePlungerCalls);
    AssertEquals(2, FController.SetFinePositioningModeCalls);
    AssertEquals(2, FController.DetectValveTypeCalls);
    AssertTrue(FStates.IsCurrentVolumeKnown(1));
    AssertTrue(FStates.IsCurrentVolumeKnown(2));
    AssertEquals(0.0, FStates.GetCurrentVolume(1), 0.001);
    AssertEquals(0.0, FStates.GetCurrentVolume(2), 0.001);
    AssertEquals(Ord(dvtNonDistributive),
      Ord(FStates.Items[1].ValveType));
    AssertEquals(Ord(dvtNonDistributive),
      Ord(FStates.Items[2].ValveType));
    AssertTrue(FLogs.Count >= 4);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.InitializeDispensersStartsEachMotorPhaseForAllDevices;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
  Success: Boolean;
begin
  AddConfiguration(2, 2);
  FController.Connected := True;
  Failures := TStringList.Create;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertTrue(Coordinator.InitializeDispensers(FConfigurations, Failures));
    AssertEquals(0, Failures.Count);
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(2, FController.InitializeValveCalls);
    AssertEquals(0, FController.QueryQuietCalls);
    AssertEquals(0, FController.InitializePlungerCalls);
    AssertEquals(0, FController.WaitForIdleCalls);
    Coordinator.PollInitialization;
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(2, FController.ValveCallsAtFirstQuiet);
    AssertEquals(2, FController.InitializePlungerCalls);
    AssertEquals(2, FController.QueryQuietCalls);
    Coordinator.PollInitialization;
    AssertFalse(Coordinator.HasActiveInitialization);
    AssertEquals(2, FController.PlungerCallsAtFirstPlungerPoll);
    AssertEquals(4, FController.QueryQuietCalls);
    Coordinator.GetInitializationResults(Failures, Success);
    AssertTrue(Success);
    AssertEquals(0, Failures.Count);
    AssertTrue(FStates.Items[1].IsInitializedFor(FConfigurations[0]));
    AssertTrue(FStates.Items[2].IsInitializedFor(FConfigurations[1]));
    AssertTrue(FStates.IsCurrentVolumeKnown(1));
    AssertTrue(FStates.IsCurrentVolumeKnown(2));
    AssertEquals(0.0, FStates.GetCurrentVolume(1), 0.001);
    AssertEquals(0.0, FStates.GetCurrentVolume(2), 0.001);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.InitializationPollAdvancesWithoutWaitingForIdle;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
  Success: Boolean;
begin
  FController.Connected := True;
  FController.QuietStatusValues[1] := 0;
  FController.QuietStatusValues[2] := STATUS_READY_MASK;
  FController.QuietStatusValues[3] := 0;
  FController.QuietStatusValues[4] := STATUS_READY_MASK;
  Failures := TStringList.Create;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertTrue(Coordinator.InitializeDispensers(FConfigurations, Failures));
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(0, FController.QueryQuietCalls);
    AssertEquals(0, FController.InitializePlungerCalls);

    Coordinator.PollInitialization;
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(1, FController.QueryQuietCalls);
    AssertEquals(0, FController.InitializePlungerCalls);
    AssertEquals(0, FController.WaitForIdleCalls);

    Coordinator.PollInitialization;
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(2, FController.QueryQuietCalls);
    AssertEquals(1, FController.InitializePlungerCalls);

    Coordinator.PollInitialization;
    AssertTrue(Coordinator.HasActiveInitialization);
    AssertEquals(3, FController.QueryQuietCalls);
    Coordinator.PollInitialization;
    AssertFalse(Coordinator.HasActiveInitialization);
    AssertEquals(4, FController.QueryQuietCalls);
    Coordinator.GetInitializationResults(Failures, Success);
    AssertTrue(Success);
    AssertEquals(0, Failures.Count);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.AllowsAnotherAddressToInitializeWhileFirstIsActive;
var
  Coordinator: TDispenserConnectionCoordinator;
  FirstConfiguration: TDispenserConfigList;
  SecondConfiguration: TDispenserConfigList;
  Failures: TStringList;
  Success: Boolean;
begin
  AddConfiguration(2, 2);
  FirstConfiguration := TDispenserConfigList.Create;
  SecondConfiguration := TDispenserConfigList.Create;
  Failures := TStringList.Create;
  FirstConfiguration.Add(FConfigurations[0].Clone);
  SecondConfiguration.Add(FConfigurations[1].Clone);
  FController.Connected := True;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertTrue(Coordinator.InitializeDispensers(FirstConfiguration, Failures));
    AssertTrue(Coordinator.IsAddressInitializing(1));
    AssertFalse(Coordinator.IsAddressInitializing(2));

    Failures.Clear;
    AssertFalse(Coordinator.InitializeDispensers(FirstConfiguration, Failures));
    AssertEquals(1, Failures.Count);
    AssertTrue(Coordinator.IsAddressInitializing(1));

    Failures.Clear;
    AssertTrue(Coordinator.InitializeDispensers(SecondConfiguration, Failures));
    AssertEquals(0, Failures.Count);
    AssertTrue(Coordinator.IsAddressInitializing(1));
    AssertTrue(Coordinator.IsAddressInitializing(2));

    Coordinator.PollInitialization;
    AssertTrue(Coordinator.IsAddressInitializing(1));
    AssertTrue(Coordinator.IsAddressInitializing(2));
    Coordinator.PollInitialization;
    AssertFalse(Coordinator.HasActiveInitialization);
    AssertFalse(Coordinator.IsAddressInitializing(1));
    AssertFalse(Coordinator.IsAddressInitializing(2));
    Coordinator.GetInitializationResults(Failures, Success);
    AssertTrue(Success);
    AssertEquals(0, Failures.Count);
    AssertTrue(FStates.Items[1].IsInitializedFor(FConfigurations[0]));
    AssertTrue(FStates.Items[2].IsInitializedFor(FConfigurations[1]));
  finally
    Coordinator.Free;
    Failures.Free;
    FirstConfiguration.Free;
    SecondConfiguration.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.InitializeDispensersKeepsSuccessfulDevicesWhenOneFails;
var
  Coordinator: TDispenserConnectionCoordinator;
  Failures: TStringList;
  Success: Boolean;
begin
  AddConfiguration(2, 2);
  FController.Connected := True;
  FController.FailInitializeValveAtCall := 2;
  FStates.SetCurrentVolume(1, 40);
  FStates.SetCurrentVolume(2, 50);
  Failures := TStringList.Create;
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    AssertTrue(Coordinator.InitializeDispensers(FConfigurations, Failures));
    AssertEquals(0, Failures.Count);
    while Coordinator.HasActiveInitialization do
      Coordinator.PollInitialization;
    Coordinator.GetInitializationResults(Failures, Success);
    AssertFalse(Success);
    AssertEquals(1, Failures.Count);
    AssertTrue(Pos('№2:', Failures[0]) > 0);
    AssertTrue(FStates.Items[1].IsInitializedFor(FConfigurations[0]));
    AssertFalse(FStates.Items[2].IsInitializedFor(FConfigurations[1]));
    AssertTrue(FStates.IsCurrentVolumeKnown(1));
    AssertEquals(0.0, FStates.GetCurrentVolume(1), 0.001);
    AssertFalse(FStates.IsCurrentVolumeKnown(2));
    AssertEquals(1, FController.InitializePlungerCalls);
    AssertEquals(0, FController.DisconnectCalls);
  finally
    Coordinator.Free;
    Failures.Free;
  end;
end;

procedure TDispenserConnectionCoordinatorTests.DisconnectResetsControllerAndRuntimeState;
var
  Coordinator: TDispenserConnectionCoordinator;
  NullCoordinator: TDispenserConnectionCoordinator;
  ErrorText: string;
begin
  FStates.Items[1].MarkInitialized(FConfigurations[0]);
  FStates.SetCurrentVolume(1, 100);
  AssertTrue(FStates.Items[1].TryBeginOperation(dooManual, dokAspirate,
    'Pump A', 1, 1, FStates.Items[1].CurrentPositionSteps, ErrorText));
  Coordinator := TDispenserConnectionCoordinator.Create(FController, FStates);
  try
    Coordinator.Disconnect;
    AssertEquals(1, FController.DisconnectCalls);
    AssertFalse(FStates.IsCurrentVolumeKnown(1));
    AssertFalse(FStates.Items[1].OperationActive);
  finally
    Coordinator.Free;
  end;

  NullCoordinator := TDispenserConnectionCoordinator.Create(nil, nil);
  try
    NullCoordinator.Disconnect;
  finally
    NullCoordinator.Free;
  end;
end;

initialization
  RegisterTest(TDispenserOperationCoordinatorTests);
  RegisterTest(TDispenserConnectionCoordinatorTests);

end.
