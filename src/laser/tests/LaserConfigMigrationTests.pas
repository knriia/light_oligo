unit LaserConfigMigrationTests;
// Тесты переноса настроек лазера из sequences.ini в laser.ini.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, LaserConfigMigration;

type
  TLaserConfigMigrationTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
    procedure WriteLines(const AName: string; const ALines: array of string);
    function ReadLines(const AName: string): TStringList;
    function LinesText(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CopiesBothSections;
    procedure KeepsExistingSection;
    procedure NoSequencesFileDoesNothing;
    procedure NoSectionsInSequencesDoesNothing;
    procedure SecondCallChangesNothing;
    procedure SequencesFileStaysUnchanged;
    procedure ReportsUnwritablePath;
    procedure SectionHeaderWithSpacesAndCaseIsRecognized;
    procedure SectionHeaderAfterBomIsRecognized;
  end;

implementation

const
  PEN_LINES: array[0..2] of string = (
    '[LaserPen]', 'PenNo=3', 'MarkSpeed=777.5');

{ TLaserConfigMigrationTests }

function TLaserConfigMigrationTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TLaserConfigMigrationTests.WriteLines(const AName: string;
  const ALines: array of string);
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    for I := 0 to High(ALines) do
      Lines.Add(ALines[I]);
    Lines.SaveToFile(FilePath(AName));
  finally
    Lines.Free;
  end;
end;

function TLaserConfigMigrationTests.ReadLines(const AName: string): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.LoadFromFile(FilePath(AName));
  except
    Result.Free;
    raise;
  end;
end;

function TLaserConfigMigrationTests.LinesText(const AName: string): string;
var
  Lines: TStringList;
begin
  Lines := ReadLines(AName);
  try
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TLaserConfigMigrationTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_laser_config_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TLaserConfigMigrationTests.TearDown;
var
  Search: TSearchRec;
begin
  if FindFirst(FilePath('*'), faAnyFile and not faDirectory, Search) = 0 then
  try
    repeat
      DeleteFile(FilePath(Search.Name));
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  RemoveDir(FDirectory);
  inherited TearDown;
end;

procedure TLaserConfigMigrationTests.CopiesBothSections;
var
  ErrorText: string;
  Lines: TStringList;
begin
  WriteLines('sequences.ini', [
    '[Other]', 'Key=1',
    '[LaserPen]', 'PenNo=3', 'MarkSpeed=777.5',
    '[Geometry]', 'Step=0.2']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  Lines := ReadLines('laser.ini');
  try
    AssertTrue('перо перенесено', Lines.IndexOf('PenNo=3') >= 0);
    AssertTrue('скорость перенесена', Lines.IndexOf('MarkSpeed=777.5') >= 0);
    AssertTrue('шаг перенесён', Lines.IndexOf('Step=0.2') >= 0);
    AssertTrue('чужие разделы не переносятся', Lines.IndexOf('Key=1') < 0);
  finally
    Lines.Free;
  end;
end;

procedure TLaserConfigMigrationTests.KeepsExistingSection;
var
  ErrorText: string;
  Lines: TStringList;
begin
  WriteLines('laser.ini', ['[LaserPen]', 'PenNo=5']);
  WriteLines('sequences.ini', [
    '[LaserPen]', 'PenNo=3',
    '[Geometry]', 'Step=0.2']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  Lines := ReadLines('laser.ini');
  try
    AssertTrue('старый раздел не перезаписан', Lines.IndexOf('PenNo=5') >= 0);
    AssertTrue('старое значение не добавлено', Lines.IndexOf('PenNo=3') < 0);
    AssertTrue('шаг перенесён', Lines.IndexOf('Step=0.2') >= 0);
  finally
    Lines.Free;
  end;
end;

procedure TLaserConfigMigrationTests.NoSequencesFileDoesNothing;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  AssertFalse('новый файл не создаётся', FileExists(FilePath('laser.ini')));
end;

procedure TLaserConfigMigrationTests.NoSectionsInSequencesDoesNothing;
var
  ErrorText: string;
begin
  WriteLines('sequences.ini', ['[Other]', 'Key=1']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  AssertFalse('новый файл не создаётся', FileExists(FilePath('laser.ini')));
end;

procedure TLaserConfigMigrationTests.SecondCallChangesNothing;
var
  ErrorText, First, Second: string;
begin
  WriteLines('sequences.ini', [
    '[LaserPen]', 'PenNo=3',
    '[Geometry]', 'Step=0.2']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  First := LinesText('laser.ini');
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  Second := LinesText('laser.ini');
  AssertEquals('файл не изменился', First, Second);
end;

procedure TLaserConfigMigrationTests.SequencesFileStaysUnchanged;
var
  ErrorText, Before, After: string;
begin
  WriteLines('sequences.ini', [
    '[LaserPen]', 'PenNo=3',
    '[Geometry]', 'Step=0.2']);
  Before := LinesText('sequences.ini');
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  AssertTrue('старый файл на месте', FileExists(FilePath('sequences.ini')));
  After := LinesText('sequences.ini');
  AssertEquals('старый файл не изменился', Before, After);
end;

procedure TLaserConfigMigrationTests.ReportsUnwritablePath;
var
  ErrorText: string;
begin
  // на месте папки - файл
  WriteLines('blocker', ['x']);
  WriteLines('sequences.ini', PEN_LINES);
  AssertFalse(MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('blocker' + PathDelim + 'laser.ini'), ErrorText));
  AssertTrue('ошибка названа', Pos('laser.ini', ErrorText) > 0);
end;

procedure TLaserConfigMigrationTests.SectionHeaderWithSpacesAndCaseIsRecognized;
var
  ErrorText: string;
  Lines: TStringList;
  i, Count: integer;
begin
  // в laser.ini заголовок с пробелами и другим регистром: дубль не появится
  WriteLines('laser.ini', ['  [laserpen]  ', 'PenNo=5']);
  WriteLines('sequences.ini', ['[LaserPen]', 'PenNo=3']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  Lines := ReadLines('laser.ini');
  try
    Count := 0;
    for i := 0 to Lines.Count - 1 do
      if SameText(Trim(Lines[i]), '[LaserPen]') then
        Inc(Count);
    AssertEquals('раздел один', 1, Count);
    AssertTrue('значение не затёрто', Lines.IndexOf('PenNo=5') >= 0);
    AssertTrue('чужое значение не добавлено', Lines.IndexOf('PenNo=3') < 0);
  finally
    Lines.Free;
  end;
end;

procedure TLaserConfigMigrationTests.SectionHeaderAfterBomIsRecognized;
var
  ErrorText: string;
  Lines: TStringList;
  i, Count: integer;
begin
  // laser.ini начинается с BOM: первый заголовок всё равно виден
  WriteLines('laser.ini', [#$EF#$BB#$BF + '[LaserPen]', 'PenNo=5']);
  WriteLines('sequences.ini', ['[LaserPen]', 'PenNo=3']);
  AssertTrue(ErrorText, MigrateLaserSettings(FilePath('sequences.ini'),
    FilePath('laser.ini'), ErrorText));
  Lines := ReadLines('laser.ini');
  try
    Count := 0;
    for i := 0 to Lines.Count - 1 do
      if Pos('[LaserPen]', Lines[i]) > 0 then
        Inc(Count);
    AssertEquals('раздел один', 1, Count);
    AssertTrue('чужое значение не добавлено', Lines.IndexOf('PenNo=3') < 0);
  finally
    Lines.Free;
  end;
end;

initialization
  RegisterTest(TLaserConfigMigrationTests);

end.
