unit UManualForm;
// Вкладка ручного управления: массив точек (матрица, геометрия, просмотр),
// лазер (параметры пера, создание EZD) и EzCAD. В группу GB_PumpStation
// главное окно встраивает шприцевую станцию. Журнал - через событие OnLog.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Spin,
  Windows, IniFiles, MarkGeometry, MatrixDocument, EzCadApp;

type
  TManualLogEvent = procedure(const AMsg: string) of object;

  { TManualForm }

  TManualForm = class(TForm)
    B_CloseEzCad: TButton;
    B_CreateEzd: TButton;
    B_Matrix: TButton;
    B_OpenEzCad: TButton;
    B_Preview: TButton;
    B_MarkEzCad: TButton;
    B_LaserParams: TButton;
    CB_AutoCenter: TCheckBox;
    FSE_GroupStep: TFloatSpinEdit;
    FSE_Step: TFloatSpinEdit;
    FSE_BiasX: TFloatSpinEdit;
    FSE_BiasY: TFloatSpinEdit;
    GB_Array: TGroupBox;
    GB_EzCAD: TGroupBox;
    GB_Laser: TGroupBox;
    GB_Dll: TGroupBox;
    GB_PumpStation: TGroupBox;
    L_AutoCenter: TLabel;
    L_BiasX: TLabel;
    L_BiasY: TLabel;
    L_GroupStep: TLabel;
    L_Group: TLabel;
    L_SpotSize: TLabel;
    L_Step: TLabel;
    L_SubstrateDiameter: TLabel;
    P_Manual: TPanel;
    P_Top: TPanel;
    P_ArrayLeft: TPanel;
    P_ArrayRight: TPanel;
    P_ArrayLeftFields: TPanel;
    P_ArrayRightFields: TPanel;
    P_DllButtons: TPanel;
    P_EzCadButtons: TPanel;
    SE_Group: TSpinEdit;
    SE_SpotSize: TSpinEdit;
    SE_SubstrateDiameter: TSpinEdit;
    SD_File: TSaveDialog;
    OD_File: TOpenDialog;
    Tmr_EzCADer: TTimer;
    procedure B_CloseEzCadClick(Sender: TObject);
    procedure B_CreateEzdClick(Sender: TObject);
    procedure B_MatrixClick(Sender: TObject);
    procedure B_OpenEzCadClick(Sender: TObject);
    procedure B_PreviewClick(Sender: TObject);
    procedure B_MarkEzCadClick(Sender: TObject);
    procedure B_LaserParamsClick(Sender: TObject);
    procedure CollapseExpand(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure P_TopResize(Sender: TObject);
    procedure GB_LaserResize(Sender: TObject);
    procedure GB_ArrayResize(Sender: TObject);
    procedure Tmr_EzCADerTimer(Sender: TObject);
  private
    FOnLog: TManualLogEvent;
    FMatrix: TMatrixDocument; // матрица точек (окно матрицы её показывает и меняет)
    FLoading: Boolean; // поля заполняются из настроек - не сохранять
    FEzCadWatcher: TEzCadDialogWatcher;
    function EnteredGeometry: TMarkGeometry;
    procedure SaveSettings;
    procedure SettingsChanged(Sender: TObject);
    procedure Log(const AMsg: string);
    procedure ShowRez(aFunName: String; aRez: integer);
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
    property OnLog: TManualLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  AppPaths,
  UMatrixForm, UPreviewForm, ULaserPenForm, LaserPen, MarkEzdWriter,
  MatrixTypes, ManualSettings,
  Lmc1Results;

{$R *.lfm}

{ TManualForm }

constructor TManualForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FMatrix:=TMatrixDocument.Create(20, 20);
  FEzCadWatcher:=TEzCadDialogWatcher.Create;
  FSE_Step.OnChange:=@SettingsChanged;
  SE_Group.OnChange:=@SettingsChanged;
  FSE_GroupStep.OnChange:=@SettingsChanged;
  SE_SpotSize.OnChange:=@SettingsChanged;
  FSE_BiasX.OnChange:=@SettingsChanged;
  FSE_BiasY.OnChange:=@SettingsChanged;
  SE_SubstrateDiameter.OnChange:=@SettingsChanged;
  CB_AutoCenter.OnChange:=@SettingsChanged;
  //для экранов с включенным масштабированием
  GB_Laser.Tag:=GB_Laser.Height;
  GB_Array.Tag:=GB_Array.Height;
end;

destructor TManualForm.Destroy;
begin
  FEzCadWatcher.Free;
  FMatrix.Free;
  inherited Destroy;
end;

procedure TManualForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_Array.Caption:=AIni.ReadString('Manual','GB_Array','Array');
  B_Matrix.Caption:=AIni.ReadString('Manual','B_Matrix','Matrix');
  L_Step.Caption:=AIni.ReadString('Manual','L_Step','Step, mm');
  L_Group.Caption:=AIni.ReadString('Manual','L_Group','Group');
  L_GroupStep.Caption:=AIni.ReadString('Manual','L_GroupStep','GroupStep, mm');
  L_SpotSize.Caption:=AIni.ReadString('Manual','L_SpotSize','SpotSize, um');
  B_Preview.Caption:=AIni.ReadString('Manual','B_Preview','Preview');
  L_AutoCenter.Caption:=AIni.ReadString('Manual','CB_AutoCenter','AutoCenter');
  CB_AutoCenter.Caption:='';
  L_AutoCenter.FocusControl:=CB_AutoCenter;
  L_AutoCenter.OnClick:=@ToggleManualOptionLabel;
  L_BiasX.Caption:=AIni.ReadString('Manual','L_BiasX','BiasX, mm');
  L_BiasY.Caption:=AIni.ReadString('Manual','L_BiasY','BiasY, mm');
  L_SubstrateDiameter.Caption:=AIni.ReadString('Manual','L_SubstrateDiameter','SubstrDiam, mm');
  SE_SubstrateDiameter.Hint:='Диаметр подложки. 0 - подложка не учитывается.';
  SE_SubstrateDiameter.ShowHint:=True;
  GB_Laser.Caption:=AIni.ReadString('Manual','GB_Laser','Laser');
  GB_Dll.Caption:=AIni.ReadString('Manual','GB_Dll','DLL');
  B_LaserParams.Caption:=AIni.ReadString('Manual','B_LaserParams','SetLasPen');
  B_CreateEzd.Caption:=AIni.ReadString('Manual','B_CreateEzd','CreateEZD');
  GB_EzCAD.Caption:=AIni.ReadString('Manual','GB_EzCAD','EzCAD');
  B_OpenEzCad.Caption:=AIni.ReadString('Manual','B_OpenEzCad','OpenEZCAD');
  B_CloseEzCad.Caption:=AIni.ReadString('Manual','B_CloseEzCad','CloseEZCAD');
  B_MarkEzCad.Caption:=AIni.ReadString('Manual','B_MarkEzCad','Mark');
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
    FSE_BiasX.Value:=Settings.Geometry.BiasX;
    FSE_BiasY.Value:=Settings.Geometry.BiasY;
    SE_SubstrateDiameter.Value:=Round(Settings.Geometry.SubstrateDiameter);
    CB_AutoCenter.Checked:=Settings.Geometry.AutoCenter;
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
  Result.BiasX:=FSE_BiasX.Value;
  Result.BiasY:=FSE_BiasY.Value;
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

procedure TManualForm.P_TopResize(Sender: TObject);
// «Массив» и «Лазер» делят верх поровну; «Лазер» прикреплён якорями справа
begin
  GB_Array.Width := P_Top.ClientWidth div 2;
end;

procedure TManualForm.Tmr_EzCADerTimer(Sender: TObject);
begin
  if not FEzCadWatcher.Tick then
    Tmr_EzCADer.Enabled:=False;
end;

procedure TManualForm.GB_ArrayResize(Sender: TObject);
// левая и правая половины группы равны; поля и кнопка каждой - по её центру
begin
  P_ArrayLeft.Width := GB_Array.ClientWidth div 2;
end;

procedure TManualForm.GB_LaserResize(Sender: TObject);
// группы DLL и EzCAD делят «Лазер» поровну
begin
  GB_Dll.Width := GB_Laser.ClientWidth div 2;
end;

procedure TManualForm.ToggleManualOptionLabel(Sender: TObject);
begin
  if Sender = L_AutoCenter then
    CB_AutoCenter.Checked := not CB_AutoCenter.Checked;
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
end;

procedure TManualForm.B_CreateEzdClick(Sender: TObject);
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

procedure TManualForm.B_OpenEzCadClick(Sender: TObject);
// Выбираем файл ezd и открываем его в EzCAD; окна лицензии и предупреждений
// EzCAD после запуска закрывает наблюдатель
begin
  if EzCadRunning then
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

  FEzCadWatcher.Start;
  Tmr_EzCADer.Enabled:=True;
  if not LaunchEzCad(AppDir, OD_File.FileName) then
    ShowMessage('Не удалось запустить EzCAD2.exe из папки программы.');
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
  Outline:=SubstrateOutline(Geometry, OUTLINE_POINTS);
  for i:=0 to High(Outline) do
    PreviewForm.AddSubstratePoint(Outline[i][0], Outline[i][1]);

  Points:=MatrixToMarkPoints(FMatrix.Matrix, Geometry);
  for i:=0 to High(Points) do
    PreviewForm.AddSpot(Points[i][0], Points[i][1], Geometry.SpotSize/2000);
  Overflow:=SubstrateOverflow(Points, Geometry);
  if (Length(Points)>0) and (Overflow>OVERFLOW_TOLERANCE_MM) then
    PreviewForm.Caption:=PreviewForm.Caption+' - массив выходит за подложку на '+
      FormatFloat('0.###', Overflow)+' мм';
  PreviewForm.ShowPreview;
end;

procedure TManualForm.B_MarkEzCadClick(Sender: TObject);
// команда маркировки F2 в EzCAD
begin
  if SendEzCadMark then
    Log('F2 отправлено')
  else
    ShowMessage('Приложение EzCAD2.exe не запущено!');
end;

procedure TManualForm.B_LaserParamsClick(Sender: TObject);
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

procedure TManualForm.B_CloseEzCadClick(Sender: TObject);
begin
  if not CloseEzCad then
    ShowMessage('Приложение EzCAD2.exe не запущено!');
end;

procedure TManualForm.ShowRez(aFunName: String; aRez: integer);
begin
  Log(Lmc1ResultText(aFunName, aRez));
end;

end.
