unit OligoArray;
// Массив олигов: типы, генерация, чтение из CSV, построение слоя матрицы

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, EzCadApi;

type
  TOlig = String;

type
  TSymbolSet = array of Char;

type
  TOligoArr = array of array of TOlig;

Function GenerateOligSeq(aLength: Integer): TOlig;
Procedure CreateMatrixLayerFromOligoArr(var aOligoArr: TOligoArr;
                                        var aSymbolSet: TSymbolSet;
                                        var aMatrixLayer: TMatrix;
                                        var maxLetter: TOlig;
                                        var maxCount: Integer);
Function StringToOlig(aStr: String): TOlig;
Procedure FindUniqueSymbols(anOlig: TOlig;
                            var aSymbolSet: TSymbolSet);
Function ReadOligsFromCSVFile(var anOligoArr: TOligoArr; aFileName: String; aSeparator: String=';'): Boolean;

implementation

function GenerateOligSeq(aLength: Integer): TOlig;
// генерируем олиг с рандомной последовательностью ATGC длиной aLength
var
  i: integer;
  Olig: TOlig;
  tmpCh: Byte;
begin
  SetLength(Olig,aLength);
  for i:=1 to High(Olig) do
  begin
    tmpCh:=Random(4);
    case tmpCh of
    0: Olig[i]:='A';
    1: Olig[i]:='T';
    2: Olig[i]:='G';
    3: Olig[i]:='C';
    end;
  end;
  Result:=Olig;
end;

procedure CreateMatrixLayerFromOligoArr(
  var aOligoArr: TOligoArr; // массив олигов для создания слоя матрицы, после создания из него удаляется буква слоя
  var aSymbolSet: TSymbolSet; // буквы в массиве
  var aMatrixLayer: TMatrix; // создаваемый слой матрицы
  var maxLetter: TOlig; // буква создаваемого слоя матрицы
  var maxCount: Integer // количество букв в слое
  );
  //Создание матрицы слоя. В слое ищется наиболее частая буква. Из нее создается матрица. В массиве она удаляется
var
  i, j, k: Integer;
  tmpS: String;
  lastCh: Char;
  letterCount: array of Integer;
  lastLetters: array of TOlig;
  maxIndex: Integer;
begin
  // Инициализация массива для подсчета вхождений каждой буквы
  SetLength(letterCount, Length(aSymbolSet));
  SetLength(lastLetters, Length(aSymbolSet));

   // Обнуляем счетчики
  for k := Low(letterCount) to High(letterCount) do
    letterCount[k] := 0;

  // Подсчет последних букв и их вхождений
  for i:=0 to Length(aOligoArr)-1 do
  begin
    for j:=0 to Length(aOligoArr[i])-1 do
    begin
      tmpS:=aOligoArr[i,j]; // скопировал олиг для анализа
      if Length(tmpS)<>0 then
      lastCh:=tmpS[Length(tmpS)] //скопировал последнюю букву
      else lastCh:=' ';

      for k:=0 to Length(aSymbolSet)-1 do
      begin
        if lastCh=aSymbolSet[k] then
        begin
          lastLetters[k]:=lastCh;
          Inc(letterCount[k]);
        end;
      end;
    end;
  end;

  // Находим букву с максимальным количеством вхождений
  maxCount:= 0;
  maxIndex:= -1;
  for k:=0 to Length(letterCount)-1 do
  begin
    if letterCount[k] > maxCount then
    begin
      maxCount:= letterCount[k];
      maxIndex:= k;
    end;
  end;
  // Если найдена буква с максимальным количеством вхождений
  if maxIndex <> -1 then
  begin
    maxLetter:= lastLetters[maxIndex];


    // Создание матрицы
    SetLength(aMatrixLayer, Length(aOligoArr)); // Размер матрицы равен размеру aOligoArr
    for i:=0 to Length(aOligoArr)-1 do
    begin
      SetLength(aMatrixlayer[i],Length(aOligoArr[i]));
      for j := 0 to Length(aOligoArr[i])-1 do
      begin
        tmpS:=aOligoArr[i,j]; // скопировал олиг для анализа
        if Length(tmpS)<>0 then
        lastCh:=tmpS[Length(tmpS)] //скопировал последнюю букву
        else lastCh:=' ';
        if lastCh = maxLetter then
          begin
            aMatrixLayer[i][j]:=1;
            if Length(aOligoArr[i,j]) > 0 then
            Delete(aOligoArr[i][j],Length(aOligoArr[i][j]),1); // сразу удаляем эту последнюю букву из олига
          end
        else
          aMatrixLayer[i][j]:=0;
      end;
    end;
  end;
end;

function StringToOlig(aStr: String): TOlig;
// Строку переводим в UpperCase
begin
  Result:=UpperCase(aStr);
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
      // Проверяем, есть ли символ уже в массиве
      for j := Low(aSymbolSet) to High(aSymbolSet) do
      begin
        if aSymbolSet[j] = anOlig[i] then
        begin
          found := True;
          Break;
        end;
      end;

      // Если символ не найден, добавляем его в массив
      if not found then
      begin
        // Увеличиваем размер массива
        SetLength(aSymbolSet, Length(aSymbolSet) + 1);
        aSymbolSet[High(aSymbolSet)] := anOlig[i];
      end;
    end;
  end;

function ReadOligsFromCSVFile(var anOligoArr: TOligoArr; aFileName: String;
  aSeparator: String=';'): Boolean;
//Чтение массива олигов из CSV файла
var
  tmpArr: TOligoArr;
  S: String;
  Parts: TStringArray;
  i,j: integer;
  F: TextFile;
begin
    try
      Result:=false;
      Setlength(tmpArr,0);
      AssignFile(F, aFileName);
      Reset(F);
      while not EOF(F) do
      begin
        ReadLN(F,S);
        Parts:=S.Split(aSeparator);
        if Length(Parts)<>0 then
        begin
          SetLength(tmpArr,Length(tmpArr)+1);
          i:=Length(tmpArr)-1;
          SetLength(tmpArr[i], Length(Parts));
          for j:=0 to Length(Parts)-1 do
          begin
            tmpArr[i,j]:=StringToOlig(Parts[j]);
          end;
        end;
      end;
      SetLength(anOligoArr,Length(tmpArr));
      begin
        for i:=0 to High(tmpArr) do
        begin
          SetLength(anOligoArr[i], Length(tmpArr[i]));
          for j:=0 to High(tmpArr[i]) do
          begin
            anOligoArr[i,j]:=tmpArr[i,j];
          end;
        end;
      end;
      Result:=true;
    finally
      CloseFile(F);
    end;
end;

end.
