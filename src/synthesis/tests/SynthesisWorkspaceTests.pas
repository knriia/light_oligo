unit SynthesisWorkspaceTests;
// Тесты собираемого синтеза: папка создаётся сразу, протоколы и слои пишутся в
// неё по мере добавления, сохранённый синтез открывается, запуск требует
// созданного синтеза со слоями и протоколами, запущенный синтез не меняется.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry, OligoSlices,
  SynthesisPorts, SynthesisFolder, SynthesisWorkspace;

type
  // Подставной порт слоёв: пишет файлы слоёв в папку синтеза так же, как
  // настоящий (ezd\, Slices.lays, geometry.ini, laser.ini), и запоминает вызовы.
  TFakeLayersBuilder = class(TLayersBuilder)
  public
    Status: TLayersBuildStatus;
    LayerCount: Integer;
    BuildCalls: Integer;
    LastSlice: string;
    LastSynthesis: string;
    ShowCalls: Integer;
    ShownSlice: string;
    ShownSynthesis: string;
    function Build(const ASliceFolder, ASynthesisFolder: string;
      out ALayers: TSliceLayers;
      out AErrorText: string): TLayersBuildStatus; override;
    function ShowGeometry(const ASliceFolder, ASynthesisFolder: string;
      out AErrorText: string): Boolean; override;
  end;

  TSynthesisWorkspaceTests = class(TTestCase)
  private
    FRoot: string;
    FProject: string;       // <корень>\projects\Arr1, в нём arrays.csv и slice\
    FSlice: string;         // <проект>\slice со Slices.txt
    FSynth: string;         // <проект>\synthes_2026-11-04
    FWs: TSynthesisWorkspace;
    FBuilder: TFakeLayersBuilder;
    function Path(const ARelative: string): string;
    procedure WriteText(const AFileName, AText: string);
    function ReadText(const AFileName: string): string;
    function Moment: TDateTime;
    function Later: TDateTime;
    function ProtocolFile(const ALetter: string): string;
    procedure CreateSynthesis;
    procedure AddProtocol(const ALetter: string);
    procedure BuildLayers(ACount: Integer);
    function InfoOf(const AFolder: string): TSynthesisInfo;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CreateNewMakesFolderAndInfoFile;
    procedure CreateNewRefusesExistingFolder;
    procedure CreateNewRefusesEmptyFolderName;
    procedure CreateNewReplacesPreviousSynthesis;
    procedure ChangesNeedCreatedSynthesis;
    procedure ProtocolIsCopiedIntoFolderImmediately;
    procedure InvalidProtocolIsRefusedAndNothingChanges;
    procedure DuplicateLetterIsRefused;
    procedure RemoveProtocolRemovesCopyAndLetter;
    procedure RemoveMissingProtocolChangesNothing;
    procedure AddLayersBuildsLayersInSynthesisFolder;
    procedure SliceOutsideProjectIsRefusedWithoutBuilding;
    procedure SliceWithoutStatisticsIsRefusedWithoutBuilding;
    procedure CancelledBuildLeavesSynthesisEmpty;
    procedure FailedBuildRemovesPartialFiles;
    procedure SecondAddLayersIsRefused;
    procedure RemoveLayersDeletesLayerFilesAndKeepsProtocols;
    procedure ShowGeometryWithoutLayersSaysSo;
    procedure ShowGeometryPassesSliceAndSynthesisFolders;
    procedure OpenLoadsCreatedSynthesis;
    procedure OpenRejectsForeignFileAndMissingLayers;
    procedure StartRequiresCreatedSynthesis;
    procedure StartRequiresLayersAndProtocols;
    procedure StartWritesStartedAndGivesSnapshot;
    procedure StartRefusesWhenLayerEzdFileIsGone;
    procedure StartedSynthesisIsNotStartedAgain;
    procedure StartedSynthesisRefusesAnyChange;
    procedure OpenedStartedSynthesisKnowsItWasStarted;
    procedure NewSynthesisClearsSessionButKeepsFiles;
    procedure RemovedProtocolOfLayersMakesStartRefuse;
  end;

implementation

{ TFakeLayersBuilder }

function TFakeLayersBuilder.Build(const ASliceFolder,
  ASynthesisFolder: string; out ALayers: TSliceLayers;
  out AErrorText: string): TLayersBuildStatus;

  procedure PutFile(const AFileName, AText: string);
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

var
  I: Integer;
  FileName: string;
begin
  Inc(BuildCalls);
  LastSlice := ASliceFolder;
  LastSynthesis := ASynthesisFolder;
  ALayers := nil;
  AErrorText := '';
  Result := Status;
  case Status of
    lbsBuilt:
      begin
        SetLength(ALayers, LayerCount);
        for I := 0 to LayerCount - 1 do
        begin
          FileName := EzdFolderOf(ASynthesisFolder) + 'Layer' +
            IntToStr(I + 1) + '.ezd';
          PutFile(FileName, 'ezd ' + IntToStr(I + 1));
          ALayers[I] := Default(TSliceLayer);
          ALayers[I].LayerNumber := I + 1;
          ALayers[I].Letter := 'A';
          ALayers[I].EZDFile := FileName;
        end;
        if not SaveSliceStatistics(ASynthesisFolder, ALayers, SLICES_EZD_FILE,
          AErrorText) then
          Result := lbsFailed;
        PutFile(IncludeTrailingPathDelimiter(ASynthesisFolder) + 'geometry.ini',
          '[Geometry]');
        PutFile(IncludeTrailingPathDelimiter(ASynthesisFolder) + 'laser.ini',
          '[Laser]');
      end;
    lbsFailed:
      begin
        // часть слоёв успела записаться
        PutFile(EzdFolderOf(ASynthesisFolder) + 'Layer1.ezd', 'partial');
        AErrorText := 'builder failed';
      end;
    lbsCancelled:
      ;
  end;
end;

function TFakeLayersBuilder.ShowGeometry(const ASliceFolder,
  ASynthesisFolder: string; out AErrorText: string): Boolean;
begin
  Inc(ShowCalls);
  ShownSlice := ASliceFolder;
  ShownSynthesis := ASynthesisFolder;
  AErrorText := '';
  Result := True;
end;

{ TSynthesisWorkspaceTests }

procedure TSynthesisWorkspaceTests.SetUp;
begin
  inherited SetUp;
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_workspace_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FRoot));
  FProject := Path('projects' + PathDelim + 'Arr1');
  FSlice := FProject + PathDelim + 'slice';
  FSynth := FProject + PathDelim + 'synthes_2026-11-04';
  WriteText(FProject + PathDelim + 'arrays.csv', 'AT;GC');
  WriteText(FSlice + PathDelim + 'Slices.txt', 'Layer');
  FWs := TSynthesisWorkspace.Create;
  FBuilder := TFakeLayersBuilder.Create;
  FBuilder.Status := lbsBuilt;
  FBuilder.LayerCount := 2;
end;

procedure TSynthesisWorkspaceTests.TearDown;
begin
  FBuilder.Free;
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

function TSynthesisWorkspaceTests.ProtocolFile(const ALetter: string): string;
begin
  Result := FSynth + PathDelim + 'protocols' + PathDelim + ALetter + '.pro';
end;

procedure TSynthesisWorkspaceTests.CreateSynthesis;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, FWs.CreateNew(FSynth, Moment, ErrorText));
end;

procedure TSynthesisWorkspaceTests.AddProtocol(const ALetter: string);
var
  Letter, ErrorText: string;
begin
  WriteText(Path('protocols' + PathDelim + ALetter + '.pro'),
    'Block=Block' + ALetter + ';' + LineEnding + #9'Pause=5;');
  AssertTrue(ErrorText, FWs.AddProtocolFile(
    Path('protocols' + PathDelim + ALetter + '.pro'), Letter, ErrorText));
  AssertEquals(ALetter, Letter);
end;

procedure TSynthesisWorkspaceTests.BuildLayers(ACount: Integer);
var
  ErrorText: string;
begin
  FBuilder.Status := lbsBuilt;
  FBuilder.LayerCount := ACount;
  AssertTrue(ErrorText, FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsBuilt);
end;

function TSynthesisWorkspaceTests.InfoOf(const AFolder: string): TSynthesisInfo;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, ReadSynthesisInfo(AFolder + PathDelim +
    SYNTHESIS_INFO_FILE, Result, ErrorText));
end;

procedure TSynthesisWorkspaceTests.CreateNewMakesFolderAndInfoFile;
var
  I: TMemIniFile;
begin
  CreateSynthesis;
  AssertEquals(FSynth, FWs.Folder);
  AssertEquals(FProject, FWs.ProjectDir);
  AssertTrue(DirectoryExists(FSynth));
  I := TMemIniFile.Create(FSynth + PathDelim + SYNTHESIS_INFO_FILE);
  try
    AssertEquals('Arr1', I.ReadString('Synthesis', 'ArrayName', ''));
    AssertEquals('2026-11-04 14:30:05', I.ReadString('Synthesis', 'Created', ''));
    AssertEquals(0, I.ReadInteger('Synthesis', 'LayerCount', -1));
    AssertEquals('', I.ReadString('Synthesis', 'Letters', ''));
  finally
    I.Free;
  end;
  AssertEquals(0, FWs.Session.LayerCount);
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertFalse(FWs.Started);
end;

procedure TSynthesisWorkspaceTests.CreateNewRefusesExistingFolder;
var
  ErrorText: string;
begin
  WriteText(FSynth + PathDelim + 'busy.txt', 'x');
  AssertFalse(FWs.CreateNew(FSynth, Moment, ErrorText));
  AssertTrue(ErrorText, Pos('уже существует', ErrorText) > 0);
  AssertTrue('чужие файлы целы', FileExists(FSynth + PathDelim + 'busy.txt'));
  AssertFalse(FileExists(FSynth + PathDelim + SYNTHESIS_INFO_FILE));
  AssertEquals('', FWs.Folder);
end;

procedure TSynthesisWorkspaceTests.CreateNewRefusesEmptyFolderName;
var
  ErrorText: string;
begin
  AssertFalse(FWs.CreateNew('', Moment, ErrorText));
  AssertTrue(ErrorText, Pos('Не указана папка', ErrorText) > 0);
  AssertEquals('', FWs.Folder);
end;

procedure TSynthesisWorkspaceTests.CreateNewReplacesPreviousSynthesis;
var
  Second, ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  Second := FProject + PathDelim + 'synthes_2026-11-04_2';
  AssertTrue(ErrorText, FWs.CreateNew(Second, Later, ErrorText));
  AssertEquals(Second, FWs.Folder);
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertTrue('прежний синтез остался на диске', FileExists(ProtocolFile('A')));
end;

procedure TSynthesisWorkspaceTests.ChangesNeedCreatedSynthesis;
var
  Letter, ErrorText: string;
begin
  WriteText(Path('A.pro'), 'Block=BlockA;' + LineEnding + #9'Pause=5;');
  AssertFalse(FWs.AddProtocolFile(Path('A.pro'), Letter, ErrorText));
  AssertTrue(ErrorText, Pos('Создать синтез', ErrorText) > 0);
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertTrue(FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsFailed);
  AssertTrue(ErrorText, Pos('Создать синтез', ErrorText) > 0);
  AssertEquals('слои не создавались', 0, FBuilder.BuildCalls);
  AssertFalse(FWs.RemoveProtocol('A', ErrorText));
  AssertFalse(FWs.RemoveLayers(ErrorText));
  AssertFalse(DirectoryExists(FSynth));
end;

procedure TSynthesisWorkspaceTests.ProtocolIsCopiedIntoFolderImmediately;
begin
  CreateSynthesis;
  AddProtocol('A');
  AssertEquals(Trim('Block=BlockA;' + LineEnding + #9'Pause=5;'),
    ReadText(ProtocolFile('A')));
  AssertEquals(1, FWs.Session.ProtocolCount);
  AddProtocol('G');
  AssertTrue(FileExists(ProtocolFile('G')));
  AssertTrue(FileExists(ProtocolFile('A')));
end;

procedure TSynthesisWorkspaceTests.InvalidProtocolIsRefusedAndNothingChanges;
var
  Letter, ErrorText: string;
begin
  CreateSynthesis;
  AssertFalse(FWs.AddProtocolFile(Path('nothing.pro'), Letter, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertFalse(DirectoryExists(FSynth + PathDelim + 'protocols'));
end;

procedure TSynthesisWorkspaceTests.DuplicateLetterIsRefused;
var
  Letter, ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  WriteText(Path('other' + PathDelim + 'A.pro'),
    'Block=Other;' + LineEnding + #9'Pause=9;');
  AssertFalse(FWs.AddProtocolFile(Path('other' + PathDelim + 'A.pro'), Letter,
    ErrorText));
  AssertEquals(1, FWs.Session.ProtocolCount);
  AssertTrue('копия первого протокола не затёрта',
    Pos('BlockA', ReadText(ProtocolFile('A'))) > 0);
end;

procedure TSynthesisWorkspaceTests.RemoveProtocolRemovesCopyAndLetter;
var
  ErrorText: string;
  Info: TMemIniFile;
begin
  CreateSynthesis;
  AddProtocol('A');
  AddProtocol('C');
  AddProtocol('G');
  AssertTrue(ErrorText, FWs.RemoveProtocol('C', ErrorText));
  AssertEquals(2, FWs.Session.ProtocolCount);
  AssertFalse(FWs.Session.HasProtocol('C'));
  AssertEquals('A', FWs.Session.ProtocolLetters[0]);
  AssertEquals('G', FWs.Session.ProtocolLetters[1]);
  AssertFalse(FileExists(ProtocolFile('C')));
  AssertTrue(FileExists(ProtocolFile('A')));
  AssertTrue(FileExists(ProtocolFile('G')));
  Info := TMemIniFile.Create(FSynth + PathDelim + SYNTHESIS_INFO_FILE);
  try
    AssertEquals('A,G', Info.ReadString('Synthesis', 'Letters', ''));
  finally
    Info.Free;
  end;
end;

procedure TSynthesisWorkspaceTests.RemoveMissingProtocolChangesNothing;
var
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  AssertFalse(FWs.RemoveProtocol('T', ErrorText));
  AssertTrue(ErrorText, Pos('Протокол T не найден', ErrorText) > 0);
  AssertEquals(1, FWs.Session.ProtocolCount);
  AssertTrue(FileExists(ProtocolFile('A')));
end;

procedure TSynthesisWorkspaceTests.AddLayersBuildsLayersInSynthesisFolder;
begin
  CreateSynthesis;
  BuildLayers(2);
  AssertEquals(FSlice, FBuilder.LastSlice);
  AssertEquals(FSynth, FBuilder.LastSynthesis);
  AssertEquals(2, FWs.Session.LayerCount);
  AssertEquals(FSynth + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd',
    FWs.Session.Layers[0].EZDFile);
  AssertEquals('ezd 2', ReadText(FWs.Session.Layers[1].EZDFile));
  AssertTrue(FileExists(FSynth + PathDelim + SYNTHESIS_SLICES_FILE));
  AssertEquals(FSlice, FWs.SourceFolder);
  AssertEquals(2, InfoOf(FSynth).LayerCount);
  AssertEquals(FSlice, InfoOf(FSynth).SourceFolder);
end;

procedure TSynthesisWorkspaceTests.SliceOutsideProjectIsRefusedWithoutBuilding;
var
  Other, ErrorText: string;
begin
  CreateSynthesis;
  Other := Path('projects' + PathDelim + 'Other' + PathDelim + 'slice');
  WriteText(Other + PathDelim + 'Slices.txt', 'Layer');
  AssertTrue(FWs.AddLayers(FBuilder, Other, ErrorText) = lbsFailed);
  AssertTrue(ErrorText, Pos('в папке проекта', ErrorText) > 0);
  AssertEquals(0, FBuilder.BuildCalls);
  AssertEquals(0, FWs.Session.LayerCount);
end;

procedure TSynthesisWorkspaceTests.SliceWithoutStatisticsIsRefusedWithoutBuilding;
var
  Empty, ErrorText: string;
begin
  CreateSynthesis;
  Empty := FProject + PathDelim + 'empty';
  ForceDirectories(Empty);
  AssertTrue(FWs.AddLayers(FBuilder, Empty, ErrorText) = lbsFailed);
  AssertTrue(ErrorText, Pos('Slices.txt', ErrorText) > 0);
  AssertEquals(0, FBuilder.BuildCalls);
end;

procedure TSynthesisWorkspaceTests.CancelledBuildLeavesSynthesisEmpty;
var
  ErrorText: string;
begin
  CreateSynthesis;
  FBuilder.Status := lbsCancelled;
  AssertTrue(FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsCancelled);
  AssertEquals(1, FBuilder.BuildCalls);
  AssertEquals(0, FWs.Session.LayerCount);
  AssertEquals('', FWs.SourceFolder);
  AssertFalse(DirectoryExists(FSynth + PathDelim + 'ezd'));
  AssertEquals(0, InfoOf(FSynth).LayerCount);
end;

procedure TSynthesisWorkspaceTests.FailedBuildRemovesPartialFiles;
var
  ErrorText: string;
begin
  CreateSynthesis;
  FBuilder.Status := lbsFailed;
  AssertTrue(FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsFailed);
  AssertEquals('builder failed', ErrorText);
  AssertEquals(0, FWs.Session.LayerCount);
  AssertFalse('недозаписанные EZD убраны',
    DirectoryExists(FSynth + PathDelim + 'ezd'));
  AssertFalse(FileExists(FSynth + PathDelim + SYNTHESIS_SLICES_FILE));
  AssertEquals(0, InfoOf(FSynth).LayerCount);
end;

procedure TSynthesisWorkspaceTests.SecondAddLayersIsRefused;
var
  ErrorText: string;
begin
  CreateSynthesis;
  BuildLayers(2);
  AssertTrue(FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsFailed);
  AssertTrue(ErrorText, Pos('уже загружены', ErrorText) > 0);
  AssertEquals(1, FBuilder.BuildCalls);
  AssertEquals(2, FWs.Session.LayerCount);
end;

procedure TSynthesisWorkspaceTests.RemoveLayersDeletesLayerFilesAndKeepsProtocols;
var
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(2);
  AssertTrue(ErrorText, FWs.RemoveLayers(ErrorText));
  AssertEquals(0, FWs.Session.LayerCount);
  AssertEquals(1, FWs.Session.ProtocolCount);
  AssertFalse(DirectoryExists(FSynth + PathDelim + 'ezd'));
  AssertFalse(FileExists(FSynth + PathDelim + SYNTHESIS_SLICES_FILE));
  AssertFalse(FileExists(FSynth + PathDelim + 'geometry.ini'));
  AssertFalse(FileExists(FSynth + PathDelim + 'laser.ini'));
  AssertTrue(FileExists(ProtocolFile('A')));
  AssertEquals(0, InfoOf(FSynth).LayerCount);
  AssertEquals('', InfoOf(FSynth).SourceFolder);
  AssertEquals('', FWs.SourceFolder);
end;

procedure TSynthesisWorkspaceTests.ShowGeometryWithoutLayersSaysSo;
var
  ErrorText: string;
begin
  CreateSynthesis;
  AssertFalse(FWs.ShowGeometry(FBuilder, ErrorText));
  AssertEquals('Нет загруженных слоёв для просмотра геометрии.', ErrorText);
  AssertEquals(0, FBuilder.ShowCalls);
end;

procedure TSynthesisWorkspaceTests.ShowGeometryPassesSliceAndSynthesisFolders;
var
  ErrorText: string;
begin
  CreateSynthesis;
  BuildLayers(1);
  AssertTrue(ErrorText, FWs.ShowGeometry(FBuilder, ErrorText));
  AssertEquals(1, FBuilder.ShowCalls);
  AssertEquals(FSlice, FBuilder.ShownSlice);
  AssertEquals(FSynth, FBuilder.ShownSynthesis);
end;

procedure TSynthesisWorkspaceTests.OpenLoadsCreatedSynthesis;
var
  ErrorText: string;
  Other: TSynthesisWorkspace;
begin
  CreateSynthesis;
  AddProtocol('A');
  AddProtocol('T');
  BuildLayers(2);
  Other := TSynthesisWorkspace.Create;
  try
    AssertTrue(ErrorText, Other.Open(FSynth + PathDelim + SYNTHESIS_INFO_FILE,
      ErrorText));
    AssertEquals(FSynth, Other.Folder);
    AssertEquals(FProject, Other.ProjectDir);
    AssertEquals(FSlice, Other.SourceFolder);
    AssertEquals(2, Other.Session.LayerCount);
    AssertEquals(2, Other.Session.ProtocolCount);
    AssertTrue(Other.Session.HasProtocol('T'));
    AssertEquals(FSynth + PathDelim + 'ezd' + PathDelim + 'Layer2.ezd',
      Other.Session.Layers[1].EZDFile);
    AssertFalse(Other.Started);
  finally
    Other.Free;
  end;
end;

procedure TSynthesisWorkspaceTests.OpenRejectsForeignFileAndMissingLayers;
var
  ErrorText: string;
begin
  CreateSynthesis;
  BuildLayers(1);
  AddProtocol('Z');
  WriteText(Path('other.ini'), '[Laser]' + LineEnding + 'A=1');
  AssertFalse(FWs.Open(Path('other.ini'), ErrorText));
  AssertTrue(ErrorText, ErrorText <> '');
  AssertEquals('прежнее загруженное не тронуто', 1, FWs.Session.ProtocolCount);

  DeleteFile(FSynth + PathDelim + SYNTHESIS_SLICES_FILE);
  AssertFalse(FWs.Open(FSynth + PathDelim + SYNTHESIS_INFO_FILE, ErrorText));
  AssertTrue(ErrorText, Pos('Slices.lays', ErrorText) > 0);
  AssertEquals('после неудачи пусто', 0, FWs.Session.LayerCount);
  AssertEquals('', FWs.Folder);
end;

procedure TSynthesisWorkspaceTests.StartRequiresCreatedSynthesis;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  AssertFalse(FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Создать синтез', ErrorText) > 0);
  AssertFalse(FWs.Started);
end;

procedure TSynthesisWorkspaceTests.StartRequiresLayersAndProtocols;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  CreateSynthesis;
  AssertFalse('нет слоёв', FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('слои', ErrorText) > 0);
  BuildLayers(1);
  AssertFalse('нет протокола буквы слоя', FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Нет протоколов для букв: A', ErrorText) > 0);
  AssertFalse(FWs.Started);
  AssertFalse('запуск не записан',
    InfoOf(FSynth).Started);
end;

procedure TSynthesisWorkspaceTests.StartWritesStartedAndGivesSnapshot;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(2);
  AssertTrue(ErrorText, FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(FWs.Started);
  AssertEquals(FSynth, Snap.Folder);
  AssertEquals(FSynth + PathDelim + SYNTHESIS_LOG_FILE, Snap.LogFile);
  AssertEquals(2, Length(Snap.Layers));
  AssertEquals(FSynth + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd',
    Snap.Layers[0].EZDFile);
  AssertTrue(InfoOf(FSynth).Started);
end;

procedure TSynthesisWorkspaceTests.StartRefusesWhenLayerEzdFileIsGone;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(2);
  DeleteFile(FWs.Session.Layers[1].EZDFile);
  AssertFalse(FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Слой 2', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('Layer2.ezd', ErrorText) > 0);
  AssertFalse('запуск не записан', FWs.Started);
  AssertFalse(InfoOf(FSynth).Started);
end;

procedure TSynthesisWorkspaceTests.StartedSynthesisIsNotStartedAgain;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(1);
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, Snap, ErrorText));
  AssertFalse(FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('уже запускался', ErrorText) > 0);
end;

procedure TSynthesisWorkspaceTests.StartedSynthesisRefusesAnyChange;
var
  Snap: TSynthesisSnapshot;
  Letter, ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(1);
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, Snap, ErrorText));

  WriteText(Path('G.pro'), 'Block=BlockG;' + LineEnding + #9'Pause=5;');
  AssertFalse(FWs.AddProtocolFile(Path('G.pro'), Letter, ErrorText));
  AssertTrue(ErrorText, Pos('запись выполненного', ErrorText) > 0);
  AssertFalse(FileExists(ProtocolFile('G')));
  AssertEquals(1, FWs.Session.ProtocolCount);

  AssertFalse(FWs.RemoveProtocol('A', ErrorText));
  AssertTrue(ErrorText, Pos('запись выполненного', ErrorText) > 0);
  AssertTrue(FileExists(ProtocolFile('A')));
  AssertTrue(FWs.Session.HasProtocol('A'));

  AssertFalse(FWs.RemoveLayers(ErrorText));
  AssertTrue(ErrorText, Pos('запись выполненного', ErrorText) > 0);
  AssertEquals(1, FWs.Session.LayerCount);
  AssertTrue(FileExists(FWs.Session.Layers[0].EZDFile));

  AssertTrue(FWs.AddLayers(FBuilder, FSlice, ErrorText) = lbsFailed);
  AssertTrue(ErrorText, Pos('запись выполненного', ErrorText) > 0);
  AssertEquals(1, FBuilder.BuildCalls);
end;

procedure TSynthesisWorkspaceTests.OpenedStartedSynthesisKnowsItWasStarted;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
  Other: TSynthesisWorkspace;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(1);
  AssertTrue(ErrorText, FWs.PrepareStart(Moment, Snap, ErrorText));
  Other := TSynthesisWorkspace.Create;
  try
    AssertTrue(ErrorText, Other.Open(FSynth + PathDelim + SYNTHESIS_INFO_FILE,
      ErrorText));
    AssertTrue(Other.Started);
    AssertFalse(Other.PrepareStart(Later, Snap, ErrorText));
    AssertTrue(ErrorText, Pos('уже запускался', ErrorText) > 0);
  finally
    Other.Free;
  end;
end;

procedure TSynthesisWorkspaceTests.NewSynthesisClearsSessionButKeepsFiles;
var
  Letter, ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(1);
  FWs.NewSynthesis;
  AssertEquals(0, FWs.Session.ProtocolCount);
  AssertEquals(0, FWs.Session.LayerCount);
  AssertEquals('', FWs.Folder);
  AssertEquals('', FWs.SourceFolder);
  AssertFalse(FWs.Started);
  AssertTrue(FileExists(ProtocolFile('A')));
  AssertTrue(FileExists(FSynth + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd'));
  AssertFalse('без синтеза менять нечего',
    FWs.AddProtocolFile(Path('protocols' + PathDelim + 'A.pro'), Letter,
      ErrorText));
end;

procedure TSynthesisWorkspaceTests.RemovedProtocolOfLayersMakesStartRefuse;
var
  Snap: TSynthesisSnapshot;
  ErrorText: string;
begin
  CreateSynthesis;
  AddProtocol('A');
  BuildLayers(1);
  AssertTrue(ErrorText, FWs.RemoveProtocol('A', ErrorText));
  AssertFalse(FWs.PrepareStart(Later, Snap, ErrorText));
  AssertTrue(ErrorText, Pos('Нет протоколов для букв: A', ErrorText) > 0);
end;

initialization
  RegisterTest(TSynthesisWorkspaceTests);

end.
