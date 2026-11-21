unit AppComposition;
// Composition root приложения: создаёт формы вкладок, адаптеры и связывает
// их с оболочкой главного окна.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls,
  UProtocolForm, USynthesisForm, UDispenserStationHost, USequencesForm,
  UManualForm, ULaserActions, EzCadApp, AppSynthesisAdapters;

type
  { TAppComposition }

  TAppComposition = class
  private
    FOwner: TComponent;
    FHolder: TWinControl;
    FManualLog: TManualLogEvent;
    FSynthesisLog: TSynthesisLogEvent;
    FSequencesLog: TSequencesLogEvent;
    FLaserLog: TLaserLogEvent;
    FClearLog: TNotifyEvent;
    FStationLog: TDispenserStationLogEvent;
    FStartEzCadWatcher: TThreadMethod;
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    FProtocolForm: TProtocolForm;
    FSynthesisForm: TSynthesisForm;
    FManualForm: TManualForm;
    FLaserActions: TLaserActions;
    FEzCadWatcher: TEzCadDialogWatcher;
    FSynthesisStation: TStationSyringeAdapter;
    FSynthesisMarker: TEzCadLayerMarker;
    FSynthesisLayers: TLaserLayersBuilder;
  public
    // AHolder - невидимый контейнер, в котором формы создаются; на вкладки
    // их переносит хост документов.
    constructor Create(AOwner: TComponent; AHolder: TWinControl;
      AManualLog: TManualLogEvent; ASynthesisLog: TSynthesisLogEvent;
      ASequencesLog: TSequencesLogEvent; ALaserLog: TLaserLogEvent;
      AClearLog: TNotifyEvent;
      AStationLog: TDispenserStationLogEvent;
      AStartEzCadWatcher: TThreadMethod);
    destructor Destroy; override;
    // Порядок вызова: сначала Initialize (данные, папки, локализация),
    // потом Build (формы вкладок); каждый - один раз.
    procedure Initialize;
    procedure Build;
    function CanCloseAll: Boolean;
    procedure EzCadWatcherStart;
    function EzCadWatcherTick: Boolean;
    property SequencesForm: TSequencesForm read FSequencesForm;
    property ManualForm: TManualForm read FManualForm;
    property ProtocolForm: TProtocolForm read FProtocolForm;
    property SynthesisForm: TSynthesisForm read FSynthesisForm;
    property LaserActions: TLaserActions read FLaserActions;
  end;

implementation

uses
  AppPaths, Localization;

{ TAppComposition }

constructor TAppComposition.Create(AOwner: TComponent; AHolder: TWinControl;
  AManualLog: TManualLogEvent; ASynthesisLog: TSynthesisLogEvent;
  ASequencesLog: TSequencesLogEvent; ALaserLog: TLaserLogEvent;
  AClearLog: TNotifyEvent;
  AStationLog: TDispenserStationLogEvent;
  AStartEzCadWatcher: TThreadMethod);
begin
  inherited Create;
  FOwner := AOwner;
  FHolder := AHolder;
  FManualLog := AManualLog;
  FSynthesisLog := ASynthesisLog;
  FSequencesLog := ASequencesLog;
  FLaserLog := ALaserLog;
  FClearLog := AClearLog;
  FStationLog := AStationLog;
  FStartEzCadWatcher := AStartEzCadWatcher;
end;

destructor TAppComposition.Destroy;
begin
  // Формы принадлежат FOwner и уже освобождены его деструктором.
  // Адаптеры, действия лазера и наблюдатель освобождаются после дочерних форм.
  FreeAndNil(FSynthesisLayers);
  FreeAndNil(FLaserActions);
  FreeAndNil(FSynthesisMarker);
  FreeAndNil(FSynthesisStation);
  FreeAndNil(FEzCadWatcher);
  inherited Destroy;
end;

procedure TAppComposition.Initialize;
begin
  // папка data с данными рядом с exe; переносим туда данные из старых мест
  MigrateLegacyData;
  EnsureDataDirs;

  // интерфейс и настройки
  InitializeLocalization(ConfigFilePath(INTERFACE_FILE),
    ConfigFilePath(PROG_CONFIG_FILE));
end;

procedure TAppComposition.Build;
begin
  Assert(InterfaceIniFile <> nil, 'Build вызван до Initialize');
  Assert(FEzCadWatcher = nil, 'Build вызван повторно');
  // для экранов с включенным масштабированием
  FEzCadWatcher := TEzCadDialogWatcher.Create;

  // Порядок создания форм важен для Parent, Align и ApplyCaptions.
  FManualForm := TManualForm.Create(FOwner);
  FManualForm.BorderStyle := bsNone;
  FManualForm.Parent := FHolder;
  FManualForm.Align := alClient;
  FManualForm.ApplyCaptions(InterfaceIniFile);
  FManualForm.LoadSettings;
  FManualForm.OnLog := FManualLog;
  FManualForm.Show;

  FProtocolForm := TProtocolForm.Create(FOwner);
  FProtocolForm.BorderStyle := bsNone;
  FProtocolForm.Parent := FHolder;
  FProtocolForm.Align := alClient;
  FProtocolForm.ApplyCaptions(InterfaceIniFile);
  FProtocolForm.Show;

  FDispenserStation := TDispenserStationForm.Create(FOwner);
  FDispenserStation.BorderStyle := bsNone;
  FDispenserStation.Parent := FManualForm.GB_PumpStation;
  FDispenserStation.Align := alClient;
  FDispenserStation.AttachLogSink(FStationLog);
  FDispenserStation.Show;
  FProtocolForm.OnCheckSyringeStep := @FDispenserStation.CheckSyringeStepConfig;

  // действия лазера нужны и вкладке синтеза (слои), и вкладке последовательностей
  FLaserActions := TLaserActions.Create;
  FLaserActions.OnLog := FLaserLog;
  FLaserActions.LoadSettings;
  FSynthesisLayers := TLaserLayersBuilder.Create(FLaserActions);

  FSynthesisStation := TStationSyringeAdapter.Create(FDispenserStation);
  FSynthesisMarker := TEzCadLayerMarker.Create(
    ReadConfigInteger('Laser', 'EzCAD2OpenTime', 1000),
    FStartEzCadWatcher);

  FSynthesisForm := TSynthesisForm.Create(FOwner);
  FSynthesisForm.BorderStyle := bsNone;
  FSynthesisForm.Parent := FHolder;
  FSynthesisForm.Align := alClient;
  FSynthesisForm.ApplyCaptions(InterfaceIniFile);
  FSynthesisForm.Station := FSynthesisStation;
  FSynthesisForm.OnCheckSyringeStep := @FDispenserStation.CheckSyringeStepConfig;
  FSynthesisForm.Marker := FSynthesisMarker;
  FSynthesisForm.LayersBuilder := FSynthesisLayers;
  // кнопка параметров лазера на вкладке синтеза: форма про лазер не знает,
  // действие подключается здесь
  FSynthesisForm.OnEditLaserParams := @FLaserActions.EditLaserParams;
  FSynthesisForm.OnLog := FSynthesisLog;
  FSynthesisForm.OnClearLog := FClearLog;
  FSynthesisForm.Show;

  FSequencesForm := TSequencesForm.Create(FOwner);
  FSequencesForm.BorderStyle := bsNone;
  FSequencesForm.Parent := FHolder;
  FSequencesForm.Align := alClient;
  FSequencesForm.ApplyCaptions(InterfaceIniFile);
  FSequencesForm.OnLog := FSequencesLog;

  FSequencesForm.Show;

  // проект для синтеза задаёт главное окно (выбор в дереве проектов)
end;

function TAppComposition.CanCloseAll: Boolean;
begin
  Result := False;

  // сначала протокол и массив: вопрос о сохранении ничего не меняет в
  // оборудовании
  if Assigned(FProtocolForm) and
     not FProtocolForm.CanCloseFromHost then
    Exit;

  if Assigned(FSequencesForm) and
     not FSequencesForm.CanCloseFromHost then
    Exit;

  if Assigned(FSynthesisForm) and
     not FSynthesisForm.CanCloseFromHost then
    Exit;

  if Assigned(FDispenserStation) and
     not FDispenserStation.CanCloseFromHost then
    Exit;

  Result := True;
end;

procedure TAppComposition.EzCadWatcherStart;
begin
  FEzCadWatcher.Start;
end;

function TAppComposition.EzCadWatcherTick: Boolean;
begin
  Result := FEzCadWatcher.Tick;
end;

end.
