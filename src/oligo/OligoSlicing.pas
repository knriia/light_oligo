unit OligoSlicing;
// Слайсинг массива олигов на слои.
// Синтез идёт с конца олигов: на каждом шаге берётся самая частая последняя
// буква, из позиций с этой буквой строится матрица слоя, и буква убирается.
// Шаги повторяются, пока в массиве остаются буквы.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes, OligoArray;

const
  MAX_SLICE_LAYERS = 1001; // защита от зацикливания, как и раньше

type
  TOligoLayer = record
    Number: Integer;   // номер слоя с 1
    Letter: TOlig;     // буква слоя
    Count: Integer;    // сколько точек в слое
    Matrix: TMatrix;   // 1 - в этой позиции ставится буква слоя
  end;
  TOligoLayers = array of TOligoLayer;

// Слои массива. Сам aArr не меняется.
function SliceOligoArray(const aArr: TOligoArr): TOligoLayers;

// Имя файла матрицы слоя: Layer<номер>_<буква><количество>.txt
function LayerFileName(const aLayer: TOligoLayer): String;

implementation

function SliceOligoArray(const aArr: TOligoArr): TOligoLayers;
var
  Work: TOligoArr;
  Symbols: TSymbolSet;
  Layer: TOligoLayer;
begin
  Result:=nil;
  Work:=CopyOligoArray(aArr);
  Symbols:=CollectSymbols(Work);
  repeat
    Layer:=Default(TOligoLayer);
    CreateMatrixLayerFromOligoArr(Work, Symbols, Layer.Matrix, Layer.Letter,
      Layer.Count);
    if Layer.Count=0 then
      Break;
    Layer.Number:=Length(Result)+1;
    SetLength(Result, Length(Result)+1);
    Result[High(Result)]:=Layer;
  until Length(Result)>=MAX_SLICE_LAYERS;
end;

function LayerFileName(const aLayer: TOligoLayer): String;
begin
  Result:='Layer'+IntToStr(aLayer.Number)+'_'+aLayer.Letter+
    IntToStr(aLayer.Count)+'.txt';
end;

end.
