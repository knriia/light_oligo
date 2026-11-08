unit StationProtocolCoordinator;
// Жизненный цикл запуска протокола станции и инициализации дозаторов:
// резервы, подготовка (инициализация) перед запуском, отложенный запуск,
// остановка и обработка завершённых рабочих элементов. Не знает про виджеты:
// форма реализует IStationProtocolHost. Используется только из потока UI.

{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses
  Classes, SysUtils, DispenserConfig, DispenserLimits, DispenserRuntimeState,
  DispenserTypes, AutomationProtocol, ProtocolStartPlan, StationWork,
  SyringeStepTracker;

type
  IStationProtocolHost = interface
    ['IStationProtocolHost']
    function Configurations: TDispenserConfigList;
    function HasActiveInitialization: Boolean;
    function IsAddressInitializing(AAddress: Integer): Boolean;
    procedure GetInitializationResults(AFailures: TStrings;
      out ASuccess: Boolean);
    // Есть ли в очереди ещё не обработанная инициализация; AAddress = 0 - любая.
    function HasPendingInitializationTask(AAddress: Integer): Boolean;
    // Хозяин принимает рабочий элемент в любом случае.
    procedure QueueWorkItem(ATask: TFormWorkItem);
    procedure SetProtocolReserved(AAddress: Integer; AReserved: Boolean);
    procedure SetCommandPending(AAddress: Integer; APending: Boolean);
    procedure SetBypassSupported(AAddress: Integer; AEnabled: Boolean);
    procedure RefreshCurrentVolumes;
    procedure UpdateUI;
    procedure Log(const AMessage: string);
    procedure ShowOperationWarning(const AMessage: string);
  end;

  TStationProtocolCoordinator = class
  private
    FHost: IStationProtocolHost;
    FStates: TDispenserRuntimeStates;
    FSyringeStep: TSyringeStepTracker;
    FTaskActive: Boolean;
    FInitializationUiPending: Boolean;
    FPendingProtocol: TAutomationProtocol;
    FInitializingAddresses: array[MIN_DISPENSER_VALUE..
      MAX_DISPENSER_VALUE] of Boolean;
    FProtocolReserved: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    procedure ClearInitializingAddresses(ATask: TFormWorkItem);
    procedure ReleaseTaskReservations(ATask: TFormWorkItem);
    procedure QueuePendingProtocol;
    procedure HandleInitialize(ATask: TFormWorkItem);
    procedure HandlePrepareProtocol(ATask: TFormWorkItem);
    procedure HandleStopAll(ATask: TFormWorkItem);
    procedure HandleStartProtocol(ATask: TFormWorkItem);
    procedure HandleStopProtocol(ATask: TFormWorkItem);
  public
    // AStates и ASyringeStep принадлежат вызывающему и должны пережить
    // координатор.
    constructor Create(AHost: IStationProtocolHost;
      AStates: TDispenserRuntimeStates; ASyringeStep: TSyringeStepTracker);
    destructor Destroy; override;
    // Ставит инициализацию дозаторов; координатор становится владельцем
    // ATargets (вызывающий обнуляет ссылку).
    procedure QueueInitialization(ATargets: TDispenserConfigList);
    // Резервирует дозаторы плана и ставит подготовку/запуск. Владелец
    // AProtocol — координатор (вызывающий обнуляет ссылку). План должен
    // быть ppsReady; список инициализации забирается из плана.
    procedure QueueProtocolStart(AProtocol: TAutomationProtocol;
      APlan: TProtocolStartPlan);
    // Ставит остановку протокола; AAddress - дозатор, с которого её запросили.
    procedure QueueStopProtocol(AAddress: Integer = 0);
    // Остановка всего поставлена в очередь; ARunnerRunning - идёт ли протокол.
    procedure MarkStopAllQueued(ARunnerRunning: Boolean);
    // Обрабатывает завершённый рабочий элемент подготовки/запуска/остановки
    // протокола и инициализации; для остальных видов ничего не делает.
    procedure HandleCompleted(ATask: TFormWorkItem);
    // Вызывать по таймеру: завершает инициализацию и ставит отложенный запуск.
    procedure FinishInitializationIfComplete;
    // Снимает резервы протокола (протокол завершился или не стартовал).
    procedure ReleaseProtocolReservations;
    property TaskActive: Boolean read FTaskActive;
  end;

implementation

constructor TStationProtocolCoordinator.Create(AHost: IStationProtocolHost;
  AStates: TDispenserRuntimeStates; ASyringeStep: TSyringeStepTracker);
var
  Address: Integer;
begin
  inherited Create;
  FHost := AHost;
  FStates := AStates;
  FSyringeStep := ASyringeStep;
  FTaskActive := False;
  FInitializationUiPending := False;
  FPendingProtocol := nil;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    FInitializingAddresses[Address] := False;
    FProtocolReserved[Address] := False;
  end;
end;

destructor TStationProtocolCoordinator.Destroy;
begin
  FPendingProtocol.Free;
  FPendingProtocol := nil;
  inherited Destroy;
end;

procedure TStationProtocolCoordinator.QueueInitialization(
  ATargets: TDispenserConfigList);
var
  Task: TFormWorkItem;
  Config: TDispenserConfig;
  I: Integer;
begin
  Task := TFormWorkItem.Create(btkInitialize);
  Task.Configs := ATargets;
  for I := 0 to Task.Configs.Count - 1 do
  begin
    Config := Task.Configs[I];
    FStates.Items[Config.Address].CommandPending := True;
    FHost.SetCommandPending(Config.Address, True);
    Task.ReservedAddresses[Config.Address] := True;
    FInitializingAddresses[Config.Address] := True;
  end;
  FHost.QueueWorkItem(Task);
end;

procedure TStationProtocolCoordinator.QueueProtocolStart(
  AProtocol: TAutomationProtocol; APlan: TProtocolStartPlan);
var
  Task: TFormWorkItem;
  Address: Integer;
  I: Integer;
begin
  if APlan.InitializationTargets.Count > 0 then
  begin
    Task := TFormWorkItem.Create(btkPrepareProtocol);
    Task.Configs := APlan.TakeInitializationTargets;
  end
  else
    Task := TFormWorkItem.Create(btkStartProtocol);
  Task.Protocol := AProtocol;
  for I := 0 to APlan.Targets.Count - 1 do
  begin
    Address := APlan.Targets[I].Address;
    Task.ReservedAddresses[Address] := True;
    FProtocolReserved[Address] := True;
    FStates.Items[Address].ProtocolReserved := True;
    FHost.SetProtocolReserved(Address, True);
  end;
  if Task.WorkKind = btkPrepareProtocol then
    for I := 0 to Task.Configs.Count - 1 do
    begin
      Address := Task.Configs[I].Address;
      FStates.Items[Address].CommandPending := True;
      FInitializingAddresses[Address] := True;
      FHost.SetCommandPending(Address, True);
    end;
  FTaskActive := True;
  FHost.QueueWorkItem(Task);
end;

procedure TStationProtocolCoordinator.QueueStopProtocol(AAddress: Integer);
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem.Create(btkStopProtocol);
  Task.Address := AAddress;
  FTaskActive := True;
  FHost.QueueWorkItem(Task);
end;

procedure TStationProtocolCoordinator.MarkStopAllQueued(
  ARunnerRunning: Boolean);
begin
  FTaskActive := ARunnerRunning;
end;

// Снимает признак инициализации и CommandPending с адресов неудавшейся задачи.
procedure TStationProtocolCoordinator.ClearInitializingAddresses(
  ATask: TFormWorkItem);
var
  Address: Integer;
  State: TDispenserRuntimeState;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if ATask.ReservedAddresses[Address] then
    begin
      FInitializingAddresses[Address] := False;
      State := FStates.Items[Address];
      if State <> nil then
        State.CommandPending := False;
      FHost.SetCommandPending(Address, False);
    end;
end;

// Снимает резервы протокола только с адресов задачи.
procedure TStationProtocolCoordinator.ReleaseTaskReservations(
  ATask: TFormWorkItem);
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if ATask.ReservedAddresses[Address] then
    begin
      FStates.Items[Address].ProtocolReserved := False;
      FHost.SetProtocolReserved(Address, False);
      FProtocolReserved[Address] := False;
    end;
end;

procedure TStationProtocolCoordinator.ReleaseProtocolReservations;
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FProtocolReserved[Address] then
    begin
      FStates.Items[Address].ProtocolReserved := False;
      FHost.SetProtocolReserved(Address, False);
      FProtocolReserved[Address] := False;
    end;
end;

procedure TStationProtocolCoordinator.QueuePendingProtocol;
var
  Address: Integer;
  Task: TFormWorkItem;
begin
  if FPendingProtocol = nil then
  begin
    FTaskActive := False;
    ReleaseProtocolReservations;
    Exit;
  end;

  if FSyringeStep.StopRequested then
  begin
    // Синтез остановлен во время инициализации: протокол не запускаем.
    FreeAndNil(FPendingProtocol);
    FTaskActive := False;
    ReleaseProtocolReservations;
    FSyringeStep.Finish(True, 'Шаг дозаторов остановлен пользователем.');
    FHost.Log('Шаг дозаторов остановлен до запуска.');
    Exit;
  end;

  Task := TFormWorkItem.Create(btkStartProtocol);
  Task.Protocol := FPendingProtocol;
  FPendingProtocol := nil;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FProtocolReserved[Address] then
      Task.ReservedAddresses[Address] := True;
  FHost.QueueWorkItem(Task);
end;

procedure TStationProtocolCoordinator.FinishInitializationIfComplete;
var
  Address: Integer;
  I: Integer;
  Configs: TDispenserConfigList;
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
  Failures: TStringList;
  Success: Boolean;
  ReleasedAddress: Boolean;
  IsProtocolInitialization: Boolean;
begin
  ReleasedAddress := False;
  Configs := FHost.Configurations;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    if not FInitializingAddresses[Address] or
      FHost.IsAddressInitializing(Address) or
      FHost.HasPendingInitializationTask(Address) then
      Continue;

    FInitializingAddresses[Address] := False;
    State := FStates.Items[Address];
    Config := nil;
    if Configs <> nil then
      for I := 0 to Configs.Count - 1 do
        if Configs[I].Address = Address then
        begin
          Config := Configs[I];
          Break;
        end;
    if State <> nil then
    begin
      State.CommandPending := False;
      FHost.SetBypassSupported(Address,
        State.IsInitializedFor(Config) and
        (State.ValveType = dvtNonDistributive));
    end;
    FHost.SetCommandPending(Address, False);
    ReleasedAddress := True;
  end;

  if ReleasedAddress then
  begin
    FHost.RefreshCurrentVolumes;
    FHost.UpdateUI;
  end;

  if not FInitializationUiPending or
    FHost.HasActiveInitialization or
    FHost.HasPendingInitializationTask(0) then
    Exit;

  Failures := TStringList.Create;
  try
    FHost.GetInitializationResults(Failures, Success);
    IsProtocolInitialization := FPendingProtocol <> nil;
    FInitializationUiPending := False;
    FHost.RefreshCurrentVolumes;

    if Failures.Count > 0 then
      FHost.ShowOperationWarning('Не удалось инициализировать дозаторы:' +
        LineEnding + Failures.Text)
    else if not Success then
      FHost.ShowOperationWarning('Не удалось завершить инициализацию дозаторов.')
    else if IsProtocolInitialization then
      FHost.Log('Дозаторы протокола готовы; запуск протокола поставлен в очередь.')
    else
      FHost.Log('Инициализация всех запущенных дозаторов завершена');

    if IsProtocolInitialization then
    begin
      if Success and (Failures.Count = 0) then
        QueuePendingProtocol
      else
      begin
        FreeAndNil(FPendingProtocol);
        FTaskActive := False;
        ReleaseProtocolReservations;
        FSyringeStep.Finish(True, 'Не удалось инициализировать дозаторы.');
      end;
    end;
    FHost.UpdateUI;
  finally
    Failures.Free;
  end;
end;

procedure TStationProtocolCoordinator.HandleCompleted(ATask: TFormWorkItem);
begin
  case ATask.WorkKind of
    btkInitialize: HandleInitialize(ATask);
    btkPrepareProtocol: HandlePrepareProtocol(ATask);
    btkStopAll: HandleStopAll(ATask);
    btkStartProtocol: HandleStartProtocol(ATask);
    btkStopProtocol: HandleStopProtocol(ATask);
  end;
end;

procedure TStationProtocolCoordinator.HandleInitialize(ATask: TFormWorkItem);
begin
  if ATask.Success then
    FInitializationUiPending := True
  else
  begin
    ClearInitializingAddresses(ATask);
    if (ATask.Failures <> nil) and (ATask.Failures.Count > 0) then
      FHost.ShowOperationWarning('Не удалось запустить инициализацию:' +
        LineEnding + ATask.Failures.Text)
    else
      FHost.ShowOperationWarning('Не удалось выполнить инициализацию: ' +
        ATask.ErrorText);
  end;
end;

procedure TStationProtocolCoordinator.HandlePrepareProtocol(
  ATask: TFormWorkItem);
begin
  if ATask.Success then
  begin
    FPendingProtocol := ATask.Protocol;
    ATask.Protocol := nil;
    FInitializationUiPending := True;
  end
  else
  begin
    ClearInitializingAddresses(ATask);
    FTaskActive := False;
    ReleaseProtocolReservations;
    FSyringeStep.Finish(True, 'Не удалось подготовить дозаторы.');
    if (ATask.Failures <> nil) and (ATask.Failures.Count > 0) then
      FHost.ShowOperationWarning(
        'Не удалось запустить инициализацию дозаторов протокола:' +
        LineEnding + ATask.Failures.Text)
    else
      FHost.ShowOperationWarning('Не удалось подготовить протокол: ' +
        ATask.ErrorText);
  end;
end;

procedure TStationProtocolCoordinator.HandleStopAll(ATask: TFormWorkItem);
var
  Address: Integer;
begin
  FTaskActive := False;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if ATask.ReservedAddresses[Address] then
    begin
      FStates.Items[Address].CommandPending := False;
      FHost.SetCommandPending(Address, False);
    end;
  if not ATask.Success and (ATask.ErrorText <> '') then
    FHost.ShowOperationWarning(ATask.ErrorText);
end;

procedure TStationProtocolCoordinator.HandleStartProtocol(
  ATask: TFormWorkItem);
begin
  FTaskActive := False;
  if not ATask.Success then
  begin
    ReleaseTaskReservations(ATask);
    FSyringeStep.Finish(True, 'Не удалось запустить протокол: ' +
      ATask.ErrorText);
    FHost.ShowOperationWarning('Не удалось запустить протокол: ' +
      ATask.ErrorText);
  end
  else if FSyringeStep.StopRequested then
    // Остановку запросили, пока протокол ставился в очередь.
    QueueStopProtocol;
end;

procedure TStationProtocolCoordinator.HandleStopProtocol(
  ATask: TFormWorkItem);
begin
  FTaskActive := False;
  if not ATask.Success and (ATask.ErrorText <> '') then
    FHost.ShowOperationWarning(ATask.ErrorText);
end;

end.
