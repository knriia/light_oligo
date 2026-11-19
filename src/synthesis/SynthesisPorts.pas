unit SynthesisPorts;
// Порты синтеза: действия исполнения, маркировка слоя, создание слоёв и
// шприцевая станция.
// Реализации оборудования находятся в composition root (app), а synthesis
// работает только с этими контрактами.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, ProtocolFormat, OligoSlices;

type
  // Порт не утверждает успех, если не знает, выполнилось ли действие.
  TPortResult = (prSucceeded, prFailed, prUnknown);

  // Прогресс одной операции синтеза. Индексы слоя и операции начинаются с 1.
  TSynthesisProgress = record
    LayerIndex: Integer;
    LayerCount: Integer;
    OperationIndex: Integer;
    ErrorText: string;
  end;

  // Контекст текущего исполнения. Wait прерывается остановкой, Poll - нет.
  TExecutionContext = class
  public
    function StopRequested: Boolean; virtual; abstract;
    procedure Wait(AMilliseconds: Integer); virtual; abstract;
    procedure Poll(AMilliseconds: Integer); virtual; abstract;
    procedure Log(const AText: string); virtual; abstract;
    // Маршалинг вызова в главный поток. Для не-GUI подставных контекстов
    // достаточно реализации по умолчанию.
    procedure Synchronize(AMethod: TThreadMethod); virtual;
  end;

  // Действия, которыми runner исполняет протокол.
  TSynthesisActions = class
  public
    procedure Log(const AText: string); virtual; abstract;
    function StopRequested: Boolean; virtual; abstract;
    procedure Pause(ASeconds: Integer); virtual; abstract;
    procedure Vacuum(AOn: Boolean); virtual; abstract;
    function RunSyringe(const AStep: TSyringeStep;
      out AErrorText: string): TPortResult; virtual; abstract;
    function Laser(ARepeats: Integer; ATimeSeconds: Double;
      const AEzdFile: string; out AErrorText: string): TPortResult;
      virtual; abstract;
    procedure Progress(const AEvent: TSynthesisProgress); virtual;
  end;

  // Порт маркировки одного слоя.
  TLayerMarker = class
  private
    FExecutionContext: TExecutionContext;
  protected
    property ExecutionContext: TExecutionContext read FExecutionContext;
  public
    function MarkLayer(const AEzdFile: string; ARepeats: Integer;
      ATimeSeconds: Double; out AErrorText: string): TPortResult;
      virtual; abstract;
    // Контекст действует только во время вызова MarkLayer.
    procedure SetExecutionContext(AContext: TExecutionContext); virtual;
  end;

  // Чем кончилось создание слоёв синтеза.
  TLayersBuildStatus = (lbsBuilt, lbsCancelled, lbsFailed);

  // Порт слоёв синтеза: геометрия и EZD-файлы слоёв слайса.
  TLayersBuilder = class
  public
    // По слайсу из ASliceFolder (Slices.txt и матрицы слоёв) спрашивает
    // геометрию и создаёт в ASynthesisFolder EZD-файлы слоёв (ezd\), таблицу
    // Slices.lays, geometry.ini и laser.ini. lbsBuilt - все слои созданы,
    // ALayers с путями к EZD; lbsCancelled - пользователь отказался, ничего
    // не создано; lbsFailed - причина в AErrorText, часть файлов могла
    // остаться (чистит вызывающий).
    function Build(const ASliceFolder, ASynthesisFolder: string;
      out ALayers: TSliceLayers;
      out AErrorText: string): TLayersBuildStatus; virtual; abstract;
    // Показывает геометрию, с которой созданы слои синтеза (geometry.ini в
    // ASynthesisFolder), на занятых ячейках слайса ASliceFolder. Только
    // просмотр: изменить параметры нельзя. False - показать не удалось.
    function ShowGeometry(const ASliceFolder, ASynthesisFolder: string;
      out AErrorText: string): Boolean; virtual; abstract;
  end;

  // Порт шприцевой станции.
  TSyringeStation = class
  public
    function StartSyringeStep(const AStep: TSyringeStep;
      out AError: string): Boolean; virtual; abstract;
    function SyringeStepStatus(out AError: string): TSyringeStepStatus;
      virtual; abstract;
    procedure StopSyringeStep; virtual; abstract;
  end;

implementation

procedure TExecutionContext.Synchronize(AMethod: TThreadMethod);
begin
  if Assigned(AMethod) then
    AMethod;
end;

procedure TSynthesisActions.Progress(const AEvent: TSynthesisProgress);
begin
end;

procedure TLayerMarker.SetExecutionContext(AContext: TExecutionContext);
begin
  FExecutionContext := AContext;
end;

end.
