unit MarkGeometry;
// Геометрия маркировки массива точек: шаг, группировка и смещение.
// Используется при создании EZD-файлов в ручном режиме и для слоёв.

{$mode ObjFPC}{$H+}

interface

uses
  MatrixTypes;

type
  TMarkGeometry = record
    Step: Double;       // шаг между точками, мм
    GroupStep: Double;  // дополнительный шаг между группами, мм
    Group: Integer;     // точек в группе (0 - без групп)
    AutoCenter: Boolean;// центрировать массив автоматически
    BiasX: Double;      // ручное смещение по X, мм
    BiasY: Double;      // ручное смещение по Y, мм
  end;

// Смещение массива: автоцентр по матрице или ручное из геометрии.
function MarkBias(const AMatrix: TMatrix; const AGeometry: TMarkGeometry): TPoint;

implementation

uses
  OligoMatrix;

function MarkBias(const AMatrix: TMatrix; const AGeometry: TMarkGeometry): TPoint;
begin
  if AGeometry.AutoCenter then
    Result := AutoCenterBiasMatrix(AMatrix, AGeometry.Step, AGeometry.GroupStep,
      AGeometry.Group)
  else
  begin
    Result[0] := AGeometry.BiasX;
    Result[1] := AGeometry.BiasY;
  end;
end;

end.
