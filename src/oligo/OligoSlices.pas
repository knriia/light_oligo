unit OligoSlices;
// Таблица нарезки массива олигов на слои: запись и чтение файла слайсов

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSliceStruc = record  // запись слайсинга слоя
    LayerCount: Integer; // номер слоя
    Col: Integer;        //кол-во колонок
    Row: Integer;        //кол-во строк
    Letter: String;      //буква нуклеотида слоя
    NumOfChar: Integer;  //число букв в слое
    MatrixFile: String;  //путь к файлу матрицы
    EZDFile: String;     //путь к файлу EZD
  end;

  type
   TArrSliceStruc = array of TSliceStruc;

procedure SaveSliceStatistics(aDir: String;
                              const aTable: array of TSliceStruc; aFileType: word=0);
Function LoadSliceFile(var aSliceTable: TArrSliceStruc; aSliceFile: String): integer;

// Файлы слоёв в папке (Layer*.txt и Layer*.ezd), полные пути по алфавиту.
// Для несуществующей папки - пустой список.
function ListLayerFiles(const aDir: String): TStringArray;
// Удаляет файлы слоёв из папки. False и текст ошибки, если какой-то не удалился.
function DeleteLayerFiles(const aDir: String; out aErrorText: String): Boolean;

implementation

uses
  AppPaths;

procedure SaveSliceStatistics(aDir: String;
  const aTable: array of TSliceStruc; aFileType: word=0);
// Сохранение статистики слайсинга
//aFileType=0 - txt, aFileType=1 ezd
// Файлы слоёв из папки aDir записываются только по имени, чтобы папку
// с результатами нарезки можно было переносить.
var
   i: integer;
   s: String;
   f: TextFile;
   aFTStr: String;
begin
case aFileType of
0: aFTStr:='.txt';
1: aFTStr:='.lays';
end;

  if Length(aTable)<>0 then
  try
    AssignFile(f, aDir+'\Slices'+aFTStr);
    {$I-}
    Rewrite(f);
    {$I+}
    case aFileType of
    0: s:='Layer'+#9+'Letter'+#9+'NumOfLetters'+#9+'Filepath';
    1: s:='Layer'+#9+'Letter'+#9+'Filepath';
    end;
    WriteLN(f,S);

    for i:=0 to Length(aTable)-1 do
     case aFileType of
      0: begin
          s:=IntToStr(aTable[i].LayerCount)+
          #9+aTable[i].Letter+
          #9+IntToStr(aTable[i].NumOfChar)+
          #9+MakePathRelative(aDir, aTable[i].MatrixFile);
          WriteLN(f,S);
         end;
      1: begin
          s:=IntToStr(aTable[i].LayerCount)+
          #9+aTable[i].Letter+
          #9+MakePathRelative(aDir, aTable[i].EZDFile);
          WriteLN(f,S);
         end;
    end;
  finally
    CloseFile(f);
  end;
end;

function LoadSliceFile(var aSliceTable: TArrSliceStruc;
  aSliceFile: String): integer;
var
  F: TextFile;
  S: String;
  Parts: TStringArray;
begin
  Result:=-1;
  if FileExists(aSliceFile) then
  begin
    try
      AssignFile(F,aSliceFile);
      Reset(F);
      SetLength(aSliceTable,0);
      ReadLN(F,S); //просто считываем первую строку с заголовками
      while not EOF(F) do
      begin
        ReadLN(F,S);
          // Разделяем входную строку по символу табуляции
        Parts:=S.Split(#9); // #9 - символ табуляции
          // Проверяем, что строка содержит 3 части
        if Length(Parts) <> 3 then
        begin
          Result:=-1;
          Exit;
        end
        else
        SetLength(aSliceTable, Length(aSliceTable)+1); //увеличиваем размер на 1
        TryStrToInt(Parts[0], aSliceTable[High(aSliceTable)].LayerCount);
        aSliceTable[High(aSliceTable)].Letter:=trim(Parts[1]);
        // Имя файла ищем рядом с файлом слоёв; старые файлы с полными
        // путями читаются как раньше.
        aSliceTable[High(aSliceTable)].EZDFile:=
          ResolvePath(ExtractFileDir(aSliceFile), trim(Parts[2]));
      end;
      Result:=0;
    finally
      CloseFile(F);
    end;
  end;
end;

function ListLayerFiles(const aDir: String): TStringArray;
const
  MASKS: array[0..1] of String = ('Layer*.txt', 'Layer*.ezd');
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
    for i:=Low(MASKS) to High(MASKS) do
      if FindFirst(Dir+MASKS[i], faAnyFile and not faDirectory, Search)=0 then
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

function DeleteLayerFiles(const aDir: String; out aErrorText: String): Boolean;
var
  Files: TStringArray;
  i: integer;
begin
  aErrorText:='';
  Files:=ListLayerFiles(aDir);
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

end.
