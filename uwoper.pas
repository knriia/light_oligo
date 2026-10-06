unit UWOper;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, ExtCtrls,
  StdCtrls, Spin, MyGlobals;



type

  { TForm7 }

  TForm7 = class(TForm)
    BB_Ok: TBitBtn;
    BB_Cancel: TBitBtn;
    ChB_Vac: TCheckBox;
    FSE_SyrVolume: TFloatSpinEdit;
    GB_SyrSt: TGroupBox;
    GB_Vac: TGroupBox;
    GB_Laser: TGroupBox;
    GB_Pause: TGroupBox;
    GB_Comment: TGroupBox;
    L_LasTime: TLabel;
    L_SyrVol: TLabel;
    L_Flow: TLabel;
    L_Pause: TLabel;
    L_LasRepeats: TLabel;
    LE_Comment: TLabeledEdit;
    LE_SyrNames: TLabeledEdit;
    Panel1: TPanel;
    Panel2: TPanel;
    RG_Operator: TRadioGroup;
    SE_Flow: TSpinEdit;
    SE_LasTIme: TSpinEdit;
    SE_Pause: TSpinEdit;
    SE_LasRepeats: TSpinEdit;
    procedure BB_OkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RG_OperatorClick(Sender: TObject);
  private
    Procedure ShowHidePannels(aValue: Integer);

  public

  end;

var
  Form7: TForm7;

implementation
uses UMain;

{$R *.lfm}

{ TForm3 }

procedure TForm7.RG_OperatorClick(Sender: TObject);
begin
  ShowHidePannels(RG_Operator.ItemIndex);
end;

procedure TForm7.ShowHidePannels(aValue: Integer);
// В зависимости от RG_Operator.ItemIndex отображаем нужную панель
begin
    case aValue of
    0:begin
        GB_SyrSt.Visible:=true;
        GB_Vac.Visible:=false;
        GB_Laser.Visible:=false;
        GB_Pause.Visible:=false;
        GB_Comment.Visible:=false;
      end;
    1:begin
        GB_SyrSt.Visible:=false;
        GB_Vac.Visible:=true;
        GB_Laser.Visible:=false;
        GB_Pause.Visible:=false;
        GB_Comment.Visible:=false;
      end;
    2:begin
        GB_SyrSt.Visible:=false;
        GB_Vac.Visible:=false;
        GB_Laser.Visible:=true;
        GB_Pause.Visible:=false;
        GB_Comment.Visible:=false;
      end;
    3:begin
        GB_SyrSt.Visible:=false;
        GB_Vac.Visible:=false;
        GB_Laser.Visible:=false;
        GB_Pause.Visible:=true;
        GB_Comment.Visible:=false;
      end;
    4:begin
        GB_SyrSt.Visible:=false;
        GB_Vac.Visible:=false;
        GB_Laser.Visible:=false;
        GB_Pause.Visible:=false;
        GB_Comment.Visible:=true;
      end;
    end;
end;

procedure TForm7.BB_OkClick(Sender: TObject);
begin
  case RG_Operator.ItemIndex of
    0:begin
        if LE_SyrNames.Text='' then
          begin
            ShowMessage('Введите название шприца!');
            ModalResult:=mrCancel;
            Exit;
          end;
        MyOper.Func:=dSyrSt;
        MyOper.FloatParam:=FSE_SyrVolume.Value;
        MyOper.IntParam:=SE_Flow.Value;
        MyOper.StrParam:='SyrSt='+LE_SyrNames.Text;
      end;
    1:begin
        MyOper.Func:=dVac;
        MyOper.FloatParam:=0;
        MyOper.IntParam:=0;
        MyOper.BoolParam:=ChB_Vac.Checked;
        MyOper.StrParam:='Vacuum=';
      end;
    2:begin
        MyOper.Func:=dlaser;
        MyOper.FloatParam:=SE_LasTime.Value;
        MyOper.IntParam:=SE_LasRepeats.Value;
        MyOper.StrParam:='Laser=';
      end;
    3:begin
        MyOper.Func:=dPause;
        MyOper.FloatParam:=0;
        MyOper.IntParam:=SE_Pause.Value;
        MyOper.StrParam:='Pause=';
      end;
    4:begin
        MyOper.Func:=dName;
        MyOper.FloatParam:=0;
        MyOper.IntParam:=0;
        MyOper.StrParam:='Comment='+LE_Comment.Text;
      end;
  end;
end;

procedure TForm7.FormCreate(Sender: TObject);
begin
  Form7.Caption:=MyInterface.ReadString('Operator','Form7','Add Operator');
  RG_Operator.Caption:=MyInterface.ReadString('Operator','RG_Operator','Operator');
  RG_Operator.Items[0]:=MyInterface.ReadString('Operator','SyringeStation_RG','SyringeStation');
  RG_Operator.Items[1]:=MyInterface.ReadString('Operator','Vacuum_RG','Vacuum');
  RG_Operator.Items[2]:=MyInterface.ReadString('Operator','Laser_RG','Laser');
  RG_Operator.Items[3]:=MyInterface.ReadString('Operator','Pause_RG','Pause');
  RG_Operator.Items[4]:=MyInterface.ReadString('Operator','Comment_RG','Comment');
  BB_Cancel.Caption:=MyInterface.ReadString('Operator','BB_Cancel','Cancel');
  BB_Ok.Caption:=MyInterface.ReadString('Operator','BB_Ok','Ok');
  GB_SyrSt.Caption:=MyInterface.ReadString('Operator','GB_SyrSt','Syringe Station');
  LE_SyrNames.EditLabel.Caption:=MyInterface.ReadString('Operator','LE_SyrNames','Syringe Name');
  L_SyrVol.Caption:=MyInterface.ReadString('Operator','L_SyrVol','Volume, ul');
  L_Flow.Caption:=MyInterface.ReadString('Operator','L_Flow','Flow, ul/s');
  GB_Vac.Caption:=MyInterface.ReadString('Operator','GB_Vac','Vacuum');
  ChB_Vac.Caption:=MyInterface.ReadString('Operator','ChB_Vac','On/Off');
  GB_Laser.Caption:=MyInterface.ReadString('Operator','GB_Laser','Laser');
  L_LasRepeats.Caption:=MyInterface.ReadString('Operator','L_LasRepeats','Repeats');
  L_LasTime.Caption:=MyInterface.ReadString('Operator','L_LasTime','LasTime, s');
  GB_Pause.Caption:=MyInterface.ReadString('Operator','GB_Pause','Pause');
  L_Pause.Caption:=MyInterface.ReadString('Operator','L_Pause','Pause, s');
  GB_Comment.Caption:=MyInterface.ReadString('Operator','GB_Comment','Comment');
  LE_Comment.EditLabel.Caption:=MyInterface.ReadString('Operator','LE_Comment','Enter a comment');

  {TODO: Добавить считывание параметров из MyIni}
  RG_Operator.ItemIndex:=MyIni.ReadInteger('Operators', 'RG_Operator', 4);
  ChB_Vac.Checked:=MyIni.ReadBool('Operators', 'ChB_Vac', false);
  LE_Comment.Text:=MyIni.ReadString('Operators','LE_Comment','');
  SE_Pause.Value:=MyIni.ReadInteger('Operators', 'SE_Pause', 1);
  LE_SyrNames.Text:=MyIni.ReadString('Operators','LE_SyrNames','W');
  FSE_SyrVolume.Value:=MyIni.ReadFloat('Operators','FSE_SyrVolume',250);
  SE_Flow.Value:=MyIni.ReadInteger('Operators', 'SE_Flow', 10);
  SE_LasRepeats.Value:=MyIni.ReadInteger('Operators', 'SE_LasRepeats', 1);
  SE_LasTIme.Value:=MyIni.ReadInteger('Operators', 'SE_LasTIme', 3);
end;

end.

