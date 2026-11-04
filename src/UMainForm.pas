unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons,
  UProtocolForm, UDispenserStationHost, DispenserLayout,
  CommonUtils, OligoSlices, SynthesisSession,
  AppPaths, IniFiles, SynthesisThread,
  USequencesForm, UManualForm, EzCadApp;


type

  { TMainForm }

  TMainForm = class(TForm)
    B_ClearAll: TButton;
    B_Pause: TButton;
    B_Start: TButton;
    B_LoadLayers: TButton;
    B_LoadProtToSynth: TButton;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    OD_File: TOpenDialog;
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    TV_Synthesis: TTreeView;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Log: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure B_ClearAllClick(Sender: TObject);
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    FProtocolForm: TProtocolForm;
    FSession: TSynthesisSession;          // слои и протоколы для синтеза
    FSynthesisThread: TSynthesisThread;   // nil, пока синтез не идёт
    FManualForm: TManualForm;
    FEzCadWatcher: TEzCadDialogWatcher;
    function SynthesisRunning: Boolean;
    procedure SynthesisFinished(Sender: TObject);
    procedure SequencesLayersChanged(const ALayers: TSliceLayers);
    procedure SequencesLog(const AMsg: string);
    procedure UpdateManualControlsWidth;
    procedure UpdateMinimumWindowWidth;
    procedure DispenserStationLogMessage(Sender: TObject; const Msg: string);
    procedure LoadFileIntoTreeView(const FileName: string; TreeView: TTreeView);
  public
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


  GB_SynthControl.Caption:=MyInterface.ReadString('Synthesis','GB_SynthControl','Synthesis Control');
  GB_Files.Caption:=MyInterface.ReadString('Synthesis','GB_Files','Files');
  B_LoadProtToSynth.Caption:=MyInterface.ReadString('Synthesis','B_LoadProtToSynth','Load Protocol');
  B_LoadLayers.Caption:=MyInterface.ReadString('Synthesis','B_LoadLayers','Load Layers');
  B_ClearAll.Caption:=MyInterface.ReadString('Synthesis','B_ClearAll','Clear All');
  B_Start.Caption:=MyInterface.ReadString('Synthesis','B_Start','Start');
  B_Pause.Caption:=MyInterface.ReadString('Synthesis','B_Pause','Pause');

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
  FSession := TSynthesisSession.Create;
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

procedure TMainForm.LoadFileIntoTreeView(const FileName: string; TreeView: TTreeView);
// Загрузка содержимого файла в ноду TreeView
var
  FileLines: TStringList;
  NewNode, ChildNode: TTreeNode;
  i: Integer;
begin
  // Проверяем, существует ли файл
  if not FileExists(FileName) then
  begin
    ShowMessage('Файл не найден: ' + FileName);
    Exit;
  end;

  // Создаем список строк из файла
  FileLines:=TStringList.Create;
  try
    FileLines.LoadFromFile(FileName); // Загружаем содержимое файла в TStringList

    // Создаем новую корневую ноду
    NewNode:=TreeView.Items.Add(nil, ExtractFileName(FileName)); // Имя новой ноды - имя файла

    // Добавляем строки файла как дочерние элементы новой ноды
    for i:=0 to FileLines.Count-1 do
    begin
      ChildNode:=TreeView.Items.AddChild(NewNode, FileLines[i]); // Добавляем дочерний элемент
    end;

    // Раскрываем новую ноду
    NewNode.Expand(True);
  finally
    FileLines.Free; // Освобождаем память
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // сначала массив и протокол: вопрос о сохранении ничего не меняет в
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

  if Assigned(FDispenserStation) and
     not FDispenserStation.CanCloseFromHost then
  begin
    CloseAction := caNone;
    Exit;
  end;

  // идущий синтез останавливаем; сессию он ещё читает, поэтому не освобождаем
  if FSynthesisThread <> nil then
    FSynthesisThread.Terminate
  else
    FreeAndNil(FSession);
  MyInterface.Free;
  MyIni.Free;
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

function TMainForm.SynthesisRunning: Boolean;
begin
  Result:=FSynthesisThread<>nil;
end;

procedure TMainForm.SynthesisFinished(Sender: TObject);
// Поток закончил работу (сам освободится): синтез можно запускать снова
begin
  FSynthesisThread:=nil;
end;

procedure TMainForm.SequencesLayersChanged(const ALayers: TSliceLayers);
begin
  FSession.SetLayers(ALayers);
end;

procedure TMainForm.B_LoadProtToSynthClick(Sender: TObject);
// Загрузить файлы протоколов
var
  Letter, ErrorText: String;
begin
  if SynthesisRunning then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять протоколы.');
    Exit;
  end;
  OD_File.Filter:='Протокол|*.pro';
  OD_File.InitialDir:=ProtocolsDir;
  OD_File.FileName:='';
  if not OD_File.Execute then
    Exit;
  if FSession.AddProtocolFile(OD_File.FileName, Letter, ErrorText) then
  begin
    Memo1.Lines.Add('Протокол для буквы '+Letter+' загружен: '+OD_File.FileName);
    LoadFileIntoTreeView(OD_File.FileName, TV_Synthesis);
  end
  else
    ShowMessage(ErrorText);
end;

procedure TMainForm.B_LoadLayersClick(Sender: TObject);
// Загрузить файлы слоев
var
  ErrorText: String;
  Node: TTreeNode;
begin
  Node := TV_Synthesis.Items.GetFirstNode; // Получаем первый корневой узел
  while Node <> nil do
  begin
    // Проверяем, содержит ли узел искомый текст
    if Pos('.lays', Node.Text) > 0 then
      begin
        ShowMessage('Файл слоев уже загружен!');
        Exit;
      end;
    Node := Node.GetNext; // Переходим к следующему корневому узлу
  end;

  OD_File.Filter:='Слои|*.lays';
  OD_File.InitialDir:=SlicesDir;
  OD_File.FileName:='';
  if not OD_File.Execute then
    Exit;
  if FSession.LoadLayersFile(OD_File.FileName, ErrorText) then
    LoadFileIntoTreeView(OD_File.FileName, TV_Synthesis)
  else
    ShowMessage(ErrorText);
end;

procedure TMainForm.B_ClearAllClick(Sender: TObject);
// Очистить протоколы и файлы
begin
  if SynthesisRunning then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы очистить загруженное.');
    Exit;
  end;
  FSession.Clear;
  TV_Synthesis.Items.Clear;
end;

procedure TMainForm.B_StartClick(Sender: TObject);
//запуск синтеза
var
  i: integer;
  ErrorText: String;
begin
  if SynthesisRunning then
  begin
    ShowMessage('Синтез уже идёт.');
    Exit;
  end;
  Memo1.Clear;

  // Перед запуском проверяем, что есть слои и протоколы на все буквы
  if not FSession.CheckReady(ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;

  for i:=0 to FSession.ProtocolCount-1 do
    Memo1.Lines.Add(FSession.ProtocolLetters[i]);
  Memo1.Lines.Add('Число слоев='+IntToStr(FSession.LayerCount));
  Memo1.Lines.Add('Первыйслой='+IntToStr(FSession.Layers[0].LayerNumber)+' '+
                  FSession.Layers[0].EZDFile);
  Memo1.Lines.Add('Последний слой='+
                  IntToStr(FSession.Layers[FSession.LayerCount-1].LayerNumber)+' '+
                  FSession.Layers[FSession.LayerCount-1].EZDFile);

  FSynthesisThread:=TSynthesisThread.Create(FSession);
  FSynthesisThread.OnTerminate:=@SynthesisFinished;
  FSynthesisThread.Start;
end;

procedure TMainForm.B_PauseClick(Sender: TObject);
begin
  if FSynthesisThread<>nil then
    FSynthesisThread.Terminate;
  Memo1.Lines.Add('Synthesis aborted');
end;

end.

