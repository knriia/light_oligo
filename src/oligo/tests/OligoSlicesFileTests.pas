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
  end;

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
    'Layer'#9'Letter'#9'Filepath' + LineEnding +
    '1'#9'C'#9'D:\Ruslan\arr\Layer1_C2565.ezd' + LineEnding);

  AssertEquals(0, LoadSliceFile(Table,
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays'));
  AssertEquals('D:\Ruslan\arr\Layer1_C2565.ezd', Table[0].EZDFile);
end;

initialization
  RegisterTest(TOligoSlicesFileTests);

end.
