unit ManualControlsLayout;

{$mode objfpc}{$H+}

interface

uses
  Types;

type
  TManualControlsLayout = record
    ArrayBounds: TRect;
    LaserBounds: TRect;
    PumpStationBounds: TRect;
  end;

function BuildManualControlsLayout(AClientWidth, AClientHeight,
  AArrayHeight, ALaserHeight: Integer): TManualControlsLayout;

implementation

function BuildManualControlsLayout(AClientWidth, AClientHeight,
  AArrayHeight, ALaserHeight: Integer): TManualControlsLayout;
var
  ContentWidth: Integer;
  ArrayWidth: Integer;
  LaserWidth: Integer;
  ArrayHeight: Integer;
  LaserHeight: Integer;
  TopRowHeight: Integer;
  StationTop: Integer;
  StationHeight: Integer;
begin
  ContentWidth := AClientWidth - 2;
  if ContentWidth < 0 then
    ContentWidth := 0;

  ArrayWidth := ContentWidth div 2;
  LaserWidth := ContentWidth - ArrayWidth;

  ArrayHeight := AArrayHeight;
  if ArrayHeight < 0 then
    ArrayHeight := 0;
  LaserHeight := ALaserHeight;
  if LaserHeight < 0 then
    LaserHeight := 0;

  Result.ArrayBounds := Rect(1, 1, 1 + ArrayWidth, 1 + ArrayHeight);
  Result.LaserBounds := Rect(1 + ArrayWidth, 1,
    1 + ArrayWidth + LaserWidth, 1 + LaserHeight);

  TopRowHeight := ArrayHeight;
  if LaserHeight > TopRowHeight then
    TopRowHeight := LaserHeight;

  StationTop := 1 + TopRowHeight;
  StationHeight := AClientHeight - StationTop - 1;
  if StationHeight < 0 then
    StationHeight := 0;

  Result.PumpStationBounds := Rect(1, StationTop,
    1 + ContentWidth, StationTop + StationHeight);
end;

end.
