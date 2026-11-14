unit PreviewLayoutTests;
// Тесты расчётов превью (PreviewLayout).

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, PreviewLayout;

type
  TPreviewLayoutTests = class(TTestCase)
  published
    procedure SquareInWideAreaIsCenteredHorizontally;
    procedure SquareInTallAreaIsCenteredVertically;
    procedure SquareInSquareAreaFillsIt;
    procedure OddLeftoverIsRoundedDown;
    procedure NegativeAreaGivesEmptySquare;
    procedure ZoomIsForcedOnRequest;
    procedure ZoomIsKeptWhenSubstrateIsTheSame;
    procedure ZoomIsResetWhenSubstrateChanges;
    procedure ZoomIsResetWithoutSubstrate;
  end;

implementation

procedure AssertRect(const AMessage: string; ALeft, ATop, ARight, ABottom: Integer;
  const AActual: TRect);
begin
  TTestCase.AssertEquals(AMessage + ': Left', ALeft, AActual.Left);
  TTestCase.AssertEquals(AMessage + ': Top', ATop, AActual.Top);
  TTestCase.AssertEquals(AMessage + ': Right', ARight, AActual.Right);
  TTestCase.AssertEquals(AMessage + ': Bottom', ABottom, AActual.Bottom);
end;

procedure TPreviewLayoutTests.SquareInWideAreaIsCenteredHorizontally;
begin
  // сторона 200, слева и справа по 50
  AssertRect('широкая', 50, 0, 250, 200, CenteredSquare(300, 200));
end;

procedure TPreviewLayoutTests.SquareInTallAreaIsCenteredVertically;
begin
  AssertRect('высокая', 0, 50, 200, 250, CenteredSquare(200, 300));
end;

procedure TPreviewLayoutTests.SquareInSquareAreaFillsIt;
begin
  AssertRect('квадратная', 0, 0, 200, 200, CenteredSquare(200, 200));
end;

procedure TPreviewLayoutTests.OddLeftoverIsRoundedDown;
begin
  // остаток 101 делится на 50 слева и 51 справа
  AssertRect('нечётный остаток', 50, 0, 250, 200, CenteredSquare(301, 200));
end;

procedure TPreviewLayoutTests.NegativeAreaGivesEmptySquare;
begin
  // ширина 0: сторона 0, пустой квадрат по центру высоты
  AssertRect('отрицательная ширина', 0, 100, 0, 100, CenteredSquare(-5, 200));
  AssertRect('обе отрицательные', 0, 0, 0, 0, CenteredSquare(-5, -7));
end;

procedure TPreviewLayoutTests.ZoomIsForcedOnRequest;
begin
  AssertTrue(NeedFullZoom(True, 20, 20));
end;

procedure TPreviewLayoutTests.ZoomIsKeptWhenSubstrateIsTheSame;
begin
  AssertFalse(NeedFullZoom(False, 20, 20));
end;

procedure TPreviewLayoutTests.ZoomIsResetWhenSubstrateChanges;
begin
  AssertTrue(NeedFullZoom(False, 20, 25));
end;

procedure TPreviewLayoutTests.ZoomIsResetWithoutSubstrate;
begin
  AssertTrue('подложка убрана', NeedFullZoom(False, 20, 0));
  AssertTrue('подложки не было и нет', NeedFullZoom(False, 0, 0));
end;

initialization
  RegisterTest(TPreviewLayoutTests);
end.
