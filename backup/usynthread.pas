unit USynThread;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, MyGlobals, LasFunc, JwaTlHelp32, JwaPsApi;

type

  { TSynThread }

  TSynThread = class(TThread)
  protected
    procedure OutLog;
    procedure TrigTimer;
    procedure Execute; override;
  end;


implementation
uses UMain;

var
  OutS: String;
  F: TextFile;



procedure TSynThread.OutLog;
begin
  OutS:=TimeToStr(Time())+': '+OutS;
  Form1.Memo1.Lines.Add(OutS);
  WriteLN(F, OutS);
end;

procedure TSynThread.TrigTimer;
begin
  Form1.Tmr_EzCADer.Enabled:=true;
end;

procedure TSynThread.Execute;
var
  ProcH: THandle;
  sl,i,j,a: integer;
  tmpPath: String;
begin
  tmpPath:=ExtractFilePath(SliceTable[0].EZDFile);
  AssignFile(F, tmpPath+'\log.txt');
  {$I-}
  Rewrite(F);
  {$I+}
  OutS:='Synthesis started';
  Synchronize(@OutLog);

  for sl:=0 to High(SliceTable) do
  begin
    if not IsStarted then Break;
    //Определяем, какая буква в текущем слое, находим ее номер и открываем ее протокол
    a:=AlphabetNum(SliceTable[sl].Letter); // a хранит номер текущего протокола в массиве протоколов
    OutS:='CICLE='+IntToStr(sl)+';    PROTOCOL LETTER='+Alphabet[a]+'; '+ 'LAYER NUMBER='+IntToStr(SliceTable[sl].LayerCount);
    Synchronize(@OutLog);
    for i:=0 to High(MySynthProt[a]) do // проходим все операции в протоколе
    begin
      if not IsStarted then Break;
      case MySynthProt[a,i].Func of   {dName, dSyrSt, dVac, dlaser, dPause}
        dName: begin
                 OutS:='Name='+MySynthProt[a,i].StrParam;
                 Synchronize(@OutLog);
               end;
        dPause: begin
                  Sleep(MySynthProt[a,i].IntParam*100);  {TODO: Временно поставил 100мс, потом заменить на 1000}
                  OutS:='Pause='+IntToStr(MySynthProt[a,i].IntParam);
                  Synchronize(@OutLog);
                end;
        dVac:   begin
                  Sleep(100); {TODO: заменить на функцию вкл/выкл вакуума}
                  OutS:='Vac='+BoolToStr(MySynthProt[a,i].BoolParam);
                  Synchronize(@OutLog);
                end;
        dSyrSt: begin
                  Sleep(100); {TODO: заменить на функцию работы шприца}
                  OutS:='SyrSt='+MySynthProt[a,i].StrParam+'; Volume='+
                               FloatTostr(MySynthProt[a,i].FloatParam)+
                        '; Speed='+IntTostr(MySynthProt[a,i].IntParam)+';';
                  Synchronize(@OutLog);
                end;
        dLaser: begin
                   OutS:='Laser='+IntToStr(MySynthProt[a,i].IntParam);
                   Synchronize(@OutLog);
                   OutS:='File='+SliceTable[sl].EZDFile;
                   Synchronize(@OutLog);
                   // открываем EzCAD
                   if GetProcessHandle('EzCad2.exe')=0 then
                   begin
                     GlobalI:=0; // обнуляем глобальный счетчик
                     Synchronize(@TrigTimer);
                     OutS:='EzCAD opening';
                     Synchronize(@OutLog);
                     ShellExecute(0, 'open', PChar(ExtractFilePath(ParamStr(0))+'EzCAD2.exe'),
                     PChar(SliceTable[sl].EZDFile), nil, SW_SHOWMINIMIZED);   // Открываем EzCAD2
                     Sleep(MyIni.ReadInteger('Laser','EzCAD2OpenTime',1000)); // задержка перед маркировкой на время открытия EzCAD. Читаем из ini
                     for j:=0 to MySynthProt[a,i].IntParam-1 do
                     begin
                       SendMsgToProc('EzCAD2.exe',VK_F2); // команда на маркировку
                       OutS:='Laser----F2--->';
                       Sleep(Round(MySynthProt[a,i].FloatParam)*1000); // задержка после маркировки
                       Synchronize(@OutLog);
                       if not IsStarted then Break; // Потом убрать
                     end;
                   end;
                   ProcH:=GetProcessHandle('EzCad2.exe');
                   if ProcH<>0 then
                   begin
                     SendMsgToProcWithMod('EzCAD2.exe',VK_F4, VK_MENU); // Alt+F4. закрываем
                     PostMessage(ProcH, WM_CLOSE, 0, 0);
                     OutS:='EzCAD closed';
                     Synchronize(@OutLog);
                   end;
                end;
      end;
    end;
  end;
  OutS:='Synthesis completed!';
  Synchronize(@OutLog);
  CloseFile(F);
end;



end.

