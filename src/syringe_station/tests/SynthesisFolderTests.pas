unit SynthesisFolderTests;
// Тесты папки запуска синтеза: имя, копии слоёв и протоколов, synthesis.ini.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry, OligoSlices,
  ProtocolModel, SynthesisSession, SynthesisFolder;

type
  TSynthesisFolderTests = class(TTestCase)
  private
    FRoot: string;        // временная папка теста
    FSession: TSynthesisSession;
    function Path(const ARelative: string): string;
    procedure WriteText(const AFileName, AText: string);
    function ReadText(const AFileName: string): string;
    function AddLayer(var ATable: TSliceLayers; ANumber: Integer;
      const ALetter, AEzdFile: string): Integer;
    procedure LoadProtocol(const ALetter, ABlock: string);
    function Moment: TDateTime;
    procedure RemoveTree(const ADirectory: string);
    function Ini(const AFolder: string): TMemIniFile;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure ArrayNameComesFromArrayFolderNotFromEzdFolder;
    procedure FolderNameHasDateTimeAndSafeArrayName;
    procedure SnapshotCopiesLayersAndProtocolsAndWritesInfo;
    procedure SnapshotLayersPointIntoSnapshotFolder;
    procedure SlicesLaysOfSnapshotLoadsBack;
    procedure OnlyProtocolsOfUsedLettersAreCopied;
    procedure SameMomentGetsSecondFolderWithSuffix;
    procedure SameEzdFileIsCopiedOnce;
    procedure EzdFilesWithSameNameGetDistinctCopies;
    procedure MissingLayerFileFailsAndLeavesNoFolder;
    procedure NoLayersFails;
    procedure ResultIsAppendedToInfo;
    procedure ResultReportsMissingFolder;
  end;

implementation

procedure TSynthesisFolderTests.SetUp;
begin
  inherited SetUp;
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_synfolder_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FRoot));
  FSession := TSynthesisSession.Create;
end;

procedure TSynthesisFolderTests.TearDown;
begin
  FSession.Free;
  RemoveTree(FRoot);
  inherited TearDown;
end;

procedure TSynthesisFolderTests.RemoveTree(const ADirectory: string);
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

procedure TSynthesisFolderTests.LoadProtocol(const ALetter, ABlock: string);
var
  Letter, ErrorText: string;
begin
  WriteText(Path('src_protocols' + PathDelim + ALetter + '.pro'),
    'Block=' + ABlock + ';' + LineEnding + #9'Pause=5;');
  AssertTrue(ErrorText, FSession.AddProtocolFile(
    Path('src_protocols' + PathDelim + ALetter + '.pro'), Letter, ErrorText));
end;

function TSynthesisFolderTests.Moment: TDateTime;
begin
  Result := EncodeDate(2026, 11, 4) + EncodeTime(14, 30, 5, 0);
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
  AssertEquals('2026-11-04_143005_array', SynthesisFolderName('', Moment));
  AssertEquals('name', SafeFolderPart('name...'));
  AssertEquals(60, Length(SafeFolderPart(StringOfChar('x', 200))));
end;

procedure TSynthesisFolderTests.SnapshotCopiesLayersAndProtocolsAndWritesInfo;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText, Folder: string;
  I: TMemIniFile;
begin
  T := nil;
  WriteText(Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd'), 'ezd-one');
  WriteText(Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd' + PathDelim + 'Layer2.ezd'), 'ezd-two');
  AddLayer(T, 1, 'A', Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd'));
  AddLayer(T, 2, 'T', Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd' + PathDelim + 'Layer2.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'BlockA');
  LoadProtocol('T', 'BlockT');

  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syntheses'),
    Moment, Snap, ErrorText));
  Folder := Snap.Folder;
  AssertEquals(Path('syntheses' + PathDelim + '2026-11-04_143005_Arr1'), Folder);
  AssertEquals(IncludeTrailingPathDelimiter(Folder) + 'log.txt', Snap.LogFile);
  AssertEquals('ezd-one', ReadText(Folder + PathDelim + 'layers' + PathDelim + 'Layer1.ezd'));
  AssertEquals('ezd-two', ReadText(Folder + PathDelim + 'layers' + PathDelim + 'Layer2.ezd'));
  AssertEquals(FSession.ProtocolOf('A').ToText,
    ReadText(Folder + PathDelim + 'protocols' + PathDelim + 'A.pro') + LineEnding);
  AssertTrue(FileExists(Folder + PathDelim + 'protocols' + PathDelim + 'T.pro'));
  AssertTrue(FileExists(Folder + PathDelim + 'Slices.lays'));

  I := Ini(Folder);
  try
    AssertEquals('LightOligo', I.ReadString('Synthesis', 'Program', ''));
    AssertEquals('2026-11-04 14:30:05', I.ReadString('Synthesis', 'Started', ''));
    AssertEquals('Arr1', I.ReadString('Synthesis', 'ArrayName', ''));
    AssertEquals(2, I.ReadInteger('Synthesis', 'LayerCount', 0));
    AssertEquals('A,T', I.ReadString('Synthesis', 'Letters', ''));
    AssertTrue(I.ReadString('Synthesis', 'SourceFolder', '') <> '');
  finally
    I.Free;
  end;
end;

procedure TSynthesisFolderTests.SnapshotLayersPointIntoSnapshotFolder;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'Layer1.ezd'), 'x');
  AddLayer(T, 7, 'A', Path('a' + PathDelim + 'Layer1.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertEquals(1, Length(Snap.Layers));
  AssertEquals(7, Snap.Layers[0].LayerNumber);
  AssertEquals('A', Snap.Layers[0].Letter);
  AssertEquals(Snap.Folder + PathDelim + 'layers' + PathDelim + 'Layer1.ezd',
    Snap.Layers[0].EZDFile);
  AssertTrue(FileExists(Snap.Layers[0].EZDFile));
  AssertEquals('исходный слой сессии не тронут', Path('a' + PathDelim + 'Layer1.ezd'),
    FSession.Layers[0].EZDFile);
end;

procedure TSynthesisFolderTests.SlicesLaysOfSnapshotLoadsBack;
var
  T, Loaded: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L1.ezd'), '1');
  WriteText(Path('a' + PathDelim + 'L2.ezd'), '2');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L1.ezd'));
  AddLayer(T, 2, 'A', Path('a' + PathDelim + 'L2.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertTrue(ErrorText, LoadSliceLayers(Snap.Folder + PathDelim + 'Slices.lays',
    Loaded, ErrorText));
  AssertEquals(2, Length(Loaded));
  AssertEquals(Snap.Layers[1].EZDFile, Loaded[1].EZDFile);
end;

procedure TSynthesisFolderTests.OnlyProtocolsOfUsedLettersAreCopied;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L1.ezd'), '1');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L1.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  LoadProtocol('G', 'Extra');   // загружен, но слоёв с G нет
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertTrue(FileExists(Snap.Folder + PathDelim + 'protocols' + PathDelim + 'A.pro'));
  AssertFalse(FileExists(Snap.Folder + PathDelim + 'protocols' + PathDelim + 'G.pro'));
end;

procedure TSynthesisFolderTests.SameMomentGetsSecondFolderWithSuffix;
var
  T: TSliceLayers;
  First, Second: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('arr' + PathDelim + 'L1.ezd'), '1');
  AddLayer(T, 1, 'A', Path('arr' + PathDelim + 'L1.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    First, ErrorText));
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Second, ErrorText));
  AssertTrue(First.Folder <> Second.Folder);
  AssertEquals(First.Folder + '_2', Second.Folder);
  AssertTrue(DirectoryExists(First.Folder));
  AssertTrue(DirectoryExists(Second.Folder));
end;

procedure TSynthesisFolderTests.SameEzdFileIsCopiedOnce;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L.ezd'), 'same');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L.ezd'));
  AddLayer(T, 2, 'A', Path('a' + PathDelim + 'L.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertEquals(Snap.Layers[0].EZDFile, Snap.Layers[1].EZDFile);
  AssertFalse(FileExists(Snap.Folder + PathDelim + 'layers' + PathDelim + 'L_2.ezd'));
end;

procedure TSynthesisFolderTests.EzdFilesWithSameNameGetDistinctCopies;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L.ezd'), 'from a');
  WriteText(Path('b' + PathDelim + 'L.ezd'), 'from b');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L.ezd'));
  AddLayer(T, 2, 'A', Path('b' + PathDelim + 'L.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertTrue(Snap.Layers[0].EZDFile <> Snap.Layers[1].EZDFile);
  AssertEquals('from a', ReadText(Snap.Layers[0].EZDFile));
  AssertEquals('from b', ReadText(Snap.Layers[1].EZDFile));
end;

procedure TSynthesisFolderTests.MissingLayerFileFailsAndLeavesNoFolder;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L1.ezd'), '1');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L1.ezd'));
  AddLayer(T, 5, 'A', Path('a' + PathDelim + 'gone.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertFalse(CreateSynthesisSnapshot(FSession, Path('syn'), Moment, Snap,
    ErrorText));
  AssertTrue(ErrorText, Pos('gone.ezd', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('5', ErrorText) > 0);   // номер слоя
  AssertEquals('', Snap.Folder);
  AssertFalse('недоделанная папка удалена',
    DirectoryExists(Path('syn' + PathDelim + '2026-11-04_143005_a')));
  AssertFalse(DirectoryExists(Path('syn' + PathDelim + '2026-11-04_143005_array')));
end;

procedure TSynthesisFolderTests.NoLayersFails;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  AssertFalse(CreateSynthesisSnapshot(FSession, Path('syn'), Moment, Snap,
    ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TSynthesisFolderTests.ResultIsAppendedToInfo;
var
  T: TSliceLayers;
  Snap: TSynthesisSnapshot;
  ErrorText: string;
  I: TMemIniFile;
begin
  T := nil;
  WriteText(Path('a' + PathDelim + 'L1.ezd'), '1');
  AddLayer(T, 1, 'A', Path('a' + PathDelim + 'L1.ezd'));
  FSession.SetLayers(T);
  LoadProtocol('A', 'B');
  AssertTrue(ErrorText, CreateSynthesisSnapshot(FSession, Path('syn'), Moment,
    Snap, ErrorText));
  AssertTrue(ErrorText, SaveSynthesisResult(Snap.Folder, srStopped,
    Moment + EncodeTime(0, 10, 0, 0), ErrorText));
  I := Ini(Snap.Folder);
  try
    AssertEquals('stopped', I.ReadString('Result', 'Status', ''));
    AssertEquals('2026-11-04 14:40:05', I.ReadString('Result', 'Finished', ''));
    AssertEquals('запуск не потерян', 'A', I.ReadString('Synthesis', 'Letters', ''));
  finally
    I.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisResult(Snap.Folder, srFailed, Moment, ErrorText));
  I := Ini(Snap.Folder);
  try
    AssertEquals('failed', I.ReadString('Result', 'Status', ''));
  finally
    I.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisResult(Snap.Folder, srCompleted, Moment, ErrorText));
  I := Ini(Snap.Folder);
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

initialization
  RegisterTest(TSynthesisFolderTests);

end.
