unit FormWorkDispatcher;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs;

type
  TWorkDispatcherExecuteEvent = procedure(AWorkItem: TObject) of object;

  TFormWorkDispatcher = class(TThread)
  private
    FQueue: TList;
    FLock: TCriticalSection;
    FAvailableEvent: TEvent;
    FStopping: Boolean;
    FOnExecuteWorkItem: TWorkDispatcherExecuteEvent;
    function TakeNextWorkItem(out AShouldStop: Boolean): TObject;
  protected
    procedure Execute; override;
  public
    constructor Create(AOnExecuteWorkItem: TWorkDispatcherExecuteEvent);
    destructor Destroy; override;
    function Enqueue(AWorkItem: TObject): Boolean;
    procedure Stop;
  end;

implementation

uses
  SysUtils;

constructor TFormWorkDispatcher.Create(
  AOnExecuteWorkItem: TWorkDispatcherExecuteEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FQueue := TList.Create;
  FLock := TCriticalSection.Create;
  FAvailableEvent := TEvent.Create(nil, False, False, '');
  FStopping := False;
  FOnExecuteWorkItem := AOnExecuteWorkItem;
  Start;
end;

destructor TFormWorkDispatcher.Destroy;
begin
  Stop;
  FAvailableEvent.Free;
  FLock.Free;
  FQueue.Free;
  inherited Destroy;
end;

function TFormWorkDispatcher.TakeNextWorkItem(
  out AShouldStop: Boolean): TObject;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FQueue.Count > 0 then
    begin
      Result := TObject(FQueue[0]);
      FQueue.Delete(0);
      AShouldStop := False;
    end
    else
      AShouldStop := FStopping;
  finally
    FLock.Release;
  end;
end;

procedure TFormWorkDispatcher.Execute;
var
  WorkItem: TObject;
  ShouldStop: Boolean;
begin
  repeat
    WorkItem := TakeNextWorkItem(ShouldStop);
    if WorkItem = nil then
    begin
      if ShouldStop then
        Exit;
      FAvailableEvent.WaitFor(High(Cardinal));
      Continue;
    end;

    if Assigned(FOnExecuteWorkItem) then
      FOnExecuteWorkItem(WorkItem);
  until False;
end;

function TFormWorkDispatcher.Enqueue(AWorkItem: TObject): Boolean;
begin
  Result := False;
  if AWorkItem = nil then
    Exit;

  FLock.Acquire;
  try
    if not FStopping then
    begin
      FQueue.Add(AWorkItem);
      FAvailableEvent.SetEvent;
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TFormWorkDispatcher.Stop;
begin
  FLock.Acquire;
  try
    FStopping := True;
    FAvailableEvent.SetEvent;
  finally
    FLock.Release;
  end;
  if not Finished then
    WaitFor;
end;

end.
