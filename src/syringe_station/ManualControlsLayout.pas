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

  TManualArrayVerticalLayout = record
    StepFieldTop: Integer;
    StepLabelTop: Integer;
    GroupFieldTop: Integer;
    GroupLabelTop: Integer;
    GroupStepFieldTop: Integer;
    GroupStepLabelTop: Integer;
    SpotSizeFieldTop: Integer;
    SpotSizeLabelTop: Integer;
    AutoCenterTop: Integer;
    AutoCenterLabelTop: Integer;
    BiasXFieldTop: Integer;
    BiasXLabelTop: Integer;
    BiasYFieldTop: Integer;
    BiasYLabelTop: Integer;
    ShowSubstrateTop: Integer;
    ShowSubstrateLabelTop: Integer;
    SubstrateDiameterFieldTop: Integer;
    SubstrateDiameterLabelTop: Integer;
    ActionButtonTop: Integer;
  end;

function BuildManualControlsLayout(AClientWidth, AClientHeight,
  AArrayHeight, ALaserHeight: Integer): TManualControlsLayout;
function BuildManualArrayVerticalLayout(AVerticalShift, AGroupClientHeight,
  AActionButtonHeight, AActionButtonBottomMargin: Integer):
  TManualArrayVerticalLayout;

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

function BuildManualArrayVerticalLayout(AVerticalShift, AGroupClientHeight,
  AActionButtonHeight, AActionButtonBottomMargin: Integer):
  TManualArrayVerticalLayout;
begin
  Result.StepFieldTop := 27 - AVerticalShift;
  Result.StepLabelTop := 31 - AVerticalShift;
  Result.GroupFieldTop := 51 - AVerticalShift;
  Result.GroupLabelTop := 53 - AVerticalShift;
  Result.GroupStepFieldTop := 75 - AVerticalShift;
  Result.GroupStepLabelTop := 77 - AVerticalShift;
  Result.SpotSizeFieldTop := 121 - AVerticalShift;
  Result.SpotSizeLabelTop := 121 - AVerticalShift;
  Result.AutoCenterTop := 25 - AVerticalShift;
  Result.AutoCenterLabelTop := 25 - AVerticalShift;
  Result.BiasXFieldTop := 51 - AVerticalShift;
  Result.BiasXLabelTop := 53 - AVerticalShift;
  Result.BiasYFieldTop := 75 - AVerticalShift;
  Result.BiasYLabelTop := 77 - AVerticalShift;
  Result.ShowSubstrateTop := 99 - AVerticalShift;
  Result.ShowSubstrateLabelTop := 99 - AVerticalShift;
  Result.SubstrateDiameterFieldTop := 121 - AVerticalShift;
  Result.SubstrateDiameterLabelTop := 123 - AVerticalShift;

  Result.ActionButtonTop := AGroupClientHeight - AActionButtonHeight -
    AActionButtonBottomMargin;
  if Result.ActionButtonTop < 0 then
    Result.ActionButtonTop := 0;
end;

end.
