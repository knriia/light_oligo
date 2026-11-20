unit UiThemeTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, UiTheme, UiIconNames;

type
  TUiThemeTests = class(TTestCase)
  published
    procedure ScaleUiKeepsValueAt96Ppi;
    procedure ScaleUiScalesTo125And150Percent;
    procedure ScaleUiRoundsToNearestPixel;
    procedure ScaleUiTreatsNonPositivePpiAsBase;
    procedure IconSizeForPpiPicksSizeByWindowsScale;
    procedure IconIndexFollowsListOrder;
    procedure IconIndexReturnsMinusOneForUnknownName;
    procedure IconIndexOfEveryNameMatchesItsPosition;
    procedure IconCountMatchesList;
    procedure IconsDirBuildsSizeFolderWithTrailingDelimiter;
    procedure IconsDirDoesNotDoubleDelimiter;
    procedure IconsDirDefaultsToIconsNextToExe;
    procedure IconNamesAreUnique;
    procedure EveryIconHasPngInEverySize;
  end;

implementation

procedure TUiThemeTests.ScaleUiKeepsValueAt96Ppi;
begin
  AssertEquals(8, ScaleUi(8, 96));
  AssertEquals(4, ScaleUi(4, 96));
  AssertEquals(16, ScaleUi(16, 96));
  AssertEquals(0, ScaleUi(0, 96));
end;

procedure TUiThemeTests.ScaleUiScalesTo125And150Percent;
begin
  AssertEquals(10, ScaleUi(8, 120));
  AssertEquals(12, ScaleUi(8, 144));
  AssertEquals(16, ScaleUi(8, 192));
end;

procedure TUiThemeTests.ScaleUiRoundsToNearestPixel;
begin
  // 4 * 120 / 96 = 5; 3 * 120 / 96 = 3.75 -> 4; 5 * 120 / 96 = 6.25 -> 6
  AssertEquals(5, ScaleUi(4, 120));
  AssertEquals(4, ScaleUi(3, 120));
  AssertEquals(6, ScaleUi(5, 120));
end;

procedure TUiThemeTests.ScaleUiTreatsNonPositivePpiAsBase;
begin
  AssertEquals(8, ScaleUi(8, 0));
  AssertEquals(8, ScaleUi(8, -1));
end;

procedure TUiThemeTests.IconSizeForPpiPicksSizeByWindowsScale;
begin
  AssertEquals('100%', 16, IconSizeForPpi(96));
  AssertEquals('до 125%', 16, IconSizeForPpi(119));
  AssertEquals('125%', 24, IconSizeForPpi(120));
  AssertEquals('150%', 24, IconSizeForPpi(144));
  AssertEquals('до 200%', 24, IconSizeForPpi(167));
  AssertEquals('от 168', 32, IconSizeForPpi(168));
  AssertEquals('200%', 32, IconSizeForPpi(192));
  AssertEquals('ниже 100%', 16, IconSizeForPpi(72));
end;

procedure TUiThemeTests.IconIndexFollowsListOrder;
begin
  AssertEquals(0, IconIndex('new'));
  AssertEquals(5, IconIndex('add'));
  AssertEquals(22, IconIndex('project_open'));
end;

procedure TUiThemeTests.IconIndexReturnsMinusOneForUnknownName;
begin
  AssertEquals(-1, IconIndex('no_such_icon'));
end;

procedure TUiThemeTests.IconIndexOfEveryNameMatchesItsPosition;
var
  I: Integer;
begin
  for I := Low(ICON_ALL) to High(ICON_ALL) do
    AssertEquals(ICON_ALL[I], I, IconIndex(ICON_ALL[I]));
end;

procedure TUiThemeTests.IconCountMatchesList;
begin
  AssertEquals(23, ICON_COUNT);
  AssertEquals(23, Length(ICON_ALL));
end;

procedure TUiThemeTests.IconsDirBuildsSizeFolderWithTrailingDelimiter;
begin
  AssertEquals('C:\x\16\', IconsDir(16, 'C:\x'));
  AssertEquals('C:\x\32\', IconsDir(32, 'C:\x'));
end;

procedure TUiThemeTests.IconsDirDoesNotDoubleDelimiter;
begin
  AssertEquals('C:\x\24\', IconsDir(24, 'C:\x\'));
end;

procedure TUiThemeTests.IconsDirDefaultsToIconsNextToExe;
begin
  AssertEquals(ExtractFilePath(ExpandFileName(ParamStr(0))) + 'icons\16\',
    IconsDir(16));
end;

procedure TUiThemeTests.IconNamesAreUnique;
var
  I, J: Integer;
begin
  for I := Low(ICON_ALL) to High(ICON_ALL) do
    for J := I + 1 to High(ICON_ALL) do
      AssertTrue(ICON_ALL[I] + ' повторяется', ICON_ALL[I] <> ICON_ALL[J]);
end;

procedure TUiThemeTests.EveryIconHasPngInEverySize;
const
  SIZES: array[0..2] of Integer = (16, 24, 32);
  // у PNG после 8 байт сигнатуры и 8 байт заголовка IHDR: ширина и высота,
  // по 4 байта, старший байт первым
  WIDTH_OFFSET = 16;
var
  Root, FileName: string;
  I, S: Integer;
  Stream: TFileStream;
  Header: array[0..23] of Byte;
  Width, Height: Cardinal;
begin
  // тесты запускаются из srcplatform	ests; значки лежат в <корень>binicons
  Root := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
    '..' + PathDelim + '..' + PathDelim + 'bin' + PathDelim + 'icons');
  for S := Low(SIZES) to High(SIZES) do
    for I := Low(ICON_ALL) to High(ICON_ALL) do
    begin
      FileName := IconsDir(SIZES[S], Root) + ICON_ALL[I] + '.png';
      AssertTrue('нет файла ' + FileName, FileExists(FileName));
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        AssertEquals('короткий файл ' + FileName, SizeOf(Header),
          Stream.Read(Header, SizeOf(Header)));
      finally
        Stream.Free;
      end;
      AssertEquals('не PNG ' + FileName, $89, Header[0]);
      AssertEquals('не PNG ' + FileName, Ord('P'), Header[1]);
      Width := (Cardinal(Header[WIDTH_OFFSET]) shl 24) or
        (Cardinal(Header[WIDTH_OFFSET + 1]) shl 16) or
        (Cardinal(Header[WIDTH_OFFSET + 2]) shl 8) or Header[WIDTH_OFFSET + 3];
      Height := (Cardinal(Header[WIDTH_OFFSET + 4]) shl 24) or
        (Cardinal(Header[WIDTH_OFFSET + 5]) shl 16) or
        (Cardinal(Header[WIDTH_OFFSET + 6]) shl 8) or Header[WIDTH_OFFSET + 7];
      AssertEquals('ширина ' + FileName, SIZES[S], Integer(Width));
      AssertEquals('высота ' + FileName, SIZES[S], Integer(Height));
    end;
end;

initialization
  RegisterTest(TUiThemeTests);

end.
