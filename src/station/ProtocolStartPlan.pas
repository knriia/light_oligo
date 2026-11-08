unit ProtocolStartPlan;
// Планирование запуска протокола станции: по протоколу и состояниям дозаторов
// определяет, какие дозаторы нужно зарезервировать и какие инициализировать,
// либо причину отказа. Ничего не меняет и не знает про UI и очередь задач.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DispenserConfig, DispenserRuntimeState,
  AutomationProtocol;

type
  TProtocolStartPlanStatus = (ppsReady, ppsStateUnavailable, ppsDispenserBusy);

  TProtocolStartPlan = class
  private
    FStatus: TProtocolStartPlanStatus;
    FErrorText: string;
    FTargets: TDispenserConfigList;
    FInitializationTargets: TDispenserConfigList;
    FInitializationDescriptions: TStringList;
    procedure Reject(AStatus: TProtocolStartPlanStatus;
      const AErrorText: string);
  public
    constructor Create;
    destructor Destroy; override;
    // Передаёт список на инициализацию вызывающему; план его больше не держит,
    // InitializationTargets после вызова равен nil. Вызывать не более одного
    // раза и только при Status = ppsReady.
    function TakeInitializationTargets: TDispenserConfigList;
    property Status: TProtocolStartPlanStatus read FStatus;
    // Заполнен только при Status <> ppsReady; при отказе списки ниже пусты.
    property ErrorText: string read FErrorText;
    // Все дозаторы протокола, по одному на адрес (копии конфигураций).
    property Targets: TDispenserConfigList read FTargets;
    // Дозаторы, которые нужно инициализировать перед запуском (копии).
    property InitializationTargets: TDispenserConfigList
      read FInitializationTargets;
    // Строки «- имя (адрес N)» для диалога подтверждения.
    property InitializationDescriptions: TStringList
      read FInitializationDescriptions;
  end;

// Возвращает план; вызывающий освобождает его. Протокол не изменяется.
// При отказе (Status <> ppsReady) списки плана пусты.
function PlanProtocolStart(AProtocol: TAutomationProtocol;
  AStates: TDispenserRuntimeStates): TProtocolStartPlan;

implementation

uses
  DispenserLimits;

constructor TProtocolStartPlan.Create;
begin
  inherited Create;
  FStatus := ppsReady;
  FTargets := TDispenserConfigList.Create;
  FInitializationTargets := TDispenserConfigList.Create;
  FInitializationDescriptions := TStringList.Create;
end;

destructor TProtocolStartPlan.Destroy;
begin
  FInitializationDescriptions.Free;
  FInitializationTargets.Free;
  FTargets.Free;
  inherited Destroy;
end;

procedure TProtocolStartPlan.Reject(AStatus: TProtocolStartPlanStatus;
  const AErrorText: string);
begin
  FStatus := AStatus;
  FErrorText := AErrorText;
  FTargets.Clear;
  FInitializationTargets.Clear;
  FInitializationDescriptions.Clear;
end;

function TProtocolStartPlan.TakeInitializationTargets: TDispenserConfigList;
begin
  Result := FInitializationTargets;
  FInitializationTargets := nil;
end;

function PlanProtocolStart(AProtocol: TAutomationProtocol;
  AStates: TDispenserRuntimeStates): TProtocolStartPlan;
var
  Address: Integer;
  I: Integer;
  J: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  SeenAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
begin
  Result := TProtocolStartPlan.Create;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    SeenAddresses[Address] := False;
  for I := 0 to AProtocol.Count - 1 do
    for J := 0 to High(AProtocol[I].Targets) do
    begin
      Target := AProtocol[I].Targets[J];
      Address := Target.Config.Address;
      State := AStates.Items[Address];
      if State = nil then
      begin
        Result.Reject(ppsStateUnavailable, Target.Config.Name +
          ': не удалось получить состояние дозатора.');
        Exit;
      end;
      if State.OperationActive or State.CommandPending or
        State.ProtocolReserved then
      begin
        Result.Reject(ppsDispenserBusy, Target.Config.Name +
          ': дозатор сейчас выполняет другую команду.');
        Exit;
      end;
      if not SeenAddresses[Address] then
      begin
        Result.FTargets.Add(Target.Config.Clone);
        SeenAddresses[Address] := True;
        if not State.IsInitializedFor(Target.Config) or
          not State.CurrentVolumeKnown then
        begin
          Result.FInitializationTargets.Add(Target.Config.Clone);
          Result.FInitializationDescriptions.Add(Format('- %s (адрес %d)',
            [Target.Config.Name, Address]));
        end;
      end;
    end;
end;

end.
