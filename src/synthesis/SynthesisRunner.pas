unit SynthesisRunner;
// Ход синтеза без оборудования и без потока: проходит слои по порядку, для
// каждого берёт протокол его буквы и по очереди выполняет операции. Сами
// действия (станция, пауза, вакуум, лазер, журнал, проверка остановки)
// делает исполнитель TSynthesisActions: в программе его реализует поток
// синтеза, в тестах - подставной. Поэтому порядок операций, остановка и
// ошибки проверяются тестами.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, OligoSlices, ProtocolFormat, ProtocolModel, SynthesisPorts;

type
  // Протокол буквы; nil, если для буквы протокола нет.
  TProtocolLookup = function(const ALetter: string): TProtocolModel of object;

  TSynthesisRunner = class
  private
    FLayers: TSliceLayers;
    FLookup: TProtocolLookup;
    FActions: TSynthesisActions;
    FFailed: Boolean;
    function Aborted: Boolean;
    procedure RunStep(const AStep: TProtocolStep; const AEzdFile: string;
      ALayerIndex, AOperationIndex: Integer);
    procedure RunLayer(AIndex: Integer);
  public
    constructor Create(const ALayers: TSliceLayers; ALookup: TProtocolLookup;
      AActions: TSynthesisActions);
    // Выполняет синтез. True - дошли до конца, False - остановили или
    // случилась ошибка. Слои и протоколы на время работы менять нельзя.
    function Run: Boolean;
    // Синтез остановился из-за ошибки (а не по просьбе пользователя).
    property Failed: Boolean read FFailed;
  end;

implementation

constructor TSynthesisRunner.Create(const ALayers: TSliceLayers;
  ALookup: TProtocolLookup; AActions: TSynthesisActions);
begin
  inherited Create;
  FLayers := Copy(ALayers);
  FLookup := ALookup;
  FActions := AActions;
end;

function TSynthesisRunner.Aborted: Boolean;
begin
  Result := FFailed or FActions.StopRequested;
end;

procedure TSynthesisRunner.RunStep(const AStep: TProtocolStep;
  const AEzdFile: string; ALayerIndex, AOperationIndex: Integer);
var
  ErrorText: string;
  ProgressEvent: TSynthesisProgress;
begin
  ProgressEvent.LayerIndex := ALayerIndex + 1;
  ProgressEvent.LayerCount := Length(FLayers);
  ProgressEvent.OperationIndex := AOperationIndex;
  ProgressEvent.ErrorText := '';
  FActions.Progress(ProgressEvent);
  case AStep.Kind of
    pskComment:
      FActions.Log('Name=' + AStep.Text);
    pskPause:
      begin
        FActions.Pause(AStep.IntValue);
        FActions.Log('Pause=' + IntToStr(AStep.IntValue));
      end;
    pskVacuum:
      begin
        FActions.Vacuum(AStep.BoolValue);
        FActions.Log('Vac=' + BoolToStr(AStep.BoolValue));
      end;
    pskSyringe:
      begin
        FActions.Log(SyringeStepSummary(AStep.Syringe));
        case FActions.RunSyringe(AStep.Syringe, ErrorText) of
          prSucceeded:
            FActions.Log('SyrSt done');
          prFailed:
            begin
              FActions.Log('SyrSt ERROR: ' + ErrorText);
              ProgressEvent.ErrorText := ErrorText;
              FActions.Progress(ProgressEvent);
              FFailed := True;
            end;
          prUnknown:
            begin
              FActions.Log('SyrSt UNKNOWN: ' + ErrorText);
              ProgressEvent.ErrorText := ErrorText;
              FActions.Progress(ProgressEvent);
              FFailed := True;
            end;
        end;
      end;
    pskLaser:
      begin
        FActions.Log('Laser=' + IntToStr(AStep.IntValue));
        FActions.Log('File=' + AEzdFile);
        case FActions.Laser(AStep.IntValue, AStep.FloatValue, AEzdFile,
          ErrorText) of
          prSucceeded:
            ;
          prFailed:
            begin
              FActions.Log('Laser ERROR: ' + ErrorText);
              ProgressEvent.ErrorText := ErrorText;
              FActions.Progress(ProgressEvent);
              FFailed := True;
            end;
          prUnknown:
            begin
              FActions.Log('Laser UNKNOWN: ' + ErrorText);
              ProgressEvent.ErrorText := ErrorText;
              FActions.Progress(ProgressEvent);
              FFailed := True;
            end;
        end;
      end;
  end;
end;

procedure TSynthesisRunner.RunLayer(AIndex: Integer);
var
  Protocol: TProtocolModel;
  B, S, OperationIndex: Integer;
  ProgressEvent: TSynthesisProgress;
begin
  // сессия проверила, что протоколы есть для всех букв; здесь защита
  Protocol := FLookup(FLayers[AIndex].Letter);
  if Protocol = nil then
  begin
    ProgressEvent.LayerIndex := AIndex + 1;
    ProgressEvent.LayerCount := Length(FLayers);
    ProgressEvent.OperationIndex := 0;
    ProgressEvent.ErrorText := 'no protocol for letter ' + FLayers[AIndex].Letter;
    FActions.Progress(ProgressEvent);
    FActions.Log('ERROR: no protocol for letter ' + FLayers[AIndex].Letter);
    FFailed := True;
    Exit;
  end;
  ProgressEvent.LayerIndex := AIndex + 1;
  ProgressEvent.LayerCount := Length(FLayers);
  ProgressEvent.OperationIndex := 0;
  ProgressEvent.ErrorText := '';
  FActions.Progress(ProgressEvent);
  FActions.Log('CICLE=' + IntToStr(AIndex) + ';    PROTOCOL LETTER=' +
    FLayers[AIndex].Letter + '; LAYER NUMBER=' +
    IntToStr(FLayers[AIndex].LayerNumber));
  OperationIndex := 0;
  for B := 0 to Protocol.BlockCount - 1 do
  begin
    FActions.Log('Name=' + Protocol.BlockNames[B]);
    for S := 0 to Protocol.StepCount(B) - 1 do
    begin
      if Aborted then
        Exit;
      Inc(OperationIndex);
      RunStep(Protocol.Steps[B, S], FLayers[AIndex].EZDFile,
        AIndex, OperationIndex);
    end;
    if Aborted then
      Exit;
  end;
end;

function TSynthesisRunner.Run: Boolean;
var
  I: Integer;
  Stopped: Boolean;
begin
  FFailed := False;
  FActions.Log('Synthesis started');
  for I := 0 to High(FLayers) do
  begin
    if Aborted then
      Break;
    RunLayer(I);
  end;
  Stopped := Aborted;
  Result := not Stopped;
  // итог в журнале называет, чем закончился синтез
  if FFailed then
    FActions.Log('Synthesis stopped by error')
  else if Stopped then
    FActions.Log('Synthesis stopped by user')
  else
    FActions.Log('Synthesis completed!');
end;

end.
