unit SynthesisFolderTests;
// Тесты действий над папкой синтеза: имя, проект и слайс, файлы слоёв,
// копии протоколов, synthesis.ini и итог.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fpcunit, testregistry, ProtocolModel,
  SynthesisFolder;

type
  TSynthesisFolderTests = class(TTestCase)
  private
    FRoot: string;        // временная папка теста
    function Path(const ARelative: string): string;
    procedure WriteText(const AFileName, AText: string);
    function ReadText(const AFileName: string): string;
    function Moment: TDateTime;
    function Later: TDateTime;
    function Ini(const AFolder: string): TMemIniFile;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure FolderNameIsPrefixAndDate;
    procedure FreeFolderNameIsPlainWhenNotTaken;
    procedure FreeFolderNameGetsSuffixWhenTaken;
    procedure SafeFolderPartReplacesBadCharsAndCutsLength;
    procedure FolderWithCsvIsProject;
    procedure FolderWithoutCsvOrMissingIsNotProject;
    procedure SliceInsideProjectIsAccepted;
    procedure SliceInProjectRootIsAccepted;
    procedure SliceOutsideProjectIsRefused;
    procedure SliceInSiblingFolderWithSamePrefixIsRefused;
    procedure SliceWithoutStatisticsFileIsRefused;
    procedure SynthesisFolderNameNeedsPrefix;
    procedure EzdFolderIsInsideSynthesisFolder;
    procedure RemoveLayerFilesKeepsProtocolsAndInfo;
    procedure ProtocolCopyFileIsInProtocolsFolder;
    procedure ProtocolCopyIsWrittenAsIs;
    procedure ProtocolCopyFailureNamesFile;
    procedure InfoIsWrittenAndReadBack;
    procedure RewrittenInfoKeepsCreatedTimeAndStart;
    procedure StartIsAddedToInfo;
    procedure NewStartErasesPreviousResult;
    procedure RunLogFileNameHasLogsFolderAndTime;
    procedure RunLogFileNameAvoidsExistingFile;
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

procedure TSynthesisFolderTests.FolderNameIsPrefixAndDate;
begin
  AssertEquals('synthes_2026-11-04', SynthesisFolderName(Moment));
end;

procedure TSynthesisFolderTests.FreeFolderNameIsPlainWhenNotTaken;
begin
  ForceDirectories(Path('proj' + PathDelim + 'slices_base'));
  AssertEquals('synthes_2026-11-04', FreeSynthesisFolderName(
    Path('proj' + PathDelim + 'slices_base'), Moment));
end;

procedure TSynthesisFolderTests.FreeFolderNameGetsSuffixWhenTaken;
begin
  ForceDirectories(Path('proj' + PathDelim + 'slices_base' + PathDelim +
    'synthes_2026-11-04'));
  AssertEquals('synthes_2026-11-04_2', FreeSynthesisFolderName(
    Path('proj' + PathDelim + 'slices_base'), Moment));
  ForceDirectories(Path('proj' + PathDelim + 'slices_base' + PathDelim +
    'synthes_2026-11-04_2'));
  AssertEquals('synthes_2026-11-04_3', FreeSynthesisFolderName(
    Path('proj' + PathDelim + 'slices_base'), Moment));
end;

procedure TSynthesisFolderTests.SafeFolderPartReplacesBadCharsAndCutsLength;
begin
  AssertEquals('a_b_c_d', SafeFolderPart('a/b:c*d'));
  AssertEquals('name', SafeFolderPart('name...'));
  AssertEquals(60, Length(SafeFolderPart(StringOfChar('x', 200))));
  AssertEquals('array', SafeFolderPart(''));
end;

procedure TSynthesisFolderTests.FolderWithCsvIsProject;
begin
  WriteText(Path('proj' + PathDelim + 'arrays.csv'), 'AT;GC');
  AssertTrue(IsProjectFolder(Path('proj')));
end;

procedure TSynthesisFolderTests.FolderWithoutCsvOrMissingIsNotProject;
begin
  WriteText(Path('plain' + PathDelim + 'notes.txt'), 'x');
  AssertFalse(IsProjectFolder(Path('plain')));
  AssertFalse(IsProjectFolder(Path('missing')));
  AssertFalse(IsProjectFolder(''));
end;

procedure TSynthesisFolderTests.SliceInsideProjectIsAccepted;
var
  ErrorText: string;
begin
  WriteText(Path('proj' + PathDelim + 'slice2' + PathDelim + 'Slices.txt'), 'x');
  AssertTrue(ErrorText, CheckSliceFolder(Path('proj'),
    Path('proj' + PathDelim + 'slice2'), ErrorText));
  AssertEquals('', ErrorText);
end;

procedure TSynthesisFolderTests.SliceInProjectRootIsAccepted;
var
  ErrorText: string;
begin
  WriteText(Path('proj' + PathDelim + 'Slices.txt'), 'x');
  AssertTrue(ErrorText, CheckSliceFolder(Path('proj'), Path('proj'), ErrorText));
end;

procedure TSynthesisFolderTests.SliceOutsideProjectIsRefused;
var
  ErrorText: string;
begin
  WriteText(Path('other' + PathDelim + 'slice' + PathDelim + 'Slices.txt'), 'x');
  ForceDirectories(Path('proj'));
  AssertFalse(CheckSliceFolder(Path('proj'),
    Path('other' + PathDelim + 'slice'), ErrorText));
  AssertTrue(ErrorText, Pos('в папке проекта', ErrorText) > 0);
  AssertTrue(ErrorText, Pos(Path('proj'), ErrorText) > 0);
end;

procedure TSynthesisFolderTests.SliceInSiblingFolderWithSamePrefixIsRefused;
var
  ErrorText: string;
begin
  // proj2 начинается с имени proj, но проектом proj не является
  WriteText(Path('proj2' + PathDelim + 'slice' + PathDelim + 'Slices.txt'), 'x');
  ForceDirectories(Path('proj'));
  AssertFalse(CheckSliceFolder(Path('proj'),
    Path('proj2' + PathDelim + 'slice'), ErrorText));
  AssertTrue(ErrorText, Pos('в папке проекта', ErrorText) > 0);
end;

procedure TSynthesisFolderTests.SliceWithoutStatisticsFileIsRefused;
var
  ErrorText: string;
begin
  ForceDirectories(Path('proj' + PathDelim + 'empty'));
  AssertFalse(CheckSliceFolder(Path('proj'), Path('proj' + PathDelim + 'empty'),
    ErrorText));
  AssertTrue(ErrorText, Pos('Slices.txt', ErrorText) > 0);
end;

procedure TSynthesisFolderTests.SynthesisFolderNameNeedsPrefix;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, CheckSynthesisFolderName('synthes_2026-11-04', ErrorText));
  AssertEquals('', ErrorText);
  AssertTrue(ErrorText, CheckSynthesisFolderName('Synthes_my', ErrorText));
  AssertFalse(CheckSynthesisFolderName('layers', ErrorText));
  AssertEquals('Имя папки синтеза должно начинаться с synthes_', ErrorText);
  AssertFalse(CheckSynthesisFolderName('', ErrorText));
  AssertFalse(CheckSynthesisFolderName('synthes', ErrorText));
end;

procedure TSynthesisFolderTests.EzdFolderIsInsideSynthesisFolder;
begin
  AssertEquals(Path('syn' + PathDelim + 'ezd') + PathDelim,
    EzdFolderOf(Path('syn')));
end;

procedure TSynthesisFolderTests.RemoveLayerFilesKeepsProtocolsAndInfo;
begin
  WriteText(Path('syn' + PathDelim + 'ezd' + PathDelim + 'Layer1.ezd'), 'e');
  WriteText(Path('syn' + PathDelim + SYNTHESIS_SLICES_FILE), 's');
  WriteText(Path('syn' + PathDelim + 'geometry.ini'), 'g');
  WriteText(Path('syn' + PathDelim + 'laser.ini'), 'l');
  WriteText(Path('syn' + PathDelim + 'protocols' + PathDelim + 'A.pro'), 'p');
  WriteText(Path('syn' + PathDelim + SYNTHESIS_INFO_FILE), 'i');
  RemoveLayerFiles(Path('syn'));
  AssertFalse(DirectoryExists(Path('syn' + PathDelim + 'ezd')));
  AssertFalse(FileExists(Path('syn' + PathDelim + SYNTHESIS_SLICES_FILE)));
  AssertFalse(FileExists(Path('syn' + PathDelim + 'geometry.ini')));
  AssertFalse(FileExists(Path('syn' + PathDelim + 'laser.ini')));
  AssertTrue(FileExists(Path('syn' + PathDelim + 'protocols' + PathDelim + 'A.pro')));
  AssertTrue(FileExists(Path('syn' + PathDelim + SYNTHESIS_INFO_FILE)));
  RemoveLayerFiles(Path('syn'));   // повторно и без слоёв - не ошибка
end;

procedure TSynthesisFolderTests.ProtocolCopyFileIsInProtocolsFolder;
begin
  AssertEquals(Path('syn' + PathDelim + 'protocols' + PathDelim + 'A.pro'),
    ProtocolCopyFileName(Path('syn'), 'A'));
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
    AssertEquals(Trim('Block=BlockA;' + LineEnding + #9'Pause=5;'),
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
    AssertEquals('2026-11-04 14:30:05', I.ReadString('Synthesis', 'Created', ''));
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
end;

procedure TSynthesisFolderTests.RewrittenInfoKeepsCreatedTimeAndStart;
var
  Letters: TStringList;
  ErrorText: string;
  I: TMemIniFile;
begin
  ForceDirectories(Path('syn'));
  Letters := TStringList.Create;
  try
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', '', 0,
      Letters, Moment, ErrorText));
    AssertTrue(ErrorText, SaveSynthesisStart(Path('syn'), Later, ErrorText));
    Letters.Add('G');
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', 'D:\s', 3,
      Letters, Later + 1, ErrorText));
  finally
    Letters.Free;
  end;
  I := Ini(Path('syn'));
  try
    AssertEquals('время создания не меняется', '2026-11-04 14:30:05',
      I.ReadString('Synthesis', 'Created', ''));
    AssertEquals('запуск не потерян', '2026-11-04 14:40:05',
      I.ReadString('Synthesis', 'Started', ''));
    AssertEquals('G', I.ReadString('Synthesis', 'Letters', ''));
    AssertEquals(3, I.ReadInteger('Synthesis', 'LayerCount', 0));
  finally
    I.Free;
  end;
end;

procedure TSynthesisFolderTests.StartIsAddedToInfo;
var
  Letters: TStringList;
  ErrorText: string;
  Info: TSynthesisInfo;
  I: TMemIniFile;
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
  AssertEquals('Arr1', Info.ArrayName);
  I := Ini(Path('syn'));
  try
    AssertEquals('2026-11-04 14:40:05', I.ReadString('Synthesis', 'Started', ''));
  finally
    I.Free;
  end;
  AssertFalse(SaveSynthesisStart(Path('nowhere'), Later, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TSynthesisFolderTests.NewStartErasesPreviousResult;
var
  Letters: TStringList;
  ErrorText: string;
  I: TMemIniFile;
begin
  ForceDirectories(Path('syn'));
  Letters := TStringList.Create;
  try
    AssertTrue(ErrorText, SaveSynthesisInfo(Path('syn'), 'Arr1', '', 1,
      Letters, Moment, ErrorText));
  finally
    Letters.Free;
  end;
  AssertTrue(ErrorText, SaveSynthesisStart(Path('syn'), Moment, ErrorText));
  AssertTrue(ErrorText, SaveSynthesisResult(Path('syn'), srCompleted, Later,
    ErrorText));
  AssertTrue(ErrorText, SaveSynthesisStart(Path('syn'), Later + 1, ErrorText));
  I := Ini(Path('syn'));
  try
    AssertFalse('итог прежнего запуска убран', I.SectionExists('Result'));
    AssertEquals('время нового запуска', '2026-11-05 14:40:05',
      I.ReadString('Synthesis', 'Started', ''));
  finally
    I.Free;
  end;
end;

procedure TSynthesisFolderTests.RunLogFileNameHasLogsFolderAndTime;
begin
  AssertEquals(Path('syn') + PathDelim + 'logs' + PathDelim +
    '2026-11-04_14-30-05.txt', RunLogFileName(Path('syn'), Moment));
  AssertEquals(Path('syn') + PathDelim + 'logs' + PathDelim +
    '2026-11-04_14-40-05.txt', RunLogFileName(Path('syn') + PathDelim, Later));
end;

procedure TSynthesisFolderTests.RunLogFileNameAvoidsExistingFile;
var
  First, Second: string;
begin
  ForceDirectories(Path('syn' + PathDelim + 'logs'));
  First := RunLogFileName(Path('syn'), Moment);
  WriteText(First, 'первый запуск');
  Second := RunLogFileName(Path('syn'), Moment);
  AssertEquals(Path('syn') + PathDelim + 'logs' + PathDelim +
    '2026-11-04_14-30-05_2.txt', Second);
  WriteText(Second, 'второй запуск');
  AssertEquals(Path('syn') + PathDelim + 'logs' + PathDelim +
    '2026-11-04_14-30-05_3.txt', RunLogFileName(Path('syn'), Moment));
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
