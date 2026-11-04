unit SynthesisWorkspaceTests;
// Тесты собираемого синтеза: файлы копируются в папку только при сохранении,
// сохранённый синтез открывается, запуск требует сохранённого и неизменённого.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry, OligoSlices,
  SynthesisFolder, SynthesisWorkspace;

type
  TSynthesisWorkspaceTests = class(TTestCase)
  private
    FRoot: string;
    FWs: TSynthesisWorkspace;
    function Path(const ARelative: string): string;
    procedure WriteText(const AFileName, AText: string);
    function ReadText(const AFileName: string): string;
    function Moment: TDateTime;
    function Later: TDateTime;
    function MakeLayers(const AArray, ALetter: string; ACount: Integer): TSliceLayers;
    procedure AddProtocol(const ALetter: string);
    procedure LoadLayers(const AArray, ALetter: string; ACount: Integer);
    function SaveTo(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure LoadingCopiesNothingUntilSaved;
    procedure InvalidProtocolIsRefusedAndNothingChanges;
    procedure DuplicateLetterIsRefused;
    procedure LayersFileLoadsFromOriginalPlace;
    procedure SaveCopiesLayersProtocolsAndWritesSynthesisFile;
    procedure SessionUsesCopiesAfterSave;
    procedure SaveNeedsSomethingToSave;
    procedure SaveRefusesNonEmptyForeignFolder;
    procedure SaveFailureRemovesNewFolderAndKeepsSession;
    procedure SaveAgainToSameFolderReplacesLayers;
    procedure SaveAgainKeepsStoredLayers;
    procedure ChangeAfterSaveNeedsSaveAgain;
    procedure OpenLoadsSavedSynthesis;
    procedure OpenRejectsForeignFileAndMissingLayers;
    procedure StartRequiresSaveAndNoChanges;
    procedure StartWritesStartedAndGivesSnapshot;
    procedure StartedSynthesisIsNotStartedOrSavedOverAgain;
    procedure StartedSynthesisCanBeSavedElsewhereAndStartedAgain;
    procedure OpenedStartedSynthesisKnowsItWasStarted;
    procedure NewSynthesisClearsSessionButKeepsFiles;
  end;

implementation

procedure TSynthesisWorkspaceTests.SetUp;
begin
  inherited SetUp;
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_workspace_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FRoot));
  FWs := TSynthesisWorkspace.Create;
end;

procedure TSynthesisWorkspaceTests.TearDown;
begin
  FWs.Free;
  RemoveDirectoryTree(FRoot);
  inherited TearDown;
end;

function TSynthesisWorkspaceTests.Path(const ARelative: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FRoot) + ARelative;
end;

procedure TSynthesisWorkspaceTests.WriteText(const AFileName, AText: string);
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

function TSynthesisWorkspaceTests.ReadText(const AFileName: string): string;
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

function TSynthesisWorkspaceTests.Moment: TDateTime;
begin
  Result := EncodeDate(2026, 11, 4) + EncodeTime(14, 30, 5, 0);
end;

function TSynthesisWorkspaceTests.Later: TDateTime;
begin
  Result := Moment + EncodeTime(0, 10, 0, 0);
end;

function TSynthesisWorkspaceTests.MakeLayers(const AArray, ALetter: string;
  ACount: Integer): TSliceLayers;
var
  I: Integer;
  FileName: string;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    FileName := Path('arrays' + PathDelim + AArray + PathDelim + 'ezd' +
      PathDelim + 'Layer' + IntToStr(I + 1) + '.ezd');
    WriteText(FileName, AArray + ' layer ' + IntToStr(I + 1));
    Result[I] := Default(TSliceLayer);
    Result[I].LayerNumber := I + 1;
    Result[I].Letter := ALetter;
    Result[I].EZDFile := FileName;
  end;
end;

procedure TSynthesisWorkspaceTests.AddProtocol(const ALetter: string);
var
  Letter, ErrorText: string;
begin
  WriteText(Path('protocols' + PathDelim + ALetter + '.pro'),
    'Block=Block' + ALetter + ';' + LineEnding + #9'Pause=5;');
  AssertTrue(ErrorText, FWs.AddProtocolFile(
    Path('protocols' + PathDelim + ALetter + '.pro'), Letter, ErrorText));
end;

procedure TSynthesisWorkspaceTests.LoadLayers(const AArray, ALetter: string;
  ACount: Integer);
begin
  FWs.ReplaceLayers(MakeLayers(AArray, ALetter, ACount));
end;

function TSynthesisWorkspaceTests.SaveTo(const AName: string): string;
var
  ErrorText: string;
begin
  Result := Path('syntheses' + PathDelim + AName);
  AssertTrue(ErrorText, FWs.Save(Result, Moment, ErrorText));
end;

procedure TSynthesisWorkspaceTests.LoadingCopiesNothingUntilSaved;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 2);
  AssertEquals('', FWs.Folder);
  AssertTrue(FWs.NeedsSave);
  AssertFalse(DirectoryExists(Path('syntheses')));
  AssertEquals('слои пока исходные',
    Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd'),
    FWs.Session.Layers[0].EZDFile);
end;

procedure TSynthesisWorkspaceTests.InvalidProtocolIsRefusedAndNothingChanges;
var
  Letter, ErrorText: string;
begin
  AssertFalse(FWs.AddProtocolFile(Path('nothing.pro'), Letter, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertFalse(FWs.NeedsSave);
end;

procedure TSynthesisWorkspaceTests.DuplicateLetterIsRefused;
var
  Letter, ErrorText: string;
begin
  AddProtocol('A');
  WriteText(Path('other' + PathDelim + 'A.pro'),
    'Block=Other;' + LineEnding + #9'Pause=9;');
  AssertFalse(FWs.AddProtocolFile(Path('other' + PathDelim + 'A.pro'), Letter,
    ErrorText));
  AssertEquals(1, FWs.Session.ProtocolCount);
end;

procedure TSynthesisWorkspaceTests.LayersFileLoadsFromOriginalPlace;
var
  Layers: TSliceLayers;
  ErrorText: string;
begin
  Layers := MakeLayers('Arr1', 'A', 2);
  AssertTrue(ErrorText, SaveSliceStatistics(Path('arrays' + PathDelim + 'Arr1'),
    Layers, SLICES_EZD_FILE, ErrorText));
  AssertTrue(ErrorText, FWs.AddLayersFile(Path('arrays' + PathDelim + 'Arr1' +
    PathDelim + 'Slices.lays'), ErrorText));
  AssertEquals(2, FWs.Session.LayerCount);
  AssertEquals(Layers[1].EZDFile, FWs.Session.Layers[1].EZDFile);
  AssertFalse(FWs.AddLayersFile(Path('arrays' + PathDelim + 'none.lays'), ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals('прежние слои на месте', 2, FWs.Session.LayerCount);
end;

procedure TSynthesisWorkspaceTests.SaveCopiesLayersProtocolsAndWritesSynthesisFile;
var
  Folder: string;
  I: TMemIniFile;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 2);
  Folder := SaveTo('first');
  AssertEquals(Folder, FWs.Folder);
  AssertEquals('Arr1 layer 1', ReadText(Folder + PathDelim + 'layers' + PathDelim + 'Layer1.ezd'));
  AssertEquals('Arr1 layer 2', ReadText(Folder + PathDelim + 'layers' + PathDelim + 'Layer2.ezd'));
  AssertEquals(Trim(FWs.Session.ProtocolOf('A').ToText),
    ReadText(Folder + PathDelim + 'protocols' + PathDelim + 'A.pro'));
  AssertTrue(FileExists(Folder + PathDelim + SYNTHESIS_SLICES_FILE));
  I := TMemIniFile.Create(Folder + PathDelim + SYNTHESIS_INFO_FILE);
  try
    AssertEquals('Arr1', I.ReadString('Synthesis', 'ArrayName', ''));
    AssertEquals(2, I.ReadInteger('Synthesis', 'LayerCount', 0));
    AssertEquals('A', I.ReadString('Synthesis', 'Letters', ''));
    AssertEquals('2026-11-04 14:30:05', I.ReadString('Synthesis', 'Saved', ''));
    AssertEquals(Path('arrays' + PathDelim + 'Arr1' + PathDelim + 'ezd'),
      I.ReadString('Synthesis', 'SourceFolder', ''));
  finally
    I.Free;
  end;
  AssertFalse(FWs.NeedsSave);
end;

procedure TSynthesisWorkspaceTests.SessionUsesCopiesAfterSave;
var
  Folder: string;
  Original: string;
begin
  LoadLayers('Arr1', 'A', 1);
  Original := FWs.Session.Layers[0].EZDFile;
  Folder := SaveTo('first');
  AssertEquals(Folder + PathDelim + 'layers' + PathDelim + 'Layer1.ezd',
    FWs.Session.Layers[0].EZDFile);
  AssertTrue('исходный файл не тронут', FileExists(Original));
end;

procedure TSynthesisWorkspaceTests.SaveNeedsSomethingToSave;
var
  ErrorText: string;
begin
  AssertFalse(FWs.Save(Path('syn'), Moment, ErrorText));
  AssertTrue(ErrorText, ErrorText <> '');
  AssertFalse(DirectoryExists(Path('syn')));
end;

procedure TSynthesisWorkspaceTests.SaveRefusesNonEmptyForeignFolder;
var
  ErrorText: string;
begin
  AddProtocol('A');
  WriteText(Path('busy' + PathDelim + 'something.txt'), 'x');
  AssertFalse(FWs.Save(Path('busy'), Moment, ErrorText));
  AssertTrue(ErrorText, Pos('busy', ErrorText) > 0);
  AssertTrue('чужие файлы целы', FileExists(Path('busy' + PathDelim + 'something.txt')));
  AssertEquals('', FWs.Folder);
end;

procedure TSynthesisWorkspaceTests.SaveFailureRemovesNewFolderAndKeepsSession;
var
  Layers: TSliceLayers;
  ErrorText: string;
begin
  Layers := MakeLayers('Arr1', 'A', 2);
  DeleteFile(Layers[1].EZDFile);
  FWs.ReplaceLayers(Layers);
  AssertFalse(FWs.Save(Path('syn'), Moment, ErrorText));
  AssertTrue(ErrorText, Pos('Layer2.ezd', ErrorText) > 0);
  AssertFalse(DirectoryExists(Path('syn')));
  AssertEquals('', FWs.Folder);
  AssertEquals(2, FWs.Session.LayerCount);
  AssertEquals(Layers[0].EZDFile, FWs.Session.Layers[0].EZDFile);
  AssertTrue(FWs.NeedsSave);
end;

procedure TSynthesisWorkspaceTests.SaveAgainToSameFolderReplacesLayers;
var
  Folder, ErrorText: string;
begin
  LoadLayers('Arr1', 'A', 3);
  Folder := SaveTo('first');
  LoadLayers('Arr2', 'A', 1);
  AssertTrue(ErrorText, FWs.Save(Folder, Later, ErrorText));
  AssertEquals(1, FWs.Session.LayerCount);
  AssertEquals('Arr2 layer 1', ReadText(FWs.Session.Layers[0].EZDFile));
  AssertFalse('лишняя копия убрана',
    FileExists(Folder + PathDelim + 'layers' + PathDelim + 'Layer3.ezd'));
end;

procedure TSynthesisWorkspaceTests.SaveAgainKeepsStoredLayers;
var
  Folder, ErrorText: string;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 2);
  Folder := SaveTo('first');
  AddProtocol('G');
  AssertTrue(ErrorText, FWs.Save(Folder, Later, ErrorText));
  AssertEquals('Arr1 layer 2', ReadText(FWs.Session.Layers[1].EZDFile));
  AssertTrue(FileExists(Folder + PathDelim + 'protocols' + PathDelim + 'G.pro'));
  AssertTrue(FileExists(Folder + PathDelim + 'protocols' + PathDelim + 'A.pro'));
end;

procedure TSynthesisWorkspaceTests.ChangeAfterSaveNeedsSaveAgain;
begin
  AddProtocol('A');
  SaveTo('first');
  AssertFalse(FWs.NeedsSave);
  AddProtocol('G');
  AssertTrue(FWs.NeedsSave);
end;

procedure TSynthesisWorkspaceTests.OpenLoadsSavedSynthesis;
var
  Folder, ErrorText: string;
  Other: TSynthesisWorkspace;
begin
  AddProtocol('A');
  AddProtocol('T');
  LoadLayers('Arr1', 'A', 2);
  Folder := SaveTo('first');
  Other := TSynthesisWorkspace.Create;
  try
    AssertTrue(ErrorText, Other.Open(Folder + PathDelim + SYNTHESIS_INFO_FILE,
      ErrorText));
    AssertEquals(Folder, Other.Folder);
    AssertEquals(2, Other.Session.LayerCount);
    AssertEquals(2, Other.Session.ProtocolCount);
    AssertTrue(Other.Session.HasProtocol('T'));
    AssertEquals(Folder + PathDelim + 'layers' + PathDelim + 'Layer2.ezd',
      Other.Session.Layers[1].EZDFile);
    AssertFalse(Other.NeedsSave);
    AssertFalse(Other.Started);
  finally
    Other.Free;
  end;
end;

procedure TSynthesisWorkspaceTests.OpenRejectsForeignFileAndMissingLayers;
var
  Folder, ErrorText: string;
begin
  LoadLayers('Arr1', 'A', 1);
  Folder := SaveTo('first');
  AddProtocol('Z');
  WriteText(Path('other.ini'), '[Laser]' + LineEnding + 'A=1');
  AssertFalse(FWs.Open(Path('other.ini'), ErrorText));
  AssertTrue(ErrorText, ErrorText <> '');
  AssertEquals('прежнее загруженное не тронуто', 1, FWs.Session.ProtocolCount);

  DeleteFile(Folder + PathDelim + SYNTHESIS_SLICES_FILE);
  AssertFalse(FWs.Open(Folder + PathDelim + SYNTHESIS_INFO_FILE, ErrorText));
  AssertTrue(ErrorText, Pos('Slices.lays', ErrorText) > 0);
  AssertEquals('после неудачи пусто', 0, FWs.Session.LayerCount);
  AssertEquals('', FWs.Folder);
end;

procedure TSynthesisWorkspaceTests.StartRequiresSaveAndNoChanges;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  AssertFalse('нет слоёв', FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('слои', ErrorText) > 0);
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 1);
  AssertFalse('не сохранён', FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Сохранить', ErrorText) > 0);
  SaveTo('first');
  AddProtocol('G');
  AssertFalse('изменён после сохранения', FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Сохранить', ErrorText) > 0);
  AssertFalse(FWs.Started);
end;

procedure TSynthesisWorkspaceTests.StartWritesStartedAndGivesSnapshot;
var
  Snap: TSynthesisSnapshot;
  ErrorText, Folder: string;
  Info: TSynthesisInfo;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 2);
  Folder := SaveTo('first');
  AssertTrue(ErrorText, FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(FWs.Started);
  AssertEquals(Folder, Snap.Folder);
  AssertEquals(Folder + PathDelim + SYNTHESIS_LOG_FILE, Snap.LogFile);
  AssertEquals(2, Length(Snap.Layers));
  AssertEquals(Folder + PathDelim + 'layers' + PathDelim + 'Layer1.ezd',
    Snap.Layers[0].EZDFile);
  AssertTrue(ErrorText, ReadSynthesisInfo(Folder + PathDelim + SYNTHESIS_INFO_FILE,
    Info, ErrorText));
  AssertTrue(Info.Started);
end;

procedure TSynthesisWorkspaceTests.StartedSynthesisIsNotStartedOrSavedOverAgain;
var
  Snap: TSynthesisSnapshot;
  ErrorText, Folder: string;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 1);
  Folder := SaveTo('first');
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertFalse(FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('в другую папку', ErrorText) > 0);
  AssertFalse(FWs.Save(Folder, Later, ErrorText));
  AssertTrue(ErrorText, Pos('не перезаписывается', ErrorText) > 0);
end;

procedure TSynthesisWorkspaceTests.StartedSynthesisCanBeSavedElsewhereAndStartedAgain;
var
  First, Second: TSynthesisSnapshot;
  ErrorText, Folder: string;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 2);
  SaveTo('first');
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, First, ErrorText));
  Folder := SaveTo('second');
  AssertFalse(FWs.Started);
  AssertTrue(ErrorText, FWs.PrepareStart(Later, Second, ErrorText));
  AssertTrue(First.Folder <> Second.Folder);
  AssertEquals(Folder, Second.Folder);
  AssertEquals('Arr1 layer 2', ReadText(Second.Layers[1].EZDFile));
  AssertTrue(Pos(Folder, Second.Layers[1].EZDFile) = 1);
  AssertTrue('первая запись цела',
    FileExists(First.Folder + PathDelim + 'layers' + PathDelim + 'Layer2.ezd'));
end;

procedure TSynthesisWorkspaceTests.OpenedStartedSynthesisKnowsItWasStarted;
var
  Snap: TSynthesisSnapshot;
  ErrorText, Folder: string;
  Other: TSynthesisWorkspace;
begin
  AddProtocol('A');
  LoadLayers('Arr1', 'A', 1);
  Folder := SaveTo('first');
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, Snap, ErrorText));
  Other := TSynthesisWorkspace.Create;
  try
    AssertTrue(ErrorText, Other.Open(Folder + PathDelim + SYNTHESIS_INFO_FILE,
      ErrorText));
    AssertTrue(Other.Started);
    AssertFalse(Other.PrepareStart(Later, Snap, ErrorText));
  finally
    Other.Free;
  end;
end;

procedure TSynthesisWorkspaceTests.NewSynthesisClearsSessionButKeepsFiles;
var
  Folder: string;
begin
  AddProtocol('A');
  Folder := SaveTo('first');
  FWs.NewSynthesis;
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertEquals('', FWs.Folder);
  AssertFalse(FWs.NeedsSave);
  AssertFalse(FWs.Started);
  AssertTrue(FileExists(Folder + PathDelim + 'protocols' + PathDelim + 'A.pro'));
  AddProtocol('A');   // та же буква снова допустима
end;

initialization
  RegisterTest(TSynthesisWorkspaceTests);

end.
