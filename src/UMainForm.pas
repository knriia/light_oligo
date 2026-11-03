unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Graphics, Buttons,
  UProtocolOperationForm, UDispenserStationHost, DispenserLayout,
  AppState, CommonUtils, OligoSlices, SynthesisProtocol, ProtocolFormat,
  AppPaths, IniFiles, UProtocolBlockForm, SynthesisThread,
  USequencesForm, UManualForm, EzCadApp;


type

  { TMainForm }

  TMainForm = class(TForm)
    B_ClearAll: TButton;
    B_Pause: TButton;
    B_Start: TButton;
    B_LoadLayers: TButton;
    B_LoadProtToSynth: TButton;
    B_RemoveNode: TButton;
    B_AddOperInProtocol: TButton;
    B_AddBlockInProtocol: TButton;
    B_SaveProtocolLayer: TButton;
    B_LoadProtocolLayer: TButton;
    GB_EditProtocolTree: TGroupBox;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    L_MoveArrows: TLabel;
    OD_File: TOpenDialog;
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    SD_File: TSaveDialog;
    SB_UpNode: TSpeedButton;
    SB_DownNode: TSpeedButton;
    Splitter2: TSplitter;
    TV_Synthesis: TTreeView;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    TV_ProtocolLayer: TTreeView;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Log: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure B_AddBlockInProtocolClick(Sender: TObject);
    procedure B_AddOperInProtocolClick(Sender: TObject);
    procedure B_ClearAllClick(Sender: TObject);
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_LoadProtocolLayerClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_RemoveNodeClick(Sender: TObject);
    procedure B_SaveProtocolLayerClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure SB_DownNodeClick(Sender: TObject);
    procedure SB_UpNodeClick(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    FManualForm: TManualForm;
    FEzCadWatcher: TEzCadDialogWatcher;
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


  GB_EditProtocolTree.Caption:=MyInterface.ReadString('Protocol','GB_EditProtocolTree','Protocol');
  B_LoadProtocolLayer.Caption:=MyInterface.ReadString('Protocol','B_LoadProtocolLayer','Load Protocol');
  L_MoveArrows.Caption:=MyInterface.ReadString('Protocol','L_Arrows','Move Node');
  B_AddBlockInProtocol.Caption:=MyInterface.ReadString('Protocol','B_AddBlockInProtocol','Add Block');
  B_AddOperInProtocol.Caption:=MyInterface.ReadString('Protocol','B_AddOperInProtocol','Add Operator');
  B_RemoveNode.Caption:=MyInterface.ReadString('Protocol','B_RemoveNode','Remove Node');
  B_SaveProtocolLayer.Caption:=MyInterface.ReadString('Protocol','B_SaveProtocolLayer','Save Protocol');

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
// страницы - по размеру панели; ручная вкладка раскладывает себя сама
begin
  if not Assigned(Panel1) or not Assigned(PageControl1) then
    Exit;
  if (Panel1.ClientWidth <= 2) or (Panel1.ClientHeight <= 2) then
    Exit;
  PageControl1.SetBounds(1, 1, Panel1.ClientWidth - 2,
    Panel1.ClientHeight - 2);
  if Assigned(FManualForm) then
    FManualForm.UpdateLayout;
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
  // сначала массив: вопрос о сохранении ничего не меняет в оборудовании
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

procedure TMainForm.B_LoadProtocolLayerClick(Sender: TObject);
// Загрузка протокола из файла
begin
  OD_File.Filter:='Протокол|*.pro';
  OD_File.InitialDir:=ProtocolsDir;
  OD_File.FilterIndex:=1;
  OD_File.FileName:='';
  If OD_File.Execute then
  try
    TV_ProtocolLayer.LoadFromFile(OD_File.FileName);
  except
  end;
end;

procedure TMainForm.B_AddBlockInProtocolClick(Sender: TObject);
// Добавляем корневой блок в протокол
begin
  ProtocolBlockForm.ShowModal;
  if ProtocolBlockForm.ModalResult=mrOK then
    TV_ProtocolLayer.Items.Add(nil,'Block='+MyBlockName+';');
end;

procedure TMainForm.B_AddOperInProtocolClick(Sender: TObject);
// Добавляем оператор в протокол. В форме формируем функцию в записи, а здесь из нее создаем ноду
var
  tmpNode: TTreeNode;
  ParamLine: String;
begin
  if TV_ProtocolLayer.Selected= nil
  then
  begin
    ShowMessage('Сначала выделите узел');
    Exit;
  end;

  ProtocolOperationForm.ShowModal;
    if ProtocolOperationForm.ModalResult=mrOk then
    begin
      case TV_ProtocolLayer.Selected.Level of   // задаем ноду 0 уровня независимо от глубины вложения
        0 :tmpNode:=TV_ProtocolLayer.Selected;
        1 :tmpNode:=TV_ProtocolLayer.Selected.Parent;
        2 :tmpNode:=TV_ProtocolLayer.Selected.Parent.Parent;
      end;

      case MyOper.Func of
           dSyrSt: begin
                     // операция SyrSt, её параметры - вложенными строками
                     tmpNode:=TV_ProtocolLayer.Items.AddChild(tmpNode, KEY_SYRINGE+';');
                     for ParamLine in SyringeStepParamLines(MyOper.Syringe) do
                       TV_ProtocolLayer.Items.AddChild(tmpNode, ParamLine);
                     tmpNode.Expand(False);
                   end;
             dVac: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+BoolToStr(MyOper.BoolParam)+'; ');

             dLaser: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+IntToStr(MyOper.IntParam)+'; '
                                                     +'Time='+FloatToStr(MyOper.FloatParam)+';');
             dPause: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+IntToStr(MyOper.IntParam)+';');
             dName: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+';');
      end;
    end;
end;

procedure TMainForm.B_RemoveNodeClick(Sender: TObject);
begin
   if(TV_ProtocolLayer.Selected = nil) then
   begin
      ShowMessage('Выделите узел!');
      Exit;
   end;
   // удаляем
   TV_ProtocolLayer.Selected.Delete;
end;

procedure TMainForm.B_SaveProtocolLayerClick(Sender: TObject);
// Сохраняем протокол в файл
begin
  SD_File.Filter:='Протокол|*.pro';
  SD_File.InitialDir:=ProtocolsDir;
  SD_File.FilterIndex:=1;
  SD_File.FileName:='';
  if SD_File.Execute then
  try
    TV_ProtocolLayer.SaveToFile(SD_File.FileName);
  except
    ShowMessage('Ошибка сохранения файла протокола');
  end;
end;

procedure TMainForm.SB_UpNodeClick(Sender: TObject);
// перемещение ноды вверх по дереву
var
  SelectedNode, PrevNode: TTreeNode;
begin
   if(TV_ProtocolLayer.Selected = nil) then
   begin
      ShowMessage('Выделите узел!');
      Exit;
   end;

   SelectedNode := TV_ProtocolLayer.Selected;
  if Assigned(SelectedNode) then
  begin
    PrevNode := SelectedNode.GetPrevSibling;
    if Assigned(PrevNode) then
    begin
      // Перемещаем выбранный узел вверх на том же уровне
      SelectedNode.MoveTo(PrevNode, naInsert);
    end;
  end;
end;

procedure TMainForm.SB_DownNodeClick(Sender: TObject);
// Перемещение ноды вниз по дереву
var
  SelectedNode, NextNode: TTreeNode;
begin
   if(TV_ProtocolLayer.Selected = nil) then
   begin
      ShowMessage('Выделите узел!');
      Exit;
   end;

  SelectedNode := TV_ProtocolLayer.Selected;
  if Assigned(SelectedNode) then
  begin
    NextNode := SelectedNode.GetNextSibling;
    if Assigned(NextNode) then
    begin
      // Перемещаем выбранный узел вниз на том же уровне
      NextNode.MoveTo(SelectedNode, naInsert);
    end;
  end;
end;


{ВКЛАДКА Synthesis}

procedure TMainForm.B_LoadProtToSynthClick(Sender: TObject);
// Загрузить файлы протоколов
var
  TmpLet: String;
  TmpLayProt: TLayerProt;
  rez: Integer;
  i: integer;
begin
  OD_File.Filter:='Протокол|*.pro';
  OD_File.InitialDir:=ProtocolsDir;
  OD_File.FileName:='';
  if OD_File.Execute then
  begin
    TmpLet:=RemoveFileExt(ExtractFileName(OD_File.FileName));

    //Проверяем, что для этой буквы протокола еще нет
    for i:=0 to High(Alphabet) do
    if TmpLet=Alphabet[i]
    then
      begin
        ShowMessage('Протокол для '+TmpLet+ ' уже существует! Загрузка прервана');
        Exit;
    end;

    rez:=ParceProtocolFile(TmpLayProt,OD_File.FileName,Memo1.Lines);
      if rez=0 then
        begin
          SetLength(MySynthProt,Length(MySynthProt)+1); // увеличиваем массив на 1 протокол буквы
          SetLength(MySynthProt[High(MySynthProt)],Length(TmpLayProt)); // задаем размер как у TmpLayProt
          SetLength(Alphabet, Length(Alphabet)+1); // увеличили на 1 массив с названиями протоколов
          for i:=0 to Length(TmpLayProt)-1 do
            MySynthProt[High(MySynthProt),i]:=TmpLayProt[i]; // копируем
          Alphabet[High(Alphabet)]:=TmpLet;
          LoadFileIntoTreeView(OD_File.FileName, TV_Synthesis);
        end
      else ShowMessage('Ошибка! Протокол не добавлен');
  end;
end;

 procedure TMainForm.B_LoadLayersClick(Sender: TObject);
// Загрузить файлы слоев
var
  rez: integer;
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
  {TODO:
  if noda
  then
    begin
      ShowMessage(Слои уже добавлены!);
      Exit;
    end;  }

  SetLength(SliceTable,0);
  OD_File.Filter:='Слои|*.lays';
  OD_File.InitialDir:=SlicesDir;
  OD_File.FileName:='';
  if OD_File.Execute then
  begin
    rez:=LoadSliceFile(SliceTable, OD_File.FileName);
    if rez=0 then
      LoadFileIntoTreeView(OD_File.FileName, TV_Synthesis)
    else
      ShowMessage('Ошибка! Файл слоев не добавлен');
  end;
end;

procedure TMainForm.B_ClearAllClick(Sender: TObject);
// Очистить протоколы и файлы
var
  i: integer;
begin
  //Очищаем протокол
  for i:=0 to High(MySynthProt) do
      SetLength(MySynthProt[i],0);
  SetLength(MySynthProt,0);
  //очищаем массив букв
  SetLength(Alphabet,0);
  //очищаем массив слоев
  SetLength(SliceTable,0);
  //ошичаем дерево
  TV_Synthesis.Items.Clear;
end;

procedure TMainForm.B_StartClick(Sender: TObject);
//запуск синтеза
var
  MyThread: TSynthesisThread; // Поток, в котором будет проходить весь синтез
  i: integer;
  s: String;
  arrWrongLet: array of String;
  IsCorrect: boolean;
  NumOfL: integer;
begin
  Memo1.Clear;

  IsCorrect:=false;
  SetLength(arrWrongLet,0);
  if Length(SliceTable)=0 then
  begin
     ShowMessage('Отсутствуют слои!');
     Exit;
  end;

  for i:=0 to High(Alphabet) do
  begin
    Memo1.Lines.Add(Alphabet[i]);
  end;

  // Перед запуском проверяем, что имеются протоколы на все буквы
  NumOfL:=0;
  for i:=0 to High(SliceTable) do
    begin
      if AlphabetNum(SliceTable[i].Letter)=-1 then
      begin
        SetLength(arrWrongLet,Length(arrWrongLet)+1);
        arrWrongLet[High(arrWrongLet)]:=SliceTable[i].Letter;
      end;
      NumOfL:=NumOfL+1;
    end;
  Memo1.Lines.Add('Число слоев='+IntToStr(NumOfL));
  Memo1.Lines.Add('Первыйслой='+IntToStr(SliceTable[0].LayerNumber)+' '+SliceTable[0].EZDFile);
  Memo1.Lines.Add('Последний слой='+IntToStr(SliceTable[High(SliceTable)].LayerNumber)+' '
                                   +SliceTable[High(SliceTable)].EZDFile);

  if Length(arrWrongLet)=0 then
     IsCorrect:=true
  else
  begin
    s:='';
    for i:=0 to High(arrWrongLet) do
      s:=s+' '+arrWrongLet[i];
    ShowMessage('Отсутствуют протоколы для: '+s);
    Exit;
  end;

  if IsCorrect then
  begin
    IsStarted:=true;
    MyThread:=TSynthesisThread.Create(false);
  end
  else ShowMessage('');


end;

procedure TMainForm.B_PauseClick(Sender: TObject);
begin
  IsStarted:=false;
  Memo1.Lines.Add('Synthesis aborted');
end;

end.

