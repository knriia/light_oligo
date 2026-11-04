unit SynthesisThread;
// Поток синтеза: исполняет ход синтеза (SynthesisRunner) на настоящем
// оборудовании. Здесь только действия: шаг станции, пауза, вакуум, маркировка
// через EzCAD и журнал в окно и в файл. Синтез идёт по копиям слоёв из папки
// запуска (SynthesisFolder), туда же пишутся журнал и итог. Остановка -
// Terminate потока.
// С окнами поток связан через TSynthesisHost, а не через главное окно.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat, OligoSlices, SynthesisSession,
  SynthesisRunner, SynthesisFolder, LaserMarking, EzCadApp,
  UDispenserStationHost;

type
  // Что поток берёт у окон. Все вызовы идут в главном потоке (Synchronize),
  // кроме EzCadOpenDelayMs.
  TSynthesisHost = class
  public
    procedure WriteLog(const AText: string); virtual; abstract;
    // nil, если шприцевая станция не создана.
    function Station: TDispenserStationForm; virtual; abstract;
    // Синтез запускает EzCAD: включить наблюдатель за его окнами.
    procedure EzCadOpening; virtual; abstract;
    // Пауза после запуска EzCAD перед маркировкой, мс.
    function EzCadOpenDelayMs: Integer; virtual; abstract;
  end;

  TSynthesisThread = class;

  TSynthesisThreadActions = class;

  // Настоящий EzCAD для LaserMarking: действия через EzCadApp.
  TThreadEzCadDriver = class(TEzCadDriver)
  private
    FThread: TSynthesisThread;
    FActions: TSynthesisThreadActions;
  public
    constructor Create(AThread: TSynthesisThread;
      AActions: TSynthesisThreadActions);
    function IsRunning: Boolean; override;
    function Launch(const AEzdFile: string): Boolean; override;
    function SendMark: Boolean; override;
    procedure Close; override;
    procedure Wait(AMilliseconds: Integer); override;
    procedure Poll(AMilliseconds: Integer); override;
    function StopRequested: Boolean; override;
    procedure Log(const AText: string); override;
    procedure Opening; override;
  end;

  // Действия синтеза, выполняемые потоком (главное окно - через Synchronize).
  TSynthesisThreadActions = class(TSynthesisActions)
  private
    FThread: TSynthesisThread;
  public
    constructor Create(AThread: TSynthesisThread);
    procedure Log(const AText: string); override;
    function StopRequested: Boolean; override;
    function RunSyringe(const AStep: TSyringeStep;
      out AErrorText: string): Boolean; override;
    procedure Pause(ASeconds: Integer); override;
    procedure Vacuum(AOn: Boolean); override;
    function Laser(ARepeats: Integer; ATimeSeconds: Double;
      const AEzdFile: string; out AErrorText: string): Boolean; override;
  end;

  { TSynthesisThread }

  TSynthesisThread = class(TThread)
  private
    FSession: TSynthesisSession;
    FHost: TSynthesisHost;
    FSnapshot: TSynthesisSnapshot; // папка запуска и слои - копии в ней
    FLayers: TSliceLayers;
    FLogOpen: Boolean;           // журнал в файл ведётся
    FActions: TSynthesisThreadActions;
    FLogText: String;            // строка для OutLog
    FLogFile: TextFile;
    // Шаг SyrSt: данные для вызовов станции через Synchronize
    FSyringeStep: TSyringeStep;
    FSyringeStatus: TSyringeStepStatus;
    FSyringeError: String;
    procedure StartSyringeStep;
    procedure CheckSyringeStep;
    procedure StopSyringeStep;
    procedure OutLog;
    procedure TrigTimer;
  protected
    procedure Execute; override;
  public
    // Поток освобождается сам; пока он работает, сессию менять нельзя.
    constructor Create(ASession: TSynthesisSession; AHost: TSynthesisHost;
      const ASnapshot: TSynthesisSnapshot);
    destructor Destroy; override;
  end;


implementation

{ TSynthesisThreadActions }

constructor TSynthesisThreadActions.Create(AThread: TSynthesisThread);
begin
  inherited Create;
  FThread:=AThread;
end;

procedure TSynthesisThreadActions.Log(const AText: string);
begin
  FThread.FLogText:=AText;
  FThread.Synchronize(@FThread.OutLog);
end;

function TSynthesisThreadActions.StopRequested: Boolean;
begin
  Result:=FThread.Terminated;
end;

function TSynthesisThreadActions.RunSyringe(const AStep: TSyringeStep;
  out AErrorText: string): Boolean;
// Запускает шаг на станции и ждёт его завершения.
// При остановке синтеза останавливает дозаторы.
var
  StopSent: Boolean;
begin
  FThread.FSyringeStep:=AStep;
  FThread.Synchronize(@FThread.StartSyringeStep);
  StopSent:=false;
  while FThread.FSyringeStatus=sssRunning do
  begin
    if FThread.Terminated and not StopSent then
    begin
      FThread.Synchronize(@FThread.StopSyringeStep);
      StopSent:=true;
    end;
    Sleep(100);
    FThread.Synchronize(@FThread.CheckSyringeStep);
  end;
  Result:=FThread.FSyringeStatus=sssSucceeded;
  if Result then
    AErrorText:=''
  else
    AErrorText:=FThread.FSyringeError;
end;

procedure TSynthesisThreadActions.Pause(ASeconds: Integer);
begin
  Sleep(ASeconds*100);  {TODO: Временно поставил 100мс, потом заменить на 1000}
end;

procedure TSynthesisThreadActions.Vacuum(AOn: Boolean);
begin
  Sleep(100); {TODO: заменить на функцию вкл/выкл вакуума}
end;

function TSynthesisThreadActions.Laser(ARepeats: Integer;
  ATimeSeconds: Double; const AEzdFile: string;
  out AErrorText: string): Boolean;
// Порядок маркировки - в LaserMarking, здесь только настоящий EzCAD
var
  Driver: TThreadEzCadDriver;
begin
  Driver:=TThreadEzCadDriver.Create(FThread, Self);
  try
    Result:=MarkLayerWithEzCad(Driver, AEzdFile, ARepeats, ATimeSeconds,
                               FThread.FHost.EzCadOpenDelayMs, AErrorText);
  finally
    Driver.Free;
  end;
end;

{ TThreadEzCadDriver }

constructor TThreadEzCadDriver.Create(AThread: TSynthesisThread;
  AActions: TSynthesisThreadActions);
begin
  inherited Create;
  FThread:=AThread;
  FActions:=AActions;
end;

function TThreadEzCadDriver.IsRunning: Boolean;
begin
  Result:=EzCadRunning;
end;

function TThreadEzCadDriver.Launch(const AEzdFile: string): Boolean;
begin
  // путь к файлу берётся в кавычки: в нём могут быть пробелы и кириллица
  Result:=LaunchEzCad(ExtractFilePath(ParamStr(0)), AEzdFile);
end;

function TThreadEzCadDriver.SendMark: Boolean;
begin
  Result:=SendEzCadMark;
end;

procedure TThreadEzCadDriver.Close;
begin
  CloseEzCad;
end;

procedure TThreadEzCadDriver.Wait(AMilliseconds: Integer);
// Ждёт кусками по 100 мс, чтобы остановка синтеза не ждала конца паузы
var
  Left: Integer;
begin
  Left:=AMilliseconds;
  while (Left>0) and not FThread.Terminated do
  begin
    if Left<100 then
      Sleep(Left)
    else
      Sleep(100);
    Dec(Left, 100);
  end;
end;

procedure TThreadEzCadDriver.Poll(AMilliseconds: Integer);
begin
  Sleep(AMilliseconds);
end;

function TThreadEzCadDriver.StopRequested: Boolean;
begin
  Result:=FThread.Terminated;
end;

procedure TThreadEzCadDriver.Log(const AText: string);
begin
  FActions.Log(AText);
end;

procedure TThreadEzCadDriver.Opening;
begin
  FThread.Synchronize(@FThread.TrigTimer);
end;

{ TSynthesisThread }

constructor TSynthesisThread.Create(ASession: TSynthesisSession;
  AHost: TSynthesisHost; const ASnapshot: TSynthesisSnapshot);
begin
  inherited Create(True);
  FreeOnTerminate:=True;
  FSession:=ASession;
  FHost:=AHost;
  FSnapshot:=ASnapshot;
  FLayers:=ASnapshot.Layers;
  FActions:=TSynthesisThreadActions.Create(Self);
end;

destructor TSynthesisThread.Destroy;
begin
  FActions.Free;
  inherited Destroy;
end;

procedure TSynthesisThread.OutLog;
begin
  FLogText:=TimeToStr(Time())+': '+FLogText;
  FHost.WriteLog(FLogText);
  if FLogOpen then
    WriteLN(FLogFile, FLogText);
end;

procedure TSynthesisThread.TrigTimer;
begin
  FHost.EzCadOpening;
end;

procedure TSynthesisThread.StartSyringeStep;
begin
  FSyringeError:='';
  if FHost.Station=nil then
  begin
    FSyringeStatus:=sssFailed;
    FSyringeError:='шприцевая станция не создана.';
  end
  else if FHost.Station.StartSyringeStep(FSyringeStep, FSyringeError) then
    FSyringeStatus:=sssRunning
  else
    FSyringeStatus:=sssFailed;
end;

procedure TSynthesisThread.CheckSyringeStep;
begin
  FSyringeStatus:=FHost.Station.SyringeStepStatus(FSyringeError);
end;

procedure TSynthesisThread.StopSyringeStep;
begin
  FHost.Station.StopSyringeStep;
end;

procedure TSynthesisThread.Execute;
var
  Runner: TSynthesisRunner;
  Status: TSynthesisResult;
  ErrorText: String;
begin
  if Length(FLayers)=0 then
    Exit;
  AssignFile(FLogFile, FSnapshot.LogFile);
  {$I-}
  Rewrite(FLogFile);
  {$I+}
  FLogOpen:=IOResult=0;
  if not FLogOpen then
    FActions.Log('WARNING: журнал в файл не ведётся, не удалось открыть '+
                 FSnapshot.LogFile);
  Runner:=TSynthesisRunner.Create(FLayers, @FSession.ProtocolOf, FActions);
  try
    if Runner.Run then
      Status:=srCompleted
    else if Runner.Failed then
      Status:=srFailed
    else
      Status:=srStopped;
  finally
    Runner.Free;
  end;
  if not SaveSynthesisResult(FSnapshot.Folder, Status, Now, ErrorText) then
    FActions.Log('WARNING: '+ErrorText);
  if FLogOpen then
  begin
    FLogOpen:=False;
    CloseFile(FLogFile);
  end;
end;

end.
