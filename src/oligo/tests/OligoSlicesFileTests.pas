unit OligoSlicesFileTests;
// Файлы слоёв (Slices.txt, Slices.lays): в файле лежат только имена, путь
// строится от папки самого файла, поэтому папку можно переносить.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, OligoSlices;

type
  TOligoSlicesFileTests = class(TTestCase)
  private
    FDirectory: string;
    procedure WriteTextFile(const AFileName, AText: string);
    procedure RemoveTree(const ADirectory: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SliceFileStoresOnlyFileNames;
    procedure SliceFileIsReadAfterFolderMove;
    procedure SliceFileWithAbsolutePathsStillLoads;
    procedure SliceStatisticsRoundTrip;
    procedure SliceStatisticsIsReadAfterFolderMove;
    procedure SliceStatisticsMissingFileFails;
    procedure SliceStatisticsRejectsBadLine;
    procedure SliceStatisticsRejectsBadNumber;
    procedure SliceStatisticsHeaderOnlyFails;
  end;

const
  STAT_HEADER = 'Layer'#9'Letter'#9'NumOfLetters'#9'Filepath' + LineEnding;
  LAYS_HEADER = 'Layer'#9'Letter'#9'Filepath' + LineEnding;

implementation

procedure TOligoSlicesFileTests.WriteTextFile(const AFileName, AText: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
end;

procedure TOligoSlicesFileTests.RemoveTree(const ADirectory: string);
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

procedure TOligoSlicesFileTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_slices_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TOligoSlicesFileTests.TearDown;
begin
  RemoveTree(FDirectory);
  inherited TearDown;
end;

procedure TOligoSlicesFileTests.SliceFileStoresOnlyFileNames;
var
  Table: TSliceLayers;
  Lines: TStringList;
  ErrorText: string;
begin
  SetLength(Table, 1);
  Table[0].LayerNumber := 1;
  Table[0].Letter := 'A';
  Table[0].LetterCount := 10;
  Table[0].MatrixFile := IncludeTrailingPathDelimiter(FDirectory) +
    'Layer1_A10.txt';
  Table[0].EZDFile := IncludeTrailingPathDelimiter(FDirectory) +
    'Layer1_A10.ezd';
  AssertTrue(ErrorText, SaveSliceStatistics(FDirectory, Table, SLICES_STAT_FILE,
    ErrorText));
  AssertTrue(ErrorText, SaveSliceStatistics(FDirectory, Table, SLICES_EZD_FILE,
    ErrorText));

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt');
    AssertEquals('1'#9'A'#9'10'#9'Layer1_A10.txt', Lines[1]);
    Lines.LoadFromFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays');
    AssertEquals('1'#9'A'#9'Layer1_A10.ezd', Lines[1]);
  finally
    Lines.Free;
  end;
end;

procedure TOligoSlicesFileTests.SliceFileIsReadAfterFolderMove;
var
  Table: TSliceLayers;
  MovedDir: string;
begin
  // Файл слоёв с одними именами: путь строится от его новой папки.
  MovedDir := IncludeTrailingPathDelimiter(FDirectory) + 'moved';
  WriteTextFile(IncludeTrailingPathDelimiter(MovedDir) + 'Slices.lays',
    'Layer'#9'Letter'#9'Filepath' + LineEnding +
    '1'#9'A'#9'Layer1_A10.ezd' + LineEnding);

  AssertEquals(0, LoadSliceFile(Table,
    IncludeTrailingPathDelimiter(MovedDir) + 'Slices.lays'));
  AssertEquals(1, Length(Table));
  AssertEquals(IncludeTrailingPathDelimiter(MovedDir) + 'Layer1_A10.ezd',
    Table[0].EZDFile);
end;

procedure TOligoSlicesFileTests.SliceFileWithAbsolutePathsStillLoads;
var
  Table: TSliceLayers;
begin
  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays',
    LAYS_HEADER +
    '1'#9'C'#9'D:\Ruslan\arr\Layer1_C2565.ezd' + LineEnding);

  AssertEquals(0, LoadSliceFile(Table,
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays'));
  AssertEquals('D:\Ruslan\arr\Layer1_C2565.ezd', Table[0].EZDFile);
end;

function MakeTable(const ADir: string): TSliceLayers;
// два слоя, матрицы лежат в папке ADir
begin
  SetLength(Result, 2);
  Result[0].LayerNumber := 1;
  Result[0].Letter := 'A';
  Result[0].LetterCount := 10;
  Result[0].MatrixFile := IncludeTrailingPathDelimiter(ADir) + 'Layer1_A10.txt';
  Result[1].LayerNumber := 2;
  Result[1].Letter := 'C';
  Result[1].LetterCount := 7;
  Result[1].MatrixFile := IncludeTrailingPathDelimiter(ADir) + 'Layer2_C7.txt';
end;

procedure TOligoSlicesFileTests.SliceStatisticsRoundTrip;
var
  Saved, Loaded: TSliceLayers;
  ErrorText: string;
  I: Integer;
begin
  Saved := MakeTable(FDirectory);
  AssertTrue(ErrorText, SaveSliceStatistics(FDirectory, Saved,
    SLICES_STAT_FILE, ErrorText));
  AssertTrue(ErrorText, LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));

  AssertEquals(Length(Saved), Length(Loaded));
  for I := 0 to High(Saved) do
  begin
    AssertEquals(Saved[I].LayerNumber, Loaded[I].LayerNumber);
    AssertEquals(Saved[I].Letter, Loaded[I].Letter);
    AssertEquals(Saved[I].LetterCount, Loaded[I].LetterCount);
    AssertEquals(Saved[I].MatrixFile, Loaded[I].MatrixFile);
    AssertEquals('', Loaded[I].EZDFile);
  end;
end;

procedure TOligoSlicesFileTests.SliceStatisticsIsReadAfterFolderMove;
var
  MovedDir: string;
  Loaded: TSliceLayers;
  ErrorText: string;
begin
  MovedDir := IncludeTrailingPathDelimiter(FDirectory) + 'moved';
  WriteTextFile(IncludeTrailingPathDelimiter(MovedDir) + 'Slices.txt',
    STAT_HEADER +
    '1'#9'A'#9'10'#9'Layer1_A10.txt' + LineEnding +
    '2'#9'C'#9'7'#9'D:\Ruslan\arr\Layer2_C7.txt' + LineEnding);

  AssertTrue(ErrorText, LoadSliceStatistics(
    IncludeTrailingPathDelimiter(MovedDir) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals(2, Length(Loaded));
  AssertEquals(IncludeTrailingPathDelimiter(MovedDir) + 'Layer1_A10.txt',
    Loaded[0].MatrixFile);
  AssertEquals('D:\Ruslan\arr\Layer2_C7.txt', Loaded[1].MatrixFile);
  AssertEquals(7, Loaded[1].LetterCount);
end;

procedure TOligoSlicesFileTests.SliceStatisticsMissingFileFails;
var
  Loaded: TSliceLayers;
  ErrorText: string;
begin
  SetLength(Loaded, 1);
  AssertFalse(LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals('в пустой файл пустая таблица', 0, Length(Loaded));
  AssertTrue('файл назван', Pos('Slices.txt', ErrorText) > 0);
end;

procedure TOligoSlicesFileTests.SliceStatisticsRejectsBadLine;
var
  Loaded: TSliceLayers;
  ErrorText: string;
begin
  // первая строка хорошая, вторая - из трёх полей
  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt',
    STAT_HEADER +
    '1'#9'A'#9'10'#9'Layer1_A10.txt' + LineEnding +
    '2'#9'C'#9'Layer2_C7.txt' + LineEnding);
  AssertFalse(LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals('наполовину прочитанной таблицы нет', 0, Length(Loaded));
  AssertTrue('номер строки назван', Pos('3:', ErrorText) > 0);
end;

procedure TOligoSlicesFileTests.SliceStatisticsRejectsBadNumber;
var
  Loaded: TSliceLayers;
  ErrorText: string;
begin
  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt',
    STAT_HEADER + '1'#9'A'#9'many'#9'Layer1_A10.txt' + LineEnding);
  AssertFalse(LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals(0, Length(Loaded));
  AssertTrue('число букв названо', Pos('many', ErrorText) > 0);

  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt',
    STAT_HEADER + 'one'#9'A'#9'10'#9'Layer1_A10.txt' + LineEnding);
  AssertFalse(LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals(0, Length(Loaded));
  AssertTrue('номер слоя назван', Pos('one', ErrorText) > 0);
end;

procedure TOligoSlicesFileTests.SliceStatisticsHeaderOnlyFails;
var
  Loaded: TSliceLayers;
  ErrorText: string;
begin
  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt',
    STAT_HEADER);
  AssertFalse(LoadSliceStatistics(
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.txt', Loaded, ErrorText));
  AssertEquals(0, Length(Loaded));
  AssertTrue('файл назван', Pos('Slices.txt', ErrorText) > 0);
end;

initialization
  RegisterTest(TOligoSlicesFileTests);

end.
