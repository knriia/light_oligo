unit LocalizationTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Localization;

type
  TLocalizationTests = class(TTestCase)
  private
    FDirectory: string;
    FInterfaceFileName: string;
    FConfigFileName: string;
    procedure WriteTextFile(const AFileName, AText: string);
    procedure RemoveTree(const ADirectory: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MissingKeyUsesDefault;
    procedure ExistingKeyIsRead;
    procedure MissingFileUsesDefault;
    procedure ReadingBeforeInitializeUsesDefault;
    procedure ReadingAfterFinalizeUsesDefault;
    procedure ReinitializeReadsNewFiles;
    procedure ConfigValuesAreReadSeparatelyFromCaptions;
  end;

implementation

procedure TLocalizationTests.WriteTextFile(const AFileName, AText: string);
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

procedure TLocalizationTests.RemoveTree(const ADirectory: string);
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

procedure TLocalizationTests.SetUp;
begin
  inherited SetUp;
  FinalizeLocalization;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_localization_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
  FInterfaceFileName := IncludeTrailingPathDelimiter(FDirectory) +
    'Interface.ini';
  FConfigFileName := IncludeTrailingPathDelimiter(FDirectory) +
    'ProgConfig.ini';
end;

procedure TLocalizationTests.TearDown;
begin
  FinalizeLocalization;
  RemoveTree(FDirectory);
  inherited TearDown;
end;

procedure TLocalizationTests.MissingKeyUsesDefault;
begin
  WriteTextFile(FInterfaceFileName, '[Main]' + LineEnding);
  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals('Default caption', ReadInterfaceString('Main', 'Missing',
    'Default caption'));
end;

procedure TLocalizationTests.ExistingKeyIsRead;
begin
  WriteTextFile(FInterfaceFileName,
    '[Main]' + LineEnding + 'Caption=Translated caption' + LineEnding);
  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals('Translated caption', ReadInterfaceString('Main', 'Caption',
    'Default caption'));
end;

procedure TLocalizationTests.MissingFileUsesDefault;
begin
  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals('Default caption', ReadInterfaceString('Missing', 'Caption',
    'Default caption'));
end;

procedure TLocalizationTests.ReadingBeforeInitializeUsesDefault;
begin
  // SetUp уже вызвал FinalizeLocalization: файлов нет
  AssertTrue(InterfaceIniFile = nil);
  AssertEquals('Default caption', ReadInterfaceString('Main', 'Caption',
    'Default caption'));
  AssertEquals('text', ReadConfigString('Laser', 'Name', 'text'));
  AssertEquals(1000, ReadConfigInteger('Laser', 'EzCAD2OpenTime', 1000));
end;

procedure TLocalizationTests.ReadingAfterFinalizeUsesDefault;
begin
  WriteTextFile(FInterfaceFileName,
    '[Main]' + LineEnding + 'Caption=Translated caption' + LineEnding);
  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals('Translated caption', ReadInterfaceString('Main', 'Caption', ''));

  FinalizeLocalization;

  AssertTrue(InterfaceIniFile = nil);
  AssertEquals('Default caption', ReadInterfaceString('Main', 'Caption',
    'Default caption'));
  // повторный Finalize безопасен
  FinalizeLocalization;
end;

procedure TLocalizationTests.ReinitializeReadsNewFiles;
var
  OtherFileName: string;
begin
  WriteTextFile(FInterfaceFileName,
    '[Main]' + LineEnding + 'Caption=First' + LineEnding);
  OtherFileName := IncludeTrailingPathDelimiter(FDirectory) + 'Other.ini';
  WriteTextFile(OtherFileName,
    '[Main]' + LineEnding + 'Caption=Second' + LineEnding);

  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals('First', ReadInterfaceString('Main', 'Caption', ''));
  InitializeLocalization(OtherFileName, FConfigFileName);
  AssertEquals('Second', ReadInterfaceString('Main', 'Caption', ''));
end;

procedure TLocalizationTests.ConfigValuesAreReadSeparatelyFromCaptions;
begin
  WriteTextFile(FInterfaceFileName,
    '[Laser]' + LineEnding + 'EzCAD2OpenTime=1' + LineEnding);
  WriteTextFile(FConfigFileName,
    '[Laser]' + LineEnding + 'EzCAD2OpenTime=2500' + LineEnding +
    'Name=pen' + LineEnding);
  InitializeLocalization(FInterfaceFileName, FConfigFileName);
  AssertEquals(2500, ReadConfigInteger('Laser', 'EzCAD2OpenTime', 1000));
  AssertEquals('pen', ReadConfigString('Laser', 'Name', ''));
  AssertEquals('1', ReadInterfaceString('Laser', 'EzCAD2OpenTime', ''));
end;

initialization
  RegisterTest(TLocalizationTests);

end.
