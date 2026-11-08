unit UMarkGeometryForm;
// Окно параметров геометрии маркировки: шаг, группы и смещение точек,
// диаметр пятна и подложки. «Просмотр» показывает массив на подложке с
// введёнными (ещё не сохранёнными) параметрами.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Spin, MatrixTypes, MarkGeometry;

type

  { TMarkGeometryForm }

  TMarkGeometryForm = class(TForm)
    B_Cancel: TButton;
    B_OK: TButton;
    B_Preview: TButton;
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
    L_GroupStep: TLabel;
    L_Step: TLabel;
    L_SpotSize: TLabel;
    L_Substrate: TLabel;
    SE_Group: TSpinEdit;
    procedure B_PreviewClick(Sender: TObject);
    procedure CB_AutoCenterChange(Sender: TObject);
  private
    FArrayMatrix: TMatrix;
    procedure UpdateBiasEnabled;
    function EnteredGeometry: TMarkGeometry;
  public
    constructor Create(TheOwner: TComponent); override;
    // True - нажали OK, AGeometry - введённые значения.
    // При отмене AGeometry не меняется. AArrayMatrix - занятые ячейки
    // массива для просмотра (пустая - на просмотре только подложка).
    class function Execute(const ACaption: string;
      var AGeometry: TMarkGeometry; const AArrayMatrix: TMatrix): Boolean;
  end;

implementation

uses
  UPreviewForm;

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
  B_Preview.Caption:='Просмотр';
  B_OK.Caption:='OK';
  B_Cancel.Caption:='Отмена';
end;

procedure TMarkGeometryForm.CB_AutoCenterChange(Sender: TObject);
begin
  UpdateBiasEnabled;
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

procedure TMarkGeometryForm.B_PreviewClick(Sender: TObject);
// весь массив на подложке с введёнными параметрами
const
  OUTLINE_POINTS = 100;
var
  Geometry: TMarkGeometry;
  Points, Outline: TArrOfTPoint;
  Preview: TPreviewForm;
  Overflow: Double;
  i: Integer;
begin
  Geometry:=EnteredGeometry;
  Points:=MatrixToMarkPoints(FArrayMatrix, Geometry);
  Outline:=SubstrateOutline(Geometry, OUTLINE_POINTS);
  Preview:=TPreviewForm.Create(nil);
  try
    Preview.ClearPreview;
    for i:=0 to High(Outline) do
      Preview.AddSubstratePoint(Outline[i][0], Outline[i][1]);
    for i:=0 to High(Points) do
      Preview.AddSpot(Points[i][0], Points[i][1], Geometry.SpotSize/2000);
    Preview.Caption:='Просмотр';
    if Length(Points)=0 then
      Preview.Caption:=Preview.Caption+' - в массиве нет олигов'
    else
    begin
      Overflow:=SubstrateOverflow(Points, Geometry);
      if Overflow>1e-9 then
        Preview.Caption:=Preview.Caption+' - массив выходит за подложку на '+
          FormatFloat('0.###', Overflow)+' мм';
    end;
    Preview.ShowPreviewModal;
  finally
    Preview.Free;
  end;
end;

class function TMarkGeometryForm.Execute(const ACaption: string;
  var AGeometry: TMarkGeometry; const AArrayMatrix: TMatrix): Boolean;
var
  Form: TMarkGeometryForm;
begin
  Form:=TMarkGeometryForm.Create(nil);
  try
    Form.Caption:=ACaption;
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
    Result:=Form.ShowModal=mrOK;
    if Result then
      AGeometry:=Form.EnteredGeometry;
  finally
    Form.Free;
  end;
end;

end.
