unit ULayerChartForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, TAGraph,
  TASeries, TAChartUtils;

type

  { TLayerChartForm }

  TLayerChartForm = class(TForm)
    ChNCharsInLayers: TChart;
    LS_CharsInLayers: TLineSeries;
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  LayerChartForm: TLayerChartForm;

implementation
uses UMainForm;

{$R *.lfm}

{ TLayerChartForm }


procedure TLayerChartForm.FormCreate(Sender: TObject);
begin
  LayerChartForm.Caption:=MyInterface.ReadString('LayerChart','LayerChartForm','Number of spots in a layer');
  ChNCharsInLayers.AxisList.LeftAxis.Title.Caption:=MyInterface.ReadString('LayerChart','ChNCharsInLayersLeftAxis','Number of spots');
  ChNCharsInLayers.AxisList.BottomAxis.Title.Caption:=MyInterface.ReadString('LayerChart','ChNCharsInLayersBottomAxis','layer');
end;

end.

