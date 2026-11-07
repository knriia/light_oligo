unit AppComposition;
// Composition root приложения: создаёт формы вкладок, адаптеры и связывает
// их с оболочкой главного окна.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, OligoSlices,
  UProtocolForm, USynthesisForm, UDispenserStationHost, USequencesForm,
  UManualForm, EzCadApp, AppSynthesisAdapters;

type
  { TAppComposition }

  TAppComposition = class
  private
    FOwner: TComponent;
    FManualParent: TWinControl;
    FProtocolParent: TWinControl;
    FSynthesisParent: TWinControl;
    FSequencesParent: TWinControl;
    FManualLog: TManualLogEvent;
    FSynthesisLog: TSynthesisLogEvent;
    FSequencesLog: TSequencesLogEvent;
    FClearLog: TNotifyEvent;
    FStationLog: TDispenserStationLogEvent;
    FStartEzCadWatcher: TThreadMethod;
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    FProtocolForm: TProtocolForm;
    FSynthesisForm: TSynthesisForm;
    FManualForm: TManualForm;
    FEzCadWatcher: TEzCadDialogWatcher;
    FSynthesisStation: TStationSyringeAdapter;
    FSynthesisMarker: TEzCadLayerMarker;
    procedure LayersChanged(const ALayers: TSliceLayers);
  public
    constructor Create(AOwner: TComponent; AManualParent,
      AProtocolParent, ASynthesisParent, ASequencesParent: TWinControl;
      AManualLog: TManualLogEvent; ASynthesisLog: TSynthesisLogEvent;
      ASequencesLog: TSequencesLogEvent; AClearLog: TNotifyEvent;
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
  end;

implementation

uses
  AppPaths, Localization;

{ TAppComposition }

constructor TAppComposition.Create(AOwner: TComponent; AManualParent,
  AProtocolParent, ASynthesisParent, ASequencesParent: TWinControl;
  AManualLog: TManualLogEvent; ASynthesisLog: TSynthesisLogEvent;
  ASequencesLog: TSequencesLogEvent; AClearLog: TNotifyEvent;
  AStationLog: TDispenserStationLogEvent;
  AStartEzCadWatcher: TThreadMethod);
begin
  inherited Create;
  FOwner := AOwner;
  FManualParent := AManualParent;
  FProtocolParent := AProtocolParent;
  FSynthesisParent := ASynthesisParent;
  FSequencesParent := ASequencesParent;
  FManualLog := AManualLog;
  FSynthesisLog := ASynthesisLog;
  FSequencesLog := ASequencesLog;
  FClearLog := AClearLog;
  FStationLog := AStationLog;
  FStartEzCadWatcher := AStartEzCadWatcher;
end;

destructor TAppComposition.Destroy;
begin
  // Формы принадлежат FOwner и уже освобождены его деструктором.
  // Адаптеры и наблюдатель освобождаются после дочерних форм.
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
  FManualForm.Parent := FManualParent;
  FManualForm.Align := alClient;
  FManualForm.ApplyCaptions(InterfaceIniFile);
  FManualForm.LoadSettings;
  FManualForm.OnLog := FManualLog;
  FManualForm.Show;

  FProtocolForm := TProtocolForm.Create(FOwner);
  FProtocolForm.BorderStyle := bsNone;
  FProtocolForm.Parent := FProtocolParent;
  FProtocolForm.Align := alClient;
  FProtocolForm.ApplyCaptions(InterfaceIniFile);
  FProtocolForm.Show;

  FDispenserStation := TDispenserStationForm.Create(FOwner);
  FDispenserStation.BorderStyle := bsNone;
  FDispenserStation.Parent := FManualForm.GB_PumpStation;
  FDispenserStation.Align := alClient;
  FDispenserStation.AttachLogSink(FStationLog);
  FDispenserStation.Show;

  FSynthesisStation := TStationSyringeAdapter.Create(FDispenserStation);
  FSynthesisMarker := TEzCadLayerMarker.Create(
    ReadConfigInteger('Laser', 'EzCAD2OpenTime', 1000),
    FStartEzCadWatcher);

  FSynthesisForm := TSynthesisForm.Create(FOwner);
  FSynthesisForm.BorderStyle := bsNone;
  FSynthesisForm.Parent := FSynthesisParent;
  FSynthesisForm.Align := alClient;
  FSynthesisForm.ApplyCaptions(InterfaceIniFile);
  FSynthesisForm.Station := FSynthesisStation;
  FSynthesisForm.Marker := FSynthesisMarker;
  FSynthesisForm.OnLog := FSynthesisLog;
  FSynthesisForm.OnClearLog := FClearLog;
  FSynthesisForm.Show;

  FSequencesForm := TSequencesForm.Create(FOwner);
  FSequencesForm.BorderStyle := bsNone;
  FSequencesForm.Parent := FSequencesParent;
  FSequencesForm.Align := alClient;
  FSequencesForm.ApplyCaptions(InterfaceIniFile);
  FSequencesForm.OnLog := FSequencesLog;
  FSequencesForm.OnLayersChanged := @LayersChanged;
  FSequencesForm.Show;
end;

procedure TAppComposition.LayersChanged(const ALayers: TSliceLayers);
begin
  FSynthesisForm.SetLayers(ALayers);
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
