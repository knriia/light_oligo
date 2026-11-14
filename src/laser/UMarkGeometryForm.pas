unit UMarkGeometryForm;
// Окно параметров геометрии маркировки: шаг, группы и смещение точек,
// диаметр пятна и подложки. Справа в том же окне - массив на подложке с
// введёнными (ещё не сохранёнными) параметрами; он перерисовывается при
// каждом изменении.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin, MatrixTypes,
  MarkGeometry, PreviewLayout, UPreviewForm;

const
  REFRESH_DELAY_MS = 150; // пауза в вводе перед перерисовкой превью

type

  { TMarkGeometryForm }

  TMarkGeometryForm = class(TForm)
    B_Cancel: TButton;
    B_OK: TButton;
    CB_AutoCenter: TCheckBox;
    FSE_BiasX: TFloatSpinEdit;
    FSE_BiasY: TFloatSpinEdit;
    FSE_GroupStep: TFloatSpinEdit;
    FSE_Step: TFloatSpinEdit;
    FSE_SpotSize: TFloatSpinEdit;
    FSE_Substrate: TFloatSpinEdit;
    L_BiasX: TLabel;
    L_BiasY: TLabel;
    L_Group: TLabel;
    L_Info: TLabel;
    L_GroupStep: TLabel;
    L_Step: TLabel;
    L_SpotSize: TLabel;
    L_Substrate: TLabel;
    P_Preview: TPanel;
    SE_Group: TSpinEdit;
    procedure CB_AutoCenterChange(Sender: TObject);
    procedure ParamChange(Sender: TObject);
  private
    FArrayMatrix: TMatrix;
    FPreview: TPreviewForm; // встроен в P_Preview, принадлежит окну
    FLoading: Boolean;      // поля заполняются: превью рисуем один раз в конце
    FNeedZoom: Boolean;     // следующая отрисовка показывает всё целиком
    FDrawnSubstrate: Double; // подложка, с которой масштаб подогнан в последний раз
    FRefreshTimer: TTimer;  // перерисовка после паузы в вводе, не на каждую клавишу
    procedure RefreshPreview;
    procedure ScheduleRefresh;
    procedure RefreshTimerTick(Sender: TObject);
    procedure UpdateBiasEnabled;
    function EnteredGeometry: TMarkGeometry;
  public
    constructor Create(TheOwner: TComponent); override;
    // True - нажали OK, AGeometry - введённые значения.
    // При отмене AGeometry не меняется. AArrayMatrix - занятые ячейки
    // массива для превью справа (пустая - в превью только подложка).
    class function Execute(const ACaption: string;
      var AGeometry: TMarkGeometry; const AArrayMatrix: TMatrix): Boolean;
  end;

implementation

{$R *.lfm}

{ TMarkGeometryForm }

constructor TMarkGeometryForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  L_Step.Caption:='Шаг между точками, мм:';
  L_Group.Caption:='Точек в группе (0 - без групп):';
  L_GroupStep.Caption:='Доп. шаг между группами, мм:';
  CB_AutoCenter.Caption:='Центрировать автоматически';
  L_BiasX.Caption:='Смещение по X, мм:';
  L_BiasY.Caption:='Смещение по Y, мм:';
  L_SpotSize.Caption:='Диаметр пятна, мкм:';
  L_Substrate.Caption:='Диаметр подложки, мм:';
  B_OK.Caption:='OK';
  B_Cancel.Caption:='Отмена';
  L_Info.Caption:='';

  // размер при создании - минимальный: окно растёт, а поля и кнопки остаются
  // на местах, увеличивается только превью
  Constraints.MinWidth:=Width;
  Constraints.MinHeight:=Height;
  FNeedZoom:=True;
  FRefreshTimer:=TTimer.Create(Self);
  FRefreshTimer.Enabled:=False;
  FRefreshTimer.Interval:=REFRESH_DELAY_MS;
  FRefreshTimer.OnTimer:=@RefreshTimerTick;
  FPreview:=TPreviewForm.Create(Self);
  FPreview.BorderStyle:=bsNone;
  FPreview.Parent:=P_Preview;
  FPreview.Align:=alClient;
  FPreview.CenterChart:=True;
  FPreview.Show;
end;

procedure TMarkGeometryForm.CB_AutoCenterChange(Sender: TObject);
begin
  UpdateBiasEnabled;
  ScheduleRefresh;
end;

procedure TMarkGeometryForm.ParamChange(Sender: TObject);
begin
  ScheduleRefresh;
end;

procedure TMarkGeometryForm.ScheduleRefresh;
// большой массив пересчитывается заметное время: ждём паузу в вводе
begin
  if (FPreview=nil) or FLoading then
    Exit;
  FRefreshTimer.Enabled:=False;
  FRefreshTimer.Enabled:=True;
end;

procedure TMarkGeometryForm.RefreshTimerTick(Sender: TObject);
begin
  FRefreshTimer.Enabled:=False;
  RefreshPreview;
end;

procedure TMarkGeometryForm.UpdateBiasEnabled;
// при автоцентре ручное смещение не используется
begin
  FSE_BiasX.Enabled:=not CB_AutoCenter.Checked;
  FSE_BiasY.Enabled:=not CB_AutoCenter.Checked;
  L_BiasX.Enabled:=FSE_BiasX.Enabled;
  L_BiasY.Enabled:=FSE_BiasY.Enabled;
end;

function TMarkGeometryForm.EnteredGeometry: TMarkGeometry;
begin
  Result:=DefaultMarkGeometry;
  Result.Step:=FSE_Step.Value;
  Result.Group:=SE_Group.Value;
  Result.GroupStep:=FSE_GroupStep.Value;
  Result.AutoCenter:=CB_AutoCenter.Checked;
  Result.BiasX:=FSE_BiasX.Value;
  Result.BiasY:=FSE_BiasY.Value;
  Result.SpotSize:=FSE_SpotSize.Value;
  Result.SubstrateDiameter:=FSE_Substrate.Value;
end;

procedure TMarkGeometryForm.RefreshPreview;
// весь массив на подложке с введёнными параметрами
const
  OUTLINE_POINTS = 100;
var
  Geometry: TMarkGeometry;
  Points, Outline: TArrOfTPoint;
  i: Integer;
begin
  if (FPreview=nil) or FLoading then // окно ещё собирается или заполняется
    Exit;
  Geometry:=EnteredGeometry;
  FPreview.ClearPreview;
  L_Info.Caption:='';
  // пока значение вводят, поле может на миг оказаться недопустимым
  if not IsValidMarkGeometry(Geometry) then
  begin
    L_Info.Caption:='Проверьте значения параметров';
    FNeedZoom:=True;
    Exit;
  end;
  Outline:=SubstrateOutline(Geometry, OUTLINE_POINTS);
  for i:=0 to High(Outline) do
    FPreview.AddSubstratePoint(Outline[i][0], Outline[i][1]);
  Points:=MatrixToMarkPoints(FArrayMatrix, Geometry);
  for i:=0 to High(Points) do
    FPreview.AddSpot(Points[i][0], Points[i][1], Geometry.SpotSize/2000);
  L_Info.Caption:=PreviewWarning(Points, Geometry);
  // масштаб пользователя не сбрасываем, пока не изменилась сама подложка
  if NeedFullZoom(FNeedZoom, FDrawnSubstrate, Geometry.SubstrateDiameter) then
    FPreview.ZoomFull;
  FNeedZoom:=False;
  FDrawnSubstrate:=Geometry.SubstrateDiameter;
end;

class function TMarkGeometryForm.Execute(const ACaption: string;
  var AGeometry: TMarkGeometry; const AArrayMatrix: TMatrix): Boolean;
var
  Form: TMarkGeometryForm;
begin
  Form:=TMarkGeometryForm.Create(nil);
  try
    Form.Caption:=ACaption;
    Form.FLoading:=True;
    Form.FArrayMatrix:=AArrayMatrix;
    Form.FSE_Step.Value:=AGeometry.Step;
    Form.SE_Group.Value:=AGeometry.Group;
    Form.FSE_GroupStep.Value:=AGeometry.GroupStep;
    Form.CB_AutoCenter.Checked:=AGeometry.AutoCenter;
    Form.FSE_BiasX.Value:=AGeometry.BiasX;
    Form.FSE_BiasY.Value:=AGeometry.BiasY;
    Form.FSE_SpotSize.Value:=AGeometry.SpotSize;
    Form.FSE_Substrate.Value:=AGeometry.SubstrateDiameter;
    Form.UpdateBiasEnabled;
    Form.FLoading:=False;
    Form.RefreshPreview; // первый раз сразу, без ожидания таймера
    Result:=Form.ShowModal=mrOK;
    if Result then
      AGeometry:=Form.EnteredGeometry;
  finally
    Form.Free;
  end;
end;

end.
