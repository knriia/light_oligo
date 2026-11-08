unit StationWork;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, DispenserConfig, DispenserOperationCoordinator,
  DispenserConnectionCoordinator, DispenserTypes, DispenserLimits,
  AutomationProtocol;

type
  TFormWorkKind = (btkStartSingle, btkStartGroup, btkInitialize,
    btkPrepareProtocol, btkPoll, btkBypass, btkChangeSpeed, btkStopOne,
    btkStopAll,
    btkStartProtocol, btkStopProtocol, btkConnect, btkDisconnect, btkScanPorts);

  TFormWorkItem = class
  private
    FKind: TFormWorkKind;
    FCompleted: Boolean;
    FCompletionLock: TCriticalSection;
  public
    Config: TDispenserConfig;
    Configs: TDispenserConfigList;
    Requests: TDispenserOperationRequestArray;
    Protocol: TAutomationProtocol;
    Failures: TStringList;
    PortList: TStringList;
    PortName: string;
    Address: Integer;
    Channel: Integer;
    Speed: Integer;
    OperationKind: TDispenserOperationKind;
    BypassEnabled: Boolean;
    BypassValveType: TDispenserValveType;
    ReservedAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    Success: Boolean;
    ErrorText: string;
    SingleResult: TDispenserOperationStartResult;
    GroupResult: TDispenserGroupStartResult;
    ConnectionResult: TDispenserConnectionResult;
    constructor Create(AKind: TFormWorkKind);
    destructor Destroy; override;
    function IsCompleted: Boolean;
    function WorkKind: TFormWorkKind;
    procedure MarkCompleted;
  end;

  TQueuedUiEventKind = (quLog, quStateChanged, quFailure,
    quProtocolFinished);

  TQueuedUiEvent = class
  public
    Kind: TQueuedUiEventKind;
    Address: Integer;
    MessageText: string;
    Flag: Boolean;
    UpdateAndSaveVolume: Boolean;
  end;

implementation

constructor TFormWorkItem.Create(AKind: TFormWorkKind);
var
  LoopAddress: Integer;
begin
  FKind := AKind;
  FCompleted := False;
  SingleResult := dosrCommandFailed;
  GroupResult := dgsRejected;
  ConnectionResult := dcrPortOpenFailed;
  FCompletionLock := TCriticalSection.Create;
  for LoopAddress := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    ReservedAddresses[LoopAddress] := False;
end;

destructor TFormWorkItem.Destroy;
var
  I: Integer;
begin
  Config.Free;
  Configs.Free;
  for I := 0 to High(Requests) do
    Requests[I].Config.Free;
  SetLength(Requests, 0);
  Protocol.Free;
  Failures.Free;
  PortList.Free;
  FCompletionLock.Free;
  inherited Destroy;
end;

procedure TFormWorkItem.MarkCompleted;
begin
  FCompletionLock.Acquire;
  try
    FCompleted := True;
  finally
    FCompletionLock.Release;
  end;
end;

function TFormWorkItem.IsCompleted: Boolean;
begin
  FCompletionLock.Acquire;
  try
    Result := FCompleted;
  finally
    FCompletionLock.Release;
  end;
end;

function TFormWorkItem.WorkKind: TFormWorkKind;
begin
  Result := FKind;
end;

end.
