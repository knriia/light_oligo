unit SynthesisThread;
// Поток синтеза: исполняет ход синтеза (SynthesisRunner) на настоящем
// оборудовании. Здесь только действия: шаг станции, пауза, вакуум, маркировка
// через EzCAD и журнал в окно и в файл. Остановка - Terminate потока.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, WinProcessUtils, ProtocolFormat, OligoSlices,
  SynthesisSession, SynthesisRunner, UDispenserStationHost;

type
  TSynthesisThread = class;

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
    procedure Laser(ARepeats: Integer; ATimeSeconds: Double;
      const AEzdFile: string); override;
  end;

  { TSynthesisThread }

  TSynthesisThread = class(TThread)
  private
    FSession: TSynthesisSession;
    FLayers: TSliceLayers;       // слои на момент запуска
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
    constructor Create(ASession: TSynthesisSession);
    destructor Destroy; override;
  end;


implementation
uses UMainForm;

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

procedure TSynthesisThreadActions.Laser(ARepeats: Integer;
  ATimeSeconds: Double; const AEzdFile: string);
var
  ProcH: THandle;
  j: Integer;
begin
  // открываем EzCAD
  if GetProcessHandle('EzCad2.exe')=0 then
  begin
    FThread.Synchronize(@FThread.TrigTimer);
    Log('EzCAD opening');
    ShellExecute(0, 'open', PChar(ExtractFilePath(ParamStr(0))+'EzCAD2.exe'),
    PChar(AEzdFile), nil, SW_SHOWMINIMIZED);   // Открываем EzCAD2
    Sleep(MyIni.ReadInteger('Laser','EzCAD2OpenTime',1000)); // задержка перед маркировкой на время открытия EzCAD. Читаем из ini
    for j:=0 to ARepeats-1 do
    begin
      SendMsgToProc('EzCAD2.exe',VK_F2); // команда на маркировку
      Sleep(Round(ATimeSeconds)*1000); // задержка после маркировки (из протокола)
      Log('Laser----F2--->');
      if FThread.Terminated then Break; // Потом убрать
    end;
  end;
  ProcH:=GetProcessHandle('EzCad2.exe');
  if ProcH<>0 then
  begin
    SendMsgToProcWithMod('EzCAD2.exe',VK_F4, VK_MENU); // Alt+F4. закрываем
    PostMessage(ProcH, WM_CLOSE, 0, 0);
    Log('EzCAD closed');
  end;
end;

{ TSynthesisThread }

constructor TSynthesisThread.Create(ASession: TSynthesisSession);
begin
  inherited Create(True);
  FreeOnTerminate:=True;
  FSession:=ASession;
  FLayers:=Copy(ASession.Layers);
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
  MainForm.Memo1.Lines.Add(FLogText);
  WriteLN(FLogFile, FLogText);
end;

procedure TSynthesisThread.TrigTimer;
begin
  MainForm.StartEzCadWatcher;
end;

procedure TSynthesisThread.StartSyringeStep;
begin
  FSyringeError:='';
  if MainForm.DispenserStation=nil then
  begin
    FSyringeStatus:=sssFailed;
    FSyringeError:='шприцевая станция не создана.';
  end
  else if MainForm.DispenserStation.StartSyringeStep(FSyringeStep, FSyringeError) then
    FSyringeStatus:=sssRunning
  else
    FSyringeStatus:=sssFailed;
end;

procedure TSynthesisThread.CheckSyringeStep;
begin
  FSyringeStatus:=MainForm.DispenserStation.SyringeStepStatus(FSyringeError);
end;

procedure TSynthesisThread.StopSyringeStep;
begin
  MainForm.DispenserStation.StopSyringeStep;
end;

procedure TSynthesisThread.Execute;
var
  Runner: TSynthesisRunner;
begin
  if Length(FLayers)=0 then
    Exit;
  AssignFile(FLogFile, ExtractFilePath(FLayers[0].EZDFile)+'\log.txt');
  {$I-}
  Rewrite(FLogFile);
  {$I+}
  Runner:=TSynthesisRunner.Create(FLayers, @FSession.ProtocolOf, FActions);
  try
    Runner.Run;
  finally
    Runner.Free;
  end;
  CloseFile(FLogFile);
end;

end.
