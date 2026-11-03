unit UManualForm;
// Вкладка ручного управления: массив точек (матрица, геометрия, просмотр),
// лазер (параметры пера, создание EZD) и EzCAD. В группу GB_PumpStation
// главное окно встраивает шприцевую станцию. Журнал - через событие OnLog.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Spin,
  Windows, IniFiles, MarkGeometry, MatrixDocument;

type
  TManualLogEvent = procedure(const AMsg: string) of object;

  { TManualForm }

  TManualForm = class(TForm)
    B_CloseEzCAD: TButton;
    B_CreateEZD: TButton;
    B_Matrix: TButton;
    B_OpenEZCAD: TButton;
    B_Preview: TButton;
    B_SendF2: TButton;
    B_SetLasPen: TButton;
    CB_AutoCenter: TCheckBox;
    CB_ShowSubstrate: TCheckBox;
    FSE_GroupStep: TFloatSpinEdit;
    FSE_Step: TFloatSpinEdit;
    FSE_XBias: TFloatSpinEdit;
    FSE_YBias: TFloatSpinEdit;
    GB_Array: TGroupBox;
    GB_EzCAD: TGroupBox;
    GB_Laser: TGroupBox;
    GB_MarkEZDDLL: TGroupBox;
    GB_PumpStation: TGroupBox;
    L_AutoCenter: TLabel;
    L_BiasX: TLabel;
    L_BiasY: TLabel;
    L_GStep: TLabel;
    L_Group: TLabel;
    L_ShowSubstrate: TLabel;
    L_SpotSize: TLabel;
    L_Step: TLabel;
    L_SubstrD: TLabel;
    Panel3: TPanel;
    SE_Group: TSpinEdit;
    SE_SpotSize: TSpinEdit;
    SE_SubstrateDiameter: TSpinEdit;
    SD_File: TSaveDialog;
    OD_File: TOpenDialog;
    Tmr_EzCADer: TTimer;
    procedure B_CloseEzCADClick(Sender: TObject);
    procedure B_CreateEZDClick(Sender: TObject);
    procedure B_MatrixClick(Sender: TObject);
    procedure B_OpenEZCADClick(Sender: TObject);
    procedure B_PreviewClick(Sender: TObject);
    procedure B_SendF2Click(Sender: TObject);
    procedure B_SetLasPenClick(Sender: TObject);
    procedure CollapseExpand(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FOnLog: TManualLogEvent;
    FMatrix: TMatrixDocument; // матрица точек (окно матрицы её показывает и меняет)
    FLoading: Boolean; // поля заполняются из настроек - не сохранять
    function EnteredGeometry: TMarkGeometry;
    procedure SaveSettings;
    procedure SettingsChanged(Sender: TObject);
    procedure Log(const AMsg: string);
    procedure ShowRez(aFunName: String; aRez: integer);
    procedure UpdateManualArrayControlsLayout;
    procedure UpdateManualLaserControlsLayout;
    procedure ToggleManualOptionLabel(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Надписи из файла интерфейса (раздел [Manual]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Значения полей из configs\manual.ini. Дальше каждое изменение
    // сохраняется туда же.
    procedure LoadSettings;
    // Раскладка элементов под текущий размер формы.
    procedure UpdateLayout;
    property OnLog: TManualLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  AppState, AppPaths, WinProcessUtils, ManualControlsLayout,
  UMatrixForm, UPreviewForm, ULaserPenForm, LaserPen, MarkEzdWriter,
  MatrixTypes, ManualSettings,
  Lmc1Results;

{$R *.lfm}

{ TManualForm }

constructor TManualForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FMatrix:=TMatrixDocument.Create(20, 20);
  FSE_Step.OnChange:=@SettingsChanged;
  SE_Group.OnChange:=@SettingsChanged;
  FSE_GroupStep.OnChange:=@SettingsChanged;
  SE_SpotSize.OnChange:=@SettingsChanged;
  FSE_XBias.OnChange:=@SettingsChanged;
  FSE_YBias.OnChange:=@SettingsChanged;
  SE_SubstrateDiameter.OnChange:=@SettingsChanged;
  CB_AutoCenter.OnChange:=@SettingsChanged;
  CB_ShowSubstrate.OnChange:=@SettingsChanged;
  //для экранов с включенным масштабированием
  GB_Laser.Tag:=GB_Laser.Height;
  GB_Array.Tag:=GB_Array.Height;
end;

destructor TManualForm.Destroy;
begin
  FMatrix.Free;
  inherited Destroy;
end;

procedure TManualForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_Array.Caption:=AIni.ReadString('Manual','GB_Array','Array');
  B_Matrix.Caption:=AIni.ReadString('Manual','B_Matrix','Matrix');
  L_Step.Caption:=AIni.ReadString('Manual','L_Step','Step, mm');
  L_Group.Caption:=AIni.ReadString('Manual','L_Group','Group');
  L_GStep.Caption:=AIni.ReadString('Manual','L_GStep','GroupStep, mm');
  L_SpotSize.Caption:=AIni.ReadString('Manual','L_SpotSize','SpotSize, um');
  B_Preview.Caption:=AIni.ReadString('Manual','B_Preview','Preview');
  L_AutoCenter.Caption:=AIni.ReadString('Manual','CB_AutoCenter','AutoCenter');
  CB_AutoCenter.Caption:='';
  L_AutoCenter.FocusControl:=CB_AutoCenter;
  L_AutoCenter.OnClick:=@ToggleManualOptionLabel;
  L_BiasX.Caption:=AIni.ReadString('Manual','L_BiasX','BiasX, mm');
  L_BiasY.Caption:=AIni.ReadString('Manual','L_BiasY','BiasY, mm');
  L_ShowSubstrate.Caption:=AIni.ReadString('Manual','CB_ShowSubstrate','Substrate');
  CB_ShowSubstrate.Caption:='';
  L_ShowSubstrate.FocusControl:=CB_ShowSubstrate;
  L_ShowSubstrate.OnClick:=@ToggleManualOptionLabel;
  L_SubstrD.Caption:=AIni.ReadString('Manual','L_SubstrD','SubstrDiam, mm');
  GB_Laser.Caption:=AIni.ReadString('Manual','GB_Laser','Laser');
  GB_MarkEZDDLL.Caption:=AIni.ReadString('Manual','GB_MarkEZDDLL','DLL');
  B_SetLasPen.Caption:=AIni.ReadString('Manual','B_SetLasPen','SetLasPen');
  B_CreateEZD.Caption:=AIni.ReadString('Manual','B_CreateEZD','CreateEZD');
  GB_EzCAD.Caption:=AIni.ReadString('Manual','GB_EzCAD','EzCAD');
  B_OpenEZCAD.Caption:=AIni.ReadString('Manual','B_OpenEZCAD','OpenEZCAD');
  B_CloseEZCAD.Caption:=AIni.ReadString('Manual','B_CloseEZCAD','CloseEZCAD');
  B_SendF2.Caption:=AIni.ReadString('Manual','B_SendF2','Mark');
  GB_PumpStation.Caption:=AIni.ReadString('Manual','GB_PumpStation','PumpStation');
end;

procedure TManualForm.LoadSettings;
// настройки ручной вкладки из configs\manual.ini
var
  Settings: TManualSettings;
begin
  Settings:=LoadManualSettings(ManualConfigPath);
  FLoading:=True;
  try
    FSE_Step.Value:=Settings.Geometry.Step;
    SE_Group.Value:=Settings.Geometry.Group;
    FSE_GroupStep.Value:=Settings.Geometry.GroupStep;
    SE_SpotSize.Value:=Round(Settings.Geometry.SpotSize);
    FSE_XBias.Value:=Settings.Geometry.BiasX;
    FSE_YBias.Value:=Settings.Geometry.BiasY;
    SE_SubstrateDiameter.Value:=Round(Settings.Geometry.SubstrateDiameter);
    CB_AutoCenter.Checked:=Settings.Geometry.AutoCenter;
    CB_ShowSubstrate.Checked:=Settings.ShowSubstrate;
    FMatrix.Resize(Settings.MatrixRows, Settings.MatrixCols);
  finally
    FLoading:=False;
  end;
end;

function TManualForm.EnteredGeometry: TMarkGeometry;
begin
  Result:=DefaultMarkGeometry;
  Result.Step:=FSE_Step.Value;
  Result.Group:=SE_Group.Value;
  Result.GroupStep:=FSE_GroupStep.Value;
  Result.AutoCenter:=CB_AutoCenter.Checked;
  Result.BiasX:=FSE_XBias.Value;
  Result.BiasY:=FSE_YBias.Value;
  Result.SpotSize:=SE_SpotSize.Value;
  Result.SubstrateDiameter:=SE_SubstrateDiameter.Value;
end;

procedure TManualForm.SaveSettings;
// сохраняем сразу после изменения; ошибку - в журнал, чтобы не мешать вводу
var
  Settings: TManualSettings;
  ErrorText: string;
begin
  if FLoading then
    Exit;
  Settings.Geometry:=EnteredGeometry;
  Settings.ShowSubstrate:=CB_ShowSubstrate.Checked;
  Settings.MatrixRows:=FMatrix.Rows;
  Settings.MatrixCols:=FMatrix.Cols;
  if not SaveManualSettings(ManualConfigPath, Settings, ErrorText) then
    Log(ErrorText);
end;

procedure TManualForm.SettingsChanged(Sender: TObject);
begin
  SaveSettings;
end;

procedure TManualForm.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
end;

procedure TManualForm.FormResize(Sender: TObject);
begin
  UpdateLayout;
end;

procedure TManualForm.Tmr_EzCADerTimer(Sender: TObject);
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

procedure TManualForm.UpdateLayout;
var
  ManualWidth, ManualHeight: Integer;
  ManualLayout: TManualControlsLayout;
begin
  if not Assigned(Panel3) or
     not Assigned(GB_Array) or not Assigned(GB_Laser) or
     not Assigned(GB_PumpStation) then
    Exit;

  ManualWidth := ClientWidth;
  ManualHeight := ClientHeight;
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

procedure TManualForm.UpdateManualArrayControlsLayout;
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

procedure TManualForm.ToggleManualOptionLabel(Sender: TObject);
begin
  if Sender = L_AutoCenter then
    CB_AutoCenter.Checked := not CB_AutoCenter.Checked
  else if Sender = L_ShowSubstrate then
    CB_ShowSubstrate.Checked := not CB_ShowSubstrate.Checked;
end;

procedure TManualForm.UpdateManualLaserControlsLayout;
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

procedure TManualForm.CollapseExpand(Sender: TObject; Button: TMouseButton;
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
    UpdateLayout();
end;

procedure TManualForm.B_CreateEZDClick(Sender: TObject);
// EZD-файл из матрицы с геометрией и пером лазера ручной вкладки
var
  Geometry: TMarkGeometry;
  Points: TArrOfTPoint;
  EzdFile, ErrorText: string;
  Writer: TMarkEzdWriter;
  Saved: Boolean;
begin
  Geometry:=EnteredGeometry;
  Points:=MatrixToMarkPoints(FMatrix.Matrix, Geometry);
  if Length(Points)=0 then
  begin
    ShowMessage('Массив пустой: сначала задайте матрицу.');
    Exit;
  end;
  if not CheckArrayFitsSubstrate(Points, Geometry, ErrorText) then
  begin
    ShowMessage('EZD-файл не создан: '+ErrorText);
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

  // сообщение MarkEzd.dll при подключении (например, что платы нет) не
  // закрываем: пользователь должен его увидеть
  Writer:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    if not Writer.Open(ErrorText) then
    begin
      ShowMessage('Не удалось подключиться к MarkEzd.dll: '+ErrorText);
      Exit;
    end;
    try
      // перо записывается в EZD: с ним пойдёт маркировка
      Saved:=Writer.SavePoints(EzdFile, 'arr', Points,
        LoadLaserPen(ManualConfigPath), ErrorText);
    finally
      Writer.Close;
    end;
  finally
    Writer.Free;
  end;
  if Saved then
    Log('EZD-файл создан: '+EzdFile)
  else
    ShowMessage('Не удалось создать EZD-файл:'+LineEnding+EzdFile+LineEnding+
      ErrorText);
end;

procedure TManualForm.B_MatrixClick(Sender: TObject);
begin
  MatrixForm.Document:=FMatrix;
  MatrixForm.OnMatrixChanged:=@B_PreviewClick;
  MatrixForm.OnSizeChanged:=@SettingsChanged;
  MatrixForm.Show;
end;

procedure TManualForm.B_OpenEZCADClick(Sender: TObject);
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

procedure TManualForm.B_PreviewClick(Sender: TObject);
// матрица на подложке с введёнными параметрами
const
  OUTLINE_POINTS = 100;
var
  Geometry: TMarkGeometry;
  Points, Outline: TArrOfTPoint;
  Overflow: Double;
  i: Integer;
begin
  if not Assigned(PreviewForm) then
    PreviewForm:=TPreviewForm.Create(Application);
  PreviewForm.ClearPreview;
  PreviewForm.Caption:=B_Preview.Caption;

  Geometry:=EnteredGeometry;
  if CB_ShowSubstrate.Checked then
  begin
    Outline:=SubstrateOutline(Geometry, OUTLINE_POINTS);
    for i:=0 to High(Outline) do
      PreviewForm.AddSubstratePoint(Outline[i][0], Outline[i][1]);
  end;

  Points:=MatrixToMarkPoints(FMatrix.Matrix, Geometry);
  for i:=0 to High(Points) do
    PreviewForm.AddSpot(Points[i][0], Points[i][1], Geometry.SpotSize/2000);
  Overflow:=SubstrateOverflow(Points, Geometry);
  if (Length(Points)>0) and (Overflow>1e-9) then
    PreviewForm.Caption:=PreviewForm.Caption+' - массив выходит за подложку на '+
      FormatFloat('0.###', Overflow)+' мм';
  PreviewForm.ShowPreview;
end;

procedure TManualForm.B_SendF2Click(Sender: TObject);
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

procedure TManualForm.B_SetLasPenClick(Sender: TObject);
// перо лазера ручной вкладки; хранится в configs\manual.ini
var
  Pen: TLaserPen;
  Reader: TMarkEzdWriter;
  ErrorText: string;
begin
  Pen:=LoadLaserPen(ManualConfigPath);
  Reader:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    if not TLaserPenForm.Execute('Параметры лазера (ручной режим)', Pen,
         @Reader.ReadDefaultPen) then
      Exit;
  finally
    Reader.Free;
  end;
  if not SaveLaserPen(ManualConfigPath, Pen, ErrorText) then
    ShowMessage(ErrorText);
end;

procedure TManualForm.B_CloseEzCADClick(Sender: TObject);
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

procedure TManualForm.ShowRez(aFunName: String; aRez: integer);
begin
  Log(Lmc1ResultText(aFunName, aRez));
end;

end.
