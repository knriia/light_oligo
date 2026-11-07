unit ULaserPenForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin, SpinEx,
  LaserPen;

type
  // Перо APenNo со значениями EzCAD по умолчанию; False и текст ошибки,
  // если прочитать не удалось.
  TReadDefaultPenFunc = function(APenNo: Integer; out APen: TLaserPen;
    out AErrorText: string): Boolean of object;

  { TLaserPenForm }

  TLaserPenForm = class(TForm)
    B_Cancel: TButton;
    B_OK: TButton;
    B_GetPen: TButton;
    CB_WobbleMode: TCheckBox;
    FSE_WobbleDiameter: TFloatSpinEdit;
    FSE_PointTime: TFloatSpinEdit;
    FSE_JumpSpeed: TFloatSpinEdit;
    FSE_Current: TFloatSpinEdit;
    FSE_Power: TFloatSpinEdit;
    FSE_MarkSpeed: TFloatSpinEdit;
    FSE_WobbleDist: TFloatSpinEdit;
    L_PointTime: TLabel;
    L_JumpDistTC: TLabel;
    L_JumpSpeed: TLabel;
    L_JumpPosTC: TLabel;
    L_PenNo: TLabel;
    L_MarkLoop: TLabel;
    L_SpiWave: TLabel;
    L_PolyTC: TLabel;
    L_MarkSpeed: TLabel;
    L_PowerRatio: TLabel;
    L_Current: TLabel;
    L_Freq: TLabel;
    L_WobbleDiameter: TLabel;
    L_QPulseWidth: TLabel;
    L_StartTC: TLabel;
    L_LaserOffTC: TLabel;
    L_EndTC: TLabel;
    L_WobbleDist: TLabel;
    SE_JumpDistTC: TSpinEdit;
    SE_SpiWave: TSpinEdit;
    SE_PenNo: TSpinEdit;
    SE_MarkLoop: TSpinEdit;
    SE_Freq: TSpinEdit;
    SE_QPulse: TSpinEdit;
    SE_StartTC: TSpinEdit;
    SE_LaserOffTC: TSpinEdit;
    SE_EndTC: TSpinEdit;
    SE_PolyTC: TSpinEdit;
    SE_JumpPosTC: TSpinEdit;
    procedure B_GetPenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FReadDefaultPen: TReadDefaultPenFunc;
    procedure FillGUIFromLasPen(const aPen: TLaserPen);
    procedure FillLasPenFromGUI(var aPen: TLaserPen);
  public
    // Правка параметров пера. True - нажали OK, APen - введённые значения;
    // при отмене APen не меняется. AReadDefaultPen - для кнопки «Значения
    // из EzCAD» (nil - кнопка недоступна).
    class function Execute(const ACaption: string; var APen: TLaserPen;
      AReadDefaultPen: TReadDefaultPenFunc): Boolean;
  end;

implementation

uses
  Localization;

{$R *.lfm}

{ TLaserPenForm }

procedure TLaserPenForm.B_GetPenClick(Sender: TObject);
// значения EzCAD по умолчанию для пера с введённым номером
var
  Pen: TLaserPen;
  ErrorText: string;
begin
  if not Assigned(FReadDefaultPen) then
    Exit;
  if not FReadDefaultPen(SE_PenNo.Value, Pen, ErrorText) then
  begin
    ShowMessage('Не удалось получить значения из EzCAD:'+LineEnding+ErrorText);
    Exit;
  end;
  FillGUIFromLasPen(Pen);
end;

procedure TLaserPenForm.FormCreate(Sender: TObject);
begin
  // интерфейс
    Caption:=ReadInterfaceString('LaserParam','LaserPenForm','Laser Parameters');
    L_PenNo.Caption:=ReadInterfaceString('LaserParam','L_PenNo','Pen No');
    L_MarkLoop.Caption:=ReadInterfaceString('LaserParam','L_MarkLoop','Mark Loops');
    L_MarkSpeed.Caption:=ReadInterfaceString('LaserParam','L_MarkSpeed','MarkSpeed');
    L_PowerRatio.Caption:=ReadInterfaceString('LaserParam','L_PowerRatio','PowerRatio');
    L_Current.Caption:=ReadInterfaceString('LaserParam','L_Current','Current');
    L_Freq.Caption:=ReadInterfaceString('LaserParam','L_Freq','Freq');
    L_QPulseWidth.Caption:=ReadInterfaceString('LaserParam','L_QPulseWidth','QPulseWidth');
    L_StartTC.Caption:=ReadInterfaceString('LaserParam','L_StartTC','StartTC');
    L_LaserOffTC.Caption:=ReadInterfaceString('LaserParam','L_LaserOffTC','LaserOffTC');
    L_EndTC.Caption:=ReadInterfaceString('LaserParam','L_EndTC','EndTC');
    L_PolyTC.Caption:=ReadInterfaceString('LaserParam','L_PolyTC','PolyTC');
    L_JumpSpeed.Caption:=ReadInterfaceString('LaserParam','L_JumpSpeed','JumpSpeed, mm/s');
    L_JumpPosTC.Caption:=ReadInterfaceString('LaserParam','L_JumpPosTC','JumpPosTC, ms');
    L_JumpDistTC.Caption:=ReadInterfaceString('LaserParam','L_JumpDistTC','JumpDistTC, ms');
    L_PointTime.Caption:=ReadInterfaceString('LaserParam','L_PointTime','PointTime, ms');
    L_SpiWave.Caption:=ReadInterfaceString('LaserParam','L_SpiWave','SpiWave');
    CB_WobbleMode.Caption:=ReadInterfaceString('LaserParam','CB_WobbleMode','Wobble Mode');
    L_WobbleDiameter.Caption:=ReadInterfaceString('LaserParam','L_WobbleDiameter','Wobble Diam, mm');
    L_WobbleDist.Caption:=ReadInterfaceString('LaserParam','L_WobbleDist','Wobble Dist, mm');
    B_GetPen.Caption:=ReadInterfaceString('LaserParam','B_GetPen','Значения из EzCAD');
    B_OK.Caption:='OK';
    B_Cancel.Caption:='Отмена';
end;

procedure TLaserPenForm.FillGUIFromLasPen(const aPen: TLaserPen);
begin
    SE_PenNo.Value:=aPen.nPenNo;
    SE_MarkLoop.Value:=aPen.nMarkLoop;
    FSE_MarkSpeed.Value:=aPen.dMarkSpeed;
    FSE_Power.Value:=aPen.dPowerRatio;
    FSE_Current.Value:=aPen.dCurrent;
    SE_Freq.Value:=aPen.nFreq div 1000; // в окне - кГц
    SE_QPulse.Value:=Round(aPen.dQPulseWidth);
    SE_StartTC.Value:=aPen.nStartTC;
    SE_LaserOffTC.Value:=aPen.nLaserOffTC;
    SE_EndTC.Value:=aPen.nEndTC;
    SE_PolyTC.Value:=aPen.nPolyTC;
    FSE_JumpSpeed.Value:=aPen.dJumpSpeed;
    SE_JumpPosTC.Value:=aPen.nJumpPosTC;
    SE_JumpDistTC.Value:=aPen.nJumpDistTC;
    FSE_PointTime.Value:=aPen.dPointTime;
    SE_SpiWave.Value:=aPen.nSpiWave;
    CB_WobbleMode.Checked:=aPen.bWobbleMode;
    FSE_WobbleDiameter.Value:=aPen.dWobbleDiameter;
    FSE_WobbleDist.Value:=aPen.dWobbleDist;
end;

procedure TLaserPenForm.FillLasPenFromGUI(var aPen: TLaserPen);
begin
    aPen.nPenNo:=SE_PenNo.Value;
    aPen.nMarkLoop:=SE_MarkLoop.Value;
    aPen.dMarkSpeed:=FSE_MarkSpeed.Value;
    aPen.dPowerRatio:=FSE_Power.Value;
    aPen.dCurrent:=FSE_Current.Value;
    aPen.nFreq:=SE_Freq.Value*1000; // в окне - кГц
    aPen.dQPulseWidth:=SE_QPulse.Value;
    aPen.nStartTC:=SE_StartTC.Value;
    aPen.nLaserOffTC:=SE_LaserOffTC.Value;
    aPen.nEndTC:=SE_EndTC.Value;
    aPen.nPolyTC:=SE_PolyTC.Value;
    aPen.dJumpSpeed:=FSE_JumpSpeed.Value;
    aPen.nJumpPosTC:=SE_JumpPosTC.Value;
    aPen.nJumpDistTC:=SE_JumpDistTC.Value;
    aPen.dPointTime:=FSE_PointTime.Value;
    aPen.nSpiWave:=SE_SpiWave.Value;
    aPen.bWobbleMode:=CB_WobbleMode.Checked;
    aPen.dWobbleDiameter:=FSE_WobbleDiameter.Value;
    aPen.dWobbleDist:=FSE_WobbleDist.Value;
end;

class function TLaserPenForm.Execute(const ACaption: string; var APen: TLaserPen;
  AReadDefaultPen: TReadDefaultPenFunc): Boolean;
var
  Form: TLaserPenForm;
begin
  Form:=TLaserPenForm.Create(nil);
  try
    Form.Caption:=ACaption;
    Form.FReadDefaultPen:=AReadDefaultPen;
    Form.B_GetPen.Enabled:=Assigned(AReadDefaultPen);
    Form.FillGUIFromLasPen(APen);
    Result:=Form.ShowModal=mrOK;
    if Result then
      Form.FillLasPenFromGUI(APen);
  finally
    Form.Free;
  end;
end;

end.
