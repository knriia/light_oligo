unit AppPathsTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, AppPaths;

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
    procedure MigrationMovesLegacyProtocolsFolder;
    procedure ConfigsAreNextToExecutable;
    procedure MigrationMovesConfigsIntoConfigsFolder;
    procedure MigrationKeepsExistingConfigs;
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
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'data' + PathDelim +
    'syntheses', SynthesesDir(FExecutableFileName));
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

procedure TAppPathsTests.ConfigsAreNextToExecutable;
begin
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'configs',
    ConfigsDir(FExecutableFileName));
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'configs' + PathDelim +
    'Interface.ini', ConfigFilePath(INTERFACE_FILE, FExecutableFileName));
end;

procedure TAppPathsTests.MigrationMovesConfigsIntoConfigsFolder;
var
  Dir, OldSettingsDir: string;
begin
  Dir := IncludeTrailingPathDelimiter(FDirectory);
  OldSettingsDir := Dir + 'data' + PathDelim + 'settings';
  WriteTextFile(Dir + 'Interface.ini', '[Oligo]');
  WriteTextFile(Dir + 'ProgConfig.ini', '[Program]');
  WriteTextFile(IncludeTrailingPathDelimiter(OldSettingsDir) +
    'syringe_pump.ini', '[Station]');

  MigrateLegacyData(FExecutableFileName);

  AssertTrue(FileExists(ConfigFilePath(INTERFACE_FILE, FExecutableFileName)));
  AssertTrue(FileExists(ConfigFilePath(PROG_CONFIG_FILE, FExecutableFileName)));
  AssertTrue(FileExists(ConfigFilePath(SETTINGS_FILE, FExecutableFileName)));
  AssertFalse(FileExists(Dir + 'Interface.ini'));
  AssertFalse(FileExists(Dir + 'ProgConfig.ini'));
  AssertFalse('пустая data\settings удалена', DirectoryExists(OldSettingsDir));
end;

procedure TAppPathsTests.MigrationKeepsExistingConfigs;
var
  Dir: string;
  Lines: TStringList;
begin
  // в configs уже есть свой файл - старый не переносится и не затирает его
  Dir := IncludeTrailingPathDelimiter(FDirectory);
  WriteTextFile(Dir + 'ProgConfig.ini', '[Old]');
  WriteTextFile(ConfigFilePath(PROG_CONFIG_FILE, FExecutableFileName), '[New]');

  MigrateLegacyData(FExecutableFileName);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ConfigFilePath(PROG_CONFIG_FILE, FExecutableFileName));
    AssertEquals('[New]', Lines[0]);
  finally
    Lines.Free;
  end;
  AssertTrue(FileExists(Dir + 'ProgConfig.ini'));
end;

initialization
  RegisterTest(TAppPathsTests);

end.
