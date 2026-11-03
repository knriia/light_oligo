unit OligoSlices;
// Таблица нарезки массива олигов на слои: запись и чтение файла слайсов

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSliceLayer = record   // слой после слайсинга
    LayerNumber: Integer;  // номер слоя с 1
    Letter: String;        // буква нуклеотида слоя
    LetterCount: Integer;  // сколько точек с этой буквой в слое
    MatrixFile: String;    // путь к файлу матрицы слоя
    EZDFile: String;       // путь к EZD-файлу слоя
  end;
  TSliceLayers = array of TSliceLayer;

const
  SLICES_STAT_FILE = 0; // Slices.txt - статистика слайсинга, пути к матрицам
  SLICES_EZD_FILE = 1;  // Slices.lays - таблица для синтеза, пути к EZD

// Записывает таблицу слоёв в aDir (Slices.txt или Slices.lays).
// False и текст ошибки, если файл записать не удалось.
function SaveSliceStatistics(const aDir: String;
  const aTable: array of TSliceLayer; aFileType: Word;
  out aErrorText: String): Boolean;
// Читает Slices.lays: 0 - прочитан, -1 - ошибка (файла нет, строка не из
// трёх полей, номер слоя не число, нет ни одного слоя). При ошибке
// таблица пустая - наполовину прочитанной она не бывает.
Function LoadSliceFile(var aSliceTable: TSliceLayers; aSliceFile: String): integer;

// Файлы слоёв в папке (Layer*.txt и Layer*.ezd), полные пути по алфавиту.
// Для несуществующей папки - пустой список.
function ListLayerFiles(const aDir: String): TStringArray;
// Удаляет файлы слоёв из папки. False и текст ошибки, если какой-то не удалился.
function DeleteLayerFiles(const aDir: String; out aErrorText: String): Boolean;
// То же только для EZD-файлов слоёв (Layer*.ezd); файлы матриц не трогаются.
function ListLayerEzdFiles(const aDir: String): TStringArray;
function DeleteLayerEzdFiles(const aDir: String; out aErrorText: String): Boolean;

implementation

uses
  AppPaths, TextFileUtils;

function SaveSliceStatistics(const aDir: String;
  const aTable: array of TSliceLayer; aFileType: Word;
  out aErrorText: String): Boolean;
// Файлы слоёв из папки aDir записываются только по имени, чтобы папку
// с результатами нарезки можно было переносить.
var
  i: integer;
  Text, FileName: String;
begin
  if aFileType=SLICES_EZD_FILE then
  begin
    FileName:='Slices.lays';
    Text:='Layer'#9'Letter'#9'Filepath'+LineEnding;
  end
  else
  begin
    FileName:='Slices.txt';
    Text:='Layer'#9'Letter'#9'NumOfLetters'#9'Filepath'+LineEnding;
  end;

  for i:=0 to High(aTable) do
    if aFileType=SLICES_EZD_FILE then
      Text:=Text+IntToStr(aTable[i].LayerNumber)+#9+aTable[i].Letter+#9+
            MakePathRelative(aDir, aTable[i].EZDFile)+LineEnding
    else
      Text:=Text+IntToStr(aTable[i].LayerNumber)+#9+aTable[i].Letter+#9+
            IntToStr(aTable[i].LetterCount)+#9+
            MakePathRelative(aDir, aTable[i].MatrixFile)+LineEnding;

  FileName:=IncludeTrailingPathDelimiter(aDir)+FileName;
  Result:=WriteUtf8TextFile(FileName, Text, aErrorText);
  if not Result then
    aErrorText:='Не удалось записать файл:'+LineEnding+FileName+LineEnding+
                aErrorText;
end;

function LoadSliceFile(var aSliceTable: TSliceLayers;
  aSliceFile: String): integer;
var
  Lines: TStringList;
  Parts: TStringArray;
  Table: TSliceLayers;
  i, n: integer;
begin
  Result:=-1;
  aSliceTable:=nil;
  if not FileExists(aSliceFile) then
    Exit;
  Table:=nil;
  Lines:=TStringList.Create;
  try
    try
      Lines.LoadFromFile(aSliceFile);
    except
      Exit; // файл не читается (занят, нет доступа)
    end;
    // строка 0 - заголовки; пустые строки пропускаем
    for i:=1 to Lines.Count-1 do
    begin
      if Trim(Lines[i])='' then
        Continue;
      Parts:=Lines[i].Split(#9);
      if Length(Parts)<>3 then
        Exit;
      n:=Length(Table);
      SetLength(Table, n+1);
      Table[n]:=Default(TSliceLayer);
      if not TryStrToInt(Trim(Parts[0]), Table[n].LayerNumber) then
        Exit;
      Table[n].Letter:=Trim(Parts[1]);
      // Имя файла ищем рядом с файлом слоёв; старые файлы с полными
      // путями читаются как раньше.
      Table[n].EZDFile:=ResolvePath(ExtractFileDir(aSliceFile), Trim(Parts[2]));
    end;
  finally
    Lines.Free;
  end;
  if Length(Table)=0 then
    Exit;
  aSliceTable:=Table;
  Result:=0;
end;

function ListFilesByMasks(const aDir: String;
  const aMasks: array of String): TStringArray;
var
  Names: TStringList;
  Search: TSearchRec;
  Dir: String;
  i: integer;
begin
  Result:=nil;
  Dir:=IncludeTrailingPathDelimiter(aDir);
  Names:=TStringList.Create;
  try
    for i:=Low(aMasks) to High(aMasks) do
      if FindFirst(Dir+aMasks[i], faAnyFile and not faDirectory, Search)=0 then
      try
        repeat
          if (Search.Attr and faDirectory)=0 then
            Names.Add(Dir+Search.Name);
        until FindNext(Search)<>0;
      finally
        FindClose(Search);
      end;
    Names.Sort;
    SetLength(Result, Names.Count);
    for i:=0 to Names.Count-1 do
      Result[i]:=Names[i];
  finally
    Names.Free;
  end;
end;

function DeleteFileList(const Files: TStringArray; out aErrorText: String): Boolean;
var
  i: integer;
begin
  aErrorText:='';
  for i:=0 to High(Files) do
    if not DeleteFile(Files[i]) then
    begin
      if aErrorText<>'' then
        aErrorText:=aErrorText+LineEnding;
      aErrorText:=aErrorText+Files[i];
    end;
  Result:=aErrorText='';
  if not Result then
    aErrorText:='Не удалось удалить файлы:'+LineEnding+aErrorText;
end;

function ListLayerFiles(const aDir: String): TStringArray;
begin
  Result:=ListFilesByMasks(aDir, ['Layer*.txt', 'Layer*.ezd']);
end;

function DeleteLayerFiles(const aDir: String; out aErrorText: String): Boolean;
begin
  Result:=DeleteFileList(ListLayerFiles(aDir), aErrorText);
end;

function ListLayerEzdFiles(const aDir: String): TStringArray;
begin
  Result:=ListFilesByMasks(aDir, ['Layer*.ezd']);
end;

function DeleteLayerEzdFiles(const aDir: String; out aErrorText: String): Boolean;
begin
  Result:=DeleteFileList(ListLayerEzdFiles(aDir), aErrorText);
end;

end.
