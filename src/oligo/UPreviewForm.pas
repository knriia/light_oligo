unit UPreviewForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, Graphics, TAGraph, TASeries,
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
  private
    FCenterChart: Boolean;
    procedure SetCenterChart(AValue: Boolean);
  public
    procedure ClearPreview;
    procedure AddSpot(AX, AY, ARadius: Double);
    procedure AddSubstratePoint(AX, AY: Double);
    // Показать всё нарисованное целиком; окно не показывается и не
    // выдвигается - для превью, встроенного в другое окно.
    procedure ZoomFull;
    procedure ShowPreview;
    // True - квадратный чарт стоит по центру окна и занимает его меньшую
    // сторону (для превью, встроенного в растягиваемое окно). По умолчанию
    // False: квадрат прижат к левому краю, его сторона - высота окна.
    property CenterChart: Boolean read FCenterChart write SetCenterChart;
  end;

var
  PreviewForm: TPreviewForm;

implementation

uses
  PreviewLayout;

{$R *.lfm}

procedure TPreviewForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:=caHide;
end;

procedure TPreviewForm.FormResize(Sender: TObject);
var
  Square: TRect;
begin
  if FCenterChart then
  begin
    Square:=CenteredSquare(ClientWidth, ClientHeight);
    Chart1.SetBounds(Square.Left, Square.Top, Square.Right-Square.Left,
      Square.Bottom-Square.Top);
  end
  else
    Chart1.Width:=Chart1.Height;
end;

procedure TPreviewForm.SetCenterChart(AValue: Boolean);
begin
  if FCenterChart=AValue then
    Exit;
  FCenterChart:=AValue;
  if FCenterChart then
    Chart1.Align:=alNone
  else
    Chart1.Align:=alLeft;
  FormResize(Self);
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

procedure TPreviewForm.ZoomFull;
begin
  Chart1.ZoomFull;
end;

procedure TPreviewForm.ShowPreview;
begin
  Chart1.ZoomFull;
  Show;
  BringToFront;
end;

end.
