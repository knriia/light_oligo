unit StationProtocolCoordinatorTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, fpcunit, testregistry, DispenserConfig,
  DispenserLimits, DispenserRuntimeState, DispenserTypes, AutomationProtocol,
  ProtocolFormat, ProtocolStartPlan, StationWork, SyringeStepTracker,
  StationProtocolCoordinator;

type
  // Тестовый хозяин: запоминает всё, что делает координатор.
  TFakeProtocolHost = class(TObject, IStationProtocolHost)
  public
    Configs: TDispenserConfigList;
    Queue: TObjectList;
    LogLines: TStringList;
    Warnings: TStringList;
    ActiveInitialization: Boolean;
    InitializingAddress: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    PendingInitAddress: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    PendingInitAny: Boolean;
    ResultFailures: TStringList;
    ResultSuccess: Boolean;
    TableReserved: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
    TablePending: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
    TableBypass: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
    UiUpdates: Integer;
    VolumeRefreshes: Integer;
    constructor Create;
    destructor Destroy; override;
    function Configurations: TDispenserConfigList;
    function HasActiveInitialization: Boolean;
    function IsAddressInitializing(AAddress: Integer): Boolean;
    procedure GetInitializationResults(AFailures: TStrings;
      out ASuccess: Boolean);
    function HasPendingInitializationTask(AAddress: Integer): Boolean;
    procedure QueueWorkItem(ATask: TFormWorkItem);
    procedure SetProtocolReserved(AAddress: Integer; AReserved: Boolean);
    procedure SetCommandPending(AAddress: Integer; APending: Boolean);
    procedure SetBypassSupported(AAddress: Integer; AEnabled: Boolean);
    procedure RefreshCurrentVolumes;
    procedure UpdateUI;
    procedure Log(const AMessage: string);
    procedure ShowOperationWarning(const AMessage: string);
    function QueuedItem(AIndex: Integer): TFormWorkItem;
  end;

  TStationProtocolCoordinatorTests = class(TTestCase)
  private
    FHost: TFakeProtocolHost;
    FStates: TDispenserRuntimeStates;
    FStep: TSyringeStepTracker;
    FCoordinator: TStationProtocolCoordinator;
    function MakeConfig(AAddress: Integer): TDispenserConfig;
    function MakeProtocol(const AAddresses: array of Integer):
      TAutomationProtocol;
    // Запускает протокол по плану; AInitialized - дозаторы уже инициализированы
    // (иначе в плане будет инициализация).
    procedure StartProtocolOn(const AAddresses: array of Integer;
      AInitialized: Boolean = False);
    procedure Complete(ATask: TFormWorkItem; ASuccess: Boolean;
      const AError: string = '');
    // Выполняет подготовку (успешно) и доводит до отложенного запуска.
    procedure CompletePrepare(ASuccess: Boolean);
    function StepError: string;
    function StepStatus: TSyringeStepStatus;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure StartWithoutInitializationQueuesStart;
    procedure StartWithInitializationQueuesPrepare;
    procedure StartReservesAllTargetsInStatesAndTable;
    procedure PrepareSuccessWaitsForInitializationToFinish;
    procedure PrepareSuccessQueuesStartAfterInitialization;
    procedure QueuedStartCarriesReservedAddresses;
    procedure StopDuringInitializationDropsProtocolWithoutStart;
    procedure StopDuringInitializationReleasesEverything;
    procedure StopRequestedBeforePrepareCompletesStillStops;
    procedure InitializationFailureDropsProtocolAndFailsStep;
    procedure InitializationReportedUnsuccessfulDropsProtocol;
    procedure PrepareTaskFailureReleasesAndFailsStep;
    procedure PrepareTaskFailureKeepsOtherAddressesIntact;
    procedure StartSuccessClearsTaskActive;
    procedure StartSuccessWithStopRequestQueuesStop;
    procedure StartFailureReleasesTaskReservations;
    procedure StartFailureFailsStepWithMessage;
    procedure StopProtocolCompletionClearsTaskActive;
    procedure StopProtocolFailureWarns;
    procedure StopAllCompletionClearsPendingAndTaskActive;
    procedure QueueStopProtocolMarksTaskActive;
    procedure MarkStopAllQueuedFollowsRunner;
    procedure ReleaseProtocolReservationsClearsStatesAndTable;
    procedure ManualInitializationMarksPending;
    procedure ManualInitializationCompletesAndReleasesPending;
    procedure ManualInitializationWaitsForAddressToFinish;
    procedure ManualInitializationWaitsForQueuedInitTask;
    procedure ManualInitializationTaskFailureClearsPending;
    procedure ManualInitializationReportsFailures;
    procedure ManualInitializationDoesNotQueueProtocol;
    procedure FinishDoesNothingWithoutActivity;
    procedure SecondPrepareAfterFailureIsPossible;
    procedure PendingProtocolIsKeptUntilInitializationEnds;
    procedure InitializeFailureWithFailuresListWarnsWithList;
    procedure PrepareFailureWithFailuresListWarnsWithList;
    procedure InitializationFailuresWithSuccessFlagStillFailProtocol;
    procedure ManualInitializationDuringPreparationKeepsProtocol;
    procedure HandleCompletedIgnoresForeignKinds;
    procedure StartFailureWithStopRequestOnlyFailsStep;
    procedure FinishRequestsUiUpdateWhenAddressReleased;
  end;

implementation

constructor TFakeProtocolHost.Create;
var
  Address: Integer;
begin
  inherited Create;
  Configs := TDispenserConfigList.Create;
  Queue := TObjectList.Create(True);
  LogLines := TStringList.Create;
  Warnings := TStringList.Create;
  ResultFailures := TStringList.Create;
  ResultSuccess := True;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    InitializingAddress[Address] := False;
    PendingInitAddress[Address] := False;
    TableReserved[Address] := False;
    TablePending[Address] := False;
    TableBypass[Address] := False;
  end;
end;

destructor TFakeProtocolHost.Destroy;
begin
  ResultFailures.Free;
  Warnings.Free;
  LogLines.Free;
  Queue.Free;
  Configs.Free;
  inherited Destroy;
end;

function TFakeProtocolHost.Configurations: TDispenserConfigList;
begin
  Result := Configs;
end;

function TFakeProtocolHost.HasActiveInitialization: Boolean;
begin
  Result := ActiveInitialization;
end;

function TFakeProtocolHost.IsAddressInitializing(AAddress: Integer): Boolean;
begin
  Result := InitializingAddress[AAddress];
end;

procedure TFakeProtocolHost.GetInitializationResults(AFailures: TStrings;
  out ASuccess: Boolean);
begin
  AFailures.Assign(ResultFailures);
  ASuccess := ResultSuccess;
end;

function TFakeProtocolHost.HasPendingInitializationTask(
  AAddress: Integer): Boolean;
begin
  if AAddress = 0 then
    Result := PendingInitAny
  else
    Result := PendingInitAddress[AAddress];
end;

procedure TFakeProtocolHost.QueueWorkItem(ATask: TFormWorkItem);
begin
  Queue.Add(ATask);
end;

procedure TFakeProtocolHost.SetProtocolReserved(AAddress: Integer;
  AReserved: Boolean);
begin
  TableReserved[AAddress] := AReserved;
end;

procedure TFakeProtocolHost.SetCommandPending(AAddress: Integer;
  APending: Boolean);
begin
  TablePending[AAddress] := APending;
end;

procedure TFakeProtocolHost.SetBypassSupported(AAddress: Integer;
  AEnabled: Boolean);
begin
  TableBypass[AAddress] := AEnabled;
end;

procedure TFakeProtocolHost.RefreshCurrentVolumes;
begin
  Inc(VolumeRefreshes);
end;

procedure TFakeProtocolHost.UpdateUI;
begin
  Inc(UiUpdates);
end;

procedure TFakeProtocolHost.Log(const AMessage: string);
begin
  LogLines.Add(AMessage);
end;

procedure TFakeProtocolHost.ShowOperationWarning(const AMessage: string);
begin
  Warnings.Add(AMessage);
end;

function TFakeProtocolHost.QueuedItem(AIndex: Integer): TFormWorkItem;
begin
  Result := TFormWorkItem(Queue[AIndex]);
end;

procedure TStationProtocolCoordinatorTests.SetUp;
begin
  inherited SetUp;
  FHost := TFakeProtocolHost.Create;
  FStates := TDispenserRuntimeStates.Create;
  FStep := TSyringeStepTracker.Create;
  FCoordinator := TStationProtocolCoordinator.Create(FHost, FStates, FStep);
end;

procedure TStationProtocolCoordinatorTests.TearDown;
begin
  FCoordinator.Free;
  FStep.Free;
  FStates.Free;
  FHost.Free;
  inherited TearDown;
end;

function TStationProtocolCoordinatorTests.MakeConfig(
  AAddress: Integer): TDispenserConfig;
begin
  Result := FHost.Configs.AddConfig;
  Result.Number := AAddress;
  Result.Name := 'Pump ' + IntToStr(AAddress);
  Result.Address := AAddress;
  Result.Volume := 1000;
  Result.ChannelCount := 4;
  Result.StepCount := 10000;
  Result.IntakeChannel := 1;
  Result.MaxFlowRate := 12;
end;

function TStationProtocolCoordinatorTests.MakeProtocol(
  const AAddresses: array of Integer): TAutomationProtocol;
var
  Command: TAutomationProtocolCommand;
  I: Integer;
begin
  Result := TAutomationProtocol.Create;
  Command := TAutomationProtocolCommand.Create;
  Command.Number := 1;
  SetLength(Command.Targets, Length(AAddresses));
  for I := 0 to High(AAddresses) do
    Command.Targets[I].Config := MakeConfig(AAddresses[I]);
  Result.Add(Command);
end;

procedure TStationProtocolCoordinatorTests.StartProtocolOn(
  const AAddresses: array of Integer; AInitialized: Boolean);
var
  Protocol: TAutomationProtocol;
  Plan: TProtocolStartPlan;
  I: Integer;
begin
  Protocol := MakeProtocol(AAddresses);
  if AInitialized then
    for I := 0 to High(Protocol[0].Targets) do
      FStates.Items[Protocol[0].Targets[I].Config.Address].MarkInitialized(
        Protocol[0].Targets[I].Config);
  Plan := PlanProtocolStart(Protocol, FStates);
  try
    if Plan.Status <> ppsReady then
    begin
      Protocol.Free;
      Fail('План запуска отклонён: ' + Plan.ErrorText);
    end;
    FCoordinator.QueueProtocolStart(Protocol, Plan);
  finally
    Plan.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.Complete(ATask: TFormWorkItem;
  ASuccess: Boolean; const AError: string);
begin
  ATask.Success := ASuccess;
  ATask.ErrorText := AError;
  ATask.MarkCompleted;
  FCoordinator.HandleCompleted(ATask);
end;

procedure TStationProtocolCoordinatorTests.CompletePrepare(ASuccess: Boolean);
begin
  Complete(FHost.QueuedItem(0), ASuccess);
end;

function TStationProtocolCoordinatorTests.StepError: string;
var
  Error: string;
begin
  FStep.Status(Error);
  Result := Error;
end;

function TStationProtocolCoordinatorTests.StepStatus: TSyringeStepStatus;
var
  Error: string;
begin
  Result := FStep.Status(Error);
end;

procedure TStationProtocolCoordinatorTests.StartWithoutInitializationQueuesStart;
begin
  StartProtocolOn([1], True);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).WorkKind = btkStartProtocol);
  AssertTrue(FHost.QueuedItem(0).Protocol <> nil);
  AssertFalse(FStates.Items[1].CommandPending);
  AssertTrue(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.StartWithInitializationQueuesPrepare;
begin
  StartProtocolOn([1, 2]);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).WorkKind = btkPrepareProtocol);
  AssertEquals(2, FHost.QueuedItem(0).Configs.Count);
  AssertTrue(FStates.Items[1].CommandPending);
  AssertTrue(FStates.Items[2].CommandPending);
  AssertTrue(FHost.TablePending[1]);
  AssertTrue(FHost.TablePending[2]);
  AssertTrue(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.StartReservesAllTargetsInStatesAndTable;
begin
  StartProtocolOn([3, 5]);
  AssertTrue(FStates.Items[3].ProtocolReserved);
  AssertTrue(FStates.Items[5].ProtocolReserved);
  AssertTrue(FHost.TableReserved[3]);
  AssertTrue(FHost.TableReserved[5]);
  AssertFalse(FStates.Items[4].ProtocolReserved);
  AssertTrue(FHost.QueuedItem(0).ReservedAddresses[3]);
  AssertTrue(FHost.QueuedItem(0).ReservedAddresses[5]);
  AssertFalse(FHost.QueuedItem(0).ReservedAddresses[4]);
end;

procedure TStationProtocolCoordinatorTests.PrepareSuccessWaitsForInitializationToFinish;
begin
  StartProtocolOn([1]);
  CompletePrepare(True);
  FHost.ActiveInitialization := True;
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FCoordinator.TaskActive);
  AssertTrue(FStates.Items[1].ProtocolReserved);
end;

procedure TStationProtocolCoordinatorTests.PrepareSuccessQueuesStartAfterInitialization;
begin
  FStep.Start;
  StartProtocolOn([1]);
  CompletePrepare(True);
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(2, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(1).WorkKind = btkStartProtocol);
  AssertTrue(FHost.QueuedItem(1).Protocol <> nil);
  AssertTrue(FHost.QueuedItem(0).Protocol = nil);
  AssertTrue(FCoordinator.TaskActive);
  AssertTrue(StepStatus = sssRunning);
  AssertEquals(1, FHost.LogLines.Count);
  AssertEquals(
    'Дозаторы протокола готовы; запуск протокола поставлен в очередь.',
    FHost.LogLines[0]);
end;

procedure TStationProtocolCoordinatorTests.QueuedStartCarriesReservedAddresses;
begin
  StartProtocolOn([2, 4]);
  CompletePrepare(True);
  FCoordinator.FinishInitializationIfComplete;
  AssertTrue(FHost.QueuedItem(1).ReservedAddresses[2]);
  AssertTrue(FHost.QueuedItem(1).ReservedAddresses[4]);
  AssertFalse(FHost.QueuedItem(1).ReservedAddresses[3]);
end;

procedure TStationProtocolCoordinatorTests.StopDuringInitializationDropsProtocolWithoutStart;
begin
  FStep.Start;
  StartProtocolOn([1]);
  AssertTrue(FStep.RequestStop);
  CompletePrepare(True);
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertEquals(2, FHost.LogLines.Count);
  AssertEquals('Шаг дозаторов остановлен до запуска.', FHost.LogLines[1]);
end;

procedure TStationProtocolCoordinatorTests.StopDuringInitializationReleasesEverything;
begin
  FStep.Start;
  StartProtocolOn([1, 2]);
  AssertTrue(FStep.RequestStop);
  CompletePrepare(True);
  FCoordinator.FinishInitializationIfComplete;
  AssertFalse(FCoordinator.TaskActive);
  AssertFalse(FStates.Items[1].ProtocolReserved);
  AssertFalse(FStates.Items[2].ProtocolReserved);
  AssertFalse(FHost.TableReserved[1]);
  AssertFalse(FHost.TableReserved[2]);
  AssertFalse(FStates.Items[1].CommandPending);
  AssertTrue(StepStatus = sssFailed);
  AssertEquals('Шаг дозаторов остановлен пользователем.', StepError);
end;

procedure TStationProtocolCoordinatorTests.StopRequestedBeforePrepareCompletesStillStops;
begin
  FStep.Start;
  StartProtocolOn([1]);
  FHost.ActiveInitialization := True;
  AssertTrue(FStep.RequestStop);
  CompletePrepare(True);
  FCoordinator.FinishInitializationIfComplete;
  AssertTrue(FCoordinator.TaskActive);
  AssertEquals(1, FHost.Queue.Count);
  FHost.ActiveInitialization := False;
  FCoordinator.FinishInitializationIfComplete;
  AssertFalse(FCoordinator.TaskActive);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(StepStatus = sssFailed);
end;

procedure TStationProtocolCoordinatorTests.InitializationFailureDropsProtocolAndFailsStep;
begin
  FStep.Start;
  StartProtocolOn([1]);
  CompletePrepare(True);
  FHost.ResultFailures.Add('Дозатор 1: нет ответа');
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertFalse(FCoordinator.TaskActive);
  AssertFalse(FStates.Items[1].ProtocolReserved);
  AssertFalse(FHost.TableReserved[1]);
  AssertTrue(StepStatus = sssFailed);
  AssertEquals('Не удалось инициализировать дозаторы.', StepError);
  AssertEquals(1, FHost.Warnings.Count);
end;

procedure TStationProtocolCoordinatorTests.InitializationReportedUnsuccessfulDropsProtocol;
begin
  FStep.Start;
  StartProtocolOn([1]);
  CompletePrepare(True);
  FHost.ResultSuccess := False;
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertFalse(FCoordinator.TaskActive);
  AssertTrue(StepStatus = sssFailed);
  AssertEquals('Не удалось завершить инициализацию дозаторов.',
    FHost.Warnings[0]);
end;

procedure TStationProtocolCoordinatorTests.PrepareTaskFailureReleasesAndFailsStep;
begin
  FStep.Start;
  StartProtocolOn([1, 2]);
  Complete(FHost.QueuedItem(0), False, 'нет связи');
  AssertFalse(FCoordinator.TaskActive);
  AssertFalse(FStates.Items[1].ProtocolReserved);
  AssertFalse(FStates.Items[2].ProtocolReserved);
  AssertFalse(FStates.Items[1].CommandPending);
  AssertFalse(FHost.TablePending[1]);
  AssertFalse(FHost.TableReserved[2]);
  AssertTrue(StepStatus = sssFailed);
  AssertEquals('Не удалось подготовить дозаторы.', StepError);
  AssertEquals('Не удалось подготовить протокол: нет связи',
    FHost.Warnings[0]);
end;

procedure TStationProtocolCoordinatorTests.PrepareTaskFailureKeepsOtherAddressesIntact;
begin
  StartProtocolOn([1]);
  FStates.Items[7].CommandPending := True;
  FHost.TablePending[7] := True;
  Complete(FHost.QueuedItem(0), False, 'сбой');
  AssertTrue(FStates.Items[7].CommandPending);
  AssertTrue(FHost.TablePending[7]);
end;

procedure TStationProtocolCoordinatorTests.StartSuccessClearsTaskActive;
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem.Create(btkStartProtocol);
  try
    Task.ReservedAddresses[1] := True;
    FCoordinator.QueueStopProtocol;
    Complete(Task, True);
    AssertFalse(FCoordinator.TaskActive);
    AssertEquals(1, FHost.Queue.Count);
    AssertEquals(0, FHost.Warnings.Count);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.StartSuccessWithStopRequestQueuesStop;
var
  Task: TFormWorkItem;
begin
  FStep.Start;
  AssertTrue(FStep.RequestStop);
  Task := TFormWorkItem.Create(btkStartProtocol);
  try
    Complete(Task, True);
    AssertTrue(FCoordinator.TaskActive);
    AssertEquals(1, FHost.Queue.Count);
    AssertTrue(FHost.QueuedItem(0).WorkKind = btkStopProtocol);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.StartFailureReleasesTaskReservations;
begin
  StartProtocolOn([1, 2], True);
  FStates.Items[9].ProtocolReserved := True;
  FHost.TableReserved[9] := True;
  Complete(FHost.QueuedItem(0), False, 'ошибка');
  AssertFalse(FStates.Items[1].ProtocolReserved);
  AssertFalse(FStates.Items[2].ProtocolReserved);
  AssertFalse(FHost.TableReserved[1]);
  AssertFalse(FHost.TableReserved[2]);
  AssertTrue(FStates.Items[9].ProtocolReserved);
  AssertTrue(FHost.TableReserved[9]);
end;

procedure TStationProtocolCoordinatorTests.StartFailureFailsStepWithMessage;
var
  Task: TFormWorkItem;
begin
  FStep.Start;
  FStates.Items[1].ProtocolReserved := True;
  FHost.TableReserved[1] := True;
  Task := TFormWorkItem.Create(btkStartProtocol);
  try
    Task.ReservedAddresses[1] := True;
    Complete(Task, False, 'порт закрыт');
    AssertFalse(FStates.Items[1].ProtocolReserved);
    AssertFalse(FHost.TableReserved[1]);
    AssertTrue(StepStatus = sssFailed);
    AssertEquals('Не удалось запустить протокол: порт закрыт', StepError);
    AssertEquals('Не удалось запустить протокол: порт закрыт',
      FHost.Warnings[0]);
    AssertFalse(FCoordinator.TaskActive);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.StopProtocolCompletionClearsTaskActive;
begin
  FCoordinator.QueueStopProtocol;
  AssertTrue(FCoordinator.TaskActive);
  Complete(FHost.QueuedItem(0), True);
  AssertFalse(FCoordinator.TaskActive);
  AssertEquals(0, FHost.Warnings.Count);
end;

procedure TStationProtocolCoordinatorTests.StopProtocolFailureWarns;
begin
  FCoordinator.QueueStopProtocol;
  Complete(FHost.QueuedItem(0), False, 'нет ответа');
  AssertFalse(FCoordinator.TaskActive);
  AssertEquals('нет ответа', FHost.Warnings[0]);
end;

procedure TStationProtocolCoordinatorTests.StopAllCompletionClearsPendingAndTaskActive;
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem.Create(btkStopAll);
  try
    Task.ReservedAddresses[2] := True;
    FStates.Items[2].CommandPending := True;
    FHost.TablePending[2] := True;
    FCoordinator.MarkStopAllQueued(True);
    Complete(Task, True);
    AssertFalse(FCoordinator.TaskActive);
    AssertFalse(FStates.Items[2].CommandPending);
    AssertFalse(FHost.TablePending[2]);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.QueueStopProtocolMarksTaskActive;
begin
  FCoordinator.QueueStopProtocol(4);
  AssertTrue(FCoordinator.TaskActive);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).WorkKind = btkStopProtocol);
  AssertEquals(4, FHost.QueuedItem(0).Address);
end;

procedure TStationProtocolCoordinatorTests.MarkStopAllQueuedFollowsRunner;
begin
  FCoordinator.MarkStopAllQueued(True);
  AssertTrue(FCoordinator.TaskActive);
  FCoordinator.MarkStopAllQueued(False);
  AssertFalse(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.ReleaseProtocolReservationsClearsStatesAndTable;
begin
  StartProtocolOn([1, 2]);
  FCoordinator.ReleaseProtocolReservations;
  AssertFalse(FStates.Items[1].ProtocolReserved);
  AssertFalse(FStates.Items[2].ProtocolReserved);
  AssertFalse(FHost.TableReserved[1]);
  AssertFalse(FHost.TableReserved[2]);
  // Повторный вызов безопасен.
  FCoordinator.ReleaseProtocolReservations;
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationMarksPending;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).WorkKind = btkInitialize);
  AssertTrue(FHost.QueuedItem(0).ReservedAddresses[3]);
  AssertTrue(FStates.Items[3].CommandPending);
  AssertTrue(FHost.TablePending[3]);
  AssertFalse(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationCompletesAndReleasesPending;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FCoordinator.FinishInitializationIfComplete;
  AssertFalse(FStates.Items[3].CommandPending);
  AssertFalse(FHost.TablePending[3]);
  AssertTrue(FHost.VolumeRefreshes > 0);
  AssertEquals('Инициализация всех запущенных дозаторов завершена',
    FHost.LogLines[0]);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationWaitsForAddressToFinish;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FHost.InitializingAddress[3] := True;
  FHost.ActiveInitialization := True;
  FCoordinator.FinishInitializationIfComplete;
  AssertTrue(FStates.Items[3].CommandPending);
  AssertEquals(0, FHost.LogLines.Count);
  FHost.InitializingAddress[3] := False;
  FHost.ActiveInitialization := False;
  FCoordinator.FinishInitializationIfComplete;
  AssertFalse(FStates.Items[3].CommandPending);
  AssertEquals(1, FHost.LogLines.Count);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationWaitsForQueuedInitTask;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FHost.PendingInitAddress[3] := True;
  FHost.PendingInitAny := True;
  FCoordinator.FinishInitializationIfComplete;
  AssertTrue(FStates.Items[3].CommandPending);
  FHost.PendingInitAddress[3] := False;
  FHost.PendingInitAny := False;
  FCoordinator.FinishInitializationIfComplete;
  AssertFalse(FStates.Items[3].CommandPending);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationTaskFailureClearsPending;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), False, 'нет порта');
  AssertFalse(FStates.Items[3].CommandPending);
  AssertFalse(FHost.TablePending[3]);
  AssertEquals('Не удалось выполнить инициализацию: нет порта',
    FHost.Warnings[0]);
  // Дальше таймер не должен ничего делать по этому адресу.
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(0, FHost.LogLines.Count);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationReportsFailures;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FHost.ResultFailures.Add('Дозатор 3: ошибка');
  FHost.ResultSuccess := False;
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Warnings.Count);
  AssertEquals(0, FHost.LogLines.Count);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationDoesNotQueueProtocol;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertFalse(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.FinishDoesNothingWithoutActivity;
begin
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(0, FHost.Queue.Count);
  AssertEquals(0, FHost.LogLines.Count);
  AssertEquals(0, FHost.Warnings.Count);
  AssertEquals(0, FHost.UiUpdates);
end;

procedure TStationProtocolCoordinatorTests.SecondPrepareAfterFailureIsPossible;
begin
  FStep.Start;
  StartProtocolOn([1]);
  Complete(FHost.QueuedItem(0), False, 'сбой');
  FHost.Queue.Clear;
  StartProtocolOn([1]);
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).WorkKind = btkPrepareProtocol);
  AssertTrue(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.PendingProtocolIsKeptUntilInitializationEnds;
begin
  StartProtocolOn([1]);
  CompletePrepare(True);
  // Протокол ждёт внутри координатора; освободит его деструктор в TearDown.
  AssertEquals(1, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(0).Protocol = nil);
  AssertTrue(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.InitializeFailureWithFailuresListWarnsWithList;
var
  Targets: TDispenserConfigList;
  Task: TFormWorkItem;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Task := FHost.QueuedItem(0);
  Task.Failures := TStringList.Create;
  Task.Failures.Add('Дозатор 3: нет ответа');
  Complete(Task, False, 'x');
  AssertEquals(1, FHost.Warnings.Count);
  AssertTrue(Pos('Не удалось запустить инициализацию:', FHost.Warnings[0]) = 1);
  AssertTrue(Pos('Дозатор 3: нет ответа', FHost.Warnings[0]) > 0);
  AssertFalse(FStates.Items[3].CommandPending);
end;

procedure TStationProtocolCoordinatorTests.PrepareFailureWithFailuresListWarnsWithList;
var
  Task: TFormWorkItem;
begin
  StartProtocolOn([1]);
  Task := FHost.QueuedItem(0);
  Task.Failures := TStringList.Create;
  Task.Failures.Add('Дозатор 1: нет ответа');
  Complete(Task, False, 'x');
  AssertEquals(1, FHost.Warnings.Count);
  AssertTrue(Pos('Не удалось запустить инициализацию дозаторов протокола:',
    FHost.Warnings[0]) = 1);
  AssertTrue(Pos('Дозатор 1: нет ответа', FHost.Warnings[0]) > 0);
end;

procedure TStationProtocolCoordinatorTests.InitializationFailuresWithSuccessFlagStillFailProtocol;
begin
  FStep.Start;
  StartProtocolOn([1]);
  CompletePrepare(True);
  FHost.ResultFailures.Add('Дозатор 1: ошибка');
  FHost.ResultSuccess := True;
  FCoordinator.FinishInitializationIfComplete;
  AssertEquals(1, FHost.Queue.Count);
  AssertFalse(FCoordinator.TaskActive);
  AssertTrue(StepStatus = sssFailed);
  AssertTrue(Pos('Не удалось инициализировать дозаторы:',
    FHost.Warnings[0]) = 1);
end;

procedure TStationProtocolCoordinatorTests.ManualInitializationDuringPreparationKeepsProtocol;
var
  Targets: TDispenserConfigList;
begin
  // Протокол ждёт подготовки дозатора 1; параллельно вручную инициализируют 5.
  FStep.Start;
  StartProtocolOn([1]);
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(5).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  Complete(FHost.QueuedItem(1), True);
  FCoordinator.FinishInitializationIfComplete;
  // Общий итог считается инициализацией протокола: запуск поставлен.
  AssertEquals(3, FHost.Queue.Count);
  AssertTrue(FHost.QueuedItem(2).WorkKind = btkStartProtocol);
  AssertTrue(FHost.QueuedItem(2).Protocol <> nil);
  AssertFalse(FStates.Items[5].CommandPending);
  AssertTrue(FCoordinator.TaskActive);
end;

procedure TStationProtocolCoordinatorTests.HandleCompletedIgnoresForeignKinds;
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem.Create(btkPoll);
  try
    FCoordinator.QueueStopProtocol;
    Complete(Task, False, 'ошибка опроса');
    AssertTrue(FCoordinator.TaskActive);
    AssertEquals(0, FHost.Warnings.Count);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.StartFailureWithStopRequestOnlyFailsStep;
var
  Task: TFormWorkItem;
begin
  FStep.Start;
  AssertTrue(FStep.RequestStop);
  Task := TFormWorkItem.Create(btkStartProtocol);
  try
    Complete(Task, False, 'сбой');
    AssertFalse(FCoordinator.TaskActive);
    AssertEquals(0, FHost.Queue.Count);
    AssertTrue(StepStatus = sssFailed);
  finally
    Task.Free;
  end;
end;

procedure TStationProtocolCoordinatorTests.FinishRequestsUiUpdateWhenAddressReleased;
var
  Targets: TDispenserConfigList;
begin
  Targets := TDispenserConfigList.Create;
  Targets.Add(MakeConfig(3).Clone);
  FCoordinator.QueueInitialization(Targets);
  Complete(FHost.QueuedItem(0), True);
  FCoordinator.FinishInitializationIfComplete;
  AssertTrue(FHost.UiUpdates > 0);
end;

initialization
  RegisterTest(TStationProtocolCoordinatorTests);

end.
