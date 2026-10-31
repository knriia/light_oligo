unit CommonUtils;
// Мелкие общие функции: имена файлов, таблицы StringGrid

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Grids;

Function RemoveFileExt(Const aFileName: String): String;
Procedure NumerateGrid(aSG: TStringGrid);

implementation

function RemoveFileExt(const aFileName: String): String;
//Удаление расширения в имени файла
var
  DotPos: Integer;
begin
  // Находим позицию последней точки в имени файла
  DotPos:=LastDelimiter('.', aFileName);

  // Если точка найдена, возвращаем строку до точки, иначе возвращаем оригинальное имя
  if DotPos > 0 then
    Result:=Copy(aFileName, 1, DotPos-1)
  else
    Result:=aFileName;
end;

procedure NumerateGrid(aSG: TStringGrid);
// нумерация строк и стобцов StringGrid [i,0] и [0,i]
var
  i: integer;
begin
  for i:=1 to aSG.ColCount-1 do
  begin
    aSG.Cells[i,0]:=IntToStr(i);
  end;
    for i:=1 to aSG.RowCount-1 do
  begin
    aSG.Cells[0,i]:=IntToStr(i);
  end;
end;

end.
