unit SynthesisThread;
// Поток синтеза: проходит слои по порядку, для каждого берёт протокол его
// буквы и выполняет операции. Данные - в сессии (SynthesisSession); остановка
// синтеза - Terminate потока.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, WinProcessUtils, ProtocolFormat, ProtocolModel,
  OligoSlices, SynthesisSession, UDispenserStationHost;

type

  { TSynthesisThread }

  TSynthesisThread = class(TThread)
  private
    FSession: TSynthesisSession;
    FLayers: TSliceLayers;       // слои на момент запуска
    FLogText: String;            // строка для OutLog
    FLogFile: TextFile;
    // Шаг SyrSt: данные для вызовов станции через Synchronize
    FSyringeStep: TSyringeStep;
    FSyringeStatus: TSyringeStepStatus;
    FSyringeError: String;
    procedure StartSyringeStep;
    procedure CheckSyringeStep;
    procedure StopSyringeStep;
    procedure RunSyringeStep;
    procedure RunLaser(const AStep: TProtocolStep; const AEzdFile: String);
    procedure RunStep(const AStep: TProtocolStep; const AEzdFile: String);
    procedure Log(const AText: String);
  protected
    procedure OutLog;
    procedure TrigTimer;
    procedure Execute; override;
  public
    // Поток освобождается сам; пока он работает, сессию менять нельзя.
    constructor Create(ASession: TSynthesisSession);
  end;


implementation
uses UMainForm;

constructor TSynthesisThread.Create(ASession: TSynthesisSession);
begin
  inherited Create(True);
  FreeOnTerminate:=True;
  FSession:=ASession;
  FLayers:=Copy(ASession.Layers);
end;

procedure TSynthesisThread.OutLog;
begin
  FLogText:=TimeToStr(Time())+': '+FLogText;
  MainForm.Memo1.Lines.Add(FLogText);
  WriteLN(FLogFile, FLogText);
end;

procedure TSynthesisThread.Log(const AText: String);
begin
  FLogText:=AText;
  Synchronize(@OutLog);
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

procedure TSynthesisThread.RunSyringeStep;
// Запускает шаг на станции и ждёт его завершения.
// При ошибке синтез останавливается; при остановке синтеза останавливает дозаторы.
var
  StopSent: Boolean;
begin
  Synchronize(@StartSyringeStep);
  StopSent:=false;
  while FSyringeStatus=sssRunning do
  begin
    if Terminated and not StopSent then
    begin
      Synchronize(@StopSyringeStep);
      StopSent:=true;
    end;
    Sleep(100);
    Synchronize(@CheckSyringeStep);
  end;

  if FSyringeStatus=sssSucceeded then
    Log('SyrSt done')
  else
  begin
    FLogText:='SyrSt ERROR: '+FSyringeError;
    Terminate;
    Synchronize(@OutLog);
  end;
end;

procedure TSynthesisThread.RunLaser(const AStep: TProtocolStep;
  const AEzdFile: String);
var
  ProcH: THandle;
  j: Integer;
begin
  Log('Laser='+IntToStr(AStep.IntValue));
  Log('File='+AEzdFile);
  // открываем EzCAD
  if GetProcessHandle('EzCad2.exe')=0 then
  begin
    Synchronize(@TrigTimer);
    Log('EzCAD opening');
    ShellExecute(0, 'open', PChar(ExtractFilePath(ParamStr(0))+'EzCAD2.exe'),
    PChar(AEzdFile), nil, SW_SHOWMINIMIZED);   // Открываем EzCAD2
    Sleep(MyIni.ReadInteger('Laser','EzCAD2OpenTime',1000)); // задержка перед маркировкой на время открытия EzCAD. Читаем из ini
    for j:=0 to AStep.IntValue-1 do
    begin
      SendMsgToProc('EzCAD2.exe',VK_F2); // команда на маркировку
      FLogText:='Laser----F2--->';
      Sleep(Round(AStep.FloatValue)*1000); // задержка после маркировки (из протокола)
      Synchronize(@OutLog);
      if Terminated then Break; // Потом убрать
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

procedure TSynthesisThread.RunStep(const AStep: TProtocolStep;
  const AEzdFile: String);
begin
  case AStep.Kind of
    pskComment:
      Log('Name='+AStep.Text);
    pskPause:
      begin
        Sleep(AStep.IntValue*100);  {TODO: Временно поставил 100мс, потом заменить на 1000}
        Log('Pause='+IntToStr(AStep.IntValue));
      end;
    pskVacuum:
      begin
        Sleep(100); {TODO: заменить на функцию вкл/выкл вакуума}
        Log('Vac='+BoolToStr(AStep.BoolValue));
      end;
    pskSyringe:
      begin
        FSyringeStep:=AStep.Syringe;
        Log(SyringeStepSummary(FSyringeStep));
        RunSyringeStep;
      end;
    pskLaser:
      RunLaser(AStep, AEzdFile);
  end;
end;

procedure TSynthesisThread.Execute;
var
  sl, b, i: Integer;
  Protocol: TProtocolModel;
begin
  AssignFile(FLogFile, ExtractFilePath(FLayers[0].EZDFile)+'\log.txt');
  {$I-}
  Rewrite(FLogFile);
  {$I+}
  Log('Synthesis started');

  for sl:=0 to High(FLayers) do
  begin
    if Terminated then Break;
    // протокол буквы текущего слоя (сессия проверила, что он есть для всех букв)
    Protocol:=FSession.ProtocolOf(FLayers[sl].Letter);
    if Protocol=nil then
    begin
      Log('ERROR: no protocol for letter '+FLayers[sl].Letter);
      Break;
    end;
    Log('CICLE='+IntToStr(sl)+';    PROTOCOL LETTER='+FLayers[sl].Letter+'; '+
        'LAYER NUMBER='+IntToStr(FLayers[sl].LayerNumber));
    for b:=0 to Protocol.BlockCount-1 do
    begin
      Log('Name='+Protocol.BlockNames[b]);
      for i:=0 to Protocol.StepCount(b)-1 do
      begin
        if Terminated then Break;
        RunStep(Protocol.Steps[b,i], FLayers[sl].EZDFile);
      end;
      if Terminated then Break;
    end;
  end;
  Log('Synthesis completed!');
  CloseFile(FLogFile);
end;

end.
