unit UMarkGeometryForm;
// Окно параметров геометрии маркировки: шаг, группы и смещение точек.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Spin, MarkGeometry;

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
    L_BiasX: TLabel;
    L_BiasY: TLabel;
    L_Group: TLabel;
    L_GroupStep: TLabel;
    L_Step: TLabel;
    SE_Group: TSpinEdit;
    procedure CB_AutoCenterChange(Sender: TObject);
  private
    procedure UpdateBiasEnabled;
  public
    constructor Create(TheOwner: TComponent); override;
    // True - нажали OK, AGeometry - введённые значения.
    // При отмене AGeometry не меняется.
    class function Execute(const ACaption: string;
      var AGeometry: TMarkGeometry): Boolean;
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

class function TMarkGeometryForm.Execute(const ACaption: string;
  var AGeometry: TMarkGeometry): Boolean;
var
  Form: TMarkGeometryForm;
begin
  Form:=TMarkGeometryForm.Create(nil);
  try
    Form.Caption:=ACaption;
    Form.FSE_Step.Value:=AGeometry.Step;
    Form.SE_Group.Value:=AGeometry.Group;
    Form.FSE_GroupStep.Value:=AGeometry.GroupStep;
    Form.CB_AutoCenter.Checked:=AGeometry.AutoCenter;
    Form.FSE_BiasX.Value:=AGeometry.BiasX;
    Form.FSE_BiasY.Value:=AGeometry.BiasY;
    Form.UpdateBiasEnabled;
    Result:=Form.ShowModal=mrOK;
    if Result then
    begin
      AGeometry.Step:=Form.FSE_Step.Value;
      AGeometry.Group:=Form.SE_Group.Value;
      AGeometry.GroupStep:=Form.FSE_GroupStep.Value;
      AGeometry.AutoCenter:=Form.CB_AutoCenter.Checked;
      AGeometry.BiasX:=Form.FSE_BiasX.Value;
      AGeometry.BiasY:=Form.FSE_BiasY.Value;
    end;
  finally
    Form.Free;
  end;
end;

end.
