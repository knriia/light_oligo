unit UPreviewForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, TAGraph, TASeries,
  TAMultiSeries, TAPolygonSeries, TATools;

type
  TPreviewForm = class(TForm)
    Chart1: TChart;
    BS_Series: TBubbleSeries;
    PS_Series: TPolygonSeries;
    ChartToolset1: TChartToolset;
    ChartToolset1ZoomMouseWheelTool1: TZoomMouseWheelTool;
    ChartToolset1ZoomDragTool1: TZoomDragTool;
    ChartToolset1PanDragTool1: TPanDragTool;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormResize(Sender: TObject);
  public
    procedure ClearPreview;
    procedure AddSpot(AX, AY, ARadius: Double);
    procedure AddSubstratePoint(AX, AY: Double);
    procedure ShowPreview;
  end;

var
  PreviewForm: TPreviewForm;

implementation

{$R *.lfm}

procedure TPreviewForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:=caHide;
end;

procedure TPreviewForm.FormResize(Sender: TObject);
begin
  Chart1.Width:=Chart1.Height;
end;

procedure TPreviewForm.ClearPreview;
begin
  BS_Series.Clear;
  PS_Series.Clear;
end;

procedure TPreviewForm.AddSpot(AX, AY, ARadius: Double);
begin
  BS_Series.AddXY(AX, AY, ARadius, '', clRed);
end;

procedure TPreviewForm.AddSubstratePoint(AX, AY: Double);
begin
  PS_Series.AddXY(AX, AY, '', clBlue);
end;

procedure TPreviewForm.ShowPreview;
begin
  Chart1.ZoomFull;
  Show;
  BringToFront;
end;

end.
