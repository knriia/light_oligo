unit StationWorkExecutor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DispenserController, DispenserConnectionCoordinator,
  DispenserOperationCoordinator, DispenserTypes, AutomationProtocolRunner,
  StationWork;

type
  // Выполняет рабочие элементы станции в фоновом потоке. Ссылки не принадлежат
  // исполнителю; владелец обязан остановить очередь раньше, чем освободит их.
  TStationWorkExecutor = class
  private
    FDispenser: TDispenserController;
    FConnection: TDispenserConnectionCoordinator;
    FOperations: TDispenserOperationCoordinator;
    FRunner: TAutomationProtocolRunner;
  public
    constructor Create(ADispenser: TDispenserController;
      AConnection: TDispenserConnectionCoordinator;
      AOperations: TDispenserOperationCoordinator;
      ARunner: TAutomationProtocolRunner);
    procedure Execute(AWorkItem: TObject);
  end;

implementation

constructor TStationWorkExecutor.Create(ADispenser: TDispenserController;
  AConnection: TDispenserConnectionCoordinator;
  AOperations: TDispenserOperationCoordinator;
  ARunner: TAutomationProtocolRunner);
begin
  inherited Create;
  FDispenser := ADispenser;
  FConnection := AConnection;
  FOperations := AOperations;
  FRunner := ARunner;
end;

procedure TStationWorkExecutor.Execute(AWorkItem: TObject);
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem(AWorkItem);
  Task.Success := False;
  Task.ErrorText := '';
  try
    case Task.WorkKind of
    btkStartSingle:
      begin
        Task.SingleResult := FOperations.StartSingle(Task.Config,
          Task.OperationKind, Task.Channel, Task.BypassEnabled, Task.ErrorText);
        Task.Success := Task.SingleResult = dosrStarted;
      end;
    btkStartGroup:
      begin
        Task.GroupResult := FOperations.StartGroup(
          Task.OperationKind, Task.Requests, Task.ErrorText);
        Task.Success := Task.GroupResult = dgsStarted;
      end;
    btkInitialize:
      begin
        Task.Failures := TStringList.Create;
        Task.Success := FConnection.InitializeDispensers(
          Task.Configs, Task.Failures);
      end;
    btkPrepareProtocol:
      begin
        Task.Failures := TStringList.Create;
        Task.Success := FConnection.InitializeDispensers(
          Task.Configs, Task.Failures);
      end;
    btkPoll:
      begin
        if FRunner.IsRunning then
          FRunner.Poll;
        if not FRunner.IsRunning then
        begin
          FOperations.PollNextOperation;
          FOperations.PollNextProtocolOperation;
        end;
        FConnection.PollInitialization;
        Task.Success := True;
      end;
    btkBypass:
      begin
        Task.Success := FDispenser.SetBypass(Task.Address, Task.Channel,
          Task.BypassEnabled, Task.BypassValveType);
        if not Task.Success then
          Task.ErrorText := FDispenser.LastError;
      end;
    btkChangeSpeed:
      Task.Success := FOperations.ChangeActiveSpeed(Task.Config,
        Task.Speed, Task.ErrorText);
    btkStopOne:
      Task.Success := FOperations.StopActiveOperation(Task.Address,
        Task.ErrorText);
    btkStopAll:
      begin
        if FRunner.IsRunning then
          FRunner.Stop;
        Task.Success := FOperations.StopAllActiveOperations(
          Task.ErrorText);
      end;
    btkStartProtocol:
      begin
        Task.Success := FRunner.Start(Task.Protocol,
          Task.ErrorText, True);
        if Task.Success then
          Task.Protocol := nil;
      end;
    btkStopProtocol:
      begin
        FRunner.Stop;
        Task.Success := True;
      end;
    btkConnect:
      begin
        Task.ConnectionResult := FConnection.ConnectPort(
          Task.PortName, Task.ErrorText);
        Task.Success := Task.ConnectionResult = dcrConnected;
      end;
    btkDisconnect:
      begin
        FConnection.Disconnect;
        Task.Success := True;
      end;
    btkScanPorts:
      begin
        Task.PortList := TStringList.Create;
        FDispenser.ScanPorts(Task.PortList);
        Task.Success := True;
      end;
    end;
  except
    on E: Exception do
    begin
      Task.Success := False;
      Task.ErrorText := E.Message;
    end;
  end;
  Task.MarkCompleted;
end;

end.
