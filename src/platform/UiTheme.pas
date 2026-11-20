unit UiTheme;
// Единый стиль окон: шрифт и отступы. Цвета и тёмная тема сюда не входят.
// Размеры отступов заданы для 100% масштаба (96 dpi); для текущего экрана
// их пересчитывает ScaleUi. Отступы и ScaleUi - задел для новых форм,
// пока их никто не использует.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

const
  UI_FONT_NAME = 'Segoe UI';
  UI_FONT_SIZE = 9;           // пунктов

  UI_BASE_PPI = 96;

  // Отступы в пикселях при 100%.
  UI_GAP_SMALL = 4;           // между близкими элементами
  UI_GAP = 8;                 // между элементами и от края окна диалога
  UI_GAP_LARGE = 16;          // между группами

  // Размеры значков в пикселях и dpi, с которого берётся средний и большой.
  UI_ICON_SIZE_SMALL = 16;    // 100% (до UI_ICON_DPI_MEDIUM)
  UI_ICON_SIZE_MEDIUM = 24;   // 125% и 150%
  UI_ICON_SIZE_LARGE = 32;    // 200% и выше
  UI_ICON_DPI_MEDIUM = 120;
  UI_ICON_DPI_LARGE = 168;

// Пересчёт размера из пикселей при 100% в пиксели при APpi (AValue >= 0);
// округление до ближайшего пикселя. APpi <= 0 считается как 96.
function ScaleUi(AValue, APpi: Integer): Integer;
// Размер значков для APpi: 16, 24 или 32.
function IconSizeForPpi(APpi: Integer): Integer;

implementation

function ScaleUi(AValue, APpi: Integer): Integer;
begin
  if APpi <= 0 then
    APpi := UI_BASE_PPI;
  Result := (AValue * APpi + UI_BASE_PPI div 2) div UI_BASE_PPI;
end;

function IconSizeForPpi(APpi: Integer): Integer;
begin
  if APpi >= UI_ICON_DPI_LARGE then
    Result := UI_ICON_SIZE_LARGE
  else if APpi >= UI_ICON_DPI_MEDIUM then
    Result := UI_ICON_SIZE_MEDIUM
  else
    Result := UI_ICON_SIZE_SMALL;
end;

end.
