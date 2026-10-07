unit UDispenserStationHost;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, DispenserController, DispenserConfig,
  DispenserConfigStorage, ConfigurationForm, DispenserView, DispenserTable,
  DispenserCapacityValidator, WindowSettingsStorage, DispenserLayout,
  DispenserConnectionCoordinator,
  DispenserOperationCoordinator, DispenserRuntimeState, DispenserTypes,
  DispenserLimits, AutomationEditorView, AutomationProtocol,
  AutomationProtocolRunner, FormWorkDispatcher;

type
  TDispenserStationLogEvent = procedure(Sender: TObject; const Msg: string) of object;

  { TDispenserStationForm }

  TDispenserStationForm = class(TForm)
    btnConnect: TButton;
    btnConfiguration: TButton;
    btnEmptySelected: TButton;
    btnAspirateSelected: TButton;
    btnDispenseSelected: TButton;
    btnFillSelected: TButton;
    btnInitializeAll: TButton;
    btnStopAll: TButton;
    btnScanPorts: TButton;
    BatchPanel: TPanel;
    ConnectionPanel: TPanel;
    ComboBoxPorts: TComboBox;
    LabelEmpty: TLabel;
    LabelPorts: TLabel;
    LogPanel: TPanel;
    LogSplitter: TSplitter;
    MemoLog: TMemo;
    ScrollBoxDispensers: TScrollBox;
    StatusBar1: TStatusBar;
    TablePanel: TPanel;

    procedure btnConnectClick(Sender: TObject);
    procedure btnConfigurationClick(Sender: TObject);
    procedure btnEmptySelectedClick(Sender: TObject);
    procedure btnAspirateSelectedClick(Sender: TObject);
    procedure btnDispenseSelectedClick(Sender: TObject);
    procedure btnFillSelectedClick(Sender: TObject);
    procedure btnInitializeAllClick(Sender: TObject);
    procedure btnStopAllClick(Sender: TObject);
    procedure btnScanPortsClick(Sender: TObject);
    procedure ComboBoxPortsChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure LogSplitterCanResize(Sender: TObject; var NewSize: Integer;
      var Accept: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

  private
    FDispenser: TDispenserController;
    FOnLogMessage: TDispenserStationLogEvent;
    FRuntimeStates: TDispenserRuntimeStates;
    FConnectionCoordinator: TDispenserConnectionCoordinator;
    FOperationCoordinator: TDispenserOperationCoordinator;
    FAutomationRunner: TAutomationProtocolRunner;
    FConfigurations: TDispenserConfigList;
    FStorage: TDispenserConfigStorage;
    FTable: TDispenserTable;
    FMainPageControl: TPageControl;
    FDispenserPage: TTabSheet;
    FAutomationPage: TAutomationEditorView;
    FWindowSettings: TWindowSettingsStorage;
    FOperationTimer: TTimer;
    FWorkDispatcher: TFormWorkDispatcher;
    FPendingWorkItems: TList;
    FQueuedUiEvents: TThreadList;
    FPollTaskActive: Boolean;
    FDrainingWorkItems: Boolean;
    FConnectionTaskActive: Boolean;
    FScanTaskActive: Boolean;
    FProtocolTaskActive: Boolean;
    FInitializationUiPending: Boolean;
    FPendingAutomationProtocol: TAutomationProtocol;
    FInitializingAddresses: array[MIN_DISPENSER_VALUE..
      MAX_DISPENSER_VALUE] of Boolean;
    FProtocolReserved: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    FSelectedOperationRequests: TDispenserOperationRequestArray;
    FSelectedOperationRequestCount: Integer;

    procedure ClearFocusOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Log(const Msg: string);
    procedure ShowOperationWarning(const Msg: string);
    function EnsureAllDispensersEmpty: Boolean;
    procedure SaveCurrentSettings;
    procedure CreateMainPages;
    procedure UpdateUI;
    function InitializeDispensers(AConfigurations:
      TDispenserConfigList; AAddress: Integer; out ErrorText: string): Boolean;
    function ApplyConfiguration(AConfigurations:
      TDispenserConfigList; out ErrorText: string): Boolean;
    procedure SelectionChanged(AView: TDispenserView);
    procedure ExecuteRowOperation(AView: TDispenserView;
      AKind: TDispenserOperationKind);
    procedure CollectSelectedOperation(AView: TDispenserView);
    procedure ExecuteSelectedOperation(AKind: TDispenserOperationKind);
    procedure FillDispenser(AView: TDispenserView);
    procedure EmptyDispenser(AView: TDispenserView);
    procedure AspirateDispenser(AView: TDispenserView);
    procedure DispenseDispenser(AView: TDispenserView);
    procedure StopDispenser(AView: TDispenserView);
    procedure InitializeDispenser(AView: TDispenserView);
    procedure OperationSettingsChanged(AView: TDispenserView);
    function BypassChanged(AView: TDispenserView; AEnabled: Boolean): Boolean;
    procedure OperationSettingsWarning(AView: TDispenserView;
      const AReason: string);
    function HasActiveOperations: Boolean;
    procedure OperationTimerTick(Sender: TObject);
    procedure OperationStateChanged(AAddress: Integer);
    procedure OperationFailed(AAddress: Integer; const MessageText: string;
      UpdateAndSaveVolume: Boolean);
    procedure RunAutomationProtocol(Sender: TObject);
    procedure AutomationProtocolFinished(const MessageText: string;
      Failed: Boolean);
    procedure ExecuteWorkItem(AWorkItem: TObject);
    procedure QueueWorkItem(AWorkItem: TObject);
    procedure DrainCompletedWorkItems;
    procedure DrainQueuedUiEvents;
    procedure QueueUiEvent(AEvent: TObject);
    procedure ApplyOperationStateChanged(AAddress: Integer);
    procedure ApplyOperationFailed(AAddress: Integer;
      const MessageText: string; UpdateAndSaveVolume: Boolean);
    procedure ApplyAutomationProtocolFinished(const MessageText: string;
      Failed: Boolean);
    function HasPendingInitializationTask(AAddress: Integer): Boolean;
    procedure FinishInitializationIfComplete;
    procedure QueuePendingAutomationProtocol;
    procedure ReleaseProtocolReservations;
  public
    procedure AttachLogSink(AHandler: TDispenserStationLogEvent);
    function CanCloseFromHost: Boolean;
  end;


var
  DispenserStationForm: TDispenserStationForm;

implementation

type
  TFormWorkKind = (btkStartSingle, btkStartGroup, btkInitialize,
    btkPrepareProtocol, btkPoll, btkBypass, btkChangeSpeed, btkStopOne,
    btkStopAll,
    btkStartProtocol, btkStopProtocol, btkConnect, btkDisconnect, btkScanPorts);

  TFormWorkItem = class
  private
    FKind: TFormWorkKind;
    FCompleted: Boolean;
    FCompletionLock: TCriticalSection;
  public
    Config: TDispenserConfig;
    Configs: TDispenserConfigList;
    Requests: TDispenserOperationRequestArray;
    Protocol: TAutomationProtocol;
    Failures: TStringList;
    PortList: TStringList;
    PortName: string;
    Address: Integer;
    Channel: Integer;
    Speed: Integer;
    OperationKind: TDispenserOperationKind;
    BypassEnabled: Boolean;
    BypassValveType: TDispenserValveType;
    ReservedAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
      of Boolean;
    Success: Boolean;
    ErrorText: string;
    SingleResult: TDispenserOperationStartResult;
    GroupResult: TDispenserGroupStartResult;
    ConnectionResult: TDispenserConnectionResult;
    constructor Create(AKind: TFormWorkKind);
    destructor Destroy; override;
    function IsCompleted: Boolean;
    function WorkKind: TFormWorkKind;
    procedure MarkCompleted;
  end;

  TQueuedUiEventKind = (quLog, quStateChanged, quFailure,
    quProtocolFinished);

  TQueuedUiEvent = class
  public
    Kind: TQueuedUiEventKind;
    Address: Integer;
    MessageText: string;
    Flag: Boolean;
    UpdateAndSaveVolume: Boolean;
  end;

{$R *.lfm}

constructor TFormWorkItem.Create(AKind: TFormWorkKind);
var
  LoopAddress: Integer;
begin
  FKind := AKind;
  FCompleted := False;
  SingleResult := dosrCommandFailed;
  GroupResult := dgsRejected;
  ConnectionResult := dcrPortOpenFailed;
  FCompletionLock := TCriticalSection.Create;
  for LoopAddress := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    ReservedAddresses[LoopAddress] := False;
end;

destructor TFormWorkItem.Destroy;
var
  I: Integer;
begin
  Config.Free;
  Configs.Free;
  for I := 0 to High(Requests) do
    Requests[I].Config.Free;
  SetLength(Requests, 0);
  Protocol.Free;
  Failures.Free;
  PortList.Free;
  FCompletionLock.Free;
  inherited Destroy;
end;

procedure TFormWorkItem.MarkCompleted;
begin
  FCompletionLock.Acquire;
  try
    FCompleted := True;
  finally
    FCompletionLock.Release;
  end;
end;

function TFormWorkItem.IsCompleted: Boolean;
begin
  FCompletionLock.Acquire;
  try
    Result := FCompleted;
  finally
    FCompletionLock.Release;
  end;
end;

function TFormWorkItem.WorkKind: TFormWorkKind;
begin
  Result := FKind;
end;

{ TDispenserStationForm }

procedure TDispenserStationForm.FormCreate(Sender: TObject);
var
  LoadError: string;
  AutomationLoadError: string;
  LastPort: string;
  SavedWidth: Integer;
  SavedHeight: Integer;
  Address: Integer;
begin
  FPendingWorkItems := TList.Create;
  FQueuedUiEvents := TThreadList.Create;
  FWorkDispatcher := nil;
  FPollTaskActive := False;
  FDrainingWorkItems := False;
  FConnectionTaskActive := False;
  FScanTaskActive := False;
  FProtocolTaskActive := False;
  FInitializationUiPending := False;
  FPendingAutomationProtocol := nil;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    FInitializingAddresses[Address] := False;
  Constraints.MinWidth := 0;
  Constraints.MinHeight := 0;
  FWindowSettings := TWindowSettingsStorage.Create('', 'MainWindow');
  ConnectionPanel.TabStop := True;
  TablePanel.TabStop := True;
  BatchPanel.TabStop := True;
  MemoLog.TabStop := True;
  StatusBar1.TabStop := True;
  StatusBar1.Align := alBottom;
  LogSplitter.AutoSnap := False;
  LogSplitter.MinSize := 10;
  LogPanel.Constraints.MinHeight := 10;
  ConnectionPanel.OnMouseDown := @ClearFocusOnMouseDown;
  ConnectionPanel.OnMouseUp := @ClearFocusOnMouseDown;
  TablePanel.OnMouseDown := @ClearFocusOnMouseDown;
  TablePanel.OnMouseUp := @ClearFocusOnMouseDown;
  BatchPanel.OnMouseDown := @ClearFocusOnMouseDown;
  BatchPanel.OnMouseUp := @ClearFocusOnMouseDown;
  MemoLog.OnMouseDown := @ClearFocusOnMouseDown;
  MemoLog.OnMouseUp := @ClearFocusOnMouseDown;
  StatusBar1.OnMouseDown := @ClearFocusOnMouseDown;
  StatusBar1.OnMouseUp := @ClearFocusOnMouseDown;
  FWindowSettings.Load(Width, Height, SavedWidth, SavedHeight);
  if SavedWidth < Constraints.MinWidth then
    SavedWidth := Constraints.MinWidth;
  if SavedHeight < Constraints.MinHeight then
    SavedHeight := Constraints.MinHeight;
  Width := SavedWidth;
  Height := SavedHeight;
  LastPort := FWindowSettings.LoadLastPort;

  CreateMainPages;
  FAutomationPage.OnRunProtocol := @RunAutomationProtocol;

  FStorage := TDispenserConfigStorage.Create;
  FConfigurations := nil;
  if not FStorage.Load(FConfigurations, LoadError) then
    FConfigurations := TDispenserConfigList.Create;

  FRuntimeStates := TDispenserRuntimeStates.Create;
  FDispenser := TDispenserController.Create;
  FDispenser.OnLogMessage := @Log;
  FConnectionCoordinator := TDispenserConnectionCoordinator.Create(FDispenser,
    FRuntimeStates);
  FConnectionCoordinator.OnLogMessage := @Log;
  FOperationCoordinator := TDispenserOperationCoordinator.Create(FDispenser,
    FRuntimeStates);
  FOperationCoordinator.OnLogMessage := @Log;
  FOperationCoordinator.OnStateChanged := @OperationStateChanged;
  FOperationCoordinator.OnFailure := @OperationFailed;
  FAutomationRunner := TAutomationProtocolRunner.Create(FDispenser,
    FRuntimeStates);
  FAutomationRunner.OnLogMessage := @Log;
  FAutomationRunner.OnStateChanged := @OperationStateChanged;
  FAutomationRunner.OnFinished := @AutomationProtocolFinished;
  FOperationTimer := TTimer.Create(Self);
  FOperationTimer.Interval := 100;
  FOperationTimer.Enabled := False;
  FOperationTimer.OnTimer := @OperationTimerTick;
  FTable := TDispenserTable.Create(TablePanel, ScrollBoxDispensers, LabelEmpty,
    @SelectionChanged, @FillDispenser, @EmptyDispenser,
    @AspirateDispenser, @DispenseDispenser, @StopDispenser,
    @InitializeDispenser, @BypassChanged,
    @OperationSettingsChanged,
    @OperationSettingsWarning);

  FWorkDispatcher := TFormWorkDispatcher.Create(@ExecuteWorkItem);
  ComboBoxPorts.Text := LastPort;
  btnScanPortsClick(nil);
  FTable.SetConfigurations(FConfigurations);
  FTable.RefreshCurrentVolumes(@FRuntimeStates.GetCurrentVolume,
    @FRuntimeStates.IsCurrentVolumeKnown);
  FAutomationPage.LoadLastSavedFile(AutomationLoadError);
  Log('Программа запущена');
  if LoadError <> '' then
    Log('Ошибка загрузки настроек: ' + LoadError);
  if AutomationLoadError <> '' then
    Log('Ошибка загрузки последнего сценария: ' + AutomationLoadError);
  UpdateUI;
end;

procedure TDispenserStationForm.CreateMainPages;
begin
  FMainPageControl := TPageControl.Create(Self);
  FMainPageControl.Name := 'MainPageControl';
  FMainPageControl.Parent := Self;
  FMainPageControl.Align := alClient;
  FMainPageControl.TabOrder := 1;

  FDispenserPage := TTabSheet.Create(FMainPageControl);
  FDispenserPage.PageControl := FMainPageControl;
  FDispenserPage.Caption := 'Дозаторы';

  TablePanel.Parent := FDispenserPage;
  TablePanel.Align := alClient;
  BatchPanel.Parent := FDispenserPage;
  BatchPanel.Align := alBottom;

  FAutomationPage := TAutomationEditorView.Create(FMainPageControl);
  FAutomationPage.PageControl := FMainPageControl;
  FAutomationPage.SettingsStorage := FWindowSettings;
  FMainPageControl.ActivePage := FDispenserPage;
  FMainPageControl.BringToFront;
  Realign;
end;

procedure TDispenserStationForm.ClearFocusOnMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TWinControl then
  begin
    TWinControl(Sender).TabStop := True;
    TWinControl(Sender).SetFocus;
  end;
end;

procedure TDispenserStationForm.FormDestroy(Sender: TObject);
var
  I: Integer;
  Events: TList;
begin
  if FOperationTimer <> nil then
    FOperationTimer.Enabled := False;
  if FWorkDispatcher <> nil then
  begin
    FWorkDispatcher.Stop;
    FWorkDispatcher.Free;
    FWorkDispatcher := nil;
  end;
  if FPendingWorkItems <> nil then
  begin
    for I := FPendingWorkItems.Count - 1 downto 0 do
      TObject(FPendingWorkItems[I]).Free;
    FPendingWorkItems.Free;
    FPendingWorkItems := nil;
  end;
  if FQueuedUiEvents <> nil then
  begin
    Events := FQueuedUiEvents.LockList;
    try
      for I := 0 to Events.Count - 1 do
        TObject(Events[I]).Free;
      Events.Clear;
    finally
      FQueuedUiEvents.UnlockList;
    end;
    FQueuedUiEvents.Free;
    FQueuedUiEvents := nil;
  end;
  FPendingAutomationProtocol.Free;
  FPendingAutomationProtocol := nil;
  if FWindowSettings <> nil then
    FWindowSettings.Save(Width, Height);
  SaveCurrentSettings;
  FAutomationRunner.Free;
  FTable.Free;
  FConfigurations.Free;
  FConnectionCoordinator.Free;
  FOperationCoordinator.Free;
  FDispenser.Free;
  FRuntimeStates.Free;
  FStorage.Free;
  FWindowSettings.Free;
end;

procedure TDispenserStationForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if not CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  CloseAction := caFree;
end;

function TDispenserStationForm.CanCloseFromHost: Boolean;
begin
  Result := False;
  if HasActiveOperations then
  begin
    ShowOperationWarning('Дождитесь завершения операций дозаторов.');
    Exit;
  end;

  if not EnsureAllDispensersEmpty then
    Exit;

  if (FAutomationPage <> nil) and not FAutomationPage.ConfirmClose then
    Exit;

  Result := True;
end;

procedure TDispenserStationForm.AttachLogSink(AHandler: TDispenserStationLogEvent);
var
  I: Integer;
begin
  FOnLogMessage := AHandler;
  if not Assigned(FOnLogMessage) then
    Exit;

  for I := 0 to MemoLog.Lines.Count - 1 do
    FOnLogMessage(Self, MemoLog.Lines[I]);
  MemoLog.Clear;
  LogPanel.Visible := False;
  LogSplitter.Visible := False;
  LogPanel.Height := 0;
  LogSplitter.Height := 0;
  Realign;
end;

procedure TDispenserStationForm.LogSplitterCanResize(Sender: TObject; var NewSize: Integer;
  var Accept: Boolean);
begin
  if NewSize < 10 then
    NewSize := 10;
  Accept := True;
end;

procedure TDispenserStationForm.Log(const Msg: string);
var
  Event: TQueuedUiEvent;
  LogLine: string;
begin
  if GetCurrentThreadID <> MainThreadID then
  begin
    Event := TQueuedUiEvent.Create;
    Event.Kind := quLog;
    Event.MessageText := Msg;
    QueueUiEvent(Event);
    Exit;
  end;

  LogLine := DateTimeToStr(Now) + ': ' + Msg;
  if Assigned(FOnLogMessage) then
    FOnLogMessage(Self, LogLine)
  else
  begin
    MemoLog.Lines.Add(LogLine);
    MemoLog.SelStart := Length(MemoLog.Text);
  end;
end;

procedure TDispenserStationForm.QueueUiEvent(AEvent: TObject);
var
  Events: TList;
begin
  if (AEvent = nil) or (FQueuedUiEvents = nil) then
  begin
    AEvent.Free;
    Exit;
  end;
  Events := FQueuedUiEvents.LockList;
  try
    Events.Add(AEvent);
  finally
    FQueuedUiEvents.UnlockList;
  end;
end;

procedure TDispenserStationForm.DrainQueuedUiEvents;
var
  Events: TList;
  Pending: TList;
  I: Integer;
  Event: TQueuedUiEvent;
begin
  if FQueuedUiEvents = nil then
    Exit;
  Pending := TList.Create;
  try
    Events := FQueuedUiEvents.LockList;
    try
      for I := 0 to Events.Count - 1 do
        Pending.Add(Events[I]);
      Events.Clear;
    finally
      FQueuedUiEvents.UnlockList;
    end;
    for I := 0 to Pending.Count - 1 do
    begin
      Event := TQueuedUiEvent(Pending[I]);
      case Event.Kind of
        quLog: Log(Event.MessageText);
        quStateChanged: ApplyOperationStateChanged(Event.Address);
        quFailure: ApplyOperationFailed(Event.Address, Event.MessageText,
          Event.UpdateAndSaveVolume);
        quProtocolFinished:
          ApplyAutomationProtocolFinished(Event.MessageText, Event.Flag);
      end;
      Event.Free;
    end;
  finally
    Pending.Free;
  end;
end;

procedure TDispenserStationForm.ShowOperationWarning(const Msg: string);
begin
  Log(Msg);
  ShowMessage(Msg);
end;

function TDispenserStationForm.EnsureAllDispensersEmpty: Boolean;
var
  I: Integer;
  CurrentVolume: Integer;
  WarningText: string;
  FilledDispensers: TStringList;
begin
  Result := True;
  if (FConfigurations = nil) or (FDispenser = nil) then
    Exit;

  FilledDispensers := TStringList.Create;
  try
    if not FDispenser.IsConnected then
      Exit;

    for I := 0 to FConfigurations.Count - 1 do
    begin
      if FRuntimeStates.IsCurrentVolumeKnown(FConfigurations[I].Address) then
      begin
        CurrentVolume := Round(FRuntimeStates.GetCurrentVolume(
          FConfigurations[I].Address));
        if CurrentVolume > 0 then
          FilledDispensers.Add(Format('- %s (адрес %d): %d мкл',
            [FConfigurations[I].Name, FConfigurations[I].Address,
            CurrentVolume]));
      end;
    end;

    if FilledDispensers.Count = 0 then
      Exit;

    WarningText := 'Нельзя закрыть приложение или отключить устройство, '
      + 'пока дозаторы не опустошены.' + LineEnding
      + 'Проверьте следующие дозаторы:' + LineEnding
      + FilledDispensers.Text;
    ShowOperationWarning(WarningText);
    Result := False;
  finally
    FilledDispensers.Free;
  end;
end;

procedure TDispenserStationForm.SaveCurrentSettings;
var
  ErrorText: string;
begin
  if (FTable = nil) or (FStorage = nil) then
    Exit;

  FTable.SaveOperationSettings;
  if not FStorage.Save(FConfigurations, ErrorText) then
    Log('Ошибка сохранения настроек: ' + ErrorText);
end;

procedure TDispenserStationForm.UpdateUI;
var
  I: Integer;
  J: Integer;
  Address: Integer;
  InitializedCount: Integer;
  DispenserCount: Integer;
  State: TDispenserRuntimeState;
  IsInitialized: Boolean;
begin
  btnConnect.Enabled := not FConnectionTaskActive and
    (FDispenser.IsConnected or (Trim(ComboBoxPorts.Text) <> ''));
  btnScanPorts.Enabled := not FDispenser.IsConnected and not FScanTaskActive;
  ComboBoxPorts.Enabled := not FDispenser.IsConnected and
    not FConnectionTaskActive;

  if FDispenser.IsConnected then
    btnConnect.Caption := 'Отключить'
  else
    btnConnect.Caption := 'Подключить';

  if FDispenser.IsConnected then
  begin
    InitializedCount := 0;
    DispenserCount := 0;
    if FConfigurations <> nil then
    begin
      DispenserCount := FConfigurations.Count;
      for I := 0 to FConfigurations.Count - 1 do
        if FRuntimeStates.Items[FConfigurations[I].Address].IsInitializedFor(
          FConfigurations[I]) then
          Inc(InitializedCount);
    end;
    StatusBar1.SimpleText := Format('Подключено: %s; готово дозаторов: %d из %d',
      [FDispenser.PortName, InitializedCount, DispenserCount]);
  end
  else
    StatusBar1.SimpleText := 'Отключено';

  if (FTable <> nil) and not FDispenser.IsConnected then
    FTable.SetAllBypassSupported(False);
  FTable.SetOperationsEnabled(FDispenser.IsConnected);
  FTable.SetProtocolActive(FAutomationRunner.IsRunning);
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    State := FRuntimeStates.Items[Address];
    IsInitialized := False;
    if FConfigurations <> nil then
      for J := 0 to FConfigurations.Count - 1 do
        if FConfigurations[J].Address = Address then
        begin
          IsInitialized := State.IsInitializedFor(FConfigurations[J]);
          Break;
        end;
    FTable.SetOperationEnabled(Address,
      FDispenser.IsConnected and IsInitialized);
    FTable.SetOperationActive(Address, State.OperationActive);
    FTable.SetCommandPending(Address, State.CommandPending);
    FTable.SetProtocolReserved(Address, State.ProtocolReserved);
  end;
  FTable.RefreshCurrentVolumes(@FRuntimeStates.GetCurrentVolume,
    @FRuntimeStates.IsCurrentVolumeKnown);
  btnConfiguration.Enabled := not FAutomationRunner.IsRunning and
    not FProtocolTaskActive;

  btnFillSelected.Enabled := FDispenser.IsConnected and
    FTable.HasSelectedOperableDispensers;
  btnEmptySelected.Enabled := FDispenser.IsConnected and
    FTable.HasSelectedOperableDispensers;
  btnAspirateSelected.Enabled := FDispenser.IsConnected and
    FTable.HasSelectedOperableDispensers;
  btnDispenseSelected.Enabled := FDispenser.IsConnected and
    FTable.HasSelectedOperableDispensers;
  btnInitializeAll.Enabled := not FConnectionTaskActive and
    FDispenser.IsConnected;
  btnStopAll.Enabled := FDispenser.IsConnected and
    (FOperationCoordinator.HasActiveOperations or FAutomationRunner.IsRunning);
end;

function TDispenserStationForm.HasActiveOperations: Boolean;
var
  Address: Integer;
begin
  if (FPendingWorkItems <> nil) and (FPendingWorkItems.Count > 0) then
    Exit(True);
  if FAutomationRunner <> nil then
    if FAutomationRunner.IsRunning then
      Exit(True);
  if (FConnectionCoordinator <> nil) and
    FConnectionCoordinator.HasActiveInitialization then
    Exit(True);
  if FOperationCoordinator = nil then
    Exit(False);
  if FOperationCoordinator.HasActiveOperations then
    Exit(True);
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FRuntimeStates.Items[Address].CommandPending or
      FRuntimeStates.Items[Address].ProtocolReserved then
      Exit(True);
  Result := False;
end;

procedure TDispenserStationForm.OperationStateChanged(AAddress: Integer);
var
  Event: TQueuedUiEvent;
begin
  Event := TQueuedUiEvent.Create;
  Event.Kind := quStateChanged;
  Event.Address := AAddress;
  QueueUiEvent(Event);
end;

procedure TDispenserStationForm.ApplyOperationStateChanged(AAddress: Integer);
var
  State: TDispenserRuntimeState;
begin
  State := FRuntimeStates.Items[AAddress];
  if State = nil then
    Exit;

  FTable.SetOperationActive(AAddress, State.OperationActive);
  FOperationTimer.Enabled := FAutomationRunner.IsRunning or
    FOperationCoordinator.HasActiveOperations or
    FConnectionCoordinator.HasActiveInitialization;
  UpdateUI;
end;

procedure TDispenserStationForm.OperationFailed(AAddress: Integer;
  const MessageText: string; UpdateAndSaveVolume: Boolean);
var
  Event: TQueuedUiEvent;
begin
  Event := TQueuedUiEvent.Create;
  Event.Kind := quFailure;
  Event.Address := AAddress;
  Event.MessageText := MessageText;
  Event.UpdateAndSaveVolume := UpdateAndSaveVolume;
  QueueUiEvent(Event);
end;

procedure TDispenserStationForm.ApplyOperationFailed(AAddress: Integer;
  const MessageText: string; UpdateAndSaveVolume: Boolean);
begin
  FTable.SetOperationActive(AAddress, False);
  if UpdateAndSaveVolume then
  begin
    FTable.ShowCurrentVolume(AAddress,
      FRuntimeStates.GetCurrentVolume(AAddress),
      FRuntimeStates.IsCurrentVolumeKnown(AAddress));
    SaveCurrentSettings;
  end;
  UpdateUI;
  ShowMessage(MessageText);
end;

procedure TDispenserStationForm.RunAutomationProtocol(Sender: TObject);
var
  Task: TFormWorkItem;
  Protocol: TAutomationProtocol;
  Targets: TDispenserConfigList;
  InitializationTargets: TDispenserConfigList;
  InitializationTargetDescriptions: TStringList;
  ConfirmationText: string;
  ErrorText: string;
  Address: Integer;
  I: Integer;
  J: Integer;
  Target: TAutomationProtocolTarget;
  State: TDispenserRuntimeState;
  SeenAddresses: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]
    of Boolean;
begin
  if not FDispenser.IsConnected then
  begin
    ShowOperationWarning('Сначала подключите устройство.');
    Exit;
  end;
  if FAutomationRunner.IsRunning or FProtocolTaskActive then
  begin
    ShowOperationWarning('Протокол уже выполняется.');
    Exit;
  end;

  Protocol := nil;
  Targets := TDispenserConfigList.Create;
  InitializationTargets := TDispenserConfigList.Create;
  InitializationTargetDescriptions := TStringList.Create;
  try
    if not ParseAutomationProtocol(FAutomationPage.ProtocolText,
      FConfigurations, Protocol, ErrorText) then
    begin
      ShowOperationWarning('Не удалось запустить протокол: ' + ErrorText);
      Exit;
    end;

    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
      SeenAddresses[Address] := False;
    for I := 0 to Protocol.Count - 1 do
      for J := 0 to High(Protocol[I].Targets) do
      begin
        Target := Protocol[I].Targets[J];
        Address := Target.Config.Address;
        State := FRuntimeStates.Items[Address];
        if State = nil then
        begin
          ShowOperationWarning(Target.Config.Name +
            ': не удалось получить состояние дозатора.');
          Exit;
        end;
        if State.OperationActive or State.CommandPending or
          State.ProtocolReserved then
        begin
          ShowOperationWarning(Target.Config.Name +
            ': дозатор сейчас выполняет другую команду.');
          Exit;
        end;
        if not SeenAddresses[Address] then
        begin
          Targets.Add(Target.Config.Clone);
          SeenAddresses[Address] := True;
          if not State.IsInitializedFor(Target.Config) or
            not State.CurrentVolumeKnown then
          begin
            InitializationTargets.Add(Target.Config.Clone);
            InitializationTargetDescriptions.Add(Format('- %s (адрес %d)',
              [Target.Config.Name, Address]));
          end;
        end;
      end;

    if InitializationTargets.Count > 0 then
    begin
      ConfirmationText := 'Есть неинициализированные дозаторы:' +
        LineEnding + InitializationTargetDescriptions.Text + LineEnding +
        'Перед началом выполнения протокола неинициализированные дозаторы ' +
        'будут инициализированы. Продолжить?';
      if MessageDlg(ConfirmationText, mtConfirmation, [mbYes, mbNo], 0) <>
        mrYes then
        Exit;
    end;

    if InitializationTargets.Count > 0 then
    begin
      Task := TFormWorkItem.Create(btkPrepareProtocol);
      Task.Configs := InitializationTargets;
      InitializationTargets := nil;
    end
    else
      Task := TFormWorkItem.Create(btkStartProtocol);
    Task.Protocol := Protocol;
    Protocol := nil;
    for I := 0 to Targets.Count - 1 do
    begin
      Address := Targets[I].Address;
      Task.ReservedAddresses[Address] := True;
      FProtocolReserved[Address] := True;
      FRuntimeStates.Items[Address].ProtocolReserved := True;
      FTable.SetProtocolReserved(Address, True);
    end;
    if Task.WorkKind = btkPrepareProtocol then
      for I := 0 to Task.Configs.Count - 1 do
      begin
        Address := Task.Configs[I].Address;
        FRuntimeStates.Items[Address].CommandPending := True;
        FInitializingAddresses[Address] := True;
        FTable.SetCommandPending(Address, True);
      end;
    FProtocolTaskActive := True;
    QueueWorkItem(Task);
    UpdateUI;
  finally
    InitializationTargetDescriptions.Free;
    InitializationTargets.Free;
    Targets.Free;
    Protocol.Free;
  end;
end;

procedure TDispenserStationForm.AutomationProtocolFinished(const MessageText: string;
  Failed: Boolean);
var
  Event: TQueuedUiEvent;
begin
  Event := TQueuedUiEvent.Create;
  Event.Kind := quProtocolFinished;
  Event.MessageText := MessageText;
  Event.Flag := Failed;
  QueueUiEvent(Event);
end;

procedure TDispenserStationForm.ApplyAutomationProtocolFinished(const MessageText: string;
  Failed: Boolean);
begin
  if Failed then
    ShowOperationWarning(MessageText)
  else
    Log(MessageText);
  ReleaseProtocolReservations;
  FOperationTimer.Enabled := FAutomationRunner.IsRunning or
    FOperationCoordinator.HasActiveOperations or
    FConnectionCoordinator.HasActiveInitialization;
  UpdateUI;
end;

function TDispenserStationForm.HasPendingInitializationTask(AAddress: Integer): Boolean;
var
  I: Integer;
  Task: TFormWorkItem;
begin
  Result := False;
  if (FPendingWorkItems = nil) or
    ((AAddress <> 0) and
    not (AAddress in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE])) then
    Exit;

  for I := 0 to FPendingWorkItems.Count - 1 do
  begin
    Task := TFormWorkItem(FPendingWorkItems[I]);
    if (Task.WorkKind = btkInitialize) and
      ((AAddress = 0) or Task.ReservedAddresses[AAddress]) then
      Exit(True);
  end;
end;

procedure TDispenserStationForm.FinishInitializationIfComplete;
var
  Address: Integer;
  I: Integer;
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
  Failures: TStringList;
  Success: Boolean;
  ReleasedAddress: Boolean;
  IsProtocolInitialization: Boolean;
begin
  ReleasedAddress := False;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    if not FInitializingAddresses[Address] or
      FConnectionCoordinator.IsAddressInitializing(Address) or
      HasPendingInitializationTask(Address) then
      Continue;

    FInitializingAddresses[Address] := False;
    State := FRuntimeStates.Items[Address];
    Config := nil;
    if FConfigurations <> nil then
      for I := 0 to FConfigurations.Count - 1 do
        if FConfigurations[I].Address = Address then
        begin
          Config := FConfigurations[I];
          Break;
        end;
    if State <> nil then
    begin
      State.CommandPending := False;
      FTable.SetBypassSupported(Address,
        State.IsInitializedFor(Config) and
        (State.ValveType = dvtNonDistributive));
    end;
    FTable.SetCommandPending(Address, False);
    ReleasedAddress := True;
  end;

  if ReleasedAddress then
  begin
    FTable.RefreshCurrentVolumes(@FRuntimeStates.GetCurrentVolume,
      @FRuntimeStates.IsCurrentVolumeKnown);
    UpdateUI;
  end;

  if not FInitializationUiPending or
    FConnectionCoordinator.HasActiveInitialization or
    HasPendingInitializationTask(0) then
      Exit;

  Failures := TStringList.Create;
  try
    FConnectionCoordinator.GetInitializationResults(Failures, Success);
    IsProtocolInitialization := FPendingAutomationProtocol <> nil;
    FInitializationUiPending := False;
    FTable.RefreshCurrentVolumes(@FRuntimeStates.GetCurrentVolume,
      @FRuntimeStates.IsCurrentVolumeKnown);

    if Failures.Count > 0 then
      ShowOperationWarning('Не удалось инициализировать дозаторы:' +
        LineEnding + Failures.Text)
    else if not Success then
      ShowOperationWarning('Не удалось завершить инициализацию дозаторов.')
    else if IsProtocolInitialization then
      Log('Дозаторы протокола готовы; запуск протокола поставлен в очередь.')
    else
      Log('Инициализация всех запущенных дозаторов завершена');

    if IsProtocolInitialization then
    begin
      if Success and (Failures.Count = 0) then
        QueuePendingAutomationProtocol
      else
      begin
        FPendingAutomationProtocol.Free;
        FPendingAutomationProtocol := nil;
        FProtocolTaskActive := False;
        ReleaseProtocolReservations;
      end;
    end;
    UpdateUI;
  finally
    Failures.Free;
  end;
end;

procedure TDispenserStationForm.QueuePendingAutomationProtocol;
var
  Address: Integer;
  Task: TFormWorkItem;
begin
  if FPendingAutomationProtocol = nil then
  begin
    FProtocolTaskActive := False;
    ReleaseProtocolReservations;
    Exit;
  end;

  Task := TFormWorkItem.Create(btkStartProtocol);
  Task.Protocol := FPendingAutomationProtocol;
  FPendingAutomationProtocol := nil;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FProtocolReserved[Address] then
      Task.ReservedAddresses[Address] := True;
  QueueWorkItem(Task);
end;

procedure TDispenserStationForm.ReleaseProtocolReservations;
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FProtocolReserved[Address] then
    begin
      FRuntimeStates.Items[Address].ProtocolReserved := False;
      FTable.SetProtocolReserved(Address, False);
      FProtocolReserved[Address] := False;
    end;
end;

procedure TDispenserStationForm.OperationTimerTick(Sender: TObject);
var
  Task: TFormWorkItem;
begin
  DrainCompletedWorkItems;
  DrainQueuedUiEvents;
  FinishInitializationIfComplete;
  if not FPollTaskActive and
    (not FProtocolTaskActive or
    FConnectionCoordinator.HasActiveInitialization) and
    (FAutomationRunner.IsRunning or FOperationCoordinator.HasActiveOperations or
    FConnectionCoordinator.HasActiveInitialization)
    and FDispenser.IsConnected then
  begin
    Task := TFormWorkItem.Create(btkPoll);
    FPollTaskActive := True;
    QueueWorkItem(Task);
  end;
  FOperationTimer.Enabled := (FPendingWorkItems.Count > 0) or
    FAutomationRunner.IsRunning or FOperationCoordinator.HasActiveOperations or
    FConnectionCoordinator.HasActiveInitialization;
end;

procedure TDispenserStationForm.QueueWorkItem(AWorkItem: TObject);
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem(AWorkItem);
  FPendingWorkItems.Add(Task);
  if (FWorkDispatcher = nil) or not FWorkDispatcher.Enqueue(Task) then
  begin
    Task.Success := False;
    Task.ErrorText := 'Очередь фоновых операций остановлена.';
    Task.MarkCompleted;
  end;
  FOperationTimer.Enabled := True;
end;

procedure TDispenserStationForm.ExecuteWorkItem(AWorkItem: TObject);
var
  Task: TFormWorkItem;
begin
  Task := TFormWorkItem(AWorkItem);
  Task.Success := False;
  Task.ErrorText := '';
  try
    case Task.WorkKind of
    btkStartSingle:
      begin
        Task.SingleResult := FOperationCoordinator.StartSingle(Task.Config,
          Task.OperationKind, Task.Channel, Task.BypassEnabled, Task.ErrorText);
        Task.Success := Task.SingleResult = dosrStarted;
      end;
    btkStartGroup:
      begin
        Task.GroupResult := FOperationCoordinator.StartGroup(
          Task.OperationKind, Task.Requests, Task.ErrorText);
        Task.Success := Task.GroupResult = dgsStarted;
      end;
    btkInitialize:
      begin
        Task.Failures := TStringList.Create;
        Task.Success := FConnectionCoordinator.InitializeDispensers(
          Task.Configs, Task.Failures);
      end;
    btkPrepareProtocol:
      begin
        Task.Failures := TStringList.Create;
        Task.Success := FConnectionCoordinator.InitializeDispensers(
          Task.Configs, Task.Failures);
      end;
    btkPoll:
      begin
        if FAutomationRunner.IsRunning then
          FAutomationRunner.Poll;
        if not FAutomationRunner.IsRunning then
        begin
          FOperationCoordinator.PollNextOperation;
          FOperationCoordinator.PollNextProtocolOperation;
        end;
        FConnectionCoordinator.PollInitialization;
        Task.Success := True;
      end;
    btkBypass:
      begin
        Task.Success := FDispenser.SetBypass(Task.Address, Task.Channel,
          Task.BypassEnabled, Task.BypassValveType);
        if not Task.Success then
          Task.ErrorText := FDispenser.LastError;
      end;
    btkChangeSpeed:
      Task.Success := FOperationCoordinator.ChangeActiveSpeed(Task.Config,
        Task.Speed, Task.ErrorText);
    btkStopOne:
      Task.Success := FOperationCoordinator.StopActiveOperation(Task.Address,
        Task.ErrorText);
    btkStopAll:
      begin
        if FAutomationRunner.IsRunning then
          FAutomationRunner.Stop;
        Task.Success := FOperationCoordinator.StopAllActiveOperations(
          Task.ErrorText);
      end;
    btkStartProtocol:
      begin
        Task.Success := FAutomationRunner.Start(Task.Protocol,
          Task.ErrorText, True);
        if Task.Success then
          Task.Protocol := nil;
      end;
    btkStopProtocol:
      begin
        FAutomationRunner.Stop;
        Task.Success := True;
      end;
    btkConnect:
      begin
        Task.ConnectionResult := FConnectionCoordinator.ConnectPort(
          Task.PortName, Task.ErrorText);
        Task.Success := Task.ConnectionResult = dcrConnected;
      end;
    btkDisconnect:
      begin
        FConnectionCoordinator.Disconnect;
        Task.Success := True;
      end;
    btkScanPorts:
      begin
        Task.PortList := TStringList.Create;
        FDispenser.ScanPorts(Task.PortList);
        Task.Success := True;
      end;
    end;
  except
    on E: Exception do
    begin
      Task.Success := False;
      Task.ErrorText := E.Message;
    end;
  end;
  Task.MarkCompleted;
end;

procedure TDispenserStationForm.DrainCompletedWorkItems;
var
  I: Integer;
  J: Integer;
  SelectedPortIndex: Integer;
  Task: TFormWorkItem;
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
begin
  if (FPendingWorkItems = nil) or FDrainingWorkItems then
    Exit;
  FDrainingWorkItems := True;
  try
  I := 0;
  while I < FPendingWorkItems.Count do
  begin
    Task := TFormWorkItem(FPendingWorkItems[I]);
    if not Task.IsCompleted then
      Break;
    case Task.WorkKind of
      btkStartSingle:
        begin
          FRuntimeStates.Items[Task.Address].CommandPending := False;
          FTable.SetCommandPending(Task.Address, False);
          if Task.SingleResult = dosrRejected then
            ShowOperationWarning(Task.Config.Name + ': ' + Task.ErrorText)
          else if Task.SingleResult = dosrBusy then
            ShowOperationWarning(Task.Config.Name +
              ': дозатор сейчас выполняет другую команду.')
          else if (Task.SingleResult = dosrCommandFailed) and
            (Task.ErrorText <> '') then
            ShowOperationWarning(Task.Config.Name + ': ' + Task.ErrorText);
        end;
      btkStartGroup:
        begin
          for J := 0 to High(Task.Requests) do
          begin
            Config := Task.Requests[J].Config;
            FRuntimeStates.Items[Config.Address].CommandPending := False;
            FTable.SetCommandPending(Config.Address, False);
          end;
          if Task.GroupResult = dgsRejected then
            ShowOperationWarning('Групповая операция отменена: ' +
              Task.ErrorText)
          else if Task.GroupResult = dgsStoppedOnCommandError then
            ShowOperationWarning('Групповая операция прервана при запуске; ' +
              'проверьте состояние дозаторов: ' + Task.ErrorText);
        end;
      btkInitialize:
        begin
          if Task.Success then
            FInitializationUiPending := True
          else
          begin
            for J := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
              if Task.ReservedAddresses[J] then
              begin
                FInitializingAddresses[J] := False;
                State := FRuntimeStates.Items[J];
                if State <> nil then
                  State.CommandPending := False;
                FTable.SetCommandPending(J, False);
              end;
            if (Task.Failures <> nil) and (Task.Failures.Count > 0) then
              ShowOperationWarning('Не удалось запустить инициализацию:' +
                LineEnding + Task.Failures.Text)
            else
            ShowOperationWarning('Не удалось выполнить инициализацию: ' +
              Task.ErrorText);
          end;
        end;
      btkPrepareProtocol:
        begin
          if Task.Success then
          begin
            FPendingAutomationProtocol := Task.Protocol;
            Task.Protocol := nil;
            FInitializationUiPending := True;
          end
          else
          begin
            for J := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
              if Task.ReservedAddresses[J] then
              begin
                FInitializingAddresses[J] := False;
                State := FRuntimeStates.Items[J];
                if State <> nil then
                  State.CommandPending := False;
                FTable.SetCommandPending(J, False);
              end;
            FProtocolTaskActive := False;
            ReleaseProtocolReservations;
            if (Task.Failures <> nil) and (Task.Failures.Count > 0) then
              ShowOperationWarning('Не удалось запустить инициализацию дозаторов протокола:' +
                LineEnding + Task.Failures.Text)
            else
              ShowOperationWarning('Не удалось подготовить протокол: ' +
                Task.ErrorText);
          end;
        end;
      btkPoll:
        begin
          FPollTaskActive := False;
          if not Task.Success and (Task.ErrorText <> '') then
            ShowOperationWarning('Ошибка фонового опроса дозаторов: ' +
              Task.ErrorText);
        end;
      btkBypass:
        begin
          FRuntimeStates.Items[Task.Address].CommandPending := False;
          FTable.SetCommandPending(Task.Address, False);
          if Task.Success then
          begin
            SaveCurrentSettings;
            UpdateUI;
          end
          else
          begin
            FTable.SetBypassActive(Task.Address, not Task.BypassEnabled);
            ShowOperationWarning(Task.ErrorText);
          end;
        end;
      btkChangeSpeed:
        begin
          FRuntimeStates.Items[Task.Address].CommandPending := False;
          FTable.SetCommandPending(Task.Address, False);
          if not Task.Success then
            ShowOperationWarning(Task.Config.Name + ': ' + Task.ErrorText);
        end;
      btkStopOne:
        begin
          FRuntimeStates.Items[Task.Address].CommandPending := False;
          FTable.SetCommandPending(Task.Address, False);
          if not Task.Success then
            ShowOperationWarning(Task.ErrorText);
        end;
      btkStopAll:
        begin
          FProtocolTaskActive := False;
          for J := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
            if Task.ReservedAddresses[J] then
            begin
              FRuntimeStates.Items[J].CommandPending := False;
              FTable.SetCommandPending(J, False);
            end;
          if not Task.Success and (Task.ErrorText <> '') then
            ShowOperationWarning(Task.ErrorText);
        end;
      btkStartProtocol:
        begin
          FProtocolTaskActive := False;
          if not Task.Success then
          begin
            for J := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
              if Task.ReservedAddresses[J] then
              begin
                FRuntimeStates.Items[J].ProtocolReserved := False;
                FTable.SetProtocolReserved(J, False);
                FProtocolReserved[J] := False;
              end;
            ShowOperationWarning('Не удалось запустить протокол: ' +
              Task.ErrorText);
          end;
        end;
      btkStopProtocol:
        begin
          FProtocolTaskActive := False;
          if not Task.Success and (Task.ErrorText <> '') then
            ShowOperationWarning(Task.ErrorText);
        end;
      btkConnect:
        begin
          FConnectionTaskActive := False;
          if Task.ConnectionResult = dcrConnected then
            Log('Подключён COM-порт; инициализируйте дозаторы кнопками в таблице')
          else
            Log('Ошибка подключения: ' + Task.ErrorText);
        end;
      btkDisconnect:
        begin
          FConnectionTaskActive := False;
          if Task.Success then
            Log('Отключено')
          else
            ShowOperationWarning('Не удалось отключить устройство: ' +
              Task.ErrorText);
        end;
      btkScanPorts:
        begin
          FScanTaskActive := False;
          if Task.PortList <> nil then
            ComboBoxPorts.Items.Assign(Task.PortList)
          else
            ComboBoxPorts.Items.Clear;
          SelectedPortIndex := ComboBoxPorts.Items.IndexOf(Task.PortName);
          if SelectedPortIndex >= 0 then
            ComboBoxPorts.ItemIndex := SelectedPortIndex
          else if ComboBoxPorts.Items.Count > 0 then
          begin
            if Task.PortName = '' then
              ComboBoxPorts.ItemIndex := 0
            else
            begin
              ComboBoxPorts.ItemIndex := -1;
              ComboBoxPorts.Text := Task.PortName;
            end;
          end
          else
            ComboBoxPorts.Text := '';
          if Task.Success then
            Log('Найдено портов: ' + IntToStr(ComboBoxPorts.Items.Count))
          else if Task.ErrorText <> '' then
            ShowOperationWarning(Task.ErrorText);
        end;
    end;
    FPendingWorkItems.Delete(I);
    Task.Free;
  end;
  UpdateUI;
  finally
    FDrainingWorkItems := False;
  end;
end;

procedure TDispenserStationForm.SelectionChanged(AView: TDispenserView);
begin
  UpdateUI;
end;

procedure TDispenserStationForm.ExecuteRowOperation(AView: TDispenserView;
  AKind: TDispenserOperationKind);
var
  State: TDispenserRuntimeState;
  Task: TFormWorkItem;
begin
  if (AView = nil) or (FDispenser = nil) then
    Exit;

  if not FDispenser.IsConnected then
  begin
    ShowOperationWarning('Дозатор не подключён или не готов к работе.');
    Exit;
  end;

  State := FRuntimeStates.Items[AView.Config.Address];
  if (State = nil) then
    Exit;
  if State.OperationActive or State.CommandPending or State.ProtocolReserved then
  begin
    ShowOperationWarning(AView.Config.Name +
      ': дозатор сейчас выполняет другую команду.');
    Exit;
  end;
  if (State = nil) or not State.IsInitializedFor(AView.Config) then
  begin
    ShowOperationWarning(AView.Config.Name +
      ': Сначала инициализируйте дозатор.');
    Exit;
  end;

  AView.SaveOperationSettings;
  Task := TFormWorkItem.Create(btkStartSingle);
  Task.Config := AView.Config.Clone;
  Task.OperationKind := AKind;
  Task.Channel := AView.SelectedChannel;
  Task.BypassEnabled := AView.BypassActive;
  Task.Address := AView.Config.Address;
  State.CommandPending := True;
  FTable.SetCommandPending(Task.Address, True);
  QueueWorkItem(Task);
  UpdateUI;
end;

procedure TDispenserStationForm.CollectSelectedOperation(AView: TDispenserView);
begin
  if (AView = nil) or
    (FSelectedOperationRequestCount >= Length(FSelectedOperationRequests)) then
    Exit;

  FSelectedOperationRequests[FSelectedOperationRequestCount].Config :=
    AView.Config;
  FSelectedOperationRequests[FSelectedOperationRequestCount].SelectedChannel :=
    AView.SelectedChannel;
  FSelectedOperationRequests[FSelectedOperationRequestCount].BypassActive :=
    AView.BypassActive;
  Inc(FSelectedOperationRequestCount);
end;

procedure TDispenserStationForm.ExecuteSelectedOperation(AKind: TDispenserOperationKind);
var
  SelectedCount: Integer;
  OperableCount: Integer;
  I: Integer;
  HasSkipped: Boolean;
  Task: TFormWorkItem;
  State: TDispenserRuntimeState;
begin
  if not FDispenser.IsConnected then
  begin
    ShowOperationWarning('Дозаторы не подключены или не готовы к работе.');
    Exit;
  end;

  SelectedCount := FTable.SelectedCount;
  if SelectedCount = 0 then
  begin
    ShowOperationWarning('Выберите хотя бы один дозатор.');
    Exit;
  end;

  OperableCount := FTable.SelectedOperableCount;
  if OperableCount = 0 then
  begin
    ShowOperationWarning(
      'Среди выбранных нет свободных дозаторов для команды.');
    Exit;
  end;

  HasSkipped := OperableCount < SelectedCount;

  FTable.SaveOperationSettings;
  SetLength(FSelectedOperationRequests, OperableCount);
  FSelectedOperationRequestCount := 0;
  FTable.ForEachSelected(@CollectSelectedOperation);
  if FSelectedOperationRequestCount <> OperableCount then
  begin
    ShowOperationWarning(
      'Не удалось подготовить выбранные дозаторы для групповой операции.');
    UpdateUI;
    Exit;
  end;

  Task := TFormWorkItem.Create(btkStartGroup);
  Task.OperationKind := AKind;
  SetLength(Task.Requests, FSelectedOperationRequestCount);
  for I := 0 to FSelectedOperationRequestCount - 1 do
  begin
    Task.Requests[I] := FSelectedOperationRequests[I];
    Task.Requests[I].Config := FSelectedOperationRequests[I].Config.Clone;
    State := FRuntimeStates.Items[Task.Requests[I].Config.Address];
    State.CommandPending := True;
    FTable.SetCommandPending(Task.Requests[I].Config.Address, True);
  end;

  QueueWorkItem(Task);
  if HasSkipped then
    ShowOperationWarning('Занятые, неинициализированные дозаторы и дозаторы '
      + 'с bypass пропущены; команда отправится доступным выбранным дозаторам.');
  UpdateUI;
end;

procedure TDispenserStationForm.FillDispenser(AView: TDispenserView);
begin
  ExecuteRowOperation(AView, dokFill);
end;

procedure TDispenserStationForm.EmptyDispenser(AView: TDispenserView);
begin
  ExecuteRowOperation(AView, dokEmpty);
end;

procedure TDispenserStationForm.AspirateDispenser(AView: TDispenserView);
begin
  ExecuteRowOperation(AView, dokAspirate);
end;

procedure TDispenserStationForm.DispenseDispenser(AView: TDispenserView);
begin
  ExecuteRowOperation(AView, dokDispense);
end;

procedure TDispenserStationForm.StopDispenser(AView: TDispenserView);
var
  Task: TFormWorkItem;
  State: TDispenserRuntimeState;
begin
  if (AView = nil) or (FOperationCoordinator = nil) then
    Exit;

  if not FDispenser.IsConnected then
  begin
    ShowOperationWarning('Сначала подключите устройство.');
    Exit;
  end;

  State := FRuntimeStates.Items[AView.Config.Address];
  if (State = nil) or not State.OperationActive then
  begin
    ShowOperationWarning(AView.Config.Name + ': нет активной операции для остановки.');
    Exit;
  end;
  if State.CommandPending and (State.OperationOwner <> dooProtocol) then
  begin
    ShowOperationWarning(AView.Config.Name + ': команда этому дозатору уже отправляется.');
    Exit;
  end;

  if State.OperationOwner = dooProtocol then
  begin
    Task := TFormWorkItem.Create(btkStopProtocol);
    FProtocolTaskActive := True;
  end
  else
  begin
    Task := TFormWorkItem.Create(btkStopOne);
    State.CommandPending := True;
    FTable.SetCommandPending(AView.Config.Address, True);
  end;
  Task.Address := AView.Config.Address;
  QueueWorkItem(Task);
  UpdateUI;
end;

procedure TDispenserStationForm.InitializeDispenser(AView: TDispenserView);
var
  ErrorText: string;
begin
  if AView = nil then
    Exit;
  if not InitializeDispensers(FConfigurations, AView.Config.Address,
    ErrorText) then
    ShowOperationWarning(ErrorText);
end;

procedure TDispenserStationForm.btnInitializeAllClick(Sender: TObject);
var
  ErrorText: string;
begin
  if not InitializeDispensers(FConfigurations, 0, ErrorText) then
    ShowOperationWarning(ErrorText);
end;

procedure TDispenserStationForm.btnStopAllClick(Sender: TObject);
var
  Task: TFormWorkItem;
  Address: Integer;
begin
  if not FOperationCoordinator.HasActiveOperations and
    not FAutomationRunner.IsRunning then
  begin
    ShowOperationWarning('Нет активных операций для остановки.');
    Exit;
  end;
  Task := TFormWorkItem.Create(btkStopAll);
  FProtocolTaskActive := FAutomationRunner.IsRunning;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if FRuntimeStates.Items[Address].OperationActive then
    begin
      FRuntimeStates.Items[Address].CommandPending := True;
      FTable.SetCommandPending(Address, True);
      Task.ReservedAddresses[Address] := True;
    end;
  QueueWorkItem(Task);
  UpdateUI;
end;

function TDispenserStationForm.BypassChanged(AView: TDispenserView; AEnabled: Boolean): Boolean;
var
  State: TDispenserRuntimeState;
  Task: TFormWorkItem;
begin
  Result := False;
  if (AView = nil) or not FDispenser.IsConnected then
    Exit;
  State := FRuntimeStates.Items[AView.Config.Address];
  if (State = nil) or State.OperationActive or State.CommandPending or
    State.ProtocolReserved then
  begin
    ShowOperationWarning(AView.Config.Name +
      ': дозатор сейчас выполняет другую команду.');
    Exit;
  end;
  if (State = nil) or not State.IsInitializedFor(AView.Config) then
  begin
    ShowOperationWarning(AView.Config.Name +
      ': Сначала инициализируйте дозатор.');
    Exit;
  end;

  Task := TFormWorkItem.Create(btkBypass);
  Task.Address := AView.Config.Address;
  Task.Channel := AView.SelectedChannel;
  Task.BypassEnabled := AEnabled;
  Task.BypassValveType := State.ValveType;
  State.CommandPending := True;
  FTable.SetCommandPending(Task.Address, True);
  QueueWorkItem(Task);
  Result := True;
end;

procedure TDispenserStationForm.OperationSettingsChanged(AView: TDispenserView);
var
  State: TDispenserRuntimeState;
  Task: TFormWorkItem;
begin
  if AView = nil then
    Exit;

  State := FRuntimeStates.Items[AView.Config.Address];
  if (State <> nil) and
    (AView.Config.Operation.Speed <> AView.PreviousOperationSpeed) then
  begin
    if State.CommandPending then
      ShowOperationWarning(AView.Config.Name +
        ': дозатор сейчас выполняет другую команду.')
    else if State.OperationActive then
    begin
      Task := TFormWorkItem.Create(btkChangeSpeed);
      Task.Config := AView.Config.Clone;
      Task.Address := AView.Config.Address;
      Task.Speed := AView.Config.Operation.Speed;
      State.CommandPending := True;
      FTable.SetCommandPending(Task.Address, True);
      QueueWorkItem(Task);
    end;
  end;

  SaveCurrentSettings;
end;

procedure TDispenserStationForm.OperationSettingsWarning(AView: TDispenserView;
  const AReason: string);
begin
  ShowOperationWarning(Format('%s: %s', [AView.Config.Name, AReason]));
end;

procedure TDispenserStationForm.btnFillSelectedClick(Sender: TObject);
begin
  ExecuteSelectedOperation(dokFill);
end;

procedure TDispenserStationForm.btnEmptySelectedClick(Sender: TObject);
begin
  ExecuteSelectedOperation(dokEmpty);
end;

procedure TDispenserStationForm.btnAspirateSelectedClick(Sender: TObject);
begin
  ExecuteSelectedOperation(dokAspirate);
end;

procedure TDispenserStationForm.btnDispenseSelectedClick(Sender: TObject);
begin
  ExecuteSelectedOperation(dokDispense);
end;
procedure TDispenserStationForm.btnScanPortsClick(Sender: TObject);
var
  Task: TFormWorkItem;
begin
  if FScanTaskActive or FDispenser.IsConnected then
    Exit;
  Task := TFormWorkItem.Create(btkScanPorts);
  Task.PortName := Trim(ComboBoxPorts.Text);
  FScanTaskActive := True;
  QueueWorkItem(Task);
  UpdateUI;
end;

function TDispenserStationForm.ApplyConfiguration(AConfigurations:
  TDispenserConfigList; out ErrorText: string): Boolean;
type
  TAddressFlags = array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
var
  Affected: TAddressFlags;
  I: Integer;
  Address: Integer;
  OldConfig: TDispenserConfig;
  NewConfig: TDispenserConfig;
  DisplayConfig: TDispenserConfig;
  State: TDispenserRuntimeState;
  CurrentVolume: Double;

  function FindByAddress(AList: TDispenserConfigList;
    AAddress: Integer): TDispenserConfig;
  var
    J: Integer;
  begin
    Result := nil;
    if AList = nil then
      Exit;
    for J := 0 to AList.Count - 1 do
      if AList[J].Address = AAddress then
        Exit(AList[J]);
  end;

  function SameConfiguration(ALeft, ARight: TDispenserConfig): Boolean;
  begin
    Result := (ALeft <> nil) and (ARight <> nil) and
      (ALeft.Number = ARight.Number) and (ALeft.Name = ARight.Name) and
      (ALeft.Address = ARight.Address) and (ALeft.Volume = ARight.Volume) and
      (ALeft.ChannelCount = ARight.ChannelCount) and
      (ALeft.StepCount = ARight.StepCount) and
      (ALeft.IntakeChannel = ARight.IntakeChannel) and
      (ALeft.MaxFlowRate = ARight.MaxFlowRate) and
      (ALeft.Operation.Volume = ARight.Operation.Volume) and
      (ALeft.Operation.Speed = ARight.Operation.Speed) and
      (ALeft.Operation.Channel = ARight.Operation.Channel);
  end;

begin
  Result := False;
  ErrorText := '';

  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    Affected[Address] := False;

  if FConfigurations <> nil then
    for I := 0 to FConfigurations.Count - 1 do
    begin
      OldConfig := FConfigurations[I];
      NewConfig := FindByAddress(AConfigurations, OldConfig.Address);
      if not SameConfiguration(OldConfig, NewConfig) then
        Affected[OldConfig.Address] := True;
    end;

  if AConfigurations <> nil then
    for I := 0 to AConfigurations.Count - 1 do
    begin
      NewConfig := AConfigurations[I];
      OldConfig := FindByAddress(FConfigurations, NewConfig.Address);
      if not SameConfiguration(OldConfig, NewConfig) then
        Affected[NewConfig.Address] := True;
    end;

  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if Affected[Address] then
    begin
      State := FRuntimeStates.Items[Address];
      if (State <> nil) and
        (State.OperationActive or State.CommandPending or
        State.ProtocolReserved) then
      begin
        DisplayConfig := FindByAddress(FConfigurations, Address);
        if DisplayConfig = nil then
          DisplayConfig := FindByAddress(AConfigurations, Address);
        if DisplayConfig <> nil then
          ErrorText := DisplayConfig.Name +
            ': сейчас выполняется команда; дождитесь её завершения.'
        else
          ErrorText := Format(
            'Дозатор по адресу %d сейчас выполняет команду; дождитесь её завершения.',
            [Address]);
        Exit;
      end;
    end;

  if FDispenser.IsConnected then
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
      if Affected[Address] and
        FRuntimeStates.IsCurrentVolumeKnown(Address) then
      begin
        CurrentVolume := FRuntimeStates.GetCurrentVolume(Address);
        if CurrentVolume <= 0 then
          Continue;

        DisplayConfig := FindByAddress(FConfigurations, Address);
        if DisplayConfig = nil then
          DisplayConfig := FindByAddress(AConfigurations, Address);
        if DisplayConfig <> nil then
          ErrorText := Format(
            '%s (адрес %d) содержит %.0f мкл. Сначала опустошите дозатор или переинициализируйте его.',
            [DisplayConfig.Name, Address, CurrentVolume])
        else
          ErrorText := Format(
            'В дозаторе по адресу %d осталось %.0f мкл. Сначала опустошите его или переинициализируйте.',
            [Address, CurrentVolume]);
        Exit;
      end;

  if not TDispenserCapacityValidator.ValidateChange(FConfigurations,
    AConfigurations, @FRuntimeStates.GetCurrentVolume, ErrorText) then
    Exit;

  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    if Affected[Address] then
    begin
      State := FRuntimeStates.Items[Address];
      if State <> nil then
        State.RequireInitialization;
    end;

  FTable.SetConfigurations(nil);
  FConfigurations.Free;
  FConfigurations := AConfigurations.Clone;
  FTable.SetConfigurations(FConfigurations);
  FTable.RefreshCurrentVolumes(@FRuntimeStates.GetCurrentVolume,
    @FRuntimeStates.IsCurrentVolumeKnown);
  UpdateUI;
  SaveCurrentSettings;
  Log('Конфигурация дозаторов обновлена');
  Result := True;
end;

function TDispenserStationForm.InitializeDispensers(AConfigurations:
  TDispenserConfigList; AAddress: Integer; out ErrorText: string): Boolean;
var
  I: Integer;
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
  Targets: TDispenserConfigList;
  BusyDispensers: TStringList;
  AddressFound: Boolean;
  Task: TFormWorkItem;
begin
  Result := False;
  ErrorText := '';
  if not FDispenser.IsConnected then
  begin
    ErrorText := 'Сначала подключите COM-порт.';
    Exit;
  end;
  if (AConfigurations = nil) or (AConfigurations.Count = 0) then
  begin
    ErrorText := 'В конфигурации нет дозаторов для инициализации.';
    Exit;
  end;

  Targets := TDispenserConfigList.Create;
  BusyDispensers := TStringList.Create;
  try
    AddressFound := AAddress = 0;
    for I := 0 to AConfigurations.Count - 1 do
    begin
      Config := AConfigurations[I];
      if (AAddress <> 0) and (Config.Address <> AAddress) then
        Continue;
      AddressFound := True;
      if not (Config.Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
      begin
        ErrorText := Format('Неверный адрес дозатора: %d.', [Config.Address]);
        Exit;
      end;

      State := FRuntimeStates.Items[Config.Address];
      if State = nil then
      begin
        ErrorText := Format('Не удалось получить состояние дозатора по адресу %d.',
          [Config.Address]);
        Exit;
      end;
      if State.OperationActive or State.CommandPending or
        State.ProtocolReserved then
      begin
        if AAddress <> 0 then
        begin
          ErrorText := Format('Дозатор №%d выполняет другую команду.',
            [Config.Address]);
          Exit;
        end;
        BusyDispensers.Add(Format('Дозатор №%d', [Config.Address]));
        Continue;
      end;
      Targets.Add(Config.Clone);
    end;

    if not AddressFound then
    begin
      ErrorText := Format('Дозатор с адресом %d не найден в конфигурации.',
        [AAddress]);
      Exit;
    end;
    if Targets.Count = 0 then
    begin
      if BusyDispensers.Count > 0 then
        ErrorText := 'Все выбранные дозаторы сейчас выполняют команды.';
      Exit;
    end;

    Task := TFormWorkItem.Create(btkInitialize);
    Task.Configs := Targets;
    Targets := nil;
    for I := 0 to Task.Configs.Count - 1 do
    begin
      Config := Task.Configs[I];
      State := FRuntimeStates.Items[Config.Address];
      State.CommandPending := True;
      FTable.SetCommandPending(Config.Address, True);
      Task.ReservedAddresses[Config.Address] := True;
      FInitializingAddresses[Config.Address] := True;
    end;
    QueueWorkItem(Task);
    if BusyDispensers.Count > 0 then
      ShowOperationWarning('Инициализация запущена для свободных дозаторов. '
        + 'Пропущены занятые:' + LineEnding + BusyDispensers.Text);
    Result := True;
  finally
    BusyDispensers.Free;
    Targets.Free;
  end;
end;
procedure TDispenserStationForm.btnConnectClick(Sender: TObject);
var
  Task: TFormWorkItem;
begin
  if FConnectionTaskActive then
  begin
    ShowOperationWarning('Подключение или отключение уже выполняется.');
    Exit;
  end;
  if FDispenser.IsConnected then
  begin
    if HasActiveOperations then
    begin
      ShowOperationWarning('Дождитесь завершения операций дозаторов.');
      Exit;
    end;

    if not EnsureAllDispensersEmpty then
      Exit;

    Task := TFormWorkItem.Create(btkDisconnect);
    FConnectionTaskActive := True;
    QueueWorkItem(Task);
    UpdateUI;
    Exit;
  end;

  if Trim(ComboBoxPorts.Text) = '' then
  begin
    Log('Выберите COM-порт');
    Exit;
  end;

  Task := TFormWorkItem.Create(btkConnect);
  Task.PortName := Trim(ComboBoxPorts.Text);
  FConnectionTaskActive := True;
  QueueWorkItem(Task);
  UpdateUI;
end;

procedure TDispenserStationForm.btnConfigurationClick(Sender: TObject);
var
  ConfigForm: TConfigurationForm;
begin
  if FAutomationRunner.IsRunning or FProtocolTaskActive then
  begin
    ShowOperationWarning('Дождитесь завершения или остановите протокол.');
    Exit;
  end;

  ConfigForm := TConfigurationForm.Create(Self);
  try
    ConfigForm.SetRuntimeContext(FDispenser.IsConnected, FRuntimeStates,
      @ApplyConfiguration);
    ConfigForm.LoadFrom(FConfigurations);
    ConfigForm.SetReadOnly(False);
    ConfigForm.ShowModal;
  finally
    ConfigForm.Free;
  end;
end;

procedure TDispenserStationForm.ComboBoxPortsChange(Sender: TObject);
begin
  if (FWindowSettings <> nil) and
    not FWindowSettings.SaveLastPort(ComboBoxPorts.Text) then
    Log('Ошибка сохранения выбранного COM-порта');
  UpdateUI;
end;

end.
