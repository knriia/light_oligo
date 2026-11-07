unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons,
  UProtocolForm, USynthesisForm, UDispenserStationHost, DispenserLayout,
  OligoSlices, AppPaths, IniFiles,
  USequencesForm, UManualForm, EzCadApp, AppSynthesisAdapters;


type

  { TMainForm }

  TMainForm = class(TForm)
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Log: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    FProtocolForm: TProtocolForm;
    FSynthesisForm: TSynthesisForm;
    FManualForm: TManualForm;
    FEzCadWatcher: TEzCadDialogWatcher;
    FSynthesisStation: TStationSyringeAdapter;
    FSynthesisMarker: TEzCadLayerMarker;
    procedure SequencesLayersChanged(const ALayers: TSliceLayers);
    procedure SynthesisClearLog(Sender: TObject);
    procedure SequencesLog(const AMsg: string);
    procedure UpdateManualControlsWidth;
    procedure UpdateMinimumWindowWidth;
    procedure DispenserStationLogMessage(Sender: TObject; const Msg: string);
  public
    destructor Destroy; override;
    property DispenserStation: TDispenserStationForm read FDispenserStation;
    // Синтез запустил EzCAD: закрывать его окна лицензии и предупреждений.
    procedure StartEzCadWatcher;
  end;

var
  MainForm: TMainForm;
  MyInterface: TIniFile; // Только интерфейс
  MyIni: TIniFile; // Все значения

implementation

{$R *.lfm}

const
  STATION_PANEL_CHROME = 24;

{ TMainForm }

{ОБЩИЕ ПОДПРОГРАММЫ}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // папка data с данными рядом с exe; переносим туда данные из старых мест
  MigrateLegacyData;
  EnsureDataDirs;

  //интерфейс
  MyInterface:=TIniFile.Create(ConfigFilePath(INTERFACE_FILE));

  MainForm.Caption:=MyInterface.ReadString('Main','MainForm','LightOligo');
  TS_Manual.Caption:=MyInterface.ReadString('Main','TS_Manual','Manual');
  TS_Sequences.Caption:=MyInterface.ReadString('Main','TS_Sequences','Sequence');
  TS_Protocol.Caption:=MyInterface.ReadString('Main','TS_Protocol','Protocol');
  TS_Synthesis.Caption:=MyInterface.ReadString('Main','TS_Synthesis','Synthesis');
  TS_Log.Caption:=MyInterface.ReadString('Main','TS_Log','Лог');


  // значения
  MyIni:=TIniFile.Create(ConfigFilePath(PROG_CONFIG_FILE));

  //для экранов с включенным масштабированием
  FEzCadWatcher := TEzCadDialogWatcher.Create;
  FManualForm := TManualForm.Create(Self);
  FManualForm.BorderStyle := bsNone;
  FManualForm.Parent := TS_Manual;
  FManualForm.Align := alClient;
  FManualForm.ApplyCaptions(MyInterface);
  FManualForm.LoadSettings;
  FManualForm.OnLog := @SequencesLog;
  FManualForm.Show;
  FProtocolForm := TProtocolForm.Create(Self);
  FProtocolForm.BorderStyle := bsNone;
  FProtocolForm.Parent := TS_Protocol;
  FProtocolForm.Align := alClient;
  FProtocolForm.ApplyCaptions(MyInterface);
  FProtocolForm.Show;
  FDispenserStation := TDispenserStationForm.Create(Self);
  FDispenserStation.BorderStyle := bsNone;
  FDispenserStation.Parent := FManualForm.GB_PumpStation;
  FDispenserStation.Align := alClient;
  FDispenserStation.AttachLogSink(@DispenserStationLogMessage);
  FDispenserStation.Show;
  FSynthesisStation := TStationSyringeAdapter.Create(FDispenserStation);
  FSynthesisMarker := TEzCadLayerMarker.Create(
    MyIni.ReadInteger('Laser', 'EzCAD2OpenTime', 1000), @StartEzCadWatcher);
  FSynthesisForm := TSynthesisForm.Create(Self);
  FSynthesisForm.BorderStyle := bsNone;
  FSynthesisForm.Parent := TS_Synthesis;
  FSynthesisForm.Align := alClient;
  FSynthesisForm.ApplyCaptions(MyInterface);
  FSynthesisForm.Station := FSynthesisStation;
  FSynthesisForm.Marker := FSynthesisMarker;
  FSynthesisForm.OnLog := @SequencesLog;
  FSynthesisForm.OnClearLog := @SynthesisClearLog;
  FSynthesisForm.Show;
  FSequencesForm := TSequencesForm.Create(Self);
  FSequencesForm.BorderStyle := bsNone;
  FSequencesForm.Parent := TS_Sequences;
  FSequencesForm.Align := alClient;
  FSequencesForm.ApplyCaptions(MyInterface);
  FSequencesForm.OnLog := @SequencesLog;
  FSequencesForm.OnLayersChanged := @SequencesLayersChanged;
  FSequencesForm.Show;
  Randomize();
  UpdateMinimumWindowWidth();
  UpdateManualControlsWidth();

  // при запуске всегда открываем вкладку синтеза,
  // независимо от того, какая вкладка сохранена в дизайнере
  PageControl1.ActivePage:=TS_Synthesis;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  UpdateManualControlsWidth();
end;

procedure TMainForm.UpdateMinimumWindowWidth;
const
  FORM_NONCLIENT_CHROME_FALLBACK = 24;
var
  RequiredPanelWidth: Integer;
  RequiredClientWidth: Integer;
  RequiredFormWidth: Integer;
  FormChromeWidth: Integer;
begin
  if not Assigned(Panel1) then
    Exit;

  RequiredPanelWidth := MAIN_WINDOW_MIN_WIDTH + STATION_PANEL_CHROME;
  RequiredClientWidth := RequiredPanelWidth;

  FormChromeWidth := Width - ClientWidth;
  if FormChromeWidth < FORM_NONCLIENT_CHROME_FALLBACK then
    FormChromeWidth := FORM_NONCLIENT_CHROME_FALLBACK;
  RequiredFormWidth := RequiredClientWidth + FormChromeWidth;
  Constraints.MinWidth := RequiredFormWidth;
end;
procedure TMainForm.UpdateManualControlsWidth;
// страницы - по размеру панели
begin
  if not Assigned(Panel1) or not Assigned(PageControl1) then
    Exit;
  if (Panel1.ClientWidth <= 2) or (Panel1.ClientHeight <= 2) then
    Exit;
  PageControl1.SetBounds(1, 1, Panel1.ClientWidth - 2,
    Panel1.ClientHeight - 2);
end;

procedure TMainForm.SequencesLog(const AMsg: string);
begin
  Memo1.Lines.Add(AMsg);
end;

procedure TMainForm.Tmr_EzCADerTimer(Sender: TObject);
begin
  if not FEzCadWatcher.Tick then
    Tmr_EzCADer.Enabled:=False;
end;

procedure TMainForm.StartEzCadWatcher;
begin
  FEzCadWatcher.Start;
  Tmr_EzCADer.Enabled:=True;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // сначала протокол и массив: вопрос о сохранении ничего не меняет в
  // оборудовании
  if Assigned(FProtocolForm) and
     not FProtocolForm.CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  if Assigned(FSequencesForm) and
     not FSequencesForm.CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  if Assigned(FSynthesisForm) and
     not FSynthesisForm.CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  if Assigned(FDispenserStation) and
     not FDispenserStation.CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  MyInterface.Free;
  MyIni.Free;
end;

destructor TMainForm.Destroy;
begin
  // Адаптеры принадлежат composition root и освобождаются после дочерних
  // форм, которым они делегируют вызовы.
  inherited Destroy;
  FreeAndNil(FSynthesisMarker);
  FreeAndNil(FSynthesisStation);
  FreeAndNil(FEzCadWatcher);
end;

procedure TMainForm.DispenserStationLogMessage(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);
  Memo1.SelStart := Length(Memo1.Text);
end;

{ВКЛАДКА Manual}

{ВКЛАДКА Sequence}
 
{ВКЛАДКА Protocol}

{ВКЛАДКА Synthesis}

procedure TMainForm.SequencesLayersChanged(const ALayers: TSliceLayers);
begin
  FSynthesisForm.SetLayers(ALayers);
end;

procedure TMainForm.SynthesisClearLog(Sender: TObject);
begin
  Memo1.Clear;
end;

end.

