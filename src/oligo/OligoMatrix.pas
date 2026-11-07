unit OligoMatrix;
// Матрица точек: копирование, центрирование, текстовый формат файла.
//
// Формат файла матрицы:
//   первая строка - "<столбцов> <строк>";
//   далее по строке на каждую строку матрицы, значения через пробел.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes;

Procedure CopyMatrix(aDonorMatrix: TMatrix;
                     var aAcceptorMatrix: TMatrix);
Function AutoCenterBiasMatrix(aMatrix: TMatrix;
                              aStep: Double;
                              aGStep: Double;
                              aGroup: Integer): TMatrixPoint;

// Текст файла матрицы. Для пустой матрицы - пустая строка.
function FormatMatrixText(const aMatrix: TMatrix): string;
// Разбор текста файла матрицы. Все строки матрицы должны быть полными.
function ParseMatrixText(const aText: string; out aMatrix: TMatrix;
  out aErrorText: string): Boolean;

Function SaveMatrixAsFile(aMatrix: TMatrix;
                          aFName: String): boolean;
Function ReadMatrixFromFile(const filename: string;
                            var aMatrix: TMatrix): Boolean;
// То же с текстом ошибки. Матрица без единой строки - тоже ошибка.
// При ошибке aMatrix не меняется.
function LoadMatrixFile(const AFileName: string; var AMatrix: TMatrix;
  out AErrorText: string): Boolean;
// Новый размер матрицы: значения, попавшие в новый размер, сохраняются,
// новые ячейки - нули.
procedure ResizeMatrix(var AMatrix: TMatrix; ARows, ACols: Integer);

implementation

uses
  TextFileUtils;

procedure CopyMatrix(aDonorMatrix: TMatrix; var aAcceptorMatrix: TMatrix);
// копирование матрицы донора в матрицу акцептора
var
  i,j: integer;
begin
  SetLength(aAcceptorMatrix, Length(aDonorMatrix));
  for i:=0 to High(aDonorMatrix) do
  begin
    SetLength(aAcceptorMatrix[i], Length(aDonorMatrix[i]));
    for j:=0 to High(aDonorMatrix[i]) do
      aAcceptorMatrix[i][j]:=aDonorMatrix[i][j];
  end;
end;

function AutoCenterBiasMatrix(aMatrix: TMatrix; aStep: Double; aGStep: Double;
  aGroup: Integer): TMatrixPoint;
// Определение смещения для центрирования матрицы с учетом шага, группировки и шага группы.
// Для пустой матрицы смещение нулевое.
var
  BX, BY: Double;
begin
  Result[0]:=0;
  Result[1]:=0;
  if (Length(aMatrix)=0) or (Length(aMatrix[High(aMatrix)])=0) then
    Exit;
  if aGroup<>0 then
    begin
      BY:=-(-High(aMatrix)*aStep-aGStep*(High(aMatrix) div aGroup))/2;
      BX:=(-High(aMatrix[High(aMatrix)])*aStep-aGStep*(High(aMatrix[High(aMatrix)]) div aGroup))/2;
    end
  else
    begin
      BY:=-(-High(aMatrix)*aStep)/2;
      BX:=(-High(aMatrix[High(aMatrix)])*aStep)/2;
    end;
  Result[0]:=BX;
  Result[1]:=BY;
end;

function FormatMatrixText(const aMatrix: TMatrix): string;
var
  i,j: integer;
  Lines: TStringList;
  Line: String;
begin
  Result:='';
  if Length(aMatrix)=0 then
    Exit;
  Lines:=TStringList.Create;
  try
    // число столбцов берётся по последней строке, как и раньше
    Lines.Add(IntToStr(Length(aMatrix[High(aMatrix)]))+' '+IntToStr(Length(aMatrix)));
    for i:=0 to High(aMatrix) do
    begin
      Line:='';
      for j:=0 to High(aMatrix[i]) do
        Line:=Line+' '+IntToStr(aMatrix[i][j]);
      Lines.Add(Line);
    end;
    Result:=Lines.Text;
  finally
    Lines.Free;
  end;
end;

function ParseMatrixText(const aText: string; out aMatrix: TMatrix;
  out aErrorText: string): Boolean;
var
  Tokens: TStringArray;
  Values: array of Integer;
  Count, i, j, k, Value: Integer;
  Cols, Rows: Integer;
begin
  Result:=false;
  aMatrix:=nil;
  aErrorText:='';

  // все числа файла подряд: столбцы, строки, затем значения по строкам
  Tokens:=aText.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty);
  SetLength(Values, Length(Tokens));
  Count:=0;
  for i:=0 to High(Tokens) do
  begin
    if not TryStrToInt(Tokens[i], Value) then
    begin
      aErrorText:='Не число: "'+Tokens[i]+'".';
      Exit;
    end;
    Values[Count]:=Value;
    Inc(Count);
  end;

  if Count<2 then
  begin
    aErrorText:='Нет размеров матрицы.';
    Exit;
  end;
  Cols:=Values[0];
  Rows:=Values[1];
  if (Cols<=0) or (Rows<=0) then
  begin
    aErrorText:='Неверные размеры матрицы: '+IntToStr(Cols)+' x '+IntToStr(Rows)+'.';
    Exit;
  end;
  if Count-2<>Cols*Rows then
  begin
    aErrorText:='Ожидалось значений: '+IntToStr(Cols*Rows)+', в файле: '+
      IntToStr(Count-2)+'.';
    Exit;
  end;

  SetLength(aMatrix, Rows);
  k:=2;
  for i:=0 to Rows-1 do
  begin
    SetLength(aMatrix[i], Cols);
    for j:=0 to Cols-1 do
    begin
      if (Values[k]<0) or (Values[k]>255) then
      begin
        aErrorText:='Значение вне диапазона 0..255: '+IntToStr(Values[k])+'.';
        aMatrix:=nil;
        Exit;
      end;
      aMatrix[i][j]:=Values[k];
      Inc(k);
    end;
  end;
  Result:=true;
end;

function SaveMatrixAsFile(aMatrix: TMatrix; aFName: String): boolean;
// Сохраняем матрицу слоя в файл. Пустая матрица не сохраняется.
var
  ErrorText: String;
begin
  Result:=false;
  if Length(aMatrix)=0 then
    Exit;
  Result:=WriteUtf8TextFile(aFName, FormatMatrixText(aMatrix), ErrorText);
end;

function ReadMatrixFromFile(const filename: string;
  var aMatrix: TMatrix): Boolean;
// Чтение матрицы из файла. При ошибке aMatrix не меняется.
var
  Text: UTF8String;
  ErrorText: String;
  Matrix: TMatrix;
begin
  Result:=ReadUtf8TextFile(filename, Text, ErrorText) and
          ParseMatrixText(Text, Matrix, ErrorText);
  if Result then
    aMatrix:=Matrix;
end;

function LoadMatrixFile(const AFileName: string; var AMatrix: TMatrix;
  out AErrorText: string): Boolean;
var
  Text: UTF8String;
  Matrix: TMatrix;
begin
  Matrix:=nil;
  Result:=ReadUtf8TextFile(AFileName, Text, AErrorText) and
          ParseMatrixText(Text, Matrix, AErrorText);
  if Result and ((Length(Matrix)=0) or (Length(Matrix[0])=0)) then
  begin
    Result:=False;
    AErrorText:='В файле нет ни одной строки матрицы.';
  end;
  if Result then
    AMatrix:=Matrix;
end;

procedure ResizeMatrix(var AMatrix: TMatrix; ARows, ACols: Integer);
var
  i, j, OldCols: Integer;
begin
  if ARows<0 then
    ARows:=0;
  if ACols<0 then
    ACols:=0;
  SetLength(AMatrix, ARows);
  for i:=0 to High(AMatrix) do
  begin
    OldCols:=Length(AMatrix[i]);
    SetLength(AMatrix[i], ACols);
    for j:=OldCols to ACols-1 do
      AMatrix[i][j]:=0;
  end;
end;

end.
