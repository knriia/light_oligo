unit GridWidthMode;
// Режимы ширины столбцов таблицы, переключаемые по кругу кликом по углу:
// по умолчанию -> по самому длинному значению -> квадратные -> по умолчанию.

{$mode ObjFPC}{$H+}

interface

type
  TGridWidthMode = (gwmDefault, gwmLongest, gwmSquare);

function NextGridWidthMode(AMode: TGridWidthMode): TGridWidthMode;

implementation

function NextGridWidthMode(AMode: TGridWidthMode): TGridWidthMode;
begin
  if AMode = High(TGridWidthMode) then
    Result := Low(TGridWidthMode)
  else
    Result := Succ(AMode);
end;

end.
