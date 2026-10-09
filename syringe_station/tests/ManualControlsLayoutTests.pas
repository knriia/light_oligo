unit ManualControlsLayoutTests;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, testregistry, ManualControlsLayout;

type
  TManualControlsLayoutTests = class(TTestCase)
  published
    procedure SplitsAvailableWidthEvenlyAndKeepsStationWithinClient;
    procedure GivesOddRemainderToLaser;
    procedure StartsStationAfterTallerControl;
    procedure MovesStationUpWhenBothControlsAreCollapsed;
    procedure ClampsStationHeightWhenClientIsTooShort;
    procedure ShiftsArrayControlsUpWithoutChangingTheirSpacing;
    procedure KeepsArrayActionButtonsFivePixelsAboveTheBottom;
  end;

implementation

procedure TManualControlsLayoutTests.
  SplitsAvailableWidthEvenlyAndKeepsStationWithinClient;
var
  Layout: TManualControlsLayout;
begin
  Layout := BuildManualControlsLayout(840, 493, 168, 168);

  AssertEquals(1, Layout.ArrayBounds.Left);
  AssertEquals(1, Layout.ArrayBounds.Top);
  AssertEquals(419, Layout.ArrayBounds.Right - Layout.ArrayBounds.Left);
  AssertEquals(420, Layout.LaserBounds.Left);
  AssertEquals(419, Layout.LaserBounds.Right - Layout.LaserBounds.Left);
  AssertEquals(169, Layout.PumpStationBounds.Top);
  AssertEquals(839, Layout.PumpStationBounds.Right);
  AssertEquals(492, Layout.PumpStationBounds.Bottom);
end;

procedure TManualControlsLayoutTests.GivesOddRemainderToLaser;
var
  Layout: TManualControlsLayout;
begin
  Layout := BuildManualControlsLayout(841, 493, 168, 168);

  AssertEquals(419, Layout.ArrayBounds.Right - Layout.ArrayBounds.Left);
  AssertEquals(420, Layout.LaserBounds.Right - Layout.LaserBounds.Left);
  AssertEquals(840, Layout.PumpStationBounds.Right);
end;

procedure TManualControlsLayoutTests.StartsStationAfterTallerControl;
var
  Layout: TManualControlsLayout;
begin
  Layout := BuildManualControlsLayout(600, 400, 120, 168);

  AssertEquals(169, Layout.PumpStationBounds.Top);
  AssertEquals(399, Layout.PumpStationBounds.Bottom);
end;

procedure TManualControlsLayoutTests.MovesStationUpWhenBothControlsAreCollapsed;
var
  Layout: TManualControlsLayout;
begin
  Layout := BuildManualControlsLayout(600, 300, 19, 19);

  AssertEquals(20, Layout.PumpStationBounds.Top);
  AssertEquals(299, Layout.PumpStationBounds.Bottom);
end;

procedure TManualControlsLayoutTests.ClampsStationHeightWhenClientIsTooShort;
var
  Layout: TManualControlsLayout;
begin
  Layout := BuildManualControlsLayout(500, 100, 168, 168);

  AssertEquals(169, Layout.PumpStationBounds.Top);
  AssertEquals(169, Layout.PumpStationBounds.Bottom);
end;

procedure TManualControlsLayoutTests.
  ShiftsArrayControlsUpWithoutChangingTheirSpacing;
var
  Layout: TManualArrayVerticalLayout;
begin
  Layout := BuildManualArrayVerticalLayout(25, 155, 25, 5);

  AssertEquals(2, Layout.StepFieldTop);
  AssertEquals(6, Layout.StepLabelTop);
  AssertEquals(26, Layout.GroupFieldTop);
  AssertEquals(28, Layout.GroupLabelTop);
  AssertEquals(96, Layout.SpotSizeFieldTop);
  AssertEquals(Layout.StepFieldTop + 24, Layout.GroupFieldTop);
  AssertEquals(Layout.GroupFieldTop + 24, Layout.GroupStepFieldTop);
  AssertEquals(Layout.GroupStepFieldTop + 46, Layout.SpotSizeFieldTop);
  AssertEquals(0, Layout.AutoCenterTop);
  AssertEquals(Layout.AutoCenterTop, Layout.AutoCenterLabelTop);
  AssertEquals(26, Layout.BiasXFieldTop);
  AssertEquals(28, Layout.BiasXLabelTop);
  AssertEquals(50, Layout.BiasYFieldTop);
  AssertEquals(52, Layout.BiasYLabelTop);
  AssertEquals(74, Layout.ShowSubstrateTop);
  AssertEquals(Layout.ShowSubstrateTop, Layout.ShowSubstrateLabelTop);
  AssertEquals(96, Layout.SubstrateDiameterFieldTop);
  AssertEquals(98, Layout.SubstrateDiameterLabelTop);
end;

procedure TManualControlsLayoutTests.
  KeepsArrayActionButtonsFivePixelsAboveTheBottom;
var
  Layout: TManualArrayVerticalLayout;
begin
  Layout := BuildManualArrayVerticalLayout(25, 155, 25, 5);

  AssertEquals(125, Layout.ActionButtonTop);
  AssertEquals(5, 155 - (Layout.ActionButtonTop + 25));
end;

initialization
  RegisterTest(TManualControlsLayoutTests);

end.
