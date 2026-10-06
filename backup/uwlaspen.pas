unit UWLasPen;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin, SpinEx,
  LasFunc, MyGlobals;

type

  { TForm5 }

  TForm5 = class(TForm)
    B_SetPen: TButton;
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
    procedure B_SetPenClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    procedure FillGUIFromLasPen(aPen: TLasPen2);
    procedure FillLasPenFromGUI(var aPen: TLasPen2);
  public

  end;

var
  Form5: TForm5;

implementation
Uses UMain;

{$R *.lfm}

{ TForm5 }

procedure TForm5.B_GetPenClick(Sender: TObject);
var
  rez: integer;
begin
  rez:=lmc1_GetPenParam2(MyLasPen.nPenNo,          // номер пера, который нужно установить (0-255)
                        MyLasPen.nMarkLoop,        // количество обработок
                        MyLasPen.dMarkSpeed,       // количество маркировок мм/с
                        MyLasPen.dPowerRatio,      // Процент мощности (0-100%)
                        MyLasPen.dCurrent,         // Текущий A
                        MyLasPen.nFreq,            // частота Гц
                        MyLasPen.dQPulseWidth,     // ширина Q-импульса us
                        MyLasPen.nStartTC,         // Старт задержит нас
                        MyLasPen.nLaserOffTC,      // задержка выключения лазера
                        MyLasPen.nEndTC,           // завершим задержку
                        MyLasPen.nPolyTC,          // задержка угла
                        MyLasPen.dJumpSpeed,       // Скорость прыжка мм/с
                        MyLasPen.nJumpPosTC,       // задержка позиции перехода
                        MyLasPen.nJumpDistTC,      // задержка на расстояние прыжка
                        MyLasPen.dPointTime,
                        MyLasPen.nSpiWave,
                        MyLasPen.bWobbleMode,
                        MyLasPen.dWobbleDiameter,
                        MyLasPen.dWobbleDist);
  FillGUIFromLasPen(MyLasPen);
  Form1.ShowRez('lmc1_GetPenParam2', rez);
end;

procedure TForm5.B_SetPenClick(Sender: TObject);
var
  rez: integer;
begin
  FillLasPenFromGUI(MyLasPen);
  rez:=lmc1_SetPenParam2(MyLasPen.nPenNo,MyLasPen.nMarkLoop, MyLasPen.dMarkSpeed,
                   MyLasPen.dPowerRatio, MyLasPen.dCurrent,MyLasPen.nFreq,
                   MyLasPen.dQPulseWidth, MyLasPen.nStartTC, MyLasPen.nLaserOffTC,
                   MyLasPen.nEndTC, MyLasPen.nPolyTC, MyLasPen.dJumpSpeed,
                   MyLasPen.nJumpPosTC, MyLasPen.nJumpDistTC, MyLasPen.dPointTime,
                   MyLasPen.nSpiWave, MyLasPen.bWobbleMode, MyLasPen.dWobbleDiameter,
                   MyLasPen.dWobbleDist);
  Form1.ShowRez('lmc1_SetPenParam2', rez);
end;

procedure TForm5.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  rez: integer;
begin
  rez:=lmc1_Close;
  Form1.ShowRez('lmc1_Close', rez);
end;

procedure TForm5.FormCreate(Sender: TObject);
begin
    Form5.Caption:=MyInterface.ReadString('LaserParam','Form5','Laser Parameters');
    L_PenNo.Caption:=MyInterface.ReadString('LaserParam','L_PenNo','Pen No');
    L_MarkLoop.Caption:=MyInterface.ReadString('LaserParam','L_MarkLoop','Mark Loops');
    L_MarkSpeed.Caption:=MyInterface.ReadString('LaserParam','L_MarkSpeed','MarkSpeed');
    L_PowerRatio.Caption:=MyInterface.ReadString('LaserParam','L_PowerRatio','PowerRatio');
    L_Current.Caption:=MyInterface.ReadString('LaserParam','L_Current','Current');
    L_Freq.Caption:=MyInterface.ReadString('LaserParam','L_Freq','Freq');
    L_QPulseWidth.Caption:=MyInterface.ReadString('LaserParam','L_QPulseWidth','QPulseWidth');
    L_StartTC.Caption:=MyInterface.ReadString('LaserParam','L_StartTC','StartTC');
    L_LaserOffTC.Caption:=MyInterface.ReadString('LaserParam','L_LaserOffTC','LaserOffTC');
    L_EndTC.Caption:=MyInterface.ReadString('LaserParam','L_EndTC','EndTC');
    L_PolyTC.Caption:=MyInterface.ReadString('LaserParam','L_PolyTC','PolyTC');
    L_JumpSpeed.Caption:=MyInterface.ReadString('LaserParam','L_JumpSpeed','JumpSpeed, mm/s');
    L_JumpPosTC.Caption:=MyInterface.ReadString('LaserParam','L_JumpPosTC','JumpPosTC, ms');
    L_JumpDistTC.Caption:=MyInterface.ReadString('LaserParam','L_JumpDistTC','JumpDistTC, ms');
    L_PointTime.Caption:=MyInterface.ReadString('LaserParam','L_PointTime','PointTime, ms');
    L_SpiWave.Caption:=MyInterface.ReadString('LaserParam','L_SpiWave','SpiWave');
    CB_WobbleMode.Caption:=MyInterface.ReadString('LaserParam','CB_WobbleMode','Wobble Mode');
    L_WobbleDiameter.Caption:=MyInterface.ReadString('LaserParam','L_WobbleDiameter','Wobble Diam, mm');
    L_WobbleDist.Caption:=MyInterface.ReadString('LaserParam','L_WobbleDist','Wobble Dist, mm');
    B_GetPen.Caption:=MyInterface.ReadString('LaserParam','B_GetPen','GetPen');
    B_SetPen.Caption:=MyInterface.ReadString('LaserParam','B_SetPen','SetPen');

    {TODO: ДОбавить значения из MyIni}
    SE_PenNo.Value:=MyIni.ReadInteger('LaserParam','SE_PenNo',10);
    SE_MarkLoop.Value:=MyIni.ReadInteger('LaserParam','SE_MarkLoop',1);
    FSE_MarkSpeed.Value:=MyIni.ReadFloat('LaserParam','FSE_MarkSpeed',500);
    FSE_Power.Value:=MyIni.ReadFloat('LaserParam','FSE_Power',100);
    FSE_Current.Value:=MyIni.ReadFloat('LaserParam','FSE_Current',10);
    SE_Freq.Value:=MyIni.ReadFloat('LaserParam','SE_Freq',30);
    SE_QPulse.Value:=MyIni.ReadFloat('LaserParam','SE_QPulse',10);
    SE_StartTC.Value:=MyIni.ReadFloat('LaserParam','SE_StartTC',150);
    SE_LaserOffTC.Value:=MyIni.ReadFloat('LaserParam','SE_LaserOffTC',150);
    SE_EndTC.Value:=MyIni.ReadFloat('LaserParam','SE_EndTC',300);
    SE_PolyTC.Value:=MyIni.ReadFloat('LaserParam','SE_PolyTC',100);
    FSE_JumpSpeed.Value:=MyIni.ReadFloat('LaserParam','FSE_JumpSpeed',1000);
    SE_JumpPosTC.Value:=MyIni.ReadFloat('LaserParam','SE_JumpPosTC',10);
    SE_JumpDistTC.Value:=MyIni.ReadFloat('LaserParam','SE_JumpDistTC',10);
    FSE_PointTime.Value:=MyIni.ReadFloat('LaserParam','FSE_PointTime',10);
    SE_SpiWave.Value:=MyIni.ReadInteger('LaserParam','SE_SpiWave',0);
    CB_WobbleMode.Checked:=MyIni.ReadBool('LaserParam','CB_WobbleMode',false);
    FSE_WobbleDiameter.Value:=MyIni.ReadFloat('LaserParam','FSE_WobbleDiameter',0);
    FSE_WobbleDist.Value:=MyIni.ReadFloat('LaserParam','FSE_WobbleDist',0);
end;

procedure TForm5.FillGUIFromLasPen(aPen: TLasPen2);
begin
    SE_PenNo.Value:=aPen.nPenNo;
    SE_MarkLoop.Value:=aPen.nMarkLoop;
    FSE_MarkSpeed.Value:=aPen.dMarkSpeed;
    FSE_Power.Value:=aPen.dPowerRatio;
    FSE_Current.Value:=aPen.dCurrent;
    SE_Freq.Value:=aPen.nFreq/1000;
    SE_QPulse.Value:=aPen.dQPulseWidth;
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

procedure TForm5.FillLasPenFromGUI(var aPen: TLasPen2);
begin
    aPen.nPenNo:=SE_PenNo.Value;
    aPen.nMarkLoop:=SE_MarkLoop.Value;
    aPen.dMarkSpeed:=FSE_MarkSpeed.Value;
    aPen.dPowerRatio:=FSE_Power.Value;
    aPen.dCurrent:=FSE_Current.Value;
    aPen.nFreq:=SE_Freq.Value*1000;
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

end.

