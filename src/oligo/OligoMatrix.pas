unit OligoMatrix;
// Матрица точек: копирование, центрирование, чтение и запись в файл

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, EzCadApi;

Procedure CopyMatrix(aDonorMatrix: TMatrix;
                     var aAcceptorMatrix: TMatrix);
Function AutoCenterBiasMatrix(aMatrix: TMatrix;
                              aStep: Double;
                              aGStep: Double;
                              aGroup: Integer): TPoint;
Function SaveMatrixAsFile(aMatrix: TMatrix;
                          aFName: String): boolean;
Function ReadMatrixFromFile(const filename: string;
                            var aMatrix: TMatrix): Boolean;

implementation

procedure CopyMatrix(aDonorMatrix: TMatrix; var aAcceptorMatrix: TMatrix);
// копирование матрицы донора в матрицу акцептора
var
  i,j: integer;
begin
  // устанавливаем размеры матрицы
  SetLength(aAcceptorMatrix, Length(ADonorMatrix));
  for i:=0 to Length(ADonorMatrix)-1 do
    SetLength(aAcceptorMatrix[i], Length(aDonorMatrix[i]));

  // копируем элементы из донор-матрицы в акцептор-матрицу
  for i:=0 to High(ADonorMatrix) do
  begin
   for j:=0 to High(ADonorMatrix[i]) do
     aAcceptorMatrix[i][j]:=aDonorMatrix[i][j];
  end;
 end;

function AutoCenterBiasMatrix(aMatrix: TMatrix; aStep: Double; aGStep: Double;
  aGroup: Integer): TPoint;
// Определение смещения для центрирования матрицы с учетом шага, группировки и шага группы
var
  BX, BY: Double;
begin
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

function SaveMatrixAsFile(aMatrix: TMatrix; aFName: String): boolean;
// Сохраняем матрицу слоя в файл
var
  i,j: integer;
  f: TextFile;
  Col, Row: Integer;
  TmpS: String;
begin
try
  AssignFile(f, aFName);
  {$I-}
  Rewrite(f);
  {$I+}
  Result:=false;
  Row:=Length(aMatrix);
  if Row<>0 then
  begin
    Col:=Length(aMatrix[Row-1]);
    tmpS:=IntToStr(Col)+' '+IntToStr(Row);
    WriteLN(f,TmpS);
    for i:=0 to Length(aMatrix)-1 do
    begin
      TmpS:='';
      for j:=0 to Length(aMAtrix[i])-1 do
      begin
        TmpS:=TmpS+' '+IntToStr(aMatrix[i][j]);
      end;
      WriteLN(f,TmpS);
    end;
    Result:=true;
  end;
finally
  CloseFile(f);
end;
end;

function ReadMatrixFromFile(const filename: string;
  var aMatrix: TMatrix): Boolean;
// Чтение матрицы из файла
// В первой строке файла должно быть указано количество столбцов и строк
var
  f: TextFile;
  i, j, Nx, Ny: Integer;
    ch: Char;
begin
  Result := False;
    try
      // Открываем файл для чтения
      AssignFile(f, filename);
      Reset(f);
      try
       if not Eof(f) then
        // Читаем первую строку с размерами
       begin
         Nx:=0;
         while not Eof(f) and not Eoln(f) do
          begin
            Read(f, ch);
            if ch = ' ' then Break; // Конец первого числа
            if (ch >= '0') and (ch <= '9') then
              Nx := Nx * 10 + (Ord(ch) - Ord('0'));
          end;

         // Читаем второе число (Ny)
         Ny := 0;
         while not Eof(f) and not Eoln(f) do
           begin
            Read(f, ch);
            if (ch >= '0') and (ch <= '9') then
              Ny := Ny * 10 + (Ord(ch) - Ord('0'));
           end;

         ReadLn(f); // Переходим к следующей строке

         // Устанавливаем размеры массива
         SetLength(aMatrix, Nx);
         for i := 0 to (Nx - 1) do
            SetLength(aMatrix[i], Ny);

       // Читаем данные матрицы
       for i :=0 to (Nx - 1) do
         begin
           if Eof(f) then
             Exit;  // Недостаточно строк в файле
           for j := 0 to (Ny - 1) do
           begin
             if Eof(f) then
               Exit; // Недостаточно чисел в строке
               Read(f, aMatrix[i][j]);
           end;
             ReadLn(f); // Переходим к следующей строке
             Result := True; // Успешное чтение
         end;
       end;
       finally
          CloseFile(f);
        end;

    except
      on E: Exception do
      begin
       // Обрабатываем возможные ошибки
       Result := False;
      end;
    end;
end;

end.
