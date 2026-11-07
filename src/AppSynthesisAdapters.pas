unit AppSynthesisAdapters;
// Реализации портов синтеза в composition root приложения. Этот модуль
// единственный связывает synthesis с EzCAD и формой шприцевой станции.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat, SynthesisPorts, LaserMarking, EzCadApp,
  UDispenserStationHost;

type
  // Драйвер EzCAD использует контекст для маршалинга наблюдателя в UI.
  TThreadEzCadDriver = class(TEzCadDriver)
  private
    FContext: TExecutionContext;
    FOnOpening: TThreadMethod;
    procedure NotifyOpening;
  public
    constructor Create(AContext: TExecutionContext;
      AOnOpening: TThreadMethod);
    function IsRunning: Boolean; override;
    function Launch(const AEzdFile: string): Boolean; override;
    function SendMark: Boolean; override;
    procedure Close; override;
    procedure Opening; override;
  end;

  // Реализация маркировки через текущий EzCAD.
  TEzCadLayerMarker = class(TLayerMarker)
  private
    FOpenDelayMs: Integer;
    FOnOpening: TThreadMethod;
  public
    constructor Create(AOpenDelayMs: Integer; AOnOpening: TThreadMethod);
    function MarkLayer(const AEzdFile: string; ARepeats: Integer;
      ATimeSeconds: Double; out AErrorText: string): TPortResult; override;
  end;

  // Адаптер формы станции к порту synthesis.
  TStationSyringeAdapter = class(TSyringeStation)
  private
    FStation: TDispenserStationForm;
  public
    constructor Create(AStation: TDispenserStationForm);
    function StartSyringeStep(const AStep: TSyringeStep;
      out AError: string): Boolean; override;
    function SyringeStepStatus(out AError: string): TSyringeStepStatus;
      override;
    procedure StopSyringeStep; override;
  end;

implementation

{ TThreadEzCadDriver }

constructor TThreadEzCadDriver.Create(AContext: TExecutionContext;
  AOnOpening: TThreadMethod);
begin
  inherited Create;
  FContext := AContext;
  FOnOpening := AOnOpening;
end;

procedure TThreadEzCadDriver.NotifyOpening;
begin
  if Assigned(FOnOpening) then
    FOnOpening;
end;

function TThreadEzCadDriver.IsRunning: Boolean;
begin
  Result := EzCadRunning;
end;

function TThreadEzCadDriver.Launch(const AEzdFile: string): Boolean;
begin
  // путь к файлу берётся в кавычки: в нём могут быть пробелы и кириллица
  Result := LaunchEzCad(ExtractFilePath(ParamStr(0)), AEzdFile);
end;

function TThreadEzCadDriver.SendMark: Boolean;
begin
  Result := SendEzCadMark;
end;

procedure TThreadEzCadDriver.Close;
begin
  CloseEzCad;
end;

procedure TThreadEzCadDriver.Opening;
begin
  FContext.Synchronize(@NotifyOpening);
end;

{ TEzCadLayerMarker }

constructor TEzCadLayerMarker.Create(AOpenDelayMs: Integer;
  AOnOpening: TThreadMethod);
begin
  inherited Create;
  FOpenDelayMs := AOpenDelayMs;
  FOnOpening := AOnOpening;
end;

function TEzCadLayerMarker.MarkLayer(const AEzdFile: string;
  ARepeats: Integer; ATimeSeconds: Double;
  out AErrorText: string): TPortResult;
var
  Driver: TThreadEzCadDriver;
begin
  if ExecutionContext = nil then
  begin
    AErrorText := 'контекст исполнения не задан.';
    Exit(prFailed);
  end;
  Driver := TThreadEzCadDriver.Create(ExecutionContext, FOnOpening);
  try
    Result := MarkLayerWithEzCad(Driver, ExecutionContext, AEzdFile, ARepeats,
      ATimeSeconds, FOpenDelayMs, AErrorText);
  finally
    Driver.Free;
  end;
end;

{ TStationSyringeAdapter }

constructor TStationSyringeAdapter.Create(AStation: TDispenserStationForm);
begin
  inherited Create;
  FStation := AStation;
end;

function TStationSyringeAdapter.StartSyringeStep(const AStep: TSyringeStep;
  out AError: string): Boolean;
begin
  if FStation = nil then
  begin
    AError := 'шприцевая станция не создана.';
    Exit(False);
  end;
  Result := FStation.StartSyringeStep(AStep, AError);
end;

function TStationSyringeAdapter.SyringeStepStatus(
  out AError: string): TSyringeStepStatus;
begin
  if FStation = nil then
  begin
    AError := 'шприцевая станция не создана.';
    Exit(sssFailed);
  end;
  Result := FStation.SyringeStepStatus(AError);
end;

procedure TStationSyringeAdapter.StopSyringeStep;
begin
  if FStation <> nil then
    FStation.StopSyringeStep;
end;

end.
