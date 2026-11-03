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
  end;

// Значения по умолчанию: шаг 0.1 мм, группы по 10 с доп. шагом 0.1 мм,
// автоцентр, без ручного смещения.
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

implementation

uses
  IniFiles, OligoMatrix;

function PointFormat: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function DefaultMarkGeometry: TMarkGeometry;
begin
  Result := Default(TMarkGeometry);
  Result.Step := 0.1;
  Result.GroupStep := 0.1;
  Result.Group := 10;
  Result.AutoCenter := True;
end;

function LoadMarkGeometry(const AFileName: string): TMarkGeometry;
var
  Ini: TMemIniFile;

  function ReadNumber(const AKey: string; ADefault: Double): Double;
  var
    Text: string;
  begin
    Text := StringReplace(Trim(Ini.ReadString(GEOMETRY_SECTION, AKey, '')),
      ',', '.', []);
    if not TryStrToFloat(Text, Result, PointFormat) then
      Result := ADefault;
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
      Ini.WriteString(GEOMETRY_SECTION, 'Step',
        FloatToStr(AGeometry.Step, PointFormat));
      Ini.WriteInteger(GEOMETRY_SECTION, 'Group', AGeometry.Group);
      Ini.WriteString(GEOMETRY_SECTION, 'GroupStep',
        FloatToStr(AGeometry.GroupStep, PointFormat));
      Ini.WriteBool(GEOMETRY_SECTION, 'AutoCenter', AGeometry.AutoCenter);
      Ini.WriteString(GEOMETRY_SECTION, 'BiasX',
        FloatToStr(AGeometry.BiasX, PointFormat));
      Ini.WriteString(GEOMETRY_SECTION, 'BiasY',
        FloatToStr(AGeometry.BiasY, PointFormat));
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

end.
