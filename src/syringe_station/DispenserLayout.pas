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
  TABLE_COLUMN_GAP = 2;
  COL_NUMBER = 8;
  WIDTH_NUMBER = 18;
  COL_NAME = COL_NUMBER + WIDTH_NUMBER + TABLE_COLUMN_GAP;
  WIDTH_NAME = 30;
  COL_SELECTED = COL_NAME + WIDTH_NAME + TABLE_COLUMN_GAP;
  WIDTH_SELECTED = 40;
  COL_FILL = COL_SELECTED + WIDTH_SELECTED + TABLE_COLUMN_GAP;
  WIDTH_FILL = 72;
  COL_EMPTY = COL_FILL + WIDTH_FILL + TABLE_COLUMN_GAP;
  WIDTH_EMPTY = 78;
  COL_VALVE = COL_EMPTY + WIDTH_EMPTY + TABLE_COLUMN_GAP;
  WIDTH_VALVE = 172;
  COL_BYPASS = COL_VALVE + WIDTH_VALVE + TABLE_COLUMN_GAP;
  WIDTH_BYPASS = 44;
  COL_ASPIRATE = COL_BYPASS + WIDTH_BYPASS + TABLE_COLUMN_GAP;
  WIDTH_ASPIRATE = 65;
  COL_DISPENSE = COL_ASPIRATE + WIDTH_ASPIRATE + TABLE_COLUMN_GAP;
  WIDTH_DISPENSE = 83;
  COL_VOLUME = COL_DISPENSE + WIDTH_DISPENSE + TABLE_COLUMN_GAP;
  WIDTH_VOLUME = 76;
  COL_SPEED = COL_VOLUME + WIDTH_VOLUME + TABLE_COLUMN_GAP;
  WIDTH_SPEED = 110;
  COL_CURRENT = COL_SPEED + WIDTH_SPEED + TABLE_COLUMN_GAP;
  WIDTH_CURRENT = 120;
  COL_STOP = COL_CURRENT + WIDTH_CURRENT + TABLE_COLUMN_GAP;
  WIDTH_STOP = 54;
  COL_INITIALIZE = COL_STOP + WIDTH_STOP + TABLE_COLUMN_GAP;
  WIDTH_INITIALIZE = 60;
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

  ExtraSpace := AAvailableWidth - MAIN_WINDOW_MIN_WIDTH;
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
