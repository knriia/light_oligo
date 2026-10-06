unit ULasPen;

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
    FSE_Current: TFloatSpinEdit;
    FSE_Power: TFloatSpinEdit;
    FSE_MarkSpeed: TFloatSpinEdit;
    L_PenNo: TLabel;
    L_MarkLoop: TLabel;
    L_PolyTC: TLabel;
    L_MarkSpeed: TLabel;
    L_PowerRatio: TLabel;
    L_Current: TLabel;
    L_Freq: TLabel;
    L_QPulseWidth: TLabel;
    L_StartTC: TLabel;
    L_LaserOffTC: TLabel;
    L_EndTC: TLabel;
    SE_PenNo: TSpinEdit;
    SE_MarkLoop: TSpinEdit;
    SE_Freq: TSpinEdit;
    SE_QPulse: TSpinEdit;
    SE_StartTC: TSpinEdit;
    SE_LaserOffTC: TSpinEdit;
    SE_EndTC: TSpinEdit;
    SE_PolyTC: TSpinEdit;
    procedure B_GetPenClick(Sender: TObject);
    procedure B_SetPenClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    procedure FillGUIFromLasPen(aPen: TLasPen);
    procedure FillLasPenFromGUI(var aPen: TLasPen);
  public

  end;

var
  Form5: TForm5;

implementation
Uses Unit1;

{$R *.lfm}

{ TForm5 }

procedure TForm5.B_GetPenClick(Sender: TObject);
var
  rez: integer;
begin
  rez:=lmc1_GetPenParam(MyLasPen.nPenNo,           // номер пера, который нужно установить (0-255)
                        MyLasPen.nMarkLoop,        // количество обработок
                        MyLasPen.dMarkSpeed,       // количество маркировок мм/с
                        MyLasPen.dPowerRatio,      // Процент мощности (0-100%)
                        MyLasPen.dCurrent,         // Текущий A
                        MyLasPen.nFreq,            // частота Гц
                        MyLasPen.nQPulseWidth,     // ширина Q-импульса us
                        MyLasPen.nStartTC,         // Старт задержит нас
                        MyLasPen.nLaserOffTC,      // задержка выключения лазера
                        MyLasPen.nEndTC,           // завершим задержку
                        MyLasPen.nPolyTC,          // задержка угла
                        MyLasPen.dJumpSpeed,       // Скорость прыжка мм/с
                        MyLasPen.nJumpPosTC,       // задержка позиции перехода
                        MyLasPen.nJumpDistTC,      // задержка на расстояние прыжка
                        MyLasPen.dEndComp,         // компенсация конечной точки мм
                        MyLasPen.dAccDist,         // Дистанция ускорения мм
                        MyLasPen.dPointTime,       // задержка точки, мс
                        MyLasPen.bPulsePointMode,  // Режим точки пульса
                        MyLasPen.nPulseNum,        // Количество точек пульса
                        MyLasPen.dFlySpeed);       // Скорость производственной линии
  FillGUIFromLasPen(MyLasPen);
end;

procedure TForm5.B_SetPenClick(Sender: TObject);
begin
  FillLasPenFromGUI(MyLasPen);
  lmc1_SetPenParam(MyLasPen.nPenNo,MyLasPen.nMarkLoop, MyLasPen.dMarkSpeed,
                   MyLasPen.dPowerRatio, MyLasPen.dCurrent,MyLasPen.nFreq,
                   MyLasPen.nQPulseWidth, MyLasPen.nStartTC, MyLasPen.nLaserOffTC,
                   MyLasPen.nEndTC, MyLasPen.nPolyTC, MyLasPen.dJumpSpeed,
                   MyLasPen.nJumpPosTC, MyLasPen.nJumpDistTC, MyLasPen.dEndComp,
                   MyLasPen.dAccDist, MyLasPen.dPointTime, MyLasPen.bPulsePointMode,
                   MyLasPen.nPulseNum, MyLasPen.dFlySpeed);
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
    Form5.Caption:=MyIni.ReadString('Interface','Form5','Laser Parameters');
    L_PenNo.Caption:=MyIni.ReadString('Interface','L_PenNo','Pen No');
    L_MarkLoop.Caption:=MyIni.ReadString('Interface','L_MarkLoop','Mark Loops');
    L_MarkSpeed.Caption:=MyIni.ReadString('Interface','L_MarkSpeed','MarkSpeed');
    L_PowerRatio.Caption:=MyIni.ReadString('Interface','L_PowerRatio','PowerRatio');
    L_Current.Caption:=MyIni.ReadString('Interface','L_Current','Current');
    L_Freq.Caption:=MyIni.ReadString('Interface','L_Freq','Freq');
    L_QPulseWidth.Caption:=MyIni.ReadString('Interface','L_QPulseWidth','QPulseWidth');
    L_StartTC.Caption:=MyIni.ReadString('Interface','L_StartTC','StartTC');
    L_LaserOffTC.Caption:=MyIni.ReadString('Interface','L_LaserOffTC','LaserOffTC');
    L_EndTC.Caption:=MyIni.ReadString('Interface','L_EndTC','EndTC');
    L_PolyTC.Caption:=MyIni.ReadString('Interface','L_PolyTC','PolyTC');
    B_GetPen.Caption:=MyIni.ReadString('Interface','B_GetPen','GetPen');
    B_SetPen.Caption:=MyIni.ReadString('Interface','B_SetPen','SetPen');
end;

procedure TForm5.FillGUIFromLasPen(aPen: TLasPen);
begin
    SE_PenNo.Value:=aPen.nPenNo;
    SE_MarkLoop.Value:=aPen.nMarkLoop;
    FSE_MarkSpeed.Value:=aPen.dMarkSpeed;
    FSE_Power.Value:=aPen.dPowerRatio;
    FSE_Current.Value:=aPen.dCurrent;
    SE_Freq.Value:=aPen.nFreq/1000;
    SE_QPulse.Value:=aPen.nQPulseWidth;
    SE_StartTC.Value:=aPen.nStartTC;
    SE_LaserOffTC.Value:=aPen.nLaserOffTC;
    SE_EndTC.Value:=aPen.nEndTC;
    SE_PolyTC.Value:=aPen.nPolyTC;
    { остальные параметры
    dJumpSpeed: Double;       // Скорость прыжка мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние прыжка
    dEndComp: Double;         // компенсация конечной точки мм
    dAccDist: Double;         // Дистанция ускорения мм
    dPointTime: Double;       // задержка точки, мс
    bPulsePointMode: boolean; // Режим точки пульса
    nPulseNum: Integer;       // Количество точек пульса
    dFlySpeed: Double         // Скорость производственной линии  }
end;

procedure TForm5.FillLasPenFromGUI(var aPen: TLasPen);
begin
    aPen.nPenNo:=SE_PenNo.Value;
    aPen.nMarkLoop:=SE_MarkLoop.Value;
    aPen.dMarkSpeed:=FSE_MarkSpeed.Value;
    aPen.dPowerRatio:=FSE_Power.Value;
    aPen.dCurrent:=FSE_Current.Value;
    aPen.nFreq:=SE_Freq.Value*1000;
    aPen.nQPulseWidth:=SE_QPulse.Value;
    aPen.nStartTC:=SE_StartTC.Value;
    aPen.nLaserOffTC:=SE_LaserOffTC.Value;
    aPen.nEndTC:=SE_EndTC.Value;
    aPen.nPolyTC:=SE_PolyTC.Value;
end;

end.

