unit LaserArrayFolder;
// Папка массива для вкладки «Лазер»: сам массив из единственного .csv и
// таблица слоёв из Slices.txt, который пишет слайсинг.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, OligoArray, OligoArrayDocument, OligoSlices;

type
  TLoadedArrayFolder = record
    Folder: string;      // папка массива, абсолютный путь без '\' в конце
    ArrayFile: string;   // файл массива (.csv)
    Arr: TOligoArr;      // прочитанный массив
    Table: TSliceLayers; // слои из Slices.txt, MatrixFile - полные пути
    // Файл массива записан позже Slices.txt: массив правили и сохраняли после
    // слайсинга, слои могут не соответствовать ему. Это предупреждение, а не
    // ошибка: простое пересохранение без правок даёт то же.
    SlicesOutdated: Boolean;
  end;

// Загружает папку массива в AFolder: ровно один файл *.csv в ней должен быть
// файлом массива, рядом должен лежать Slices.txt. При ошибке - False,
// причина в AErrorText (по-русски), AResult пустой.
function LoadArrayFolder(const AFolder: string; out AResult: TLoadedArrayFolder;
  out AErrorText: string): Boolean;

implementation

uses
  Classes;

function ListArrayFiles(const AFolder: string): TStringArray;
// Полные пути к файлам *.csv в папке по алфавиту.
var
  Search: TSearchRec;
  Names: TStringList;
  Dir: string;
  i: integer;
begin
  Result := nil;
  Dir := IncludeTrailingPathDelimiter(AFolder);
  Names := TStringList.Create;
  try
    if FindFirst(Dir + '*.csv', faAnyFile and not faDirectory, Search) = 0 then
    try
      repeat
        if (Search.Attr and faDirectory) = 0 then
          Names.Add(Dir + Search.Name);
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    Names.Sort;
    SetLength(Result, Names.Count);
    for i := 0 to High(Result) do
      Result[i] := Names[i];
  finally
    Names.Free;
  end;
end;

function FileNamesListText(const AFiles: TStringArray): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(AFiles) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + '  ' + ExtractFileName(AFiles[i]);
  end;
end;

function LoadArrayFolder(const AFolder: string; out AResult: TLoadedArrayFolder;
  out AErrorText: string): Boolean;
var
  Folder, ArrayFile, SlicesFile, DocumentError: string;
  Files: TStringArray;
  Document: TOligoArrayDocument;
begin
  Result := False;
  AResult := Default(TLoadedArrayFolder);
  AErrorText := '';
  try
    Folder := ExcludeTrailingPathDelimiter(ExpandFileName(AFolder));
    if not DirectoryExists(Folder) then
    begin
      AErrorText := 'Папка массива не найдена:' + LineEnding + Folder;
      Exit;
    end;

    Files := ListArrayFiles(Folder);
    if Length(Files) = 0 then
    begin
      AErrorText := 'В папке массива нет файла массива (*.csv):' +
        LineEnding + Folder;
      Exit;
    end;
    if Length(Files) > 1 then
    begin
      AErrorText := 'В папке массива несколько файлов *.csv, непонятно, какой ' +
        'из них массив:' + LineEnding + Folder + LineEnding +
        FileNamesListText(Files);
      Exit;
    end;
    ArrayFile := Files[0];

    SlicesFile := IncludeTrailingPathDelimiter(Folder) + 'Slices.txt';
    if not FileExists(SlicesFile) then
    begin
      AErrorText := 'Сначала выполните слайсинг массива (' + Folder + '): ' +
        'рядом с массивом нет файла Slices.txt.';
      Exit;
    end;

    AResult.Folder := Folder;
    AResult.ArrayFile := ArrayFile;
    AResult.SlicesOutdated := FileAge(ArrayFile) > FileAge(SlicesFile);
    if not LoadSliceStatistics(SlicesFile, AResult.Table, AErrorText) then
    begin
      AResult := Default(TLoadedArrayFolder);
      Exit;
    end;

    Document := TOligoArrayDocument.Create;
    try
      if not Document.LoadFromFile(ArrayFile, DocumentError) then
      begin
        AResult := Default(TLoadedArrayFolder);
        AErrorText := 'Не удалось прочитать файл массива:' + LineEnding +
          ArrayFile + LineEnding + DocumentError;
        Exit;
      end;
      AResult.Arr := CopyOligoArray(Document.Arr);
    finally
      Document.Free;
    end;

    // Результат отдаётся только целиком: при ошибке запись обнуляется выше
    Result := True;
  except
    on E: Exception do
    begin
      AResult := Default(TLoadedArrayFolder);
      AErrorText := 'Не удалось загрузить папку массива:' + LineEnding +
        AFolder + LineEnding + E.Message;
    end;
  end;
end;

end.
