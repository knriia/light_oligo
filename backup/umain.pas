unit UMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Spin, Windows, Graphics, Grids, Buttons, TAGraph, TAMultiSeries, TASeries,
  TAPolygonSeries, TATools, StrUtils, LasFunc, UWMatrix, UWOligoArr, UWOper,
  UWLayerChart, Dilutor, UWLasPen, MyGlobals, IniFiles, UWBlock, USynThread;


type

  { TForm1 }

  TForm1 = class(TForm)
    B_SetGeomParam: TButton;
    B_SetLasPen2: TButton;
    B_SaveOligs: TButton;
    B_LoadOligs: TButton;
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
    B_FullLoad: TButton;
    B_Empty: TButton;
    B_Load: TButton;
    B_Dispense: TButton;
    B_PumpClose: TButton;
    B_PumpStInit: TButton;
    B_CreateArrEzd: TButton;
    B_CloseEzCAD: TButton;
    B_SetLasPen: TButton;
    B_SendF2: TButton;
    B_SliceOligoArr: TButton;
    B_CreateOligoArr: TButton;
    B_OpenEZCAD: TButton;
    B_Preview: TButton;
    B_Matrix: TButton;
    B_CreateEZD: TButton;
    Chart1: TChart;
    BS_Series: TBubbleSeries;
    CB_AutoCenter: TCheckBox;
    CB_ShowSubstrate: TCheckBox;
    Chart2: TChart;
    BS_Syringes: TBarSeries;
    BS_Liquids: TBarSeries;
    ChartToolset1: TChartToolset;
    ChartToolset1PanDragTool1: TPanDragTool;
    ChartToolset1ZoomDragTool1: TZoomDragTool;
    ChartToolset1ZoomMouseWheelTool1: TZoomMouseWheelTool;
    ComboBox1: TComboBox;
    FSE_DispSpeed: TFloatSpinEdit;
    FSE_VolLoad: TFloatSpinEdit;
    FSE_VolDisp: TFloatSpinEdit;
    FSE_LoadSpeed: TFloatSpinEdit;
    GB_PumpStation: TGroupBox;
    GB_MarkEZDDLL: TGroupBox;
    GB_EzCAD: TGroupBox;
    GB_Syringe: TGroupBox;
    GB_EditProtocolTree: TGroupBox;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    L_MoveArrows: TLabel;
    L_Volume: TLabel;
    L_Syringe: TLabel;
    L_SubstrD: TLabel;
    L_Flow: TLabel;
    OD_File: TOpenDialog;
    Panel5: TPanel;
    P_MatrixChart: TPanel;
    PS_Series: TPolygonSeries;
    FSE_XBias: TFloatSpinEdit;
    FSE_Step: TFloatSpinEdit;
    FSE_GroupStep: TFloatSpinEdit;
    FSE_YBias: TFloatSpinEdit;
    GB_OligControl: TGroupBox;
    GB_Laser: TGroupBox;
    GB_Array: TGroupBox;
    L_Group: TLabel;
    L_Step: TLabel;
    L_GStep: TLabel;
    L_BiasX: TLabel;
    L_BiasY: TLabel;
    L_SpotSize: TLabel;
    Memo1: TMemo;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    RG_Valve: TRadioGroup;
    SD_File: TSaveDialog;
    SDD_Dir: TSelectDirectoryDialog;
    SE_Group: TSpinEdit;
    SE_SpotSize: TSpinEdit;
    SE_SubstrateDiameter: TSpinEdit;
    SB_UpNode: TSpeedButton;
    SB_DownNode: TSpeedButton;
    Splitter1: TSplitter;
    SG_OligoArr: TStringGrid;
    Splitter2: TSplitter;
    TV_Synthesis: TTreeView;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    Tmr_Closer: TTimer;
    TV_ProtocolLayer: TTreeView;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure B_AddBlockInProtocolClick(Sender: TObject);
    procedure B_AddOperInProtocolClick(Sender: TObject);
    procedure B_ClearAllClick(Sender: TObject);
    procedure B_CloseEzCADClick(Sender: TObject);
    procedure B_CreateArrEzdClick(Sender: TObject);
    procedure B_CreateOligoArrClick(Sender: TObject);
    procedure B_CreateEZDClick(Sender: TObject);
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_LoadOligsClick(Sender: TObject);
    procedure B_LoadProtocolLayerClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_MatrixClick(Sender: TObject);
    procedure B_OpenEZCADClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_PreviewClick(Sender: TObject);
    procedure B_PumpStInitClick(Sender: TObject);
    procedure B_RemoveNodeClick(Sender: TObject);
    procedure B_SaveOligsClick(Sender: TObject);
    procedure B_SaveProtocolLayerClick(Sender: TObject);
    procedure B_SendF2Click(Sender: TObject);
    procedure B_SetGeomParamClick(Sender: TObject);
    procedure B_SetLasPen2Click(Sender: TObject);
    procedure B_SetLasPenClick(Sender: TObject);
    procedure B_SliceOligoArrClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure CollapseExpand(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SB_DownNodeClick(Sender: TObject);
    procedure SB_UpNodeClick(Sender: TObject);
    procedure SG_OligoArrEditingDone(Sender: TObject);
    procedure SG_OligoArrHeaderClick(Sender: TObject; IsColumn: Boolean;
      Index: Integer);
    procedure SG_OligoArrKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure SG_OligoArrSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
    procedure Splitter1Moved(Sender: TObject);
    procedure Tmr_CloserTimer(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    Procedure DisplayOligoArrInGrid(anArr: TOligoArr);
    procedure AutoSizeGridColumn(Grid : TStringGrid; column : integer);
    Procedure DisplayPumpStation();
    procedure LoadFileIntoTreeView(const FileName: string; TreeView: TTreeView);
  public
    Procedure ShowRez(aFunName: String; aRez:integer);
  end;

var
  Form1: TForm1;
  MyInterface: TIniFile; // Только интерфейс
  MyIni: TIniFile; // Все значения

implementation

{$R *.lfm}

{ TForm1 }

{ОБЩИЕ ПОДПРОГРАММЫ}

procedure TForm1.FormCreate(Sender: TObject);
begin
  //интерфейс
  MyInterface:=TIniFile.Create(GetCurrentDir+'\Interface.ini');

  Form1.Caption:=MyInterface.ReadString('Main','Form1','LightOligo');
  TS_Manual.Caption:=MyInterface.ReadString('Main','TS_Manual','Manual');
  TS_Sequences.Caption:=MyInterface.ReadString('Main','TS_Sequences','Sequence');
  TS_Protocol.Caption:=MyInterface.ReadString('Main','TS_Protocol','Protocol');
  TS_Synthesis.Caption:=MyInterface.ReadString('Main','TS_Synthesis','Synthesis');

  GB_Array.Caption:=MyInterface.ReadString('Manual','GB_Array','Array');
  B_Matrix.Caption:=MyInterface.ReadString('Manual','B_Matrix','Matrix');
  L_Step.Caption:=MyInterface.ReadString('Manual','L_Step','Step, mm');
  L_Group.Caption:=MyInterface.ReadString('Manual','L_Group','Group');
  L_GStep.Caption:=MyInterface.ReadString('Manual','L_GStep','GroupStep, mm');
  L_SpotSize.Caption:=MyInterface.ReadString('Manual','L_SpotSize','SpotSize, um');
  B_Preview.Caption:=MyInterface.ReadString('Manual','B_Preview','Preview');
  CB_AutoCenter.Caption:=MyInterface.ReadString('Manual','CB_AutoCenter','AutoCenter');
  L_BiasX.Caption:=MyInterface.ReadString('Manual','L_BiasX','BiasX, mm');
  L_BiasY.Caption:=MyInterface.ReadString('Manual','L_BiasY','BiasY, mm');
  CB_ShowSubstrate.Caption:=MyInterface.ReadString('Manual','CB_ShowSubstrate','Substrate');
  L_SubstrD.Caption:=MyInterface.ReadString('Manual','L_SubstrD','SubstrDiam, mm');
  GB_Laser.Caption:=MyInterface.ReadString('Manual','GB_Laser','Laser');
  GB_MarkEZDDLL.Caption:=MyInterface.ReadString('Manual','GB_MarkEZDDLL','DLL');
  B_SetLasPen.Caption:=MyInterface.ReadString('Manual','B_SetLasPen','SetLasPen');
  B_CreateEZD.Caption:=MyInterface.ReadString('Manual','B_CreateEZD','CreateEZD');
  GB_EzCAD.Caption:=MyInterface.ReadString('Manual','GB_EzCAD','EzCAD');
  B_OpenEZCAD.Caption:=MyInterface.ReadString('Manual','B_OpenEZCAD','OpenEZCAD');
  B_CloseEZCAD.Caption:=MyInterface.ReadString('Manual','B_CloseEZCAD','CloseEZCAD');
  B_SendF2.Caption:=MyInterface.ReadString('Manual','B_SendF2','Mark');
  GB_PumpStation.Caption:=MyInterface.ReadString('Manual','GB_PumpStation','PumpStation');
  B_PumpStInit.Caption:=MyInterface.ReadString('Manual','B_PumpStInit','Initialization');
  B_PumpClose.Caption:=MyInterface.ReadString('Manual','B_PumpClose','Disconnect');
  L_Syringe.Caption:=MyInterface.ReadString('Manual','L_Syringe','Syringe');
  GB_Syringe.Caption:=MyInterface.ReadString('Manual','GB_Syringe','Syringe');
  RG_Valve.Caption:=MyInterface.ReadString('Manual','RG_Valve','Valve');
  B_FullLoad.Caption:=MyInterface.ReadString('Manual','B_FullLoad','FullLoad');
  B_Empty.Caption:=MyInterface.ReadString('Manual','B_Empty','Empty');
  L_Volume.Caption:=MyInterface.ReadString('Manual','L_Volume','Volume, ul');
  L_Flow.Caption:=MyInterface.ReadString('Manual','L_Flow','Flow, ul/s');
  B_Load.Caption:=MyInterface.ReadString('Manual','B_Load','Load');
  B_Dispense.Caption:=MyInterface.ReadString('Manual','B_Dispense','Dispense');

  GB_OligControl.Caption:=MyInterface.ReadString('Oligo','GB_OligControl','Oligonucleotides');
  B_CreateOligoArr.Caption:=MyInterface.ReadString('Oligo','B_CreateOligoArr','OligoArray');
  B_LoadOligs.Caption:=MyInterface.ReadString('Oligo','B_LoadOligs','Load Oligs');
  B_SaveOligs.Caption:=MyInterface.ReadString('Oligo','B_SaveOligs','Save Oligs');
  B_SliceOligoArr.Caption:=MyInterface.ReadString('Oligo','B_SliceOligoArr','Slice');
  B_SetLasPen2.Caption:=MyInterface.ReadString('Oligo','B_SetLasPen2','SetLasPen');
  B_CreateArrEzd.Caption:=MyInterface.ReadString('Oligo','B_CreateArrEzd','EZD Files');

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
  MyIni:=TIniFile.Create(GetCurrentDir+'\ProgConfig.ini');
  FSE_Step.Value:=MyIni.ReadFloat('Program','FSE_Step',0.1);
  SE_Group.Value:=MyIni.ReadInteger('Program','SE_Group',10);
  FSE_GroupStep.Value:=MyIni.ReadFloat('Program','FSE_GroupStep',0.1);
  SE_SpotSize.Value:=MyIni.ReadInteger('Program','SE_SpotSize',15);
  FSE_XBias.Value:=MyIni.ReadFloat('Program','FSE_XBias',0.0);
  FSE_YBias.Value:=MyIni.ReadFloat('Program','FSE_YBias',0.0);
  SE_SubstrateDiameter.Value:=MyIni.ReadInteger('Program','SE_SubstrateDiameter',20);
  CB_AutoCenter.Checked:=MyIni.ReadBool('Program','CB_AutoCenter',true);
  CB_ShowSubstrate.Checked:=MyIni.ReadBool('Program','CB_ShowSubstrate',true);

  //для экранов с включенным масштабированием
  GB_Laser.Tag:=GB_Laser.Height;
  GB_Array.Tag:=GB_Array.Height;
  GB_PumpStation.Tag:=GB_PumpStation.Height;

  DisplayPumpStation();
  Randomize();
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  Panel2.Height:=Form1.Height div 8;
  Chart1.Width:=Chart1.Height;
end;

procedure TForm1.Splitter1Moved(Sender: TObject);
begin
    Chart1.Width:=Chart1.Height;
end;

procedure TForm1.ShowRez(aFunName: String; aRez: integer);
begin
    case aRez of
   0:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Успех!');
   1:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' работает EZCAD');
   2:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' EZCAD.CFG не найден');
   3:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' не удалось открыть LMC1');
   4:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' нет допустимого устройства LMC1');
   5:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' ошибка версии LMC1');
   6:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Невозможно найти файл конфигурации устройства');
   7:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Аварийный сигнал');
   8:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Остановка пользователя');
   9:  Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Неизвестная ошибка');
   10: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Тайм-аут');
   11: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Не инициализировано');
   12: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Ошибка чтения файла');
   13: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Пустое окно');
   14: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Невозможно найти шрифт с указанным именем');
   15: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Неправильный номер пера');
   16: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Объект с указанным именем не является текстовым объектом');
   17: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Не удалось сохранить файл');
   18: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Указанный объект не найден');
   19: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Эта операция не может быть выполнена в текущем состоянии');
   21: Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' Режим TestMode');
   else Memo1.Lines.Add(aFunName+' -> '+intTostr(aRez)+' ХЗ');
   end;
end;

procedure TForm1.Tmr_EzCADerTimer(Sender: TObject);
var
   S: string;
   h: HWND;
begin
  h:=0;
  S:='License';
  h:=FindWindow(nil,pchar(S));
  if h<>0 then
   begin
    postMessage(h,WM_KEYDOWN,VK_RETURN,0);
    h:=0;
   end;

  S:='EzCad';
  h:=FindWindow(nil,pchar(S));
  if h<>0 then
   begin
    postMessage(h,WM_CLOSE,0,0);
    h:=0;
   end;
  inc(GlobalI);
  if GlobalI>=100 then // через 100 циклов останавливаем таймер
   begin
    Tmr_EzCADer.Enabled:=false;
   end;
end;

procedure TForm1.CollapseExpand(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  {переделать. В create добавить запись высоты в тэг}
  if (Y < 0) and ((Sender as TGroupBox).Height > 19) then
    (Sender as TGroupBox).Height := 19
  else
    (Sender as TGroupBox).Height := (Sender as TGroupBox).Tag;
end;

procedure TForm1.Tmr_CloserTimer(Sender: TObject);
var
   S: string;
   h: HWND;
begin
  h:=0;
  S:=TmrCloserStr;
  h:=FindWindow(nil,pchar(S));
  if h<>0 then
   begin
    postMessage(h,WM_CLOSE,0,0);
    Tmr_Closer.Enabled:=false;
   end;
end;

procedure TForm1.AutoSizeGridColumn(Grid: TStringGrid; column: integer);

// установка ширины столбца стринггрида по самой длинной последовательности
var
i: integer;
temp: integer;
max : integer;
begin
max:= 0;
for i:= 0 to (Grid.RowCount - 1) do
begin
   temp:= Grid.Canvas.TextWidth(grid.cells[column, i]);
   if temp > max then max:= temp;
end;
Grid.ColWidths[column]:= Max + Grid.GridLineWidth + 5;
end;

procedure TForm1.DisplayPumpStation();
var
  i: integer;
begin
  if Length(MyPumpSt)<>0 then
   begin
     BS_Syringes.Clear;
     BS_Liquids.Clear;
     for i:=1 to length(MyPumpSt) do
       BS_Syringes.AddXY(i,100,MyPumpSt[i].fLabel,clWhite);
       BS_Liquids.AddXY(i,MyPumpSt[i].fVolume*100/MyPumpSt[i].fSyringeVolume,'',clBlack);
   end
  else
  begin
    for i:=1 to 8 do
    begin
      BS_Syringes.AddXY(i,100,'Syr'+IntToStr(i),clWhite);
      BS_Liquids.AddXY(i,Random(100),'',clBlack);
    end;
  end;
end;

procedure TForm1.LoadFileIntoTreeView(const FileName: string; TreeView: TTreeView);
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

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MyInterface.Free;
  MyIni.Free;
end;

{ВКЛАДКА Manual}

procedure TForm1.B_CreateEZDClick(Sender: TObject);
var
   rez: integer;
   path: string;
   pMyArr: pointer;
   TmpP: TPoint;
begin
   path:=ExtractFilePath(ParamStr(0));

   // строка заголовка сообщения об ошибке (путь к проге)
   TmrCloserStr:=ExtractFilePath(ParamStr(0))+ExtractFileName(ParamStr(0));

   // запускаем таймер закрывающий сообщение об ошибке
   Tmr_Closer.Enabled:=true;
   rez:=lmc1_Initial2(WideString(path), true, Form1.Handle);
   ShowRez('lmc1_Initial2',rez);

   // открываем/создаем файл ezd
   rez:=lmc1_LoadEzdFile(WideString(path+'Arr.ezd'));
   ShowRez('lmc1_LoadEzdFile',rez);

   // очищаем библиотеку объектов
   rez:=lmc1_ClearEntLib();
   ShowRez('lmc1_ClearEntLib',rez);

   myStep:=FSE_Step.Value;
   myGStep:=FSE_GroupStep.Value;
   myGroup:=SE_Group.Value;
   if CB_AutoCenter.Checked then
    begin
     TmpP:=AutoCenterBiasMatrix(MyMatrix, myStep, MyGStep, MyGroup);
     BiasX:=TmpP[0];
     BiasY:=TmpP[1];
    end
   else
    begin
     BiasX:=FSE_XBias.Value;
     BiasY:=FSE_YBias.Value;
    end;

   // добавляем споты в линейный массив
   rez:=ConvertMatrixToLinearArray(MyMatrix, ArrOfSpots, myStep, myGroup, myGStep, BiasX, BiasY);
   ShowRez('ConvertMatrixToLineArray', rez);

   if Length(ArrOfSpots)<>0 then
     begin
        // добавляем наш массив в файл
       pMyArr:=@ArrOfSpots[0];

       rez:=lmc1_SetPenParam2(MyLasPen.nPenNo,MyLasPen.nMarkLoop, MyLasPen.dMarkSpeed,
                             MyLasPen.dPowerRatio, MyLasPen.dCurrent,MyLasPen.nFreq,
                             MyLasPen.dQPulseWidth, MyLasPen.nStartTC, MyLasPen.nLaserOffTC,
                             MyLasPen.nEndTC, MyLasPen.nPolyTC, MyLasPen.dJumpSpeed,
                             MyLasPen.nJumpPosTC, MyLasPen.nJumpDistTC, MyLasPen.dPointTime,
                             MyLasPen.nSpiWave, MyLasPen.bWobbleMode, MyLasPen.dWobbleDiameter,
                             MyLasPen.dWobbleDist);
       ShowRez('lmc1_SetPenParam2',rez);

       rez:=lmc1_AddPointToLib(pMyArr,Length(ArrOfSpots),'arr',MyLasPen.nPenNo);
       ShowRez('lmc1_AddPointToLib',rez);

       // сохраняем файл
       rez:=lmc1_SaveEntLibToFile(WideString(path+'Arr.ezd'));
       ShowRez('lmc1_SaveEntLibToFile',rez);
     end
   else
   begin
     ShowRez('Пустой массив! Файл не перезаписан!',-1);
   end;
   // отключаемся от библиотеки
   rez:=lmc1_Close();
   ShowRez('lmc1_Close',rez);
end;

procedure TForm1.B_MatrixClick(Sender: TObject);
begin
  Form2.Show;
end;

procedure TForm1.B_OpenEZCADClick(Sender: TObject);
// Открываем приложение, по таймеру закрываем предупреждения об ошибках
begin
 if GetProcessHandle('EzCad2.exe')=0 then
  begin
   GlobalI:=0; // обнуляем глобальный счетчик
   Tmr_EzCADer.Enabled:=true;
   ShellExecute(0, 'open', PChar(ExtractFilePath(ParamStr(0))+'EzCAD2.exe'),
                PChar(ExtractFilePath(ParamStr(0))+'Arr.ezd'), nil, SW_SHOWMINIMIZED);
  end
 else
   ShowMessage('Приложение EzCAD2.exe уже запущено!');
end;

procedure TForm1.B_PreviewClick(Sender: TObject);
var
  SubRadius, Angle: Double;
   i,j: integer;
   numPoints: integer;
   TmpP: TPoint;
begin
  PS_Series.Clear;

  if CB_ShowSubstrate.Checked then // если нужно показать контур подложки
  begin
    SubRadius:=SE_SubstrateDiameter.Value/2;
    numPoints:=100;
    for i:=0 to numPoints-1 do
    begin
      Angle:=2*Pi*i/numPoints; // Угол в радианах
      PS_Series.AddXY(SubRadius*Cos(Angle), SubRadius*Sin(Angle),'',clBlue);
    end
  end;

  myStep:=FSE_Step.Value;
  myGStep:=FSE_GroupStep.Value;
  myGroup:=SE_Group.Value;

  // определяем смещение
  if CB_AutoCenter.Checked then
   begin
    TmpP:=AutoCenterBiasMatrix(MyMatrix, myStep, MyGStep, MyGroup);
    BiasX:=TmpP[0];
    BiasY:=TmpP[1];
   end
  else
   begin
     BiasX:=FSE_XBias.Value;
     BiasY:=FSE_YBias.Value;
   end;

  // заполняем серию спотами из матрицы
  mySpotR:=SE_SpotSize.Value/2000;  // переход от диаметра в мкм к радиусу в мм
  BS_Series.Clear;
  for i:=0 to Length(MyMatrix)-1 do
    for j:=0 to Length(MyMatrix[i])-1 do
    begin
      if myMatrix[i,j]<>0 then
       begin
         if myGroup=0 then
          BS_Series.AddXY(j*myStep+BiasX, -i*myStep+BiasY, mySpotR,'', clRed)
         else
          BS_Series.AddXY(j*myStep+myGStep*(j div myGroup)+BiasX, -i*myStep-myGStep*(i div myGroup)+BiasY , mySpotR,'', clRed);
       end;
    end;
end;

procedure TForm1.B_PumpStInitClick(Sender: TObject);
// Подключение и инициализация шприцевой станции
var
  NumOfSyr: Integer;
  rez: integer;
  i: integer;
begin
{  //Поключение
  rez:=PumpStation.Connect(MyInterface.ReadString('PumpStation','COMPort','COM1'));
  ShowRez('PumpStation.Connect',rez);
  if rez=0 then
   begin
      // заполняем запись по всем шприцевым дозаторам
      NumOfSyr:=MyInterface.ReadInteger('PumpStation','NumOfSyr',8);
      SetLength(MyPumpSt,NumOfSyr);
      for i:=0 to NumOfSyr-1 do
      begin
        MyPumpSt[i].SyrVolume:=MyInterface.ReadFloat('PumpStation','Syringe'+IntoStr(i+1), 250.0);
        MyPumpSt[i].SyrName:=MyInterface.ReadFloat('PumpStation','SyrName'+IntoStr(i+1), 'Syr'+IntoStr(i+1));
      end;
      // инициализируем станцию (клапаны в C-OFF, шприцы вверх)
      PumpStation.Initializaton(MyPumpSt);
      DisplayPumpStation();
   end;        }
end;

procedure TForm1.B_SendF2Click(Sender: TObject);
// Послать команду маркировки F2
begin
 if GetProcessHandle('EzCad2.exe')<>0 then
    begin
      SendMsgToProc('EzCAD2.exe',VK_F2);
      ShowRez('F2 отправлено', -1);
    end
 else
   ShowMessage('Приложение EzCAD2.exe не запущено!');
end;

procedure TForm1.B_SetLasPenClick(Sender: TObject);
// Открываем окно задания параметров лазера(LasPen)
var
   rez: integer;
   path: string;
begin
   path:=ExtractFilePath(ParamStr(0));

   // строка заголовка сообщения об ошибке (путь к проге)
   TmrCloserStr:=ExtractFilePath(ParamStr(0))+ExtractFileName(ParamStr(0));

   // запускаем таймер закрывающий сообщение об ошибке
   Tmr_Closer.Enabled:=true;
   rez:=lmc1_Initial2(WideString(path), true, Form1.Handle);
   ShowRez('lmc1_Initial2',rez);
   Form5.ShowModal;
end;

procedure TForm1.B_CloseEzCADClick(Sender: TObject);
// Закрываем приложение
var
  ProcH: THandle;
begin
  ProcH:=GetProcessHandle('EzCad2.exe');
  if ProcH<>0 then
    begin
      SendMsgToProcWithMod('EzCAD2.exe',VK_F4, VK_MENU); // Alt+F4
      PostMessage(ProcH, WM_CLOSE, 0, 0);
    end
  else
   ShowMessage('Приложение EzCAD2.exe не запущено!');
end;


{ВКЛАДКА Sequence}
 
procedure TForm1.DisplayOligoArrInGrid(anArr: TOligoArr);
// отображение массива олигов в StringGride
var
  i,j: Integer;
begin
  SG_OligoArr.Clear;
  // Устанавливаем количество строк и столбцов в TStringGrid
  SG_OligoArr.RowCount := Length(anArr)+1;
  if Length(anArr) > 0 then
    SG_OligoArr.ColCount := Length(anArr[0])+1;
  // Заполняем TStringGrid значениями из anArr
  for i := 0 to Length(anArr)-1 do
  begin
    for j := 0 to Length(anArr[i])-1 do
    begin
      // Присваиваем значение ячейке
      SG_OligoArr.Cells[j+1, i+1]:=anArr[i][j];
    end;
  end;
end;

procedure TForm1.SG_OligoArrHeaderClick(Sender: TObject; IsColumn: Boolean;
  Index: Integer);
// Переключение отображения ячеек в SG_OligoArr
var
  i: integer;
  N: INteger;
begin
  if isColumn and (Index=0) then
  begin
    SG_OligoArr.Cells[0,0]:=SG_OligoArr.Cells[0,0]+' ';
    N:=Length(SG_OligoArr.Cells[0,0]);
    case N of
    1: begin // дефолтный размер ячеек
        for i:=1 to SG_OligoArr.ColCount-1 do
            SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultColWidth;
       end;
    2: begin // максимально раскрытые ячейки
         for i:=1 to SG_OligoArr.ColCount-1 do
             AutoSizeGridColumn(SG_OligoArr, i);
       end;
    3: begin // квадратные ячейки
        for i:=1 to SG_OligoArr.ColCount-1 do
            SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultRowHeight;
        SG_OligoArr.Cells[0,0]:='';
       end;
    else begin
      SG_OligoArr.Cells[0,0]:='';
      end;
    end;
  end;
end;

procedure TForm1.SG_OligoArrKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
// обработка Ctrl+V
var
  i,j: integer;
begin
  if (Key=VK_V) and (Shift=[ssCtrl]) then
  for i:=1 to SG_OligoArr.RowCount-1 do
  begin
    for j:=1 to SG_OligoArr.ColCount-1 do
    begin
      MyOligoArr[i-1,j-1]:=StringToOlig(SG_OligoArr.Cells[j,i]);
      SG_OligoArr.Cells[j,i]:=MyOligoArr[i-1,j-1];
    end;
  end;
end;

procedure TForm1.SG_OligoArrSetEditText(Sender: TObject; ACol, ARow: Integer;
  const Value: string);
// Запоминаем начальную ячейку выделения
begin
  EditedCell.Col:=ACol;
  EditedCell.Row:=ARow;
end;

procedure TForm1.SG_OligoArrEditingDone(Sender: TObject);
// изменение содержимого ячеики
begin
if (EditedCell.Row<>0) and (EditedCell.Col<>0) then
  begin
  MyOligoArr[EditedCell.Row-1,EditedCell.Col-1]:=StringToOlig(SG_OligoArr.Cells[EditedCell.Col,EditedCell.Row]);
  SG_OligoArr.Cells[EditedCell.Col,EditedCell.Row]:=MyOligoArr[EditedCell.Row-1,EditedCell.Col-1];
  end;
end;

procedure TForm1.B_LoadOligsClick(Sender: TObject);
var
  F: TextFile;
 begin
  OD_File.Filter:='CSV Files|*.csv';
  OD_File.FilterIndex:=1;
  if OD_File.Execute then
  begin
    if ReadOligsFromCSVFile(MyOligoArr, OD_File.FileName)
    then
      begin
        DisplayOligoArrInGrid(MyOligoArr);
        NumerateGrid(SG_OligoArr);
     end;
  end;
 end;

procedure TForm1.B_SaveOligsClick(Sender: TObject);
{Сохранение массива в файл}
var
  F: TextFile;
  S: String;
  i,j: integer;
  Sep: String;
begin
  SD_File.Filter:='CSV|*.csv';
  SD_File.FilterIndex:=1;
  SD_File.FileName:='';
  if SD_File.Execute then
  try
    AssignFile(F,SD_File.FileName);
    Rewrite(F);
    for i:=0 to Length(MyOligoArr)-1 do
    begin
      S:='';
      for j:=0 to Length(MyOligoArr[i])-1 do
      begin
        // В последней строке ';' быть не должно
        if (j<Length(MyOligoArr[i])-1) then Sep:=';' else Sep:='';
        S:=S+MyOligoArr[i,j]+Sep;
      end;
      WriteLN(F,S);
    end;
  finally
    CloseFile(F);
  end;
end;

procedure TForm1.B_CreateOligoArrClick(Sender: TObject);
// Вызывается окно задания массива
// по заданным параметрам генерится массив (пустой, рандомный или предзаполненный)
var
  i,j: integer;
begin
  Form3.ShowModal;

   if FillType<>-1 then
    begin
      SetLength(SliceTable,0); // очищаем слайстаблицу, если уже ранее создавалась
      SetLength(MyOligoArr, OligoArrRow);
      for i:=0 to Length(MyOligoArr)-1 do
      begin
        SetLength(MyOligoArr[i], OligoArrCol);
        for j:=0 to Length(MyOligoArr[i])-1 do
        begin
          case FillType of
          0: begin // ничего не делаем
               MyOligoArr[i,j]:='';
            end;
          1: begin  // рандомный массив
               MyOligoArr[i,j]:=GenerateOligSeq(RND_Length);
            end;
          2: begin  // предзаполненный одинаковой последовательностью
              MyOligoArr[i,j]:=StringToOlig(ConstSeqStr);
            end;
          end;
        end;

      end;
      DisplayOligoArrInGrid(MyOligoArr);
      NumerateGrid(SG_OligoArr);
    end;
end;

procedure TForm1.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива. Если массив не пустой, то выполняем его слайсинг, формируем файлы слоев и создаем слайс-таблицу
var
  TmpOligoArr: TOligoArr;
  TmpMatrixLayer: TMatrix;
  i,j: integer;
  mySymbolSet: TSymbolSet;
  TmpS: String;
  MaxLetter: TOlig;
  MaxCount: integer;
  Path: String;

begin
  if Length(MyOligoArr)<>0 then
  begin
    if SDD_Dir.Execute then
      Path:=SDD_Dir.FileName;

    SetLength(mySymbolSet,0);

    // копируем массив во временный, с которым будем работать
    SetLength(TmpOligoArr, Length(MyOligoArr));
    for i:=0 to Length(MyOligoArr)-1 do
    begin
      SetLength(TmpOligoArr[i], Length(MyOligoArr[i]));
      for j:=0 to Length(MyOligoArr[i])-1 do
      begin
        TmpOligoArr[i,j]:=MyOligoArr[i,j];
        FindUniqueSymbols(TmpOligoArr[i,j],mySymbolSet);
      end;
    end;

    // показываем уникальные символы
    for i:=0 to Length(mySymbolSet)-1 do
      TmpS:=TmpS+mySymbolSet[i];
    showMessage(TmpS);

    // Слайсинг
    i:=0;
    SetLength(SliceTable,0);
    Form4.LS_CharsInLayers.Clear;
    repeat
      SetLength(TmpMatrixLayer,0);
      CreateMatrixLayerFromOligoArr(TmpOligoArr, mySymbolSet, TmpMatrixLayer,
          MaxLetter, MaxCount);
      if MaxCount<>0 then
      begin
        SaveMatrixAsFile(TmpMatrixLayer,Path+'\Layer'+IntToStr(i+1)+'_'+MaxLetter+IntToStr(MaxCount)+'.txt');   //+1
        SetLength(SliceTable,Length(SliceTable)+1);
        SliceTable[i].LayerCount:=i+1;
        SliceTable[i].Letter:=MaxLetter;                                                                        //+1
        SliceTable[i].NumOfChar:=MaxCount;
        SliceTable[i].MatrixFile:=Path+'\Layer'+IntToStr(i+1)+'_'+MaxLetter+IntToStr(MaxCount)+'.txt';          //+1
        Form4.LS_CharsInLayers.AddXY(SliceTable[i].LayerCount, SliceTable[i].NumOfChar, SliceTable[i].Letter);
        Inc(i);
      end;
    until (MaxCount=0) or (i>1000);
    SaveSliceStatistics(Path, SliceTable);
    Form4.ShowModal;
  end
  else
    ShowMessage('пустой массив!');
end;

procedure TForm1.B_SetLasPen2Click(Sender: TObject);
// Вызов настроек лазерного маркера
begin
   B_SetLasPenClick(Self);
end;

procedure TForm1.B_SetGeomParamClick(Sender: TObject);
begin
  {TODO: Переделать на вкладке Manual окно задания массива и вызывать его отсюда}
  ShowMessage('Перейдите на вкладку Ручного управления'+#10#13+'и задайте геометрические параметры массива');
end;

procedure TForm1.B_CreateArrEzdClick(Sender: TObject);
// Создаем файлы EZD
var
  i: integer;
  TmpPath, path: String;
  rez: integer;
  TmpP: TPoint;
  pMyArr: Pointer;
begin

 { #TODO: Сделать редактирование параметров лазера! }
  if Length(SliceTable)<>0 then
  try
    path:=ExtractFilePath(ParamStr(0)); // путь к директории с EzCAD
    TmrCloserStr:=ExtractFilePath(ParamStr(0))+ExtractFileName(ParamStr(0));
    Tmr_Closer.Enabled:=true;
    rez:=lmc1_Initial2(WideString(path), true, Form1.Handle);
    ShowRez('lmc1_Initial2',rez); // подключаемся к MarkEzd.dll

    for i:=0 to Length(SliceTable)-1 do
    begin
      ReadMatrixFromFile(SliceTable[i].MatrixFile, myMatrix);

      TmpPath:=RemoveFileExt(SliceTable[i].MatrixFile);
      rez:=lmc1_LoadEzdFile(WideString(TmpPath+'.ezd'));
      SliceTable[i].EZDFile:=WideString(TmpPath+'.ezd');
      ShowRez('lmc1_LoadEzdFile',rez);
      rez:=lmc1_ClearEntLib();
      ShowRez('lmc1_ClearEntLib',rez);

      // пока что берем значения myStep myGStep myGroup из ручного управления. Переделать!!!
      myStep:=FSE_Step.Value;
      myGStep:=FSE_GroupStep.Value;
      myGroup:=SE_Group.Value;
      if CB_AutoCenter.Checked then
        begin
          TmpP:=AutoCenterBiasMatrix(MyMatrix, myStep, MyGStep, MyGroup);
          BiasX:=TmpP[0];
          BiasY:=TmpP[1];
        end
      else
        begin
          BiasX:=FSE_XBias.Value;
          BiasY:=FSE_YBias.Value;
        end;

       // добавляем споты в линейный массив
      rez:=ConvertMatrixToLinearArray(MyMatrix, ArrOfSpots, myStep, myGroup, myGStep, BiasX, BiasY);
      ShowRez('ConvertMatrixToLineArray: '+TmpPath+' ', rez);

      if Length(ArrOfSpots)<>0 then
        begin
           // добавляем наш массив в файл
          pMyArr:=@ArrOfSpots[0];
          rez:=lmc1_AddPointToLib(pMyArr,Length(ArrOfSpots),'Layer'+IntToStr(SliceTable[i].LayerCount),1);
          ShowRez('lmc1_AddPointToLib',rez);

          // сохраняем файл
          rez:=lmc1_SaveEntLibToFile(WideString(TmpPath+'.ezd'));
          ShowRez('lmc1_SaveEntLibToFile',rez);
        end
      else
      begin
        ShowRez('Пустой массив! Файл не перезаписан!',-1);
      end;
    end;
    TmpPath:=ExtractFileDir(SliceTable[0].MatrixFile);
    SaveSliceStatistics(TmpPath, SliceTable, 1);
  finally
    rez:=lmc1_Close;
    ShowRez('lmc1_Close', rez);
  end;
end;


{ВКЛАДКА Protocol}

procedure TForm1.B_LoadProtocolLayerClick(Sender: TObject);
// Загрузка протокола из файла
begin
  OD_File.Filter:='Протокол|*.pro';
  OD_File.FilterIndex:=1;
  OD_File.FileName:='';
  If OD_File.Execute then
  try
    TV_ProtocolLayer.LoadFromFile(OD_File.FileName);
  except
  end;
end;

procedure TForm1.B_AddBlockInProtocolClick(Sender: TObject);
// Добавляем корневой блок в протокол
begin
  Form6.ShowModal;
  if Form6.ModalResult=mrOK then
    TV_ProtocolLayer.Items.Add(nil,'Block='+MyBlockName+';');
end;

procedure TForm1.B_AddOperInProtocolClick(Sender: TObject);
// Добавляем оператор в протокол. В форме формируем функцию в записи, а здесь из нее создаем ноду
var
  tmpNode: TTreeNode;
begin
  if TV_ProtocolLayer.Selected= nil
  then
  begin
    ShowMessage('Сначала выделите узел');
    Exit;
  end;

  Form7.ShowModal;
    if Form7.ModalResult=mrOk then
    begin
      case TV_ProtocolLayer.Selected.Level of   // задаем ноду 0 уровня независимо от глубины вложения
        0 :tmpNode:=TV_ProtocolLayer.Selected;
        1 :tmpNode:=TV_ProtocolLayer.Selected.Parent;
        2 :tmpNode:=TV_ProtocolLayer.Selected.Parent.Parent;
      end;

      case MyOper.Func of
           dSyrSt: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+'; '+
                                             'Volume='+FloatToStr(MyOper.FloatParam)+'; '+
                                               'Speed='+IntToStr(MyOper.IntParam)+';');
             dVac: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+BoolToStr(MyOper.BoolParam)+'; ');

             dLaser: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+IntToStr(MyOper.IntParam)+'; '
                                                     +'Time='+FloatToStr(MyOper.FloatParam)+';');
             dPause: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+IntToStr(MyOper.IntParam)+';');
             dName: TV_ProtocolLayer.Items.AddChild(tmpNode, MyOper.StrParam+';');
      end;
    end;
end;

procedure TForm1.B_RemoveNodeClick(Sender: TObject);
begin
   if(TV_ProtocolLayer.Selected = nil) then
   begin
      ShowMessage('Выделите узел!');
      Exit;
   end;
   // удаляем
   TV_ProtocolLayer.Selected.Delete;
end;

procedure TForm1.B_SaveProtocolLayerClick(Sender: TObject);
// Сохраняем протокол в файл
begin
  SD_File.Filter:='Протокол|*.pro';
  SD_File.FilterIndex:=1;
  SD_File.FileName:='';
  if SD_File.Execute then
  try
    TV_ProtocolLayer.SaveToFile(SD_File.FileName);
  except
    ShowMessage('Ошибка сохранения файла протокола');
  end;
end;

procedure TForm1.SB_UpNodeClick(Sender: TObject);
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

procedure TForm1.SB_DownNodeClick(Sender: TObject);
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

procedure TForm1.B_LoadProtToSynthClick(Sender: TObject);
// Загрузить файлы протоколов
var
  TmpLet: String;
  TmpLayProt: TLayerProt;
  rez: Integer;
  i: integer;
begin
  OD_File.Filter:='Протокол|*.pro';
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

    rez:=ParceProtocolFile(TmpLayProt,OD_File.FileName);
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

 procedure TForm1.B_LoadLayersClick(Sender: TObject);
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

procedure TForm1.B_ClearAllClick(Sender: TObject);
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

procedure TForm1.B_StartClick(Sender: TObject);
//запуск синтеза
var
  MyThread: TSynThread; // Поток, в котором будет проходить весь синтез
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
  Memo1.Lines.Add('Первыйслой='+IntToStr(SliceTable[0].LayerCount)+' '+SliceTable[0].EZDFile);
  Memo1.Lines.Add('Последний слой='+IntToStr(SliceTable[High(SliceTable)].LayerCount)+' '
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
    MyThread:=TSynTHread.Create(false);
  end
  else ShowMessage('');


end;

procedure TForm1.B_PauseClick(Sender: TObject);
begin
  IsStarted:=false;
  Memo1.Lines.Add('Synthesis aborted');
end;

end.

