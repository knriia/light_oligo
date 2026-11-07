unit LaserArrayFolderTests;
// Загрузка папки массива для вкладки «Лазер»: сам массив (.csv) и слои
// из Slices.txt.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, LaserArrayFolder, OligoArray,
  OligoArrayDocument, OligoSlices;

type
  TLaserArrayFolderTests = class(TTestCase)
  private
    FDirectory: string;
    function FolderPath(const AName: string): string;
    procedure RemoveTree(const ADirectory: string);
    function MakeArray: TOligoArr;
    // Пишет массив в папку AName под именем папки и Slices.txt со слоями.
    procedure WriteArrayFolder(const AName: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure LoadsArrayAndLayers;
    procedure FolderHasNoTrailingDelimiter;
    procedure NoCsvFileFails;
    procedure TwoCsvFilesFails;
    procedure MissingSlicesFileFails;
    procedure BrokenSlicesFileFails;
    procedure MissingFolderFails;
    procedure ArrayNewerThanSlicesIsOutdated;
    procedure SlicesNewerThanArrayIsActual;
  end;

implementation

function TLaserArrayFolderTests.FolderPath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TLaserArrayFolderTests.RemoveTree(const ADirectory: string);
var
  Search: TSearchRec;
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(ADirectory);
  if FindFirst(Dir + '*', faAnyFile, Search) = 0 then
  try
    repeat
      if (Search.Name = '.') or (Search.Name = '..') then
        Continue;
      if (Search.Attr and faDirectory) <> 0 then
        RemoveTree(Dir + Search.Name)
      else
        DeleteFile(Dir + Search.Name);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  RemoveDir(ADirectory);
end;

function TLaserArrayFolderTests.MakeArray: TOligoArr;
begin
  Result := CreateOligoArray(2, 3, ofConstant, 0, 'AT');
  Result[1, 2] := 'GC';
end;

procedure TLaserArrayFolderTests.WriteArrayFolder(const AName: string);
var
  Folder, ErrorText: string;
  Document: TOligoArrayDocument;
  Table: TSliceLayers;
begin
  Folder := FolderPath(AName);
  AssertTrue(ForceDirectories(Folder));
  Document := TOligoArrayDocument.Create;
  try
    Document.NewArray(MakeArray);
    AssertTrue(ErrorText, Document.SaveToFile(
      IncludeTrailingPathDelimiter(Folder) + AName + '.csv', ErrorText));
  finally
    Document.Free;
  end;

  SetLength(Table, 2);
  Table[0].LayerNumber := 1;
  Table[0].Letter := 'A';
  Table[0].LetterCount := 3;
  Table[0].MatrixFile := IncludeTrailingPathDelimiter(Folder) + 'Layer1_A3.txt';
  Table[1].LayerNumber := 2;
  Table[1].Letter := 'C';
  Table[1].LetterCount := 1;
  Table[1].MatrixFile := IncludeTrailingPathDelimiter(Folder) + 'Layer2_C1.txt';
  AssertTrue(ErrorText, SaveSliceStatistics(Folder, Table, SLICES_STAT_FILE,
    ErrorText));
end;

procedure TLaserArrayFolderTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_laser_folder_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TLaserArrayFolderTests.TearDown;
begin
  RemoveTree(FDirectory);
  inherited TearDown;
end;

procedure TLaserArrayFolderTests.LoadsArrayAndLayers;
var
  Folder, ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  WriteArrayFolder('arr1');
  Folder := FolderPath('arr1');
  AssertTrue(ErrorText, LoadArrayFolder(Folder, Loaded, ErrorText));
  AssertEquals(Folder, Loaded.Folder);
  AssertEquals(IncludeTrailingPathDelimiter(Folder) + 'arr1.csv',
    Loaded.ArrayFile);
  AssertEquals(2, Length(Loaded.Arr));
  AssertEquals(3, Length(Loaded.Arr[1]));
  AssertEquals('AT', Loaded.Arr[0, 0]);
  AssertEquals('GC', Loaded.Arr[1, 2]);
  AssertEquals(2, Length(Loaded.Table));
  AssertEquals(1, Loaded.Table[0].LayerNumber);
  AssertEquals('A', Loaded.Table[0].Letter);
  AssertEquals(3, Loaded.Table[0].LetterCount);
  AssertEquals(IncludeTrailingPathDelimiter(Folder) + 'Layer1_A3.txt',
    Loaded.Table[0].MatrixFile);
  AssertEquals(IncludeTrailingPathDelimiter(Folder) + 'Layer2_C1.txt',
    Loaded.Table[1].MatrixFile);
end;

procedure TLaserArrayFolderTests.FolderHasNoTrailingDelimiter;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  WriteArrayFolder('arr1');
  AssertTrue(ErrorText, LoadArrayFolder(FolderPath('arr1') + PathDelim,
    Loaded, ErrorText));
  AssertEquals(FolderPath('arr1'), Loaded.Folder);
  AssertTrue('пути к матрицам полные', Loaded.Table[0].MatrixFile =
    IncludeTrailingPathDelimiter(FolderPath('arr1')) + 'Layer1_A3.txt');
end;

procedure TLaserArrayFolderTests.NoCsvFileFails;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  AssertTrue(ForceDirectories(FolderPath('empty')));
  AssertFalse(LoadArrayFolder(FolderPath('empty'), Loaded, ErrorText));
  AssertTrue('текст ошибки по-русски', Pos('*.csv', ErrorText) > 0);
  AssertTrue('папка названа', Pos(FolderPath('empty'), ErrorText) > 0);
  AssertEquals('', Loaded.Folder);
  AssertEquals('', Loaded.ArrayFile);
  AssertEquals(0, Length(Loaded.Arr));
  AssertEquals(0, Length(Loaded.Table));
end;

procedure TLaserArrayFolderTests.TwoCsvFilesFails;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
  Document: TOligoArrayDocument;
begin
  WriteArrayFolder('arr1');
  Document := TOligoArrayDocument.Create;
  try
    Document.NewArray(MakeArray);
    AssertTrue(ErrorText, Document.SaveToFile(FolderPath('arr1') +
      PathDelim + 'copy.csv', ErrorText));
  finally
    Document.Free;
  end;
  AssertFalse(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertTrue('оба файла названы', (Pos('arr1.csv', ErrorText) > 0) and
    (Pos('copy.csv', ErrorText) > 0));
  AssertEquals(0, Length(Loaded.Arr));
  AssertEquals(0, Length(Loaded.Table));
end;

procedure TLaserArrayFolderTests.MissingSlicesFileFails;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  WriteArrayFolder('arr1');
  AssertTrue(DeleteFile(FolderPath('arr1') + PathDelim + 'Slices.txt'));
  AssertFalse(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertTrue('подсказка про слайсинг',
    Pos('Slices.txt', ErrorText) > 0);
  AssertEquals(0, Length(Loaded.Arr));
  AssertEquals(0, Length(Loaded.Table));
end;

procedure TLaserArrayFolderTests.BrokenSlicesFileFails;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
  Lines: TStringList;
begin
  WriteArrayFolder('arr1');
  Lines := TStringList.Create;
  try
    Lines.Text := 'Layer'#9'Letter'#9'NumOfLetters'#9'Filepath'#13#10 +
      '1'#9'A'#9'x'#9'Layer1_A3.txt'#13#10;
    Lines.SaveToFile(FolderPath('arr1') + PathDelim + 'Slices.txt');
  finally
    Lines.Free;
  end;
  AssertFalse(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertTrue('файл слоёв назван', Pos('Slices.txt', ErrorText) > 0);
  AssertEquals(0, Length(Loaded.Arr));
  AssertEquals(0, Length(Loaded.Table));
end;

procedure TLaserArrayFolderTests.MissingFolderFails;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  AssertFalse(LoadArrayFolder(FolderPath('none'), Loaded, ErrorText));
  AssertTrue('папка названа', Pos(FolderPath('none'), ErrorText) > 0);
  AssertEquals(0, Length(Loaded.Arr));
end;

procedure TLaserArrayFolderTests.ArrayNewerThanSlicesIsOutdated;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
  CsvFile: string;
begin
  WriteArrayFolder('arr1');
  AssertTrue(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  CsvFile := Loaded.ArrayFile;
  // массив пересохранён через два часа после слайсинга
  AssertTrue(FileSetDate(FolderPath('arr1') + PathDelim + 'Slices.txt',
    DateTimeToFileDate(Now - 4 / 24)) = 0);
  AssertTrue(FileSetDate(CsvFile, DateTimeToFileDate(Now - 2 / 24)) = 0);
  AssertTrue(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertTrue('слои устарели', Loaded.SlicesOutdated);
end;

procedure TLaserArrayFolderTests.SlicesNewerThanArrayIsActual;
var
  ErrorText: string;
  Loaded: TLoadedArrayFolder;
begin
  WriteArrayFolder('arr1');
  AssertTrue(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertTrue(FileSetDate(Loaded.ArrayFile,
    DateTimeToFileDate(Now - 4 / 24)) = 0);
  AssertTrue(FileSetDate(FolderPath('arr1') + PathDelim + 'Slices.txt',
    DateTimeToFileDate(Now - 2 / 24)) = 0);
  AssertTrue(LoadArrayFolder(FolderPath('arr1'), Loaded, ErrorText));
  AssertFalse('слои актуальны', Loaded.SlicesOutdated);
end;

initialization
  RegisterTest(TLaserArrayFolderTests);

end.
