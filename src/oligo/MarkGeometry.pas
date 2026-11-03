unit MarkGeometry;
// Геометрия маркировки массива точек: шаг, группировка и смещение.
// Используется при создании EZD-файлов в ручном режиме и для слоёв.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, MatrixTypes;

const
  GEOMETRY_SECTION = 'Geometry';
  GEOMETRY_FILE = 'geometry.ini'; // геометрия, с которой созданы EZD слоёв

type
  TMarkGeometry = record
    Step: Double;       // шаг между точками, мм
    GroupStep: Double;  // дополнительный шаг между группами, мм
    Group: Integer;     // точек в группе (0 - без групп)
    AutoCenter: Boolean;// центрировать массив автоматически
    BiasX: Double;      // ручное смещение по X, мм
    BiasY: Double;      // ручное смещение по Y, мм
    // Диаметр пятна лазера, мкм. Его задаёт оптика и режим лазера, а не
    // программа: здесь - значение, которое вводит пользователь.
    SpotSize: Double;
    SubstrateDiameter: Double; // диаметр подложки, мм (центр - в нуле)
  end;

// Значения по умолчанию: шаг 0.1 мм, группы по 10 с доп. шагом 0.1 мм,
// автоцентр, без ручного смещения, пятно 15 мкм, подложка 20 мм.
function DefaultMarkGeometry: TMarkGeometry;
// Геометрия из раздела [Geometry] ini-файла. Нет файла, ключа или значение
// недопустимо - для этого параметра берётся значение по умолчанию.
// Дробные числа - с точкой, но запятая тоже читается.
function LoadMarkGeometry(const AFileName: string): TMarkGeometry;
// Записывает раздел [Geometry]; другие разделы файла сохраняются.
function SaveMarkGeometry(const AFileName: string;
  const AGeometry: TMarkGeometry; out AErrorText: string): Boolean;

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

// На сколько мм пятна точек (с учётом их радиуса) выходят за край
// подложки. 0 или меньше - все точки помещаются.
function SubstrateOverflow(const APoints: TArrOfTPoint;
  const AGeometry: TMarkGeometry): Double;
// Контур подложки (окружность с центром в нуле) из ACount точек.
function SubstrateOutline(const AGeometry: TMarkGeometry;
  ACount: Integer): TArrOfTPoint;

implementation

uses
  IniFiles, IniNumbers, OligoMatrix;

function DefaultMarkGeometry: TMarkGeometry;
begin
  Result := Default(TMarkGeometry);
  Result.Step := 0.1;
  Result.GroupStep := 0.1;
  Result.Group := 10;
  Result.AutoCenter := True;
  Result.SpotSize := 15;
  Result.SubstrateDiameter := 20;
end;

function LoadMarkGeometry(const AFileName: string): TMarkGeometry;
var
  Ini: TMemIniFile;

  function ReadNumber(const AKey: string; ADefault: Double): Double;
  begin
    Result := ReadIniFloat(Ini, GEOMETRY_SECTION, AKey, ADefault);
  end;

begin
  Result := DefaultMarkGeometry;
  if not FileExists(AFileName) then
    Exit;
  try
    Ini := TMemIniFile.Create(AFileName);
  except
    Exit; // файл не читается - остаются значения по умолчанию
  end;
  try
    Result.Step := ReadNumber('Step', Result.Step);
    if Result.Step <= 0 then
      Result.Step := DefaultMarkGeometry.Step;
    Result.GroupStep := ReadNumber('GroupStep', Result.GroupStep);
    if Result.GroupStep < 0 then
      Result.GroupStep := DefaultMarkGeometry.GroupStep;
    Result.Group := Ini.ReadInteger(GEOMETRY_SECTION, 'Group', Result.Group);
    if Result.Group < 0 then
      Result.Group := DefaultMarkGeometry.Group;
    Result.AutoCenter := Ini.ReadBool(GEOMETRY_SECTION, 'AutoCenter',
      Result.AutoCenter);
    Result.BiasX := ReadNumber('BiasX', Result.BiasX);
    Result.BiasY := ReadNumber('BiasY', Result.BiasY);
    Result.SpotSize := ReadNumber('SpotSize', Result.SpotSize);
    if Result.SpotSize <= 0 then
      Result.SpotSize := DefaultMarkGeometry.SpotSize;
    Result.SubstrateDiameter := ReadNumber('SubstrateDiameter',
      Result.SubstrateDiameter);
    if Result.SubstrateDiameter <= 0 then
      Result.SubstrateDiameter := DefaultMarkGeometry.SubstrateDiameter;
  finally
    Ini.Free;
  end;
end;

function SaveMarkGeometry(const AFileName: string;
  const AGeometry: TMarkGeometry; out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := False;
  AErrorText := '';
  try
    Ini := TMemIniFile.Create(AFileName);
    try
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'Step',
        AGeometry.Step);
      Ini.WriteInteger(GEOMETRY_SECTION, 'Group', AGeometry.Group);
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'GroupStep',
        AGeometry.GroupStep);
      Ini.WriteBool(GEOMETRY_SECTION, 'AutoCenter', AGeometry.AutoCenter);
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'BiasX',
        AGeometry.BiasX);
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'BiasY',
        AGeometry.BiasY);
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'SpotSize',
        AGeometry.SpotSize);
      WriteIniFloat(Ini, GEOMETRY_SECTION, 'SubstrateDiameter',
        AGeometry.SubstrateDiameter);
      Ini.UpdateFile;
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать параметры геометрии:' + LineEnding +
        AFileName + LineEnding + E.Message;
  end;
end;

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

function SubstrateOverflow(const APoints: TArrOfTPoint;
  const AGeometry: TMarkGeometry): Double;
var
  i: Integer;
  Edge: Double;
begin
  Result := -1e300;
  for i := 0 to High(APoints) do
  begin
    // дальний край пятна от центра подложки минус её радиус
    Edge := Sqrt(Sqr(APoints[i][0]) + Sqr(APoints[i][1])) +
      AGeometry.SpotSize / 2000 - AGeometry.SubstrateDiameter / 2;
    if Edge > Result then
      Result := Edge;
  end;
end;

function SubstrateOutline(const AGeometry: TMarkGeometry;
  ACount: Integer): TArrOfTPoint;
var
  i: Integer;
  Angle, Radius: Double;
begin
  Result := nil;
  SetLength(Result, ACount);
  Radius := AGeometry.SubstrateDiameter / 2;
  for i := 0 to ACount - 1 do
  begin
    Angle := 2 * Pi * i / ACount;
    Result[i][0] := Radius * Cos(Angle);
    Result[i][1] := Radius * Sin(Angle);
  end;
end;

end.
