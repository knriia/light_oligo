unit SynthesisFolderTests;
// Тесты действий над папкой синтеза: имя, копии слоёв и протоколов,
// synthesis.ini и итог.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry, OligoSlices,
  ProtocolModel, SynthesisFolder;

type
  TSynthesisFolderTests = class(TTestCase)
  private
    FRoot: string;        // временная папка теста
    function Path(const ARelative: string): string;
    procedure WriteText(const AFileName, AText: string);
    function ReadText(const AFileName: string): string;
    function AddLayer(var ATable: TSliceLayers; ANumber: Integer;
      const ALetter, AEzdFile: string): Integer;
    function Moment: TDateTime;
    function Later: TDateTime;
    function Ini(const AFolder: string): TMemIniFile;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ArrayNameComesFromArrayFolderNotFromEzdFolder;
    procedure FolderNameHasDateTimeAndSafeArrayName;
    procedure FolderNameWithoutArrayIsOnlyDateTime;
    procedure LayersAreCopiedIntoLayersFolder;
    procedure SameEzdFileIsCopiedOnce;
    procedure EzdFilesWithSameNameGetDistinctCopies;
    procedure MissingLayerFileFailsNamingLayerAndFile;
    procedure ProtocolCopyIsWrittenAsIs;
    procedure ProtocolCopyFailureNamesFile;
    procedure InfoIsWrittenAndReadBack;
    procedure StartIsAddedToInfo;
    procedure ReadInfoRejectsMissingAndForeignFiles;
    procedure ResultIsAppendedToInfo;
    procedure ResultReportsMissingFolder;
    procedure RemoveDirectoryTreeRemovesNestedFiles;
  end;

implementation

procedure TSynthesisFolderTests.SetUp;
begin
  inherited SetUp;
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_synfolder_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FRoot));
end;

procedure TSynthesisFolderTests.TearDown;
begin
  RemoveDirectoryTree(FRoot);
  inherited TearDown;
end;

function TSynthesisFolderTests.Path(const ARelative: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FRoot) + ARelative;
end;

procedure TSynthesisFolderTests.WriteText(const AFileName, AText: string);
var
  F: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  F := TStringList.Create;
  try
    F.Text := AText;
    F.SaveToFile(AFileName);
  finally
    F.Free;
  end;
end;

function TSynthesisFolderTests.ReadText(const AFileName: string): string;
var
  F: TStringList;
begin
  F := TStringList.Create;
  try
    F.LoadFromFile(AFileName);
    Result := Trim(F.Text);
  finally
    F.Free;
  end;
end;

function TSynthesisFolderTests.AddLayer(var ATable: TSliceLayers;
  ANumber: Integer; const ALetter, AEzdFile: string): Integer;
begin
  Result := Length(ATable);
  SetLength(ATable, Result + 1);
  ATable[Result] := Default(TSliceLayer);
  ATable[Result].LayerNumber := ANumber;
  ATable[Result].Letter := ALetter;
  ATable[Result].EZDFile := AEzdFile;
end;

function TSynthesisFolderTests.Moment: TDateTime;
begin
  Result := EncodeDate(2026, 11, 4) + EncodeTime(14, 30, 5, 0);
end;

function TSynthesisFolderTests.Later: TDateTime;
begin
  Result := Moment + EncodeTime(0, 10, 0, 0);
end;

function TSynthesisFolderTests.Ini(const AFolder: string): TMemIniFile;
begin
  Result := TMemIniFile.Create(IncludeTrailingPathDelimiter(AFolder) +
    SYNTHESIS_INFO_FILE);
end;

procedure TSynthesisFolderTests.ArrayNameComesFromArrayFolderNotFromEzdFolder;
var
  T: TSliceLayers;
begin
  T := nil;
  AssertEquals('array', ArrayNameOfLayers(T));
  AddLayer(T, 1, 'A', 'D:\data\arrays\MyArray\ezd\Layer1.ezd');
  AssertEquals('MyArray', ArrayNameOfLayers(T));
  T := nil;
  AddLayer(T, 1, 'A', 'D:\data\arrays\Other\layers\Layer1.ezd');
  AssertEquals('Other', ArrayNameOfLayers(T));
  T := nil;
  AddLayer(T, 1, 'A', 'D:\data\arrays\Plain\Layer1.ezd');
  AssertEquals('Plain', ArrayNameOfLayers(T));
end;

procedure TSynthesisFolderTests.FolderNameHasDateTimeAndSafeArrayName;
begin
  AssertEquals('2026-11-04_143005_MyArray',
    SynthesisFolderName('MyArray', Moment));
  AssertEquals('2026-11-04_143005_a_b_c_d',
    SynthesisFolderName('a/b:c*d', Moment));
  AssertEquals('name', SafeFolderPart('name...'));
  AssertEquals(60, Length(SafeFolderPart(StringOfChar('x', 200))));
end;

procedure TSynthesisFolderTests.FolderNameWithoutArrayIsOnlyDateTime;
begin
  AssertEquals('2026-11-04_143005', SynthesisFolderName('', Moment));
end;

procedure TSynthesisFolderTests.LayersAreCopiedIntoLayersFolder;
var
  T, Copies: TSliceLayers;
  ErrorText, Folder: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'Layer1.ezd'), 'ezd-one');
  WriteText(Path('a' + PathDelim + 'Layer2.ezd'), 'ezd-two');
  AddLayer(T, 7, 'A', Path('a' + PathDelim + 'Layer1.ezd'));
  AddLayer(T, 8, 'T', Path('a' + PathDelim + 'Layer2.ezd'));
  Folder := Path('syn');
  AssertTrue(ErrorText, CopyLayersToFolder(T, Folder, Copies, ErrorText));
  AssertEquals(2, Length(Copies));
  AssertEquals(7, Copies[0].LayerNumber);
  AssertEquals('T', Copies[1].Letter);
  AssertEquals(LayersFolderOf(Folder) + 'Layer1.ezd', Copies[0].EZDFile);
  AssertEquals('ezd-one', ReadText(Copies[0].EZDFile));
  AssertEquals('ezd-two', ReadText(Copies[1].EZDFile));
  AssertEquals('исходные слои не тронуты', Path('a' + PathDelim + 'Layer1.ezd'),
    T[0].EZDFile);
end;

procedure TSynthesisFolderTests.SameEzdFileIsCopiedOnce;
var
  T, Copies: TSliceLayers;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L.ezd'), 'same');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L.ezd'));
  AddLayer(T, 2, 'A', Path('a' + PathDelim + 'L.ezd'));
  AssertTrue(ErrorText, CopyLayersToFolder(T, Path('syn'), Copies, ErrorText));
  AssertEquals(Copies[0].EZDFile, Copies[1].EZDFile);
  AssertFalse(FileExists(LayersFolderOf(Path('syn')) + 'L_2.ezd'));
end;

procedure TSynthesisFolderTests.EzdFilesWithSameNameGetDistinctCopies;
var
  T, Copies: TSliceLayers;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L.ezd'), 'from a');
  WriteText(Path('b' + PathDelim + 'L.ezd'), 'from b');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L.ezd'));
  AddLayer(T, 2, 'A', Path('b' + PathDelim + 'L.ezd'));
  AssertTrue(ErrorText, CopyLayersToFolder(T, Path('syn'), Copies, ErrorText));
  AssertTrue(Copies[0].EZDFile <> Copies[1].EZDFile);
  AssertEquals('from a', ReadText(Copies[0].EZDFile));
  AssertEquals('from b', ReadText(Copies[1].EZDFile));
end;

procedure TSynthesisFolderTests.MissingLayerFileFailsNamingLayerAndFile;
var
  T, Copies: TSliceLayers;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L1.ezd'), '1');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L1.ezd'));
  AddLayer(T, 5, 'A', Path('a' + PathDelim + 'gone.ezd'));
  AssertFalse(CopyLayersToFolder(T, Path('syn'), Copies, ErrorText));
  AssertTrue(ErrorText, Pos('gone.ezd', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('5', ErrorText) > 0);   // номер слоя
end;

procedure TSynthesisFolderTests.ProtocolCopyIsWrittenAsIs;
var
  Model: TProtocolModel;
  ErrorText: string;
begin
  WriteText(Path('A.pro'), 'Block=BlockA;' + LineEnding + #9'Pause=5;');
  Model := TProtocolModel.Create;
  try
    AssertTrue(ErrorText, Model.LoadFromFile(Path('A.pro'), ErrorText));
    AssertTrue(ErrorText, WriteProtocolCopy(Model, 'A', Path('syn'), ErrorText));
    AssertEquals(Trim(Model.ToText),
      ReadText(Path('syn' + PathDelim + 'protocols' + PathDelim + 'A.pro')));
  finally
    Model.Free;
  end;
end;

procedure TSynthesisFolderTests.ProtocolCopyFailureNamesFile;
var
  Model: TProtocolModel;
  ErrorText: string;
begin
  WriteText(Path('A.pro'), 'Block=BlockA;' + LineEnding + #9'Pause=5;');
  // на месте папки protocols лежит файл: создать её нельзя
  WriteText(Path('syn' + PathDelim + 'protocols'), 'file in the way');
  Model := TProtocolModel.Create;
  try
    AssertTrue(ErrorText, Model.LoadFromFile(Path('A.pro'), ErrorText));
    AssertFalse(WriteProtocolCopy(Model, 'A', Path('syn'), ErrorText));
    AssertTrue(ErrorText, Pos('protocols', ErrorText) > 0);
  finally
    Model.Free;
  end;
end;

procedure TSynthesisFolderTests.InfoIsWrittenAndReadBack;
var
  Letters: TStringList;
  ErrorText: string;
  I: TMemIniFile;
  Info: TSynthesisInfo;
begin
  ForceDirectories(Path('syn'));
  Letters := TStringList.Create;
  try
    Letters.Add('A');
    Letters.Add('T');
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', 'D:\src', 2,
      Letters, Moment, ErrorText));
  finally
    Letters.Free;
  end;
  I := Ini(Path('syn'));
  try
    AssertEquals('LightOligo', I.ReadString('Synthesis', 'Program', ''));
    AssertEquals('2026-11-04 14:30:05', I.ReadString('Synthesis', 'Saved', ''));
    AssertEquals('A,T', I.ReadString('Synthesis', 'Letters', ''));
    AssertFalse('запуска ещё не было', I.ValueExists('Synthesis', 'Started'));
  finally
    I.Free;
  end;
  AssertTrue(ErrorText, ReadSynthesisInfo(Path('syn' + PathDelim +
    SYNTHESIS_INFO_FILE), Info, ErrorText));
  AssertEquals('Arr1', Info.ArrayName);
  AssertEquals('D:\src', Info.SourceFolder);
  AssertEquals(2, Info.LayerCount);
  AssertFalse(Info.Started);
end;

procedure TSynthesisFolderTests.StartIsAddedToInfo;
var
  Letters: TStringList;
  ErrorText: string;
  Info: TSynthesisInfo;
begin
  ForceDirectories(Path('syn'));
  Letters := TStringList.Create;
  try
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', '', 1,
      Letters, Moment, ErrorText));
  finally
    Letters.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisStart(Path('syn'), Later, ErrorText));
  AssertTrue(ErrorText, ReadSynthesisInfo(Path('syn' + PathDelim +
    SYNTHESIS_INFO_FILE), Info, ErrorText));
  AssertTrue(Info.Started);
  AssertEquals('Arr1', Info.ArrayName);
  AssertFalse(SaveSynthesisStart(Path('nowhere'), Later, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TSynthesisFolderTests.ReadInfoRejectsMissingAndForeignFiles;
var
  Info: TSynthesisInfo;
  ErrorText: string;
begin
  AssertFalse(ReadSynthesisInfo(Path('none.ini'), Info, ErrorText));
  AssertTrue(ErrorText, Pos('none.ini', ErrorText) > 0);
  WriteText(Path('other.ini'), '[Laser]' + LineEnding + 'A=1');
  AssertFalse(ReadSynthesisInfo(Path('other.ini'), Info, ErrorText));
  AssertTrue(ErrorText, Pos('other.ini', ErrorText) > 0);
end;

procedure TSynthesisFolderTests.ResultIsAppendedToInfo;
var
  Letters: TStringList;
  ErrorText: string;
  I: TMemIniFile;
begin
  ForceDirectories(Path('syn'));
  Letters := TStringList.Create;
  try
    Letters.Add('A');
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', '', 1,
      Letters, Moment, ErrorText));
  finally
    Letters.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisResult(Path('syn'), srStopped,
    Moment + EncodeTime(0, 10, 0, 0), ErrorText));
  I := Ini(Path('syn'));
  try
    AssertEquals('stopped', I.ReadString('Result', 'Status', ''));
    AssertEquals('2026-11-04 14:40:05', I.ReadString('Result', 'Finished', ''));
    AssertEquals('сохранённое не потеряно', 'A', I.ReadString('Synthesis', 'Letters', ''));
  finally
    I.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisResult(Path('syn'), srFailed, Moment, ErrorText));
  I := Ini(Path('syn'));
  try
    AssertEquals('failed', I.ReadString('Result', 'Status', ''));
  finally
    I.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisResult(Path('syn'), srCompleted, Moment, ErrorText));
  I := Ini(Path('syn'));
  try
    AssertEquals('completed', I.ReadString('Result', 'Status', ''));
  finally
    I.Free;
  end;
end;

procedure TSynthesisFolderTests.ResultReportsMissingFolder;
var
  ErrorText: string;
begin
  AssertFalse(SaveSynthesisResult(Path('nowhere' + PathDelim + 'deeper'),
    srCompleted, Moment, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TSynthesisFolderTests.RemoveDirectoryTreeRemovesNestedFiles;
begin
  WriteText(Path('x' + PathDelim + 'y' + PathDelim + 'f.txt'), 'f');
  RemoveDirectoryTree(Path('x'));
  AssertFalse(DirectoryExists(Path('x')));
  RemoveDirectoryTree(Path('x'));   // нет папки - не ошибка
end;

initialization
  RegisterTest(TSynthesisFolderTests);

end.
