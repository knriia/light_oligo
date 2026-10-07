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

initialization
  RegisterTest(TManualControlsLayoutTests);

end.
