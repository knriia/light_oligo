unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Spin, Windows, Graphics, Grids, Buttons,
  StrUtils, EzCadApi, UMatrixForm, UOligoArrayForm, UProtocolOperationForm, ULayerChartForm,
  UDispenserStationHost, DispenserLayout, ManualControlsLayout, ULaserPenForm,
  AppState, CommonUtils, WinProcessUtils, OligoMatrix, OligoArray,
  OligoSlices, SynthesisProtocol, ProtocolFormat, AppPaths, IniFiles, UProtocolBlockForm, SynthesisThread, UPreviewForm,
  USequencesForm, MarkGeometry, Lmc1Results;


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
    B_CloseEzCAD: TButton;
    B_SetLasPen: TButton;
    B_SendF2: TButton;
    B_OpenEZCAD: TButton;
    B_Preview: TButton;
    B_Matrix: TButton;
    B_CreateEZD: TButton;
    CB_AutoCenter: TCheckBox;
    CB_ShowSubstrate: TCheckBox;
    GB_PumpStation: TGroupBox;
    GB_MarkEZDDLL: TGroupBox;
    GB_EzCAD: TGroupBox;
    GB_EditProtocolTree: TGroupBox;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    L_MoveArrows: TLabel;
    L_SubstrD: TLabel;
    L_AutoCenter: TLabel;
    L_ShowSubstrate: TLabel;
    OD_File: TOpenDialog;
    FSE_XBias: TFloatSpinEdit;
    FSE_Step: TFloatSpinEdit;
    FSE_GroupStep: TFloatSpinEdit;
    FSE_YBias: TFloatSpinEdit;
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
    Panel3: TPanel;
    SD_File: TSaveDialog;
    SE_Group: TSpinEdit;
    SE_SpotSize: TSpinEdit;
    SE_SubstrateDiameter: TSpinEdit;
    SB_UpNode: TSpeedButton;
    SB_DownNode: TSpeedButton;
    Splitter2: TSplitter;
    TV_Synthesis: TTreeView;
    TS_Synthesis: TTabSheet;
    Tmr_EzCADer: TTimer;
    Tmr_Closer: TTimer;
    TV_ProtocolLayer: TTreeView;
    TS_Protocol: TTabSheet;
    TS_Manual: TTabSheet;
    TS_Log: TTabSheet;
    TS_Sequences: TTabSheet;
    procedure B_AddBlockInProtocolClick(Sender: TObject);
    procedure B_AddOperInProtocolClick(Sender: TObject);
    procedure B_ClearAllClick(Sender: TObject);
    procedure B_CloseEzCADClick(Sender: TObject);
    procedure B_CreateEZDClick(Sender: TObject);
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_LoadProtocolLayerClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_MatrixClick(Sender: TObject);
    procedure B_OpenEZCADClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_PreviewClick(Sender: TObject);
    procedure B_RemoveNodeClick(Sender: TObject);
    procedure B_SaveProtocolLayerClick(Sender: TObject);
    procedure B_SendF2Click(Sender: TObject);
    procedure B_SetLasPenClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure CollapseExpand(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SB_DownNodeClick(Sender: TObject);
    procedure SB_UpNodeClick(Sender: TObject);
    procedure Tmr_CloserTimer(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FDispenserStation: TDispenserStationForm;
    FSequencesForm: TSequencesForm;
    procedure SequencesLog(const AMsg: string);
    procedure UpdateManualControlsWidth;
    procedure UpdateManualArrayControlsLayout;
    procedure UpdateManualLaserControlsLayout;
    procedure UpdateMinimumWindowWidth;
    procedure ToggleManualOptionLabel(Sender: TObject);
    procedure DispenserStationLogMessage(Sender: TObject; const Msg: string);
    procedure LoadFileIntoTreeView(const FileName: string; TreeView: TTreeView);
  public
    Procedure ShowRez(aFunName: String; aRez:integer);
    property DispenserStation: TDispenserStationForm read FDispenserStation;
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

  GB_Array.Caption:=MyInterface.ReadString('Manual','GB_Array','Array');
  B_Matrix.Caption:=MyInterface.ReadString('Manual','B_Matrix','Matrix');
  L_Step.Caption:=MyInterface.ReadString('Manual','L_Step','Step, mm');
  L_Group.Caption:=MyInterface.ReadString('Manual','L_Group','Group');
  L_GStep.Caption:=MyInterface.ReadString('Manual','L_GStep','GroupStep, mm');
  L_SpotSize.Caption:=MyInterface.ReadString('Manual','L_SpotSize','SpotSize, um');
  B_Preview.Caption:=MyInterface.ReadString('Manual','B_Preview','Preview');
  L_AutoCenter.Caption:=MyInterface.ReadString('Manual','CB_AutoCenter','AutoCenter');
  CB_AutoCenter.Caption:='';
  L_AutoCenter.FocusControl:=CB_AutoCenter;
  L_AutoCenter.OnClick:=@ToggleManualOptionLabel;
  L_BiasX.Caption:=MyInterface.ReadString('Manual','L_BiasX','BiasX, mm');
  L_BiasY.Caption:=MyInterface.ReadString('Manual','L_BiasY','BiasY, mm');
  L_ShowSubstrate.Caption:=MyInterface.ReadString('Manual','CB_ShowSubstrate','Substrate');
  CB_ShowSubstrate.Caption:='';
  L_ShowSubstrate.FocusControl:=CB_ShowSubstrate;
  L_ShowSubstrate.OnClick:=@ToggleManualOptionLabel;
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
  FDispenserStation := TDispenserStationForm.Create(Self);
  FDispenserStation.BorderStyle := bsNone;
  FDispenserStation.Parent := GB_PumpStation;
  FDispenserStation.Align := alClient;
  FDispenserStation.AttachLogSink(@DispenserStationLogMessage);
  FDispenserStation.Show;
  FSequencesForm := TSequencesForm.Create(Self);
  FSequencesForm.BorderStyle := bsNone;
  FSequencesForm.Parent := TS_Sequences;
  FSequencesForm.Align := alClient;
  FSequencesForm.ApplyCaptions(MyInterface);
  FSequencesForm.OnLog := @SequencesLog;
  FSequencesForm.OnShowLaserSettings := @B_SetLasPenClick;
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
var
  ManualWidth, ManualHeight: Integer;
  ManualLayout: TManualControlsLayout;
begin
  if not Assigned(Panel1) or not Assigned(PageControl1) or
     not Assigned(TS_Manual) or not Assigned(Panel3) or
     not Assigned(GB_Array) or not Assigned(GB_Laser) or
     not Assigned(GB_PumpStation) then
    Exit;

  if (Panel1.ClientWidth <= 2) or (Panel1.ClientHeight <= 2) then
    Exit;

  PageControl1.SetBounds(1, 1, Panel1.ClientWidth - 2,
    Panel1.ClientHeight - 2);

  ManualWidth := TS_Manual.ClientWidth;
  ManualHeight := TS_Manual.ClientHeight;
  if (ManualWidth <= 0) or (ManualHeight <= 0) then
    Exit;

  Panel3.SetBounds(0, 0, ManualWidth, ManualHeight);
  ManualLayout := BuildManualControlsLayout(Panel3.ClientWidth, ManualHeight,
    GB_Array.Height, GB_Laser.Height);
  GB_Array.SetBounds(ManualLayout.ArrayBounds.Left,
    ManualLayout.ArrayBounds.Top,
    ManualLayout.ArrayBounds.Right - ManualLayout.ArrayBounds.Left,
    ManualLayout.ArrayBounds.Bottom - ManualLayout.ArrayBounds.Top);
  GB_Laser.SetBounds(ManualLayout.LaserBounds.Left,
    ManualLayout.LaserBounds.Top,
    ManualLayout.LaserBounds.Right - ManualLayout.LaserBounds.Left,
    ManualLayout.LaserBounds.Bottom - ManualLayout.LaserBounds.Top);
  GB_PumpStation.SetBounds(ManualLayout.PumpStationBounds.Left,
    ManualLayout.PumpStationBounds.Top,
    ManualLayout.PumpStationBounds.Right -
      ManualLayout.PumpStationBounds.Left,
    ManualLayout.PumpStationBounds.Bottom -
      ManualLayout.PumpStationBounds.Top);

  if Assigned(GB_MarkEZDDLL) and Assigned(GB_EzCAD) then
  begin
    GB_MarkEZDDLL.Width := GB_Laser.ClientWidth div 2;
    GB_EzCAD.Left := GB_MarkEZDDLL.Width;
    GB_EzCAD.Width := GB_Laser.ClientWidth - GB_EzCAD.Left;
  end;

  UpdateManualArrayControlsLayout();
  UpdateManualLaserControlsLayout();

end;

procedure TMainForm.UpdateManualArrayControlsLayout;
const
  LEFT_LABEL_WIDTH = 55;
  LEFT_LABEL_TO_INPUT_GAP = 41;
  RIGHT_COLUMN_WIDTH = 151;
  RIGHT_LABEL_TO_INPUT_GAP = 41;
  RIGHT_INPUT_RIGHT_MARGIN = 4;
  CHECKBOX_INDICATOR_WIDTH = 20;
  ARRAY_CONTENT_VERTICAL_SHIFT = 25;
  ARRAY_ACTION_BUTTON_BOTTOM_MARGIN = 5;
var
  ArrayClientWidth: Integer;
  ArrayLeftWidth: Integer;
  ArrayRightWidth: Integer;
  LeftInputOffset: Integer;
  LeftColumnWidth: Integer;
  LeftColumnLeft: Integer;
  RightColumnLeft: Integer;
  RightColumnOffset: Integer;
  RightInputLeftOffset: Integer;
  RightLabelWidth: Integer;
  ArrayVerticalLayout: TManualArrayVerticalLayout;
begin
  if not Assigned(GB_Array) or not Assigned(B_Matrix) or
     not Assigned(B_Preview) or not Assigned(L_Step) or
     not Assigned(FSE_Step) or not Assigned(L_Group) or
     not Assigned(SE_Group) or not Assigned(L_GStep) or
     not Assigned(FSE_GroupStep) or not Assigned(L_SpotSize) or
     not Assigned(SE_SpotSize) or not Assigned(L_BiasX) or
     not Assigned(FSE_XBias) or not Assigned(L_BiasY) or
     not Assigned(FSE_YBias) or not Assigned(CB_AutoCenter) or
     not Assigned(L_AutoCenter) or not Assigned(CB_ShowSubstrate) or
     not Assigned(L_ShowSubstrate) or not Assigned(L_SubstrD) or
     not Assigned(SE_SubstrateDiameter) then
    Exit;

  ArrayClientWidth := GB_Array.ClientWidth;
  ArrayLeftWidth := ArrayClientWidth div 2;
  ArrayRightWidth := ArrayClientWidth - ArrayLeftWidth;
  LeftInputOffset := LEFT_LABEL_WIDTH + LEFT_LABEL_TO_INPUT_GAP;
  LeftColumnWidth := LeftInputOffset + FSE_Step.Width;
  if L_SpotSize.Width > LeftColumnWidth then
    LeftColumnWidth := L_SpotSize.Width;
  LeftColumnLeft := (ArrayLeftWidth - LeftColumnWidth) div 2;
  if LeftColumnLeft < 0 then
    LeftColumnLeft := 0;
  RightInputLeftOffset := RIGHT_COLUMN_WIDTH -
    RIGHT_INPUT_RIGHT_MARGIN - FSE_XBias.Width;
  RightLabelWidth := RightInputLeftOffset - RIGHT_LABEL_TO_INPUT_GAP;
  RightColumnOffset := (ArrayRightWidth - RIGHT_COLUMN_WIDTH) div 2;
  if RightColumnOffset < 0 then
    RightColumnOffset := 0;
  RightColumnLeft := ArrayLeftWidth + RightColumnOffset;
  ArrayVerticalLayout := BuildManualArrayVerticalLayout(
    ARRAY_CONTENT_VERTICAL_SHIFT, GB_Array.ClientHeight, B_Matrix.Height,
    ARRAY_ACTION_BUTTON_BOTTOM_MARGIN);

  B_Matrix.Anchors := [akTop, akLeft];
  B_Matrix.SetBounds(LeftColumnLeft +
    (LeftColumnWidth - B_Matrix.Width) div 2, ArrayVerticalLayout.ActionButtonTop,
    B_Matrix.Width, B_Matrix.Height);
  B_Preview.Anchors := [akTop, akLeft];
  B_Preview.SetBounds(RightColumnLeft +
    (RIGHT_COLUMN_WIDTH - B_Preview.Width) div 2,
    ArrayVerticalLayout.ActionButtonTop,
    B_Preview.Width, B_Preview.Height);

  L_Step.Anchors := [akTop, akLeft];
  L_Step.SetBounds(LeftColumnLeft, ArrayVerticalLayout.StepLabelTop,
    LEFT_LABEL_WIDTH, L_Step.Height);
  FSE_Step.Anchors := [akTop, akLeft];
  FSE_Step.SetBounds(LeftColumnLeft + LeftInputOffset,
    ArrayVerticalLayout.StepFieldTop,
    FSE_Step.Width, FSE_Step.Height);
  L_Group.Anchors := [akTop, akLeft];
  L_Group.SetBounds(LeftColumnLeft, ArrayVerticalLayout.GroupLabelTop,
    LEFT_LABEL_WIDTH, L_Group.Height);
  SE_Group.Anchors := [akTop, akLeft];
  SE_Group.SetBounds(LeftColumnLeft + LeftInputOffset,
    ArrayVerticalLayout.GroupFieldTop,
    SE_Group.Width, SE_Group.Height);
  L_GStep.Anchors := [akTop, akLeft];
  L_GStep.SetBounds(LeftColumnLeft, ArrayVerticalLayout.GroupStepLabelTop,
    LEFT_LABEL_WIDTH, L_GStep.Height);
  FSE_GroupStep.Anchors := [akTop, akLeft];
  FSE_GroupStep.SetBounds(LeftColumnLeft + LeftInputOffset,
    ArrayVerticalLayout.GroupStepFieldTop,
    FSE_GroupStep.Width, FSE_GroupStep.Height);
  L_SpotSize.Anchors := [akTop, akLeft];
  L_SpotSize.SetBounds(LeftColumnLeft,
    ArrayVerticalLayout.SpotSizeLabelTop,
    55, L_SpotSize.Height);
  SE_SpotSize.Anchors := [akTop, akLeft];
  SE_SpotSize.SetBounds(LeftColumnLeft + LeftInputOffset,
    ArrayVerticalLayout.SpotSizeFieldTop,
    SE_SpotSize.Width, SE_SpotSize.Height);

  L_AutoCenter.Anchors := [akTop, akLeft];
  L_AutoCenter.SetBounds(RightColumnLeft,
    ArrayVerticalLayout.AutoCenterLabelTop, L_AutoCenter.Width,
    L_AutoCenter.Height);
  CB_AutoCenter.Anchors := [akTop, akLeft];
  CB_AutoCenter.SetBounds(RightColumnLeft + RIGHT_COLUMN_WIDTH -
    RIGHT_INPUT_RIGHT_MARGIN - CHECKBOX_INDICATOR_WIDTH,
    ArrayVerticalLayout.AutoCenterTop,
    CHECKBOX_INDICATOR_WIDTH,
    CB_AutoCenter.Height);
  L_BiasX.Anchors := [akTop, akLeft];
  L_BiasX.SetBounds(RightColumnLeft,
    ArrayVerticalLayout.BiasXLabelTop, RightLabelWidth,
    L_BiasX.Height);
  FSE_XBias.Anchors := [akTop, akLeft];
  FSE_XBias.SetBounds(RightColumnLeft + RightInputLeftOffset,
    ArrayVerticalLayout.BiasXFieldTop,
    FSE_XBias.Width, FSE_XBias.Height);
  L_BiasY.Anchors := [akTop, akLeft];
  L_BiasY.SetBounds(RightColumnLeft,
    ArrayVerticalLayout.BiasYLabelTop, RightLabelWidth,
    L_BiasY.Height);
  FSE_YBias.Anchors := [akTop, akLeft];
  FSE_YBias.SetBounds(RightColumnLeft + RightInputLeftOffset,
    ArrayVerticalLayout.BiasYFieldTop,
    FSE_YBias.Width, FSE_YBias.Height);
  L_ShowSubstrate.Anchors := [akTop, akLeft];
  L_ShowSubstrate.SetBounds(RightColumnLeft,
    ArrayVerticalLayout.ShowSubstrateLabelTop, L_ShowSubstrate.Width,
    L_ShowSubstrate.Height);
  CB_ShowSubstrate.Anchors := [akTop, akLeft];
  CB_ShowSubstrate.SetBounds(RightColumnLeft + RIGHT_COLUMN_WIDTH -
    RIGHT_INPUT_RIGHT_MARGIN - CHECKBOX_INDICATOR_WIDTH,
    ArrayVerticalLayout.ShowSubstrateTop,
    CHECKBOX_INDICATOR_WIDTH,
    CB_ShowSubstrate.Height);
  L_SubstrD.Anchors := [akTop, akLeft];
  L_SubstrD.SetBounds(RightColumnLeft,
    ArrayVerticalLayout.SubstrateDiameterLabelTop, RightLabelWidth,
    L_SubstrD.Height);
  SE_SubstrateDiameter.Anchors := [akTop, akLeft];
  SE_SubstrateDiameter.SetBounds(RightColumnLeft + RightInputLeftOffset,
    ArrayVerticalLayout.SubstrateDiameterFieldTop,
    SE_SubstrateDiameter.Width, SE_SubstrateDiameter.Height);
end;

procedure TMainForm.ToggleManualOptionLabel(Sender: TObject);
begin
  if Sender = L_AutoCenter then
    CB_AutoCenter.Checked := not CB_AutoCenter.Checked
  else if Sender = L_ShowSubstrate then
    CB_ShowSubstrate.Checked := not CB_ShowSubstrate.Checked;
end;

procedure TMainForm.UpdateManualLaserControlsLayout;
const
  BUTTON_GAP = 4;
var
  MarkButtonLeft: Integer;
  MarkButtonTop: Integer;
  MarkButtonsHeight: Integer;
  EzCadButtonTop: Integer;
  EzCadButtonsHeight: Integer;
  MarkButtonWidth: Integer;
  EzCadButtonWidth: Integer;

  // ширина, при которой помещается самая длинная надпись из группы,
  // но не шире самой группы
  function GroupButtonWidth(const AButtons: array of TButton;
    AGroupWidth: Integer): Integer;
  var
    I, W, H: Integer;
  begin
    Result := 0;
    for I := 0 to High(AButtons) do
    begin
      W := 0;
      H := 0;
      AButtons[I].GetPreferredSize(W, H);
      if W <= 0 then // окно кнопки ещё не создано: оставляем как есть
        W := AButtons[I].Width;
      if W > Result then
        Result := W;
    end;
    if Result > AGroupWidth then
      Result := AGroupWidth;
  end;

begin
  if not Assigned(GB_MarkEZDDLL) or not Assigned(GB_EzCAD) or
     not Assigned(B_SetLasPen) or not Assigned(B_CreateEZD) or
     not Assigned(B_OpenEZCAD) or not Assigned(B_CloseEzCAD) or
     not Assigned(B_SendF2) then
    Exit;

  MarkButtonWidth := GroupButtonWidth([B_SetLasPen, B_CreateEZD],
    GB_MarkEZDDLL.ClientWidth);
  B_SetLasPen.Width := MarkButtonWidth;
  B_CreateEZD.Width := MarkButtonWidth;
  EzCadButtonWidth := GroupButtonWidth([B_OpenEZCAD, B_CloseEzCAD, B_SendF2],
    GB_EzCAD.ClientWidth);
  B_OpenEZCAD.Width := EzCadButtonWidth;
  B_CloseEzCAD.Width := EzCadButtonWidth;
  B_SendF2.Width := EzCadButtonWidth;

  MarkButtonsHeight := B_SetLasPen.Height + BUTTON_GAP +
    B_CreateEZD.Height;
  MarkButtonLeft := (GB_MarkEZDDLL.ClientWidth - B_SetLasPen.Width) div 2;
  if MarkButtonLeft < 0 then
    MarkButtonLeft := 0;
  MarkButtonTop := (GB_MarkEZDDLL.ClientHeight - MarkButtonsHeight) div 2;
  if MarkButtonTop < 0 then
    MarkButtonTop := 0;

  B_SetLasPen.Anchors := [akTop, akLeft];
  B_SetLasPen.SetBounds(MarkButtonLeft, MarkButtonTop, B_SetLasPen.Width,
    B_SetLasPen.Height);
  B_CreateEZD.Anchors := [akTop, akLeft];
  B_CreateEZD.SetBounds(MarkButtonLeft,
    MarkButtonTop + B_SetLasPen.Height + BUTTON_GAP,
    B_CreateEZD.Width, B_CreateEZD.Height);

  EzCadButtonsHeight := B_OpenEZCAD.Height + BUTTON_GAP +
    B_CloseEZCAD.Height + BUTTON_GAP + B_SendF2.Height;
  EzCadButtonTop := (GB_EzCAD.ClientHeight - EzCadButtonsHeight) div 2;
  if EzCadButtonTop < 0 then
    EzCadButtonTop := 0;

  B_OpenEZCAD.Anchors := [akTop, akLeft];
  B_OpenEZCAD.SetBounds((GB_EzCAD.ClientWidth - B_OpenEZCAD.Width) div 2,
    EzCadButtonTop, B_OpenEZCAD.Width, B_OpenEZCAD.Height);
  B_CloseEzCAD.Anchors := [akTop, akLeft];
  B_CloseEzCAD.SetBounds((GB_EzCAD.ClientWidth - B_CloseEzCAD.Width) div 2,
    EzCadButtonTop + B_OpenEZCAD.Height + BUTTON_GAP,
    B_CloseEzCAD.Width, B_CloseEzCAD.Height);
  B_SendF2.Anchors := [akTop, akLeft];
  B_SendF2.SetBounds((GB_EzCAD.ClientWidth - B_SendF2.Width) div 2,
    EzCadButtonTop + B_OpenEZCAD.Height + BUTTON_GAP +
      B_CloseEzCAD.Height + BUTTON_GAP,
    B_SendF2.Width, B_SendF2.Height);

end;

procedure TMainForm.ShowRez(aFunName: String; aRez: integer);
begin
  Memo1.Lines.Add(Lmc1ResultText(aFunName, aRez));
end;

procedure TMainForm.SequencesLog(const AMsg: string);
begin
  Memo1.Lines.Add(AMsg);
end;

procedure TMainForm.Tmr_EzCADerTimer(Sender: TObject);
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

procedure TMainForm.CollapseExpand(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  GroupBox: TGroupBox;
begin
  {переделать. В create добавить запись высоты в тэг}
  GroupBox := Sender as TGroupBox;
  if (Y < 0) and (GroupBox.Height > 19) then
    GroupBox.Height := 19
  else
    GroupBox.Height := GroupBox.Tag;

  if (GroupBox = GB_Array) or (GroupBox = GB_Laser) then
    UpdateManualControlsWidth();
end;

procedure TMainForm.Tmr_CloserTimer(Sender: TObject);
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
end;

procedure TMainForm.DispenserStationLogMessage(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);
  Memo1.SelStart := Length(Memo1.Text);
end;

{ВКЛАДКА Manual}

procedure TMainForm.B_CreateEZDClick(Sender: TObject);
var
   rez: integer;
   path: string;
   pMyArr: pointer;
   TmpP: TPoint;
   EzdFile: string;
begin
   path:=ExtractFilePath(ParamStr(0));

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

   if Length(ArrOfSpots)=0 then
   begin
     ShowMessage('Массив пустой: сначала задайте матрицу.');
     Exit;
   end;

   // куда сохранить файл: по умолчанию data\ezd, имя по дате и времени
   SD_File.Filter:='EzCAD|*.ezd';
   SD_File.DefaultExt:='ezd';
   SD_File.InitialDir:=EzdDir;
   SD_File.FilterIndex:=1;
   SD_File.FileName:='array_'+FormatDateTime('yyyy-mm-dd_hhnn', Now)+'.ezd';
   try
     if not SD_File.Execute then
       Exit;
     EzdFile:=SD_File.FileName;
   finally
     SD_File.DefaultExt:='';
   end;

   // строка заголовка сообщения об ошибке (путь к проге)
   TmrCloserStr:=ExtractFilePath(ParamStr(0))+ExtractFileName(ParamStr(0));

   // запускаем таймер закрывающий сообщение об ошибке
   Tmr_Closer.Enabled:=true;
   rez:=lmc1_Initial2(WideString(path), true, MainForm.Handle);
   ShowRez('lmc1_Initial2',rez);

   // очищаем библиотеку объектов: файл создаётся с нуля
   rez:=lmc1_ClearEntLib();
   ShowRez('lmc1_ClearEntLib',rez);

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
   rez:=lmc1_SaveEntLibToFile(WideString(EzdFile));
   ShowRez('lmc1_SaveEntLibToFile: '+EzdFile,rez);

   // отключаемся от библиотеки
   rez:=lmc1_Close();
   ShowRez('lmc1_Close',rez);
end;

procedure TMainForm.B_MatrixClick(Sender: TObject);
begin
  MatrixForm.Show;
end;

procedure TMainForm.B_OpenEZCADClick(Sender: TObject);
// Выбираем файл ezd и открываем его в EzCAD,
// по таймеру закрываем предупреждения об ошибках
begin
 if GetProcessHandle('EzCad2.exe')<>0 then
 begin
   ShowMessage('Приложение EzCAD2.exe уже запущено!');
   Exit;
 end;

 OD_File.Filter:='EzCAD|*.ezd';
 OD_File.InitialDir:=EzdDir;
 OD_File.FilterIndex:=1;
 OD_File.FileName:='';
 if not OD_File.Execute then
   Exit;

 GlobalI:=0; // обнуляем глобальный счетчик
 Tmr_EzCADer.Enabled:=true;
 // W-версия и кавычки: путь может содержать кириллицу и пробелы
 ShellExecuteW(0, 'open',
               PWideChar(UnicodeString(ExtractFilePath(ParamStr(0))+'EzCAD2.exe')),
               PWideChar(UnicodeString('"'+OD_File.FileName+'"')),
               nil, SW_SHOWMINIMIZED);
end;

procedure TMainForm.B_PreviewClick(Sender: TObject);
var
  SubRadius, Angle: Double;
   i,j: integer;
   numPoints: integer;
   TmpP: TPoint;
begin
  if not Assigned(PreviewForm) then
  begin
    PreviewForm:=TPreviewForm.Create(Application);
    PreviewForm.Caption:=MyInterface.ReadString('Manual','B_Preview','Preview');
  end;
  PreviewForm.ClearPreview;

  if CB_ShowSubstrate.Checked then // если нужно показать контур подложки
  begin
    SubRadius:=SE_SubstrateDiameter.Value/2;
    numPoints:=100;
    for i:=0 to numPoints-1 do
    begin
      Angle:=2*Pi*i/numPoints; // Угол в радианах
      PreviewForm.AddSubstratePoint(SubRadius*Cos(Angle), SubRadius*Sin(Angle));
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
  for i:=0 to Length(MyMatrix)-1 do
    for j:=0 to Length(MyMatrix[i])-1 do
    begin
      if myMatrix[i,j]<>0 then
       begin
        if myGroup=0 then
          PreviewForm.AddSpot(j*myStep+BiasX, -i*myStep+BiasY, mySpotR)
        else
          PreviewForm.AddSpot(j*myStep+myGStep*(j div myGroup)+BiasX,
            -i*myStep-myGStep*(i div myGroup)+BiasY, mySpotR);
       end;
    end;
  PreviewForm.ShowPreview;
end;

procedure TMainForm.B_SendF2Click(Sender: TObject);
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

procedure TMainForm.B_SetLasPenClick(Sender: TObject);
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
   rez:=lmc1_Initial2(WideString(path), true, MainForm.Handle);
   ShowRez('lmc1_Initial2',rez);
   LaserPenForm.ShowModal;
end;

procedure TMainForm.B_CloseEzCADClick(Sender: TObject);
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

