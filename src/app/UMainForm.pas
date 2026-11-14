unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons,
  DispenserLayout, Localization, AppComposition;


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
    FComposition: TAppComposition;
    procedure SynthesisClearLog(Sender: TObject);
    procedure SequencesLog(const AMsg: string);
    procedure UpdateManualControlsWidth;
    procedure UpdateMinimumWindowWidth;
    procedure DispenserStationLogMessage(Sender: TObject; const Msg: string);
  public
    destructor Destroy; override;
    // Синтез запустил EzCAD: закрывать его окна лицензии и предупреждений.
    procedure StartEzCadWatcher;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  STATION_PANEL_CHROME = 24;

{ TMainForm }

{ОБЩИЕ ПОДПРОГРАММЫ}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FComposition := TAppComposition.Create(Self, TS_Manual, TS_Protocol,
    TS_Synthesis, TS_Sequences, @SequencesLog, @SequencesLog,
    @SequencesLog, @SequencesLog,
    @SynthesisClearLog, @DispenserStationLogMessage, @StartEzCadWatcher);
  // данные, папки и настройки программы
  FComposition.Initialize;

  MainForm.Caption:=ReadInterfaceString('Main','MainForm','LightOligo');
  TS_Manual.Caption:=ReadInterfaceString('Main','TS_Manual','Manual');
  TS_Sequences.Caption:=ReadInterfaceString('Main','TS_Sequences','Sequence');
  TS_Protocol.Caption:=ReadInterfaceString('Main','TS_Protocol','Protocol');
  TS_Synthesis.Caption:=ReadInterfaceString('Main','TS_Synthesis','Synthesis');
  TS_Log.Caption:=ReadInterfaceString('Main','TS_Log','Лог');

  // формы вкладок, адаптеры и связи между ними
  FComposition.Build;
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
  if not FComposition.EzCadWatcherTick then
    Tmr_EzCADer.Enabled:=False;
end;

procedure TMainForm.StartEzCadWatcher;
begin
  FComposition.EzCadWatcherStart;
  Tmr_EzCADer.Enabled:=True;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // порядок проверок (протокол, массив, синтез, станция) - в композиции
  if Assigned(FComposition) and not FComposition.CanCloseAll then
  begin
    CloseAction := caNone;
    Exit;
  end;

  FinalizeLocalization;
end;

destructor TMainForm.Destroy;
begin
  // Адаптеры принадлежат композиции и освобождаются после дочерних форм,
  // которым они делегируют вызовы.
  inherited Destroy;
  FreeAndNil(FComposition);
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

procedure TMainForm.SynthesisClearLog(Sender: TObject);
begin
  Memo1.Clear;
end;

end.

