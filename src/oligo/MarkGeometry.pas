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

// Добавить точку в линейный массив маркиратора
function AddPointToLinearArray(const aPoint: TPoint;
  var aLinearArray: TArrOfTPoint): Integer;

// конвертировать матрицу точек в линейный массив маркиратора
Function ConvertMatrixToLinearArray(const aMatrix: TMatrix; // конвертируемая матрица
    var aLinearArray: TArrOfTPoint;                       // линейный массив для записи матрицы
    const aStep: Double;                                  // шаг между точками в мм (одинаковый для X и Y)
    const aGroup: integer=0;                              // по скольким точкам группировать
    const aGroupStep: Double=0;                            // шаг между группами (в дополнение к шагу между точками)
    const aBiasX: Double=0;                                // смещение линейного массива по X
    const aBiasY: Double=0                                // смещение линейного массива по Y
    ): Integer;                                           // 0, если получилось, иначе 1000

// Точки маркировки матрицы с учётом шага, групп и смещения из геометрии.
function MatrixToMarkPoints(const AMatrix: TMatrix;
  const AGeometry: TMarkGeometry): TArrOfTPoint;

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

//добавляем в конец массива точку
function AddPointToLinearArray(const aPoint: TPoint;
  var aLinearArray: TArrOfTPoint): Integer;
begin
  try
    SetLength(aLinearArray, Length(aLinearArray)+1);
    aLinearArray[Length(aLinearArray)-1][0]:=aPoint[0];
    aLinearArray[Length(aLinearArray)-1][1]:=aPoint[1];
    Result:=0;
  except
    Result:=2000;
  end;
end;


function ConvertMatrixToLinearArray(const aMatrix: TMatrix; // конвертируемая матрица
    var aLinearArray: TArrOfTPoint;                       // линейный массив для записи матрицы
    const aStep: Double;                                  // шаг между точками в мм (одинаковый для X и Y)
    const aGroup: integer=0;                              // по скольким точкам группировать
    const aGroupStep: Double=0;                            // шаг между группами (в дополнение к шагу между точками)
    const aBiasX: Double=0;                                // смещение массива по X
    const aBiasY: Double=0                                // смещение массива по Y
    ): Integer;                                           // 0, если получилось, иначе 1000
var
   p: TPoint;
   i,j: integer;
begin
  try
  // очищаем линейный массив
  SetLength(aLinearArray,0);

  for i:=0 to High(aMatrix) do
  begin
    for j:=0 to High(aMatrix[i]) do
    begin
      if aMatrix[i,j]<>0 then
       begin
          if aGroup=0 then
           begin
            p[0]:=j*aStep+aBiasX;
            p[1]:=-i*aStep+aBiasY;
            AddPointToLinearArray(p,aLinearArray);
           end
          else
          begin
            p[0]:=j*aStep+aGroupStep*(j div aGroup)+aBiasX;
            p[1]:=-i*aStep-aGroupStep*(i div aGroup)+aBiasY;
            AddPointToLinearArray(p,aLinearArray);
          end;
       end;
    end;
  end;
    Result:=0;
  except
    Result:=1000;
  end;
end;

function MatrixToMarkPoints(const AMatrix: TMatrix;
  const AGeometry: TMarkGeometry): TArrOfTPoint;
var
  Bias: TPoint;
begin
  Result := nil;
  Bias := MarkBias(AMatrix, AGeometry);
  ConvertMatrixToLinearArray(AMatrix, Result, AGeometry.Step, AGeometry.Group,
    AGeometry.GroupStep, Bias[0], Bias[1]);
end;

end.
