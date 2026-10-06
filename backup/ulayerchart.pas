unit ULayerChart;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, TAGraph,
  TASeries, TAChartUtils;

type

  { TForm4 }

  TForm4 = class(TForm)
    ChNCharsInLayers: TChart;
    LS_CharsInLayers: TLineSeries;
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form4: TForm4;

implementation
uses Unit1;

{$R *.lfm}

{ TForm4 }


procedure TForm4.FormCreate(Sender: TObject);
begin
  Form4.Caption:=MyIni.ReadString('Interface','Form4','Number of spots in a layer');
  ChNCharsInLayers.AxisList.LeftAxis.Title.Caption:=MyIni.ReadString('Interface','ChNCharsInLayersLeftAxis','Number of spots');
  ChNCharsInLayers.AxisList.BottomAxis.Title.Caption:=MyIni.ReadString('Interface','ChNCharsInLayersBottomAxis','layer');
end;

end.

