unit SynthesisThread;
// Поток синтеза: жизненный цикл, маршалинг в главный поток и журнал в окно
// и файл. Исполнение оборудования делегируется портам через
// TSynthesisThreadActions.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat, OligoSlices, SynthesisSession,
  SynthesisRunner, SynthesisFolder, SynthesisPorts;

type
  // Что поток берёт у окон. Все вызовы оборудования и журнала идут через
  // Synchronize из реализаций действий.
  TSynthesisHost = class
  public
    procedure WriteLog(const AText: string); virtual; abstract;
    // nil, если шприцевая станция не создана.
    function Station: TSyringeStation; virtual; abstract;
    // nil допустим как ошибка конфигурации маркера.
    function Marker: TLayerMarker; virtual; abstract;
  end;

  TSynthesisThread = class;
  TSynthesisThreadActions = class;

  // Контекст, действующий во время одного вызова маркера.
  TThreadExecutionContext = class(TExecutionContext)
  private
    FThread: TSynthesisThread;
    FActions: TSynthesisThreadActions;
  public
    constructor Create(AThread: TSynthesisThread;
      AActions: TSynthesisThreadActions);
    function StopRequested: Boolean; override;
    procedure Wait(AMilliseconds: Integer); override;
    procedure Poll(AMilliseconds: Integer); override;
    procedure Log(const AText: string); override;
    procedure Synchronize(AMethod: TThreadMethod); override;
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
      out AErrorText: string): TPortResult; override;
    procedure Pause(ASeconds: Integer); override;
    procedure Vacuum(AOn: Boolean); override;
    function Laser(ARepeats: Integer; ATimeSeconds: Double;
      const AEzdFile: string; out AErrorText: string): TPortResult; override;
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
    // Ждёт кусками по 100 мс, чтобы остановка синтеза не ждала конца паузы
    procedure WaitUnlessStopped(AMilliseconds: Int64);
  protected
    procedure Execute; override;
  public
    // Поток освобождается сам; пока он работает, сессию менять нельзя.
    constructor Create(ASession: TSynthesisSession; AHost: TSynthesisHost;
      const ASnapshot: TSynthesisSnapshot);
    destructor Destroy; override;
  end;

implementation

{ TThreadExecutionContext }

constructor TThreadExecutionContext.Create(AThread: TSynthesisThread;
  AActions: TSynthesisThreadActions);
begin
  inherited Create;
  FThread := AThread;
  FActions := AActions;
end;

function TThreadExecutionContext.StopRequested: Boolean;
begin
  Result := FThread.Terminated;
end;

procedure TThreadExecutionContext.Wait(AMilliseconds: Integer);
begin
  FThread.WaitUnlessStopped(AMilliseconds);
end;

procedure TThreadExecutionContext.Poll(AMilliseconds: Integer);
begin
  Sleep(AMilliseconds);
end;

procedure TThreadExecutionContext.Log(const AText: string);
begin
  FActions.Log(AText);
end;

procedure TThreadExecutionContext.Synchronize(AMethod: TThreadMethod);
begin
  FThread.Synchronize(AMethod);
end;

{ TSynthesisThreadActions }

constructor TSynthesisThreadActions.Create(AThread: TSynthesisThread);
begin
  inherited Create;
  FThread := AThread;
end;

procedure TSynthesisThreadActions.Log(const AText: string);
begin
  FThread.FLogText := AText;
  FThread.Synchronize(@FThread.OutLog);
end;

function TSynthesisThreadActions.StopRequested: Boolean;
begin
  Result := FThread.Terminated;
end;

function TSynthesisThreadActions.RunSyringe(const AStep: TSyringeStep;
  out AErrorText: string): TPortResult;
// Запускает шаг на станции и ждёт его завершения.
// При остановке синтеза останавливает дозаторы.
var
  StopSent: Boolean;
  Station: TSyringeStation;
begin
  Result := prFailed;
  AErrorText := '';
  Station := FThread.FHost.Station;
  FThread.FSyringeStep := AStep;
  FThread.Synchronize(@FThread.StartSyringeStep);
  StopSent := False;
  while FThread.FSyringeStatus = sssRunning do
  begin
    if FThread.Terminated and not StopSent then
    begin
      FThread.Synchronize(@FThread.StopSyringeStep);
      StopSent := True;
    end;
    Sleep(100);
    FThread.Synchronize(@FThread.CheckSyringeStep);
  end;
  if FThread.FSyringeStatus = sssSucceeded then
    Result := prSucceeded
  else
    AErrorText := FThread.FSyringeError;
  // Station используется только для того, чтобы сохранить явную проверку
  // зависимости перед Synchronize; сам вызов выполняется в главном потоке.
  if Station = nil then
    AErrorText := 'шприцевая станция не создана.';
end;

procedure TSynthesisThreadActions.Pause(ASeconds: Integer);
begin
  // пауза протокола - в секундах; остановка синтеза прерывает ожидание
  FThread.WaitUnlessStopped(Int64(ASeconds) * 1000);
end;

procedure TSynthesisThreadActions.Vacuum(AOn: Boolean);
begin
  // Управления вакуумом в программе нет: операция только записывается в
  // журнал, а оператор предупреждается, что вакуум не включался
  Log('WARNING: управление вакуумом не реализовано, операция пропущена');
  Sleep(100);
end;

function TSynthesisThreadActions.Laser(ARepeats: Integer;
  ATimeSeconds: Double; const AEzdFile: string;
  out AErrorText: string): TPortResult;
// Порядок маркировки - в LaserMarking; здесь только порт маркера.
var
  Context: TThreadExecutionContext;
  Marker: TLayerMarker;
begin
  Marker := FThread.FHost.Marker;
  if Marker = nil then
  begin
    AErrorText := 'лазерный маркер не создан.';
    Exit(prFailed);
  end;
  Context := TThreadExecutionContext.Create(FThread, Self);
  try
    Marker.SetExecutionContext(Context);
    try
      Result := Marker.MarkLayer(AEzdFile, ARepeats, ATimeSeconds,
        AErrorText);
    finally
      Marker.SetExecutionContext(nil);
    end;
  finally
    Context.Free;
  end;
end;

{ TSynthesisThread }

constructor TSynthesisThread.Create(ASession: TSynthesisSession;
  AHost: TSynthesisHost; const ASnapshot: TSynthesisSnapshot);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FSession := ASession;
  FHost := AHost;
  FSnapshot := ASnapshot;
  FLayers := ASnapshot.Layers;
  FActions := TSynthesisThreadActions.Create(Self);
end;

destructor TSynthesisThread.Destroy;
begin
  FActions.Free;
  inherited Destroy;
end;

procedure TSynthesisThread.WaitUnlessStopped(AMilliseconds: Int64);
var
  Left: Int64;
begin
  Left := AMilliseconds;
  while (Left > 0) and not Terminated do
  begin
    if Left < 100 then
      Sleep(Left)
    else
      Sleep(100);
    Dec(Left, 100);
  end;
end;

procedure TSynthesisThread.OutLog;
begin
  FLogText := TimeToStr(Time()) + ': ' + FLogText;
  FHost.WriteLog(FLogText);
  if FLogOpen then
    WriteLN(FLogFile, FLogText);
end;

procedure TSynthesisThread.StartSyringeStep;
begin
  FSyringeError := '';
  if FHost.Station = nil then
  begin
    FSyringeStatus := sssFailed;
    FSyringeError := 'шприцевая станция не создана.';
  end
  else if FHost.Station.StartSyringeStep(FSyringeStep, FSyringeError) then
    FSyringeStatus := sssRunning
  else
    FSyringeStatus := sssFailed;
end;

procedure TSynthesisThread.CheckSyringeStep;
begin
  FSyringeStatus := FHost.Station.SyringeStepStatus(FSyringeError);
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
  if Length(FLayers) = 0 then
    Exit;
  AssignFile(FLogFile, FSnapshot.LogFile);
  {$I-}
  Rewrite(FLogFile);
  {$I+}
  FLogOpen := IOResult = 0;
  if not FLogOpen then
    FActions.Log('WARNING: журнал в файл не ведётся, не удалось открыть ' +
      FSnapshot.LogFile);
  Runner := TSynthesisRunner.Create(FLayers, @FSession.ProtocolOf, FActions);
  try
    if Runner.Run then
      Status := srCompleted
    else if Runner.Failed then
      Status := srFailed
    else
      Status := srStopped;
  finally
    Runner.Free;
  end;
  if not SaveSynthesisResult(FSnapshot.Folder, Status, Now, ErrorText) then
    FActions.Log('WARNING: ' + ErrorText);
  if FLogOpen then
  begin
    FLogOpen := False;
    CloseFile(FLogFile);
  end;
end;

end.
