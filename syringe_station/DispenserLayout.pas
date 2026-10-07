unit DispenserLayout;

{$mode objfpc}{$H+}

interface

type
  TDispenserColumn = (
    dcNumber,
    dcName,
    dcSelected,
    dcFill,
    dcEmpty,
    dcValve,
    dcBypass,
    dcAspirate,
    dcDispense,
    dcVolume,
    dcSpeed,
    dcCurrent,
    dcStop,
    dcInitialize
  );

  TDispenserColumnLayout = record
    Left: Integer;
    Width: Integer;
  end;

  TDispenserTableLayout = record
    RowLeft: Integer;
    RowWidth: Integer;
    Columns: array[TDispenserColumn] of TDispenserColumnLayout;
  end;

const
  TABLE_ROW_LEFT = 8;
  COL_NUMBER = 8;
  WIDTH_NUMBER = 18;
  COL_NAME = 26;
  WIDTH_NAME = 80;
  COL_SELECTED = 108;
  WIDTH_SELECTED = 50;
  COL_FILL = 168;
  WIDTH_FILL = 90;
  COL_EMPTY = 268;
  WIDTH_EMPTY = 90;
  COL_VALVE = 363;
  WIDTH_VALVE = 172;
  COL_BYPASS = 535;
  WIDTH_BYPASS = 60;
  COL_ASPIRATE = 605;
  WIDTH_ASPIRATE = 85;
  COL_DISPENSE = 700;
  WIDTH_DISPENSE = 95;
  COL_VOLUME = 805;
  WIDTH_VOLUME = 120;
  COL_SPEED = 935;
  WIDTH_SPEED = 110;
  COL_CURRENT = 1055;
  WIDTH_CURRENT = 150;
  COL_STOP = 1215;
  WIDTH_STOP = 88;
  COL_INITIALIZE = 1311;
  WIDTH_INITIALIZE = 120;
  TABLE_RIGHT_MARGIN = 8;
  TABLE_SCROLLBAR_RESERVE = 20;
  TABLE_CONTENT_RIGHT = COL_INITIALIZE + WIDTH_INITIALIZE;
  MAIN_WINDOW_MIN_WIDTH = TABLE_ROW_LEFT + TABLE_CONTENT_RIGHT +
    TABLE_RIGHT_MARGIN + TABLE_SCROLLBAR_RESERVE;
  HEADER_HEIGHT = 30;
  ROW_HEIGHT = 40;
  TABLE_TOP = 8;

function BuildDispenserTableLayout(AAvailableWidth: Integer): TDispenserTableLayout;

implementation

function BuildDispenserTableLayout(AAvailableWidth: Integer): TDispenserTableLayout;
const
  BASE_LEFTS: array[TDispenserColumn] of Integer = (
    COL_NUMBER, COL_NAME, COL_SELECTED, COL_FILL, COL_EMPTY, COL_VALVE,
    COL_BYPASS, COL_ASPIRATE, COL_DISPENSE, COL_VOLUME, COL_SPEED,
    COL_CURRENT, COL_STOP, COL_INITIALIZE);
  BASE_WIDTHS: array[TDispenserColumn] of Integer = (
    WIDTH_NUMBER, WIDTH_NAME, WIDTH_SELECTED, WIDTH_FILL, WIDTH_EMPTY,
    WIDTH_VALVE, WIDTH_BYPASS, WIDTH_ASPIRATE, WIDTH_DISPENSE, WIDTH_VOLUME,
    WIDTH_SPEED, WIDTH_CURRENT, WIDTH_STOP, WIDTH_INITIALIZE);
var
  Column: TDispenserColumn;
  NextColumn: TDispenserColumn;
  BaseGap: Integer;
  ExtraSpace: Integer;
  ExtraGap: Integer;
  GapCount: Integer;
begin
  Result.RowLeft := TABLE_ROW_LEFT;
  Result.RowWidth := AAvailableWidth - TABLE_ROW_LEFT - TABLE_RIGHT_MARGIN;
  if Result.RowWidth < TABLE_CONTENT_RIGHT + TABLE_ROW_LEFT then
    Result.RowWidth := TABLE_CONTENT_RIGHT + TABLE_ROW_LEFT;

  for Column := Low(TDispenserColumn) to High(TDispenserColumn) do
  begin
    Result.Columns[Column].Left := BASE_LEFTS[Column];
    Result.Columns[Column].Width := BASE_WIDTHS[Column];
  end;

  ExtraSpace := Result.RowWidth - TABLE_ROW_LEFT - TABLE_CONTENT_RIGHT;
  if ExtraSpace <= 0 then
    Exit;

  GapCount := Ord(High(TDispenserColumn));
  for Column := Low(TDispenserColumn) to Pred(High(TDispenserColumn)) do
  begin
    NextColumn := Succ(Column);
    BaseGap := BASE_LEFTS[NextColumn] -
      (BASE_LEFTS[Column] + BASE_WIDTHS[Column]);
    ExtraGap := ExtraSpace div GapCount;
    if Ord(Column) < ExtraSpace mod GapCount then
      Inc(ExtraGap);
    Result.Columns[NextColumn].Left := Result.Columns[Column].Left +
      Result.Columns[Column].Width + BaseGap + ExtraGap;
  end;
end;

end.
