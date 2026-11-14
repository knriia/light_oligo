unit PreviewLayout;
// Расчёты превью массива на подложке без визуальных зависимостей:
// где поставить квадратный чарт и когда подгонять масштаб под все данные.

{$mode ObjFPC}{$H+}

interface

uses
  Types;

// Квадрат со стороной в меньшую из сторон AWidth x AHeight по центру области.
// Отрицательные размеры считаются нулевыми.
function CenteredSquare(AWidth, AHeight: Integer): TRect;

// Нужно ли показать всё нарисованное целиком (сбросить масштаб пользователя):
// AForce - принудительно; сменился диаметр подложки; подложки нет (0) -
// границы данных задают только точки массива.
function NeedFullZoom(AForce: Boolean; APrevDiameter, ADiameter: Double): Boolean;

implementation

function CenteredSquare(AWidth, AHeight: Integer): TRect;
var
  Side: Integer;
begin
  if AWidth < 0 then
    AWidth := 0;
  if AHeight < 0 then
    AHeight := 0;
  Side := AWidth;
  if AHeight < Side then
    Side := AHeight;
  Result.Left := (AWidth - Side) div 2;
  Result.Top := (AHeight - Side) div 2;
  Result.Right := Result.Left + Side;
  Result.Bottom := Result.Top + Side;
end;

function NeedFullZoom(AForce: Boolean; APrevDiameter, ADiameter: Double): Boolean;
begin
  Result := AForce or (ADiameter <> APrevDiameter) or (ADiameter <= 0);
end;

end.
