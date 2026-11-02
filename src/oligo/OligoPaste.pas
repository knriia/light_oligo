unit OligoPaste;
// Вставка в таблицу массива из буфера обмена: помещаются ли данные.
// Таблица вставляет текст как строки, ячейки в которых разделены табуляцией
// (так копирует Excel), начиная с выделенной ячейки; всё, что выходит за
// край таблицы, отбрасывается.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

// Размер вставляемых данных: строк и наибольшее число ячеек в строке.
// Завершающий перевод строки новой строкой не считается.
procedure MeasurePasteText(const AText: string; out ARows, ACols: Integer);

// False, если данные не помещаются от ячейки (AStartRow, AStartCol) до края
// таблицы ARowCount x AColCount (индексы таблицы, с заголовками).
// Тогда AMessage - что было в буфере и что поместилось.
function CheckPasteFits(const AText: string; AStartRow, AStartCol,
  ARowCount, AColCount: Integer; out AMessage: string): Boolean;

implementation

procedure MeasurePasteText(const AText: string; out ARows, ACols: Integer);
var
  Lines: TStringList;
  i, Cells: Integer;
begin
  ARows:=0;
  ACols:=0;
  Lines:=TStringList.Create;
  try
    Lines.Text:=AText;
    ARows:=Lines.Count;
    for i:=0 to Lines.Count-1 do
    begin
      Cells:=Length(Lines[i].Split([#9]));
      if Cells=0 then
        Cells:=1; // пустая строка - тоже одна ячейка
      if Cells>ACols then
        ACols:=Cells;
    end;
  finally
    Lines.Free;
  end;
end;

function CheckPasteFits(const AText: string; AStartRow, AStartCol,
  ARowCount, AColCount: Integer; out AMessage: string): Boolean;
var
  DataRows, DataCols, FreeRows, FreeCols: Integer;
begin
  AMessage:='';
  MeasurePasteText(AText, DataRows, DataCols);
  FreeRows:=ARowCount-AStartRow;
  FreeCols:=AColCount-AStartCol;
  if FreeRows<0 then FreeRows:=0;
  if FreeCols<0 then FreeCols:=0;
  Result:=(DataRows<=FreeRows) and (DataCols<=FreeCols);
  if Result then
    Exit;
  if DataRows<FreeRows then FreeRows:=DataRows;
  if DataCols<FreeCols then FreeCols:=DataCols;
  AMessage:='Данные не поместились в массив.'+LineEnding+
    'В буфере: '+IntToStr(DataRows)+' строк x '+IntToStr(DataCols)+' столбцов.'+LineEnding+
    'Вставлено: '+IntToStr(FreeRows)+' строк x '+IntToStr(FreeCols)+' столбцов,'+
    ' начиная со строки '+IntToStr(AStartRow)+', столбца '+IntToStr(AStartCol)+'.'+LineEnding+
    'Остальное отброшено.';
end;

end.
