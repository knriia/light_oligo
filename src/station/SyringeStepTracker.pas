unit SyringeStepTracker;

{$mode objfpc}{$H+}

interface

uses
  ProtocolFormat;

type
  // Состояние шага синтеза, исполняемого станцией. Не потокобезопасен:
  // используется только из потока UI.
  TSyringeStepTracker = class
  private
    FStatus: TSyringeStepStatus;
    FError: string;
    FStopRequested: Boolean;
  public
    constructor Create;
    procedure Start;
    // True, если шаг выполняется и остановка принята.
    function RequestStop: Boolean;
    procedure Finish(AFailed: Boolean; const AMessage: string);
    function Status(out AError: string): TSyringeStepStatus;
    function IsRunning: Boolean;
    // Остановка запрошена у выполняющегося шага.
    function StopRequested: Boolean;
  end;

implementation

constructor TSyringeStepTracker.Create;
begin
  inherited Create;
  FStatus := sssIdle;
  FError := '';
  FStopRequested := False;
end;

procedure TSyringeStepTracker.Start;
begin
  FStatus := sssRunning;
  FError := '';
  FStopRequested := False;
end;

function TSyringeStepTracker.RequestStop: Boolean;
begin
  Result := FStatus = sssRunning;
  if Result then
    FStopRequested := True;
end;

procedure TSyringeStepTracker.Finish(AFailed: Boolean;
  const AMessage: string);
begin
  if FStatus <> sssRunning then
    Exit;
  if AFailed then
    FStatus := sssFailed
  else
    FStatus := sssSucceeded;
  FError := AMessage;
  FStopRequested := False;
end;

function TSyringeStepTracker.Status(out AError: string): TSyringeStepStatus;
begin
  Result := FStatus;
  AError := FError;
end;

function TSyringeStepTracker.IsRunning: Boolean;
begin
  Result := FStatus = sssRunning;
end;

function TSyringeStepTracker.StopRequested: Boolean;
begin
  Result := FStopRequested and (FStatus = sssRunning);
end;

end.
