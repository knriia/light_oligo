unit StationWorkTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, CoordinatorTests, DispenserConfig, DispenserConnectionCoordinator,
  DispenserOperationCoordinator, DispenserRuntimeState, DispenserTypes,
  AutomationProtocolRunner, AutomationProtocol, StationWork,
  StationWorkExecutor;

type
  TRaisingController = class(TMockDispenserController)
  protected
    function GetIsConnected: Boolean; override;
  end;

  TStationWorkTests = class(TTestCase)
  private
    FController: TMockDispenserController;
    FStates: TDispenserRuntimeStates;
    FConnection: TDispenserConnectionCoordinator;
    FOperations: TDispenserOperationCoordinator;
    FRunner: TAutomationProtocolRunner;
    FExecutor: TStationWorkExecutor;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NewItemIsNotCompletedAndHasFailureDefaults;
    procedure MarkCompletedMakesItemCompleted;
    procedure DisconnectSucceedsAndCompletes;
    procedure FailedConnectReportsResult;
    procedure PollSucceeds;
    procedure StopProtocolSucceeds;
    procedure ExceptionBecomesFailureAndCompletes;
    procedure BypassFailureReturnsControllerError;
    procedure StopAllSucceedsWhenRunnerIdle;
    procedure StopAllWithoutConnectionFails;
    procedure InitializeCreatesFailureList;
    procedure PrepareProtocolCreatesFailureList;
    procedure FailedStartProtocolKeepsProtocolOwnership;
    procedure ScanPortsCreatesPortList;
  end;

implementation

function TRaisingController.GetIsConnected: Boolean;
begin
  raise Exception.Create('boom');
end;

procedure TStationWorkTests.SetUp;
begin
  inherited SetUp;
  FController := TMockDispenserController.Create;
  FStates := TDispenserRuntimeStates.Create;
  FController.RuntimeStates := FStates;
  FConnection := TDispenserConnectionCoordinator.Create(FController, FStates);
  FOperations := TDispenserOperationCoordinator.Create(FController, FStates);
  FRunner := TAutomationProtocolRunner.Create(FController, FStates);
  FExecutor := TStationWorkExecutor.Create(FController, FConnection,
    FOperations, FRunner);
end;

procedure TStationWorkTests.TearDown;
begin
  FExecutor.Free;
  FRunner.Free;
  FOperations.Free;
  FConnection.Free;
  FStates.Free;
  FController.Free;
  inherited TearDown;
end;

procedure TStationWorkTests.NewItemIsNotCompletedAndHasFailureDefaults;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkConnect);
  try
    AssertFalse(Item.IsCompleted);
    AssertTrue(Item.WorkKind = btkConnect);
    AssertTrue(Item.SingleResult = dosrCommandFailed);
    AssertTrue(Item.GroupResult = dgsRejected);
    AssertTrue(Item.ConnectionResult = dcrPortOpenFailed);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.MarkCompletedMakesItemCompleted;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkPoll);
  try
    Item.MarkCompleted;
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.DisconnectSucceedsAndCompletes;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkDisconnect);
  try
    FExecutor.Execute(Item);
    AssertTrue(Item.Success);
    AssertTrue(Item.IsCompleted);
    AssertEquals(1, FController.DisconnectCalls);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.FailedConnectReportsResult;
var
  Item: TFormWorkItem;
begin
  FController.ConnectResult := False;
  FController.LastErrorText := 'порт недоступен';
  Item := TFormWorkItem.Create(btkConnect);
  try
    Item.PortName := 'COM1';
    FExecutor.Execute(Item);
    AssertFalse(Item.Success);
    AssertTrue(Item.ConnectionResult = dcrPortOpenFailed);
    AssertEquals('порт недоступен', Item.ErrorText);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.PollSucceeds;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkPoll);
  try
    FExecutor.Execute(Item);
    AssertTrue(Item.Success);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.StopProtocolSucceeds;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkStopProtocol);
  try
    FExecutor.Execute(Item);
    AssertTrue(Item.Success);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.ExceptionBecomesFailureAndCompletes;
var
  Raising: TRaisingController;
  States: TDispenserRuntimeStates;
  Connection: TDispenserConnectionCoordinator;
  Executor: TStationWorkExecutor;
  Item: TFormWorkItem;
begin
  Raising := TRaisingController.Create;
  States := TDispenserRuntimeStates.Create;
  Connection := TDispenserConnectionCoordinator.Create(Raising, States);
  Executor := TStationWorkExecutor.Create(Raising, Connection, FOperations,
    FRunner);
  Item := TFormWorkItem.Create(btkConnect);
  try
    Item.PortName := 'COM1';
    Executor.Execute(Item);
    AssertFalse(Item.Success);
    AssertEquals('boom', Item.ErrorText);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
    Executor.Free;
    Connection.Free;
    States.Free;
    Raising.Free;
  end;
end;

procedure TStationWorkTests.BypassFailureReturnsControllerError;
var
  Item: TFormWorkItem;
begin
  FController.LastErrorText := 'ошибка bypass';
  Item := TFormWorkItem.Create(btkBypass);
  try
    Item.Address := 0;
    Item.Channel := 1;
    FExecutor.Execute(Item);
    AssertFalse(Item.Success);
    AssertEquals('ошибка bypass', Item.ErrorText);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.StopAllSucceedsWhenRunnerIdle;
var
  Item: TFormWorkItem;
begin
  FController.Connected := True;
  Item := TFormWorkItem.Create(btkStopAll);
  try
    FExecutor.Execute(Item);
    AssertTrue(Item.Success);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.StopAllWithoutConnectionFails;
var
  Item: TFormWorkItem;
begin
  FController.Connected := False;
  Item := TFormWorkItem.Create(btkStopAll);
  try
    FExecutor.Execute(Item);
    AssertFalse(Item.Success);
    AssertTrue(Item.ErrorText <> '');
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.InitializeCreatesFailureList;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkInitialize);
  try
    Item.Configs := TDispenserConfigList.Create;
    FExecutor.Execute(Item);
    AssertTrue(Item.Failures <> nil);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.PrepareProtocolCreatesFailureList;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkPrepareProtocol);
  try
    Item.Configs := TDispenserConfigList.Create;
    FExecutor.Execute(Item);
    AssertTrue(Item.Failures <> nil);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.FailedStartProtocolKeepsProtocolOwnership;
var
  Item: TFormWorkItem;
begin
  FController.Connected := False;
  Item := TFormWorkItem.Create(btkStartProtocol);
  try
    Item.Protocol := TAutomationProtocol.Create;
    FExecutor.Execute(Item);
    AssertFalse(Item.Success);
    AssertTrue(Item.Protocol <> nil);
    AssertTrue(Item.ErrorText <> '');
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

procedure TStationWorkTests.ScanPortsCreatesPortList;
var
  Item: TFormWorkItem;
begin
  Item := TFormWorkItem.Create(btkScanPorts);
  try
    FExecutor.Execute(Item);
    AssertTrue(Item.Success);
    AssertTrue(Item.PortList <> nil);
    AssertTrue(Item.IsCompleted);
  finally
    Item.Free;
  end;
end;

initialization
  RegisterTest(TStationWorkTests);
end.
