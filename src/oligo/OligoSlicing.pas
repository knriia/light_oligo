unit OligoSlicing;
// Слайсинг массива олигов на слои.
// Синтез идёт с конца олигов: на каждом шаге берётся самая частая последняя
// буква, из позиций с этой буквой строится матрица слоя, и буква убирается.
// Шаги повторяются, пока в массиве остаются буквы.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes, OligoArray, OligoSlices;

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

// Записывает матрицы слоёв в папку aDir и строит по ним таблицу слоёв.
// Если хоть один файл не записался - False, текст ошибки и пустая таблица:
// неполный набор слоёв использовать нельзя.
function WriteLayerFiles(const aLayers: TOligoLayers; const aDir: String;
  out aTable: TSliceLayers; out aErrorText: String): Boolean;

// Слайсинг целиком в папку слайса aSliceDir: матрицы слоёв в aSliceDir\layers
// (папка создаётся) и статистика Slices.txt в aSliceDir (пути к слоям в ней -
// относительно aSliceDir). При ошибке - False, текст ошибки и пустая таблица.
function SliceArrayIntoFolder(const aArr: TOligoArr; const aSliceDir: String;
  out aLayers: TOligoLayers; out aTable: TSliceLayers;
  out aErrorText: String): Boolean;

implementation

uses
  AppPaths, OligoMatrix;

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

function WriteLayerFiles(const aLayers: TOligoLayers; const aDir: String;
  out aTable: TSliceLayers; out aErrorText: String): Boolean;
var
  i: Integer;
  LayerFile, Failed: String;
begin
  aTable:=nil;
  Failed:='';
  SetLength(aTable, Length(aLayers));
  for i:=0 to High(aLayers) do
  begin
    LayerFile:=IncludeTrailingPathDelimiter(aDir)+LayerFileName(aLayers[i]);
    if not SaveMatrixAsFile(aLayers[i].Matrix, LayerFile) then
      Failed:=Failed+LineEnding+LayerFile;
    aTable[i]:=Default(TSliceLayer);
    aTable[i].LayerNumber:=aLayers[i].Number;
    aTable[i].Letter:=aLayers[i].Letter;
    aTable[i].LetterCount:=aLayers[i].Count;
    aTable[i].MatrixFile:=LayerFile;
  end;
  Result:=Failed='';
  if Result then
    aErrorText:=''
  else
  begin
    aTable:=nil;
    aErrorText:='Не удалось записать файлы слоёв:'+Failed;
  end;
end;

function SliceArrayIntoFolder(const aArr: TOligoArr; const aSliceDir: String;
  out aLayers: TOligoLayers; out aTable: TSliceLayers;
  out aErrorText: String): Boolean;
var
  LayersDir: String;
begin
  aLayers:=SliceOligoArray(aArr);
  LayersDir:=IncludeTrailingPathDelimiter(aSliceDir)+LAYERS_FOLDER;
  if ForceDirectories(LayersDir) then
    Result:=WriteLayerFiles(aLayers, LayersDir, aTable, aErrorText) and
      SaveSliceStatistics(aSliceDir, aTable, SLICES_STAT_FILE, aErrorText)
  else
  begin
    Result:=False;
    aErrorText:='Не удалось создать папку:'+LineEnding+LayersDir;
  end;
  if not Result then
    aTable:=nil;
end;

end.
