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

implementation

procedure SaveSliceStatistics(aDir: String;
  const aTable: array of TSliceStruc; aFileType: word=0);
// Сохранение статистики слайсинга
//aFileType=0 - txt, aFileType=1 ezd
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
          #9+aTable[i].MatrixFile;
          WriteLN(f,S);
         end;
      1: begin
          s:=IntToStr(aTable[i].LayerCount)+
          #9+aTable[i].Letter+
          #9+aTable[i].EZDFile;
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
        aSliceTable[High(aSliceTable)].EZDFile:=trim(Parts[2]);
      end;
      Result:=0;
    finally
      CloseFile(F);
    end;
  end;
end;

end.
