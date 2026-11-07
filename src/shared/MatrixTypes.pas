unit MatrixTypes;
// Матрица точек и точки на плоскости. Отдельно от EzCadApi, чтобы логику
// массивов можно было использовать и тестировать без DLL лазера.

{$mode ObjFPC}{$H+}

interface

type
  TMatrix = array of array of Byte; // [строка][столбец]: 0 - пусто, остальное - точка
  TMatrixPoint = array [0..1] of Double;  // 0 - x, 1 - y
  TArrOfTPoint = array of TMatrixPoint;

implementation

end.
