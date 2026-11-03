unit OligoArray;
// Массив олигов: типы, создание, набор букв, построение слоя матрицы

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes;

type
  TOlig = String;
  TSymbolSet = array of Char;
  TOligoArr = array of array of TOlig; // [строка][столбец]

  // способ заполнения нового массива
  TOligoFill = (ofEmpty, ofRandom, ofConstant);

Function GenerateOligSeq(aLength: Integer): TOlig;
Function StringToOlig(aStr: String): TOlig;

// Новый массив aRows x aCols: пустой, случайные олиги длины aRandomLength
// или везде одна последовательность aConstSeq.
function CreateOligoArray(aRows, aCols: Integer; aFill: TOligoFill;
  aRandomLength: Integer; const aConstSeq: String): TOligoArr;
function CopyOligoArray(const aArr: TOligoArr): TOligoArr;
// Матрица занятых ячеек: 1 - в ячейке есть олиг, 0 - пустая.
// Это все позиции, которые будут маркироваться хотя бы в одном слое.
function OccupiedCellsMatrix(const aArr: TOligoArr): TMatrix;

Procedure FindUniqueSymbols(anOlig: TOlig;
                            var aSymbolSet: TSymbolSet);
// Все буквы массива в порядке первого появления.
function CollectSymbols(const aArr: TOligoArr): TSymbolSet;
// Буквы набора одной строкой, например 'ATGC'.
function SymbolsToString(const aSymbols: TSymbolSet): String;

Procedure CreateMatrixLayerFromOligoArr(var aOligoArr: TOligoArr;
                                        var aSymbolSet: TSymbolSet;
                                        var aMatrixLayer: TMatrix;
                                        var maxLetter: TOlig;
                                        var maxCount: Integer);

implementation

function GenerateOligSeq(aLength: Integer): TOlig;
// олиг со случайной последовательностью ATGC длиной aLength
const
  Letters: array[0..3] of Char = ('A', 'T', 'G', 'C');
var
  i: integer;
begin
  Result:='';
  if aLength<=0 then
    Exit;
  SetLength(Result, aLength);
  for i:=1 to aLength do
    Result[i]:=Letters[Random(4)];
end;

function StringToOlig(aStr: String): TOlig;
// Строку переводим в UpperCase
begin
  Result:=UpperCase(aStr);
end;

function CreateOligoArray(aRows, aCols: Integer; aFill: TOligoFill;
  aRandomLength: Integer; const aConstSeq: String): TOligoArr;
var
  i,j: integer;
begin
  Result:=nil;
  if (aRows<=0) or (aCols<=0) then
    Exit;
  SetLength(Result, aRows);
  for i:=0 to aRows-1 do
  begin
    SetLength(Result[i], aCols);
    for j:=0 to aCols-1 do
      case aFill of
        ofEmpty: Result[i,j]:='';
        ofRandom: Result[i,j]:=GenerateOligSeq(aRandomLength);
        ofConstant: Result[i,j]:=StringToOlig(aConstSeq);
      end;
  end;
end;

function CopyOligoArray(const aArr: TOligoArr): TOligoArr;
var
  i,j: integer;
begin
  SetLength(Result, Length(aArr));
  for i:=0 to High(aArr) do
  begin
    SetLength(Result[i], Length(aArr[i]));
    for j:=0 to High(aArr[i]) do
      Result[i,j]:=aArr[i,j];
  end;
end;

procedure FindUniqueSymbols(anOlig: TOlig; var aSymbolSet: TSymbolSet);
// Находятся символы в anOlig и добавляются в массив aSymbolSet.
var
  i, j: Integer;
  found: Boolean;
begin
  for i := 1 to Length(anOlig) do
  begin
    found := False;
    for j := Low(aSymbolSet) to High(aSymbolSet) do
      if aSymbolSet[j] = anOlig[i] then
      begin
        found := True;
        Break;
      end;
    if not found then
    begin
      SetLength(aSymbolSet, Length(aSymbolSet) + 1);
      aSymbolSet[High(aSymbolSet)] := anOlig[i];
    end;
  end;
end;

function OccupiedCellsMatrix(const aArr: TOligoArr): TMatrix;
var
  i, j: Integer;
begin
  Result:=nil;
  SetLength(Result, Length(aArr));
  for i:=0 to High(aArr) do
  begin
    SetLength(Result[i], Length(aArr[i]));
    for j:=0 to High(aArr[i]) do
      if aArr[i,j]<>'' then
        Result[i,j]:=1
      else
        Result[i,j]:=0;
  end;
end;

function CollectSymbols(const aArr: TOligoArr): TSymbolSet;
var
  i,j: integer;
begin
  Result:=nil;
  for i:=0 to High(aArr) do
    for j:=0 to High(aArr[i]) do
      FindUniqueSymbols(aArr[i,j], Result);
end;

function SymbolsToString(const aSymbols: TSymbolSet): String;
var
  i: integer;
begin
  SetLength(Result, Length(aSymbols));
  for i:=0 to High(aSymbols) do
    Result[i+1]:=aSymbols[i];
end;

procedure CreateMatrixLayerFromOligoArr(
  var aOligoArr: TOligoArr; // массив олигов для создания слоя матрицы, после создания из него удаляется буква слоя
  var aSymbolSet: TSymbolSet; // буквы в массиве
  var aMatrixLayer: TMatrix; // создаваемый слой матрицы
  var maxLetter: TOlig; // буква создаваемого слоя матрицы
  var maxCount: Integer // количество букв в слое
  );
// Создание матрицы слоя. Среди последних букв олигов ищется самая частая
// (при равенстве - та, что раньше в aSymbolSet). Из неё создаётся матрица,
// а в массиве эта последняя буква удаляется.
var
  i, j, k: Integer;
  lastCh: Char;
  letterCount: array of Integer;
  maxIndex: Integer;

  function LastChar(const aOlig: TOlig): Char;
  begin
    if Length(aOlig)<>0 then
      Result:=aOlig[Length(aOlig)]
    else
      Result:=' ';
  end;

begin
  SetLength(letterCount, Length(aSymbolSet));
  for k := Low(letterCount) to High(letterCount) do
    letterCount[k] := 0;

  // подсчёт последних букв
  for i:=0 to High(aOligoArr) do
    for j:=0 to High(aOligoArr[i]) do
    begin
      lastCh:=LastChar(aOligoArr[i,j]);
      for k:=0 to High(aSymbolSet) do
        if lastCh=aSymbolSet[k] then
          Inc(letterCount[k]);
    end;

  // буква с максимальным количеством вхождений
  maxCount:= 0;
  maxIndex:= -1;
  for k:=0 to High(letterCount) do
    if letterCount[k] > maxCount then
    begin
      maxCount:= letterCount[k];
      maxIndex:= k;
    end;
  if maxIndex = -1 then
    Exit;

  maxLetter:= aSymbolSet[maxIndex];

  // матрица слоя того же размера, что и массив
  SetLength(aMatrixLayer, Length(aOligoArr));
  for i:=0 to High(aOligoArr) do
  begin
    SetLength(aMatrixlayer[i],Length(aOligoArr[i]));
    for j := 0 to High(aOligoArr[i]) do
      if LastChar(aOligoArr[i,j]) = maxLetter then
      begin
        aMatrixLayer[i][j]:=1;
        Delete(aOligoArr[i][j],Length(aOligoArr[i][j]),1);
      end
      else
        aMatrixLayer[i][j]:=0;
  end;
end;

end.
