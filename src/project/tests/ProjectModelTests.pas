unit ProjectModelTests;
// Тесты модели проекта: массив, слайсинги, синтезы внутри слайсингов, связь
// синтеза со слайсингом, обновление и создание проекта.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ProjectModel, SynthesisFolder;

type
  TProjectModelTests = class(TTestCase)
  private
    FRoot: string;        // временная папка теста; в ней лежат проекты
    function Path(const ARelative: string): string;
    procedure Touch(const ARelative: string);
    procedure WriteText(const ARelative, AText: string);
    procedure MakeSlice(const AProject, ASliceName: string);
    procedure MakeSynthesis(const AProject, ASliceName, ASynthesisName: string);
    function CountEntries(const AFolder: string): Integer;
    function Open(const ARelative: string): TProject;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpenFolderWithoutCsvGivesEmptyProject;
    procedure OpenFindsSingleCsv;
    procedure OpenTakesArrayNamedInProjectFile;
    procedure OpenHidesDiskItemsMissingFromProjectFile;
    procedure OpenKeepsSynthesesListedInProjectFile;
    procedure OpenFolderWithoutProjectFileIsModifiedUntilSaved;
    procedure RefreshMarksProjectModifiedAndKeepsChangesUntilSaved;
    procedure IncludeArrayAddsHiddenCsvAndMarksModified;
    procedure OpenByProjectFilePathUsesThatFile;
    procedure OpenRefusesUnreadableProjectFile;
    procedure OpenRefusesProjectFileWithPathInName;
    procedure RefreshAddsNewDiskItemsAndSavesThem;
    procedure RefreshKeepsHiddenItemsHidden;
    procedure RefreshDropsItemsDeletedFromDisk;
    procedure OpenRefusesMissingFolder;
    procedure ProjectNameIsFolderName;
    procedure SlicingsAreFoldersWithStatisticsSortedByName;
    procedure SlicingAlgorithmIsNamePartAfterPrefix;
    procedure SlicingWithoutAlgorithmPartHasEmptyAlgorithm;
    procedure SlicingFolderNamedSliceFooIsAcceptedWithEmptyAlgorithm;
    procedure FileNamedLikeSlicingIsNotSlicing;
    procedure UpperCaseCsvExtensionIsArrayFile;
    procedure RootFolderKeepsDelimiterAndNamesDrive;
    procedure SynthesesAreFoldersWithInfoFileInsideSlicing;
    procedure SynthesesBelongToTheirOwnSlicing;
    procedure FileKindCsvIsArray;
    procedure FileKindUpperCaseCsvIsArray;
    procedure FileKindProIsProtocol;
    procedure FileKindSynthesisInfoIsSynthesis;
    procedure FileKindOtherIniIsUnknown;
    procedure FileKindNoExtensionIsUnknown;
    procedure NodesOfEmptyProjectAreProjectOnly;
    procedure NodesListArraySlicingsAndTheirSynthesesInOrder;
    procedure IndexOfSlicingFindsByFolderName;
    procedure SlicingOfSynthesisFollowsParentFolder;
    procedure SlicingOfSynthesisIgnoresFoldersOutsideSlicings;
    procedure RefreshPicksUpNewFolders;
    procedure FailedRefreshKeepsPreviousState;
    procedure RefreshFailsWhenProjectFolderIsDeleted;
    procedure CreateProjectMakesEmptyProjectFolder;
    procedure CreateProjectRefusesExistingFolder;
    procedure CreateProjectRefusesBadNameAndCreatesNothing;
    procedure CreateProjectRefusesMissingParentAndCreatesNothing;
    procedure CreateProjectRefusesNameEndingWithDot;
  end;

implementation

procedure TProjectModelTests.SetUp;
var
  Guid: TGUID;
begin
  inherited SetUp;
  CreateGUID(Guid);
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_project_' + StringReplace(StringReplace(GUIDToString(Guid),
    '{', '', []), '}', '', []);
  AssertTrue('временная папка теста создаётся', ForceDirectories(FRoot));
end;

procedure TProjectModelTests.TearDown;
begin
  RemoveDirectoryTree(FRoot);
  inherited TearDown;
end;

function TProjectModelTests.Path(const ARelative: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FRoot) +
    StringReplace(ARelative, '\', PathDelim, [rfReplaceAll]);
end;

procedure TProjectModelTests.WriteText(const ARelative, AText: string);
var
  F: TStringList;
begin
  ForceDirectories(ExtractFileDir(Path(ARelative)));
  F := TStringList.Create;
  try
    F.Text := AText;
    F.SaveToFile(Path(ARelative));
  finally
    F.Free;
  end;
end;

procedure TProjectModelTests.Touch(const ARelative: string);
begin
  WriteText(ARelative, 'x');
end;

procedure TProjectModelTests.MakeSlice(const AProject, ASliceName: string);
begin
  Touch(AProject + PathDelim + ASliceName + PathDelim + 'Slices.txt');
end;

procedure TProjectModelTests.MakeSynthesis(const AProject, ASliceName,
  ASynthesisName: string);
begin
  Touch(AProject + PathDelim + ASliceName + PathDelim + ASynthesisName +
    PathDelim + 'synthesis.ini');
end;

function TProjectModelTests.CountEntries(const AFolder: string): Integer;
var
  Search: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile,
    Search) = 0 then
  try
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') then
        Inc(Result);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
end;

function TProjectModelTests.Open(const ARelative: string): TProject;
var
  ErrorText: string;
begin
  Result := OpenProject(Path(ARelative), ErrorText);
  AssertEquals('', ErrorText);
  AssertTrue('проект должен открыться', Result <> nil);
end;

procedure TProjectModelTests.OpenFolderWithoutCsvGivesEmptyProject;
var
  P: TProject;
begin
  AssertTrue('папка проекта создаётся', ForceDirectories(Path('p1')));
  P := Open('p1');
  try
    AssertEquals('', P.ArrayFile);
    AssertEquals(0, P.SlicingCount);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenFindsSingleCsv;
var
  P: TProject;
begin
  Touch('p1\data.csv');
  Touch('p1\notes.txt');
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenTakesArrayNamedInProjectFile;
var
  P: TProject;
begin
  Touch('p1\a.csv');
  Touch('p1\b.csv');
  WriteText('p1\p1.OlProj', '{"version":1,"array":"b.csv","slicings":[]}');
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\b.csv')), P.ArrayFile);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenHidesDiskItemsMissingFromProjectFile;
var
  P: TProject;
begin
  Touch('p1\a.csv');
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  WriteText('p1\p1.OlProj',
    '{"version":1,"array":"","slicings":[{"folder":"slice_base","syntheses":[]}]}');
  P := Open('p1');
  try
    AssertEquals('', P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenKeepsSynthesesListedInProjectFile;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-02');
  WriteText('p1\p1.OlProj',
    '{"version":1,"array":"","slicings":[{"folder":"slice_base",' +
    '"syntheses":["synthes_2026-11-02","synthes_2026-11-09"]}]}');
  P := Open('p1');
  try
    // synthes_2026-11-01 не в файле - скрыт; synthes_2026-11-09 нет на диске - выпал
    AssertEquals(1, Length(P.Slicings[0].Syntheses));
    AssertEquals('synthes_2026-11-02', P.Slicings[0].Syntheses[0].Name);
    AssertEquals(ExpandFileName(Path('p1\slice_base\synthes_2026-11-02')),
      P.Slicings[0].Syntheses[0].Folder);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenFolderWithoutProjectFileIsModifiedUntilSaved;
var
  P: TProject;
  ErrorText: string;
begin
  Touch('p1\data.csv');
  MakeSlice('p1', 'slice_base');
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\p1.OlProj')), P.FileName);
    AssertTrue('проект изменён', P.Modified);
    AssertFalse('файл проекта ещё не записан', FileExists(Path('p1\p1.OlProj')));
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
    AssertFalse('после записи не изменён', P.Modified);
    AssertTrue('файл проекта создан', FileExists(Path('p1\p1.OlProj')));
  finally
    P.Free;
  end;
  // файл есть, поэтому новое на диске при открытии в проект не попадает
  MakeSlice('p1', 'slice_new');
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenByProjectFilePathUsesThatFile;
var
  P: TProject;
begin
  Touch('p1\a.csv');
  Touch('p1\b.csv');
  WriteText('p1\my.OlProj', '{"version":1,"array":"b.csv","slicings":[]}');
  P := Open('p1\my.OlProj');
  try
    AssertEquals(ExpandFileName(Path('p1\my.OlProj')), P.FileName);
    AssertEquals(ExpandFileName(Path('p1')), P.Dir);
    AssertEquals(ExpandFileName(Path('p1\b.csv')), P.ArrayFile);
    AssertFalse('файл по умолчанию не создаётся', FileExists(Path('p1\p1.OlProj')));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenRefusesUnreadableProjectFile;
var
  P: TProject;
  ErrorText: string;
begin
  WriteText('p1\p1.OlProj', '{not json');
  P := OpenProject(Path('p1'), ErrorText);
  try
    AssertTrue(P = nil);
    AssertTrue('начало текста',
      Pos('Не удалось прочитать файл проекта:' + LineEnding +
        ExpandFileName(Path('p1\p1.OlProj')), ErrorText) = 1);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenRefusesProjectFileWithPathInName;
var
  P: TProject;
  ErrorText: string;
begin
  WriteText('p1\p1.OlProj',
    '{"version":1,"array":"","slicings":[{"folder":"..\\other","syntheses":[]}]}');
  P := OpenProject(Path('p1'), ErrorText);
  try
    AssertTrue(P = nil);
    AssertTrue('текст про недопустимое имя',
      Pos('недопустимое имя "..\other"', ErrorText) > 0);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshAddsNewDiskItemsAndSavesThem;
var
  P: TProject;
  ErrorText: string;
begin
  MakeSlice('p1', 'slice_base');
  P := Open('p1');
  try
    Touch('p1\data.csv');
    MakeSlice('p1', 'slice_new');
    MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals('', ErrorText);
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(2, P.SlicingCount);
    AssertEquals('slice_new', P.Slicings[1].Name);
    AssertEquals(1, Length(P.Slicings[0].Syntheses));
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
  finally
    P.Free;
  end;
  // изменения записаны в файл проекта
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(2, P.SlicingCount);
    AssertEquals(1, Length(P.Slicings[0].Syntheses));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshMarksProjectModifiedAndKeepsChangesUntilSaved;
// записанный проект: новый CSV на диске - изменение в памяти; повторная сверка
// его не теряет, запись в файл снимает признак и сохраняет изменение
var
  P: TProject;
  ErrorText: string;
begin
  WriteText('p1\p1.OlProj', '{"version":1,"array":"","slicings":[]}');
  P := Open('p1');
  try
    AssertFalse('открытый по файлу проект не изменён', P.Modified);
    Touch('p1\data.csv');
    AssertTrue(P.Refresh(ErrorText));
    AssertTrue('новый массив - проект изменён', P.Modified);
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals('повторная сверка не теряет массив',
      ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
    AssertFalse(P.Modified);
  finally
    P.Free;
  end;
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.IncludeArrayAddsHiddenCsvAndMarksModified;
// CSV на диске, которого нет в файле проекта, в проект не входит, пока его не
// включат явно; после записи файла проекта он остаётся в составе
var
  P: TProject;
  ErrorText: string;
begin
  Touch('p1\data.csv');
  WriteText('p1\p1.OlProj', '{"version":1,"array":"","slicings":[]}');
  P := Open('p1');
  try
    AssertEquals('CSV скрыт', '', P.ArrayFile);
    AssertFalse(P.Modified);
    P.IncludeArray(Path('p1\data.csv'));
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertTrue('проект изменён', P.Modified);
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals('сверка не теряет включённый CSV',
      ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
  finally
    P.Free;
  end;
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshKeepsHiddenItemsHidden;
var
  P: TProject;
  ErrorText: string;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  WriteText('p1\p1.OlProj',
    '{"version":1,"array":"","slicings":[{"folder":"slice_base","syntheses":[]}]}');
  P := Open('p1');
  try
    AssertTrue(P.Refresh(ErrorText));
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshDropsItemsDeletedFromDisk;
var
  P: TProject;
  ErrorText: string;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  Touch('p1\data.csv');
  P := Open('p1');
  try
    AssertEquals(2, P.SlicingCount);
    RemoveDirectoryTree(Path('p1\slice_other'));
    RemoveDirectoryTree(Path('p1\slice_base\synthes_2026-11-01'));
    DeleteFile(Path('p1\data.csv'));
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals('', P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
    AssertEquals(0, Length(P.Slicings[0].Syntheses));
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
  finally
    P.Free;
  end;
  // выпавшее записано в файл проекта: снова созданная папка в проект не вернётся
  MakeSlice('p1', 'slice_other');
  P := Open('p1');
  try
    AssertEquals(1, P.SlicingCount);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.OpenRefusesMissingFolder;
var
  P: TProject;
  ErrorText: string;
begin
  P := OpenProject(Path('nope'), ErrorText);
  try
    AssertTrue(P = nil);
    AssertEquals('Папка проекта не найдена:' + LineEnding +
      ExpandFileName(Path('nope')), ErrorText);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.ProjectNameIsFolderName;
var
  P: TProject;
  ErrorText: string;
begin
  AssertTrue('папка проекта создаётся',
    ForceDirectories(Path('my project')));
  P := OpenProject(Path('my project') + PathDelim, ErrorText);
  try
    AssertEquals('my project', P.Name);
    AssertEquals(ExpandFileName(Path('my project')), P.Dir);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingsAreFoldersWithStatisticsSortedByName;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_zeta');
  MakeSlice('p1', 'slice_base');
  // нет Slices.txt - это не слайсинг
  AssertTrue('папка создаётся',
    ForceDirectories(Path('p1\slice_empty')));
  // имя не со slice - не слайсинг
  MakeSlice('p1', 'other');
  P := Open('p1');
  try
    AssertEquals(2, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
    AssertEquals('slice_zeta', P.Slicings[1].Name);
    AssertEquals(ExpandFileName(Path('p1\slice_base')), P.Slicings[0].Folder);
    AssertEquals(ExpandFileName(Path('p1\slice_zeta')), P.Slicings[1].Folder);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingAlgorithmIsNamePartAfterPrefix;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_my_algo');
  P := Open('p1');
  try
    AssertEquals('base', P.Slicings[0].Algorithm);
    AssertEquals('my_algo', P.Slicings[1].Algorithm);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingWithoutAlgorithmPartHasEmptyAlgorithm;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice');
  P := Open('p1');
  try
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice', P.Slicings[0].Name);
    AssertEquals('', P.Slicings[0].Algorithm);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingFolderNamedSliceFooIsAcceptedWithEmptyAlgorithm;
var
  P: TProject;
begin
  MakeSlice('p1', 'slicefoo');
  P := Open('p1');
  try
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slicefoo', P.Slicings[0].Name);
    AssertEquals('', P.Slicings[0].Algorithm);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.FileNamedLikeSlicingIsNotSlicing;
var
  P: TProject;
begin
  Touch('p1\slice_x');
  P := Open('p1');
  try
    AssertEquals(0, P.SlicingCount);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.UpperCaseCsvExtensionIsArrayFile;
var
  P: TProject;
begin
  Touch('p1\DATA.CSV');
  P := Open('p1');
  try
    AssertEquals(ExpandFileName(Path('p1\DATA.CSV')), P.ArrayFile);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RootFolderKeepsDelimiterAndNamesDrive;
var
  P: TProject;
begin
  P := TProject.Create('C:\');
  try
    AssertEquals('C:\', P.Dir);
    AssertEquals('C:', P.Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SynthesesAreFoldersWithInfoFileInsideSlicing;
var
  P: TProject;
  S: TProjectSyntheses;
begin
  MakeSlice('p1', 'slice_base');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-02');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  // нет synthesis.ini - это не синтез
  AssertTrue('папка создаётся',
    ForceDirectories(Path('p1\slice_base\synthes_2026-11-03')));
  // имя без synthes_ - не синтез, даже с synthesis.ini
  MakeSynthesis('p1', 'slice_base', 'backup');
  P := Open('p1');
  try
    S := P.Slicings[0].Syntheses;
    AssertEquals(2, Length(S));
    AssertEquals('synthes_2026-11-01', S[0].Name);
    AssertEquals('synthes_2026-11-02', S[1].Name);
    AssertEquals(ExpandFileName(Path('p1\slice_base\synthes_2026-11-01')),
      S[0].Folder);
    AssertEquals(ExpandFileName(Path('p1\slice_base\synthes_2026-11-02')),
      S[1].Folder);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SynthesesBelongToTheirOwnSlicing;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  MakeSynthesis('p1', 'slice_other', 'synthes_2026-11-05');
  MakeSynthesis('p1', 'slice_other', 'synthes_2026-11-06');
  P := Open('p1');
  try
    AssertEquals(1, Length(P.Slicings[0].Syntheses));
    AssertEquals('synthes_2026-11-01', P.Slicings[0].Syntheses[0].Name);
    AssertEquals(2, Length(P.Slicings[1].Syntheses));
    AssertEquals('synthes_2026-11-05', P.Slicings[1].Syntheses[0].Name);
    AssertEquals('synthes_2026-11-06', P.Slicings[1].Syntheses[1].Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.NodesOfEmptyProjectAreProjectOnly;
var
  P: TProject;
  Nodes: TProjectNodes;
begin
  AssertTrue('папка проекта создаётся', ForceDirectories(Path('p1')));
  P := Open('p1');
  try
    Nodes := ProjectNodes(P);
    AssertEquals(1, Length(Nodes));
    AssertTrue(pnkProject = Nodes[0].Kind);
    AssertEquals(0, Nodes[0].Level);
    AssertEquals('p1', Nodes[0].Caption);
    AssertEquals(ExpandFileName(Path('p1')), Nodes[0].Path);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.NodesListArraySlicingsAndTheirSynthesesInOrder;
var
  P: TProject;
  Nodes: TProjectNodes;
begin
  Touch('p1\arr.csv');
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-02');
  MakeSynthesis('p1', 'slice_other', 'synthes_2026-11-05');
  P := Open('p1');
  try
    Nodes := ProjectNodes(P);
    AssertEquals(7, Length(Nodes));
    AssertTrue(pnkArray = Nodes[1].Kind);
    AssertEquals(1, Nodes[1].Level);
    AssertEquals('arr.csv', Nodes[1].Caption);
    AssertEquals(ExpandFileName(Path('p1\arr.csv')), Nodes[1].Path);
    AssertTrue(pnkSlicing = Nodes[2].Kind);
    AssertEquals(1, Nodes[2].Level);
    AssertEquals('slice_base', Nodes[2].Caption);
    AssertEquals(ExpandFileName(Path('p1\slice_base')), Nodes[2].Path);
    AssertTrue(pnkSynthesis = Nodes[3].Kind);
    AssertEquals(2, Nodes[3].Level);
    AssertEquals('synthes_2026-11-01', Nodes[3].Caption);
    AssertEquals(ExpandFileName(Path('p1\slice_base\synthes_2026-11-02')),
      Nodes[4].Path);
    AssertTrue(pnkSlicing = Nodes[5].Kind);
    AssertEquals('slice_other', Nodes[5].Caption);
    AssertEquals(ExpandFileName(Path('p1\slice_other\synthes_2026-11-05')),
      Nodes[6].Path);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.IndexOfSlicingFindsByFolderName;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  P := Open('p1');
  try
    AssertEquals(0, P.IndexOfSlicing('slice_base'));
    AssertEquals(1, P.IndexOfSlicing('slice_other'));
    AssertEquals(-1, P.IndexOfSlicing('slice_missing'));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingOfSynthesisFollowsParentFolder;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSlice('p1', 'slice_other');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  MakeSynthesis('p1', 'slice_other', 'synthes_2026-11-05');
  P := Open('p1');
  try
    AssertEquals(0, P.SlicingOfSynthesis(Path('p1\slice_base\synthes_2026-11-01')));
    AssertEquals(1, P.SlicingOfSynthesis(Path('p1\slice_other\synthes_2026-11-05')));
    // слеш на конце не мешает
    AssertEquals(1, P.SlicingOfSynthesis(
      Path('p1\slice_other\synthes_2026-11-05') + PathDelim));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.SlicingOfSynthesisIgnoresFoldersOutsideSlicings;
var
  P: TProject;
begin
  MakeSlice('p1', 'slice_base');
  MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
  MakeSlice('p2', 'slice_base');
  P := Open('p1');
  try
    // синтез в корне проекта
    AssertEquals(-1, P.SlicingOfSynthesis(Path('p1\synthes_2026-11-01')));
    // слайсинг другого проекта с тем же именем
    AssertEquals(-1, P.SlicingOfSynthesis(Path('p2\slice_base\synthes_x')));
    // глубже, чем на один уровень от слайсинга
    AssertEquals(-1, P.SlicingOfSynthesis(
      Path('p1\slice_base\synthes_2026-11-01\logs')));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshPicksUpNewFolders;
var
  P: TProject;
  ErrorText: string;
begin
  AssertTrue('папка проекта создаётся', ForceDirectories(Path('p1')));
  P := Open('p1');
  try
    AssertEquals(0, P.SlicingCount);
    Touch('p1\data.csv');
    MakeSlice('p1', 'slice_base');
    MakeSynthesis('p1', 'slice_base', 'synthes_2026-11-01');
    AssertTrue(P.Refresh(ErrorText));
    AssertEquals('', ErrorText);
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
    AssertEquals(1, Length(P.Slicings[0].Syntheses));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.FailedRefreshKeepsPreviousState;
var
  P: TProject;
  ErrorText: string;
begin
  Touch('p1\data.csv');
  MakeSlice('p1', 'slice_base');
  P := Open('p1');
  try
    AssertTrue('запись файла проекта', P.SaveProject(ErrorText));
    // файл проекта испорчен: перечитать нельзя, прежнее состояние остаётся
    WriteText('p1\p1.OlProj', '{not json');
    MakeSlice('p1', 'slice_new');
    AssertFalse(P.Refresh(ErrorText));
    AssertTrue('текст про файл проекта',
      Pos('Не удалось прочитать файл проекта:', ErrorText) = 1);
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
    AssertEquals('slice_base', P.Slicings[0].Name);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.RefreshFailsWhenProjectFolderIsDeleted;
var
  P: TProject;
  ErrorText: string;
begin
  Touch('p1\data.csv');
  MakeSlice('p1', 'slice_base');
  P := Open('p1');
  try
    RemoveDirectoryTree(Path('p1'));
    AssertFalse(P.Refresh(ErrorText));
    AssertEquals('Папка проекта не найдена:' + LineEnding +
      ExpandFileName(Path('p1')), ErrorText);
    AssertEquals(ExpandFileName(Path('p1\data.csv')), P.ArrayFile);
    AssertEquals(1, P.SlicingCount);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.CreateProjectMakesEmptyProjectFolder;
var
  P: TProject;
  ErrorText: string;
begin
  P := CreateProject(FRoot, '  new project ', ErrorText);
  try
    AssertEquals('', ErrorText);
    AssertTrue(P <> nil);
    AssertEquals('new project', P.Name);
    AssertEquals(ExpandFileName(Path('new project')), P.Dir);
    AssertEquals('', P.ArrayFile);
    AssertEquals(0, P.SlicingCount);
    AssertTrue(DirectoryExists(Path('new project')));
    AssertEquals(ExpandFileName(Path('new project\new project.OlProj')),
      P.FileName);
    AssertTrue('файл проекта создан',
      FileExists(Path('new project\new project.OlProj')));
    AssertFalse('новый проект записан', P.Modified);
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.CreateProjectRefusesExistingFolder;
var
  P: TProject;
  ErrorText: string;
begin
  Touch('taken\keep.txt');
  P := CreateProject(FRoot, 'taken', ErrorText);
  try
    AssertTrue(P = nil);
    AssertEquals('Проект с таким именем уже есть:' + LineEnding + Path('taken'),
      ErrorText);
    AssertTrue('чужие файлы не тронуты', FileExists(Path('taken\keep.txt')));
  finally
    P.Free;
  end;
end;

procedure TProjectModelTests.CreateProjectRefusesBadNameAndCreatesNothing;
var
  P: TProject;
  ErrorText: string;
begin
  P := CreateProject(FRoot, 'bad:name', ErrorText);
  try
    AssertTrue(P = nil);
    AssertTrue('текст про недопустимый символ',
      Pos('недопустимый символ ":"', ErrorText) > 0);
  finally
    P.Free;
  end;
  P := CreateProject(FRoot, '   ', ErrorText);
  try
    AssertTrue(P = nil);
    AssertTrue('текст про имя',
      Pos('Имя проекта', ErrorText) = 1);
  finally
    P.Free;
  end;
  AssertEquals('в папке теста ничего не создано', 0, CountEntries(FRoot));
end;

procedure TProjectModelTests.CreateProjectRefusesMissingParentAndCreatesNothing;
var
  P: TProject;
  ErrorText: string;
begin
  P := CreateProject(Path('typo'), 'proj', ErrorText);
  try
    AssertTrue(P = nil);
    AssertEquals('Папка для проекта не найдена:' + LineEnding + Path('typo'),
      ErrorText);
  finally
    P.Free;
  end;
  AssertEquals('в папке теста ничего не создано', 0, CountEntries(FRoot));
end;

procedure TProjectModelTests.CreateProjectRefusesNameEndingWithDot;
var
  P: TProject;
  ErrorText: string;
begin
  P := CreateProject(FRoot, 'proj.', ErrorText);
  try
    AssertTrue(P = nil);
    AssertTrue('текст про точку',
      Pos('Имя проекта', ErrorText) = 1);
  finally
    P.Free;
  end;
  AssertEquals('в папке теста ничего не создано', 0, CountEntries(FRoot));
end;

procedure TProjectModelTests.FileKindCsvIsArray;
begin
  AssertTrue(pfkArray = ProjectFileKindOf('D:\proj\a\a.csv'));
end;

procedure TProjectModelTests.FileKindUpperCaseCsvIsArray;
begin
  AssertTrue(pfkArray = ProjectFileKindOf('D:\proj\A.CSV'));
end;

procedure TProjectModelTests.FileKindProIsProtocol;
begin
  AssertTrue(pfkProtocol = ProjectFileKindOf('D:\data\protocols\A_one.pro'));
end;

procedure TProjectModelTests.FileKindSynthesisInfoIsSynthesis;
begin
  AssertTrue(pfkSynthesis = ProjectFileKindOf(
    'D:\proj\slice_base\s1\' + SYNTHESIS_INFO_FILE));
end;

procedure TProjectModelTests.FileKindOtherIniIsUnknown;
begin
  AssertTrue(pfkUnknown = ProjectFileKindOf('D:\proj\other.ini'));
end;

procedure TProjectModelTests.FileKindNoExtensionIsUnknown;
begin
  AssertTrue(pfkUnknown = ProjectFileKindOf('D:\proj\readme'));
end;

initialization
  RegisterTest(TProjectModelTests);

end.
