unit AppPathsTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, AppPaths, OligoSlices;

type
  TAppPathsTests = class(TTestCase)
  private
    FDirectory: string;
    FExecutableFileName: string;
    procedure WriteTextFile(const AFileName, AText: string);
    procedure RemoveTree(const ADirectory: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure DataFoldersAreNextToExecutable;
    procedure MakePathRelativeStripsBaseDirectory;
    procedure MakePathRelativeKeepsOutsidePath;
    procedure ResolvePathAddsBaseToRelativeName;
    procedure ResolvePathKeepsAbsolutePath;
    procedure SliceFileStoresOnlyFileNames;
    procedure SliceFileIsReadAfterFolderMove;
    procedure SliceFileWithAbsolutePathsStillLoads;
    procedure MigrationMovesLegacyProtocolsFolder;
  end;

implementation

procedure TAppPathsTests.WriteTextFile(const AFileName, AText: string);
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

procedure TAppPathsTests.RemoveTree(const ADirectory: string);
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

procedure TAppPathsTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_paths_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
  FExecutableFileName := IncludeTrailingPathDelimiter(FDirectory) +
    'LightOligo.exe';
end;

procedure TAppPathsTests.TearDown;
begin
  RemoveTree(FDirectory);
  inherited TearDown;
end;

procedure TAppPathsTests.DataFoldersAreNextToExecutable;
begin
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'data',
    DataDir(FExecutableFileName));
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'data' + PathDelim +
    'automation', AutomationDir(FExecutableFileName));
end;

procedure TAppPathsTests.MakePathRelativeStripsBaseDirectory;
begin
  AssertEquals('run1' + PathDelim + 'Layer1_A10.ezd',
    MakePathRelative(FDirectory, IncludeTrailingPathDelimiter(FDirectory) +
      'run1' + PathDelim + 'Layer1_A10.ezd'));
end;

procedure TAppPathsTests.MakePathRelativeKeepsOutsidePath;
begin
  AssertEquals('Z:\other\Layer1_A10.ezd',
    MakePathRelative(FDirectory, 'Z:\other\Layer1_A10.ezd'));
end;

procedure TAppPathsTests.ResolvePathAddsBaseToRelativeName;
begin
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'Layer1_A10.ezd',
    ResolvePath(FDirectory, 'Layer1_A10.ezd'));
end;

procedure TAppPathsTests.ResolvePathKeepsAbsolutePath;
begin
  AssertEquals('Z:\other\Layer1_A10.ezd',
    ResolvePath(FDirectory, 'Z:\other\Layer1_A10.ezd'));
end;

procedure TAppPathsTests.SliceFileStoresOnlyFileNames;
var
  Table: TArrSliceStruc;
  Lines: TStringList;
begin
  SetLength(Table, 1);
  Table[0].LayerCount := 1;
  Table[0].Letter := 'A';
  Table[0].NumOfChar := 10;
  Table[0].MatrixFile := IncludeTrailingPathDelimiter(FDirectory) +
    'Layer1_A10.txt';
  Table[0].EZDFile := IncludeTrailingPathDelimiter(FDirectory) +
    'Layer1_A10.ezd';
  SaveSliceStatistics(FDirectory, Table);
  SaveSliceStatistics(FDirectory, Table, 1);

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

procedure TAppPathsTests.SliceFileIsReadAfterFolderMove;
var
  Table: TArrSliceStruc;
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

procedure TAppPathsTests.SliceFileWithAbsolutePathsStillLoads;
var
  Table: TArrSliceStruc;
begin
  WriteTextFile(IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays',
    'Layer'#9'Letter'#9'Filepath' + LineEnding +
    '1'#9'C'#9'D:\Ruslan\arr\Layer1_C2565.ezd' + LineEnding);

  AssertEquals(0, LoadSliceFile(Table,
    IncludeTrailingPathDelimiter(FDirectory) + 'Slices.lays'));
  AssertEquals('D:\Ruslan\arr\Layer1_C2565.ezd', Table[0].EZDFile);
end;

procedure TAppPathsTests.MigrationMovesLegacyProtocolsFolder;
var
  OldDir: string;
begin
  OldDir := IncludeTrailingPathDelimiter(FDirectory) + 'protocols';
  WriteTextFile(IncludeTrailingPathDelimiter(OldDir) + 'A.pro', 'Block=Wash;');
  WriteTextFile(IncludeTrailingPathDelimiter(OldDir) + 'scenario.txt', 'run');

  MigrateLegacyData(FExecutableFileName);

  AssertTrue(FileExists(IncludeTrailingPathDelimiter(
    DataSubDir(PROTOCOLS_FOLDER, FExecutableFileName)) + 'A.pro'));
  AssertTrue(FileExists(IncludeTrailingPathDelimiter(
    AutomationDir(FExecutableFileName)) + 'scenario.txt'));
  AssertFalse(DirectoryExists(OldDir));
end;

initialization
  RegisterTest(TAppPathsTests);

end.
