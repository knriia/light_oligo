unit MarkEzdWriterTests;
// Запись EZD через настоящую MarkEzd.dll.
// Окно DLL при подключении закрывает TDllMessageCloser из EzCadApiTests.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Windows, Classes, SysUtils, fpcunit, testregistry, MatrixTypes,
  MarkGeometry, OligoSlices, OligoMatrix, LayerEzd, MarkEzdWriter,
  EzCadApiTests;

type
  TMarkEzdWriterTests = class(TTestCase)
  private
    FDirectory: string;
    FCloser: TDllMessageCloser;
    FWriter: TMarkEzdWriter;
    function FilePath(const AName: string): string;
    procedure OpenWriter;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OpenAndCloseSucceed;
    procedure FailedOpenDoesNotBlockNextOpen;
    procedure SavePointsWritesEzdFile;
    procedure SaveIntoMissingFolderFails;
    procedure CreatesLayerEzdFiles;
  end;

implementation

{ TMarkEzdWriterTests }

function TMarkEzdWriterTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TMarkEzdWriterTests.OpenWriter;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, FWriter.Open(ErrorText));
end;

procedure TMarkEzdWriterTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_markezd_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
  FCloser := TDllMessageCloser.Create(False);
  // EZCAD.CFG лежит рядом с exe тестов (bin\)
  FWriter := TMarkEzdWriter.Create(ExtractFilePath(ParamStr(0)), 0, nil);
end;

procedure TMarkEzdWriterTests.TearDown;
var
  Search: TSearchRec;
begin
  FWriter.Free;
  FCloser.Terminate;
  FCloser.WaitFor;
  FCloser.Free;
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

function Points(ACount: Integer): TArrOfTPoint;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I][0] := I * 0.5;
    Result[I][1] := 0;
  end;
end;

function FileBytes(const AFileName: string): Int64;
var
  Search: TSearchRec;
begin
  Result := -1;
  if FindFirst(AFileName, faAnyFile, Search) = 0 then
  begin
    Result := Search.Size;
    FindClose(Search);
  end;
end;

procedure TMarkEzdWriterTests.OpenAndCloseSucceed;
begin
  OpenWriter;
  FWriter.Close;
end;

procedure TMarkEzdWriterTests.FailedOpenDoesNotBlockNextOpen;
var
  BadWriter: TMarkEzdWriter;
  ErrorText: string;
begin
  // в несуществующей папке нет EZCAD.CFG - подключиться нельзя
  BadWriter := TMarkEzdWriter.Create(FilePath('no_ezcad') + PathDelim, 0, nil);
  try
    AssertFalse(BadWriter.Open(ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    BadWriter.Free;
  end;
  OpenWriter;
  FWriter.Close;
end;

procedure TMarkEzdWriterTests.SavePointsWritesEzdFile;
var
  ErrorText: string;
begin
  OpenWriter;
  try
    AssertTrue(ErrorText, FWriter.SavePoints(FilePath('Layer1_A3.ezd'),
      'Layer1', Points(3), ErrorText));
  finally
    FWriter.Close;
  end;
  AssertTrue(FileExists(FilePath('Layer1_A3.ezd')));
  AssertTrue(FileBytes(FilePath('Layer1_A3.ezd')) > 0);
end;

procedure TMarkEzdWriterTests.SaveIntoMissingFolderFails;
var
  ErrorText: string;
  Saved: Boolean;
begin
  OpenWriter;
  try
    Saved := FWriter.SavePoints(FilePath('missing' + PathDelim + 'Layer1.ezd'),
      'Layer1', Points(3), ErrorText);
  finally
    FWriter.Close;
  end;
  AssertFalse(Saved);
  AssertTrue(ErrorText <> '');
end;

procedure TMarkEzdWriterTests.CreatesLayerEzdFiles;
var
  Table, Done: TArrSliceStruc;
  Geometry: TMarkGeometry;
  Matrix: TMatrix;
  ErrorText: string;
  I: Integer;
begin
  Matrix := nil;
  SetLength(Matrix, 1, 3);
  Matrix[0][0] := 1;
  Matrix[0][2] := 1;
  SetLength(Table, 2);
  for I := 0 to 1 do
  begin
    Table[I] := Default(TSliceStruc);
    Table[I].LayerCount := I + 1;
    Table[I].Letter := 'A';
    Table[I].MatrixFile := FilePath('Layer' + IntToStr(I + 1) + '_A2.txt');
    AssertTrue(SaveMatrixAsFile(Matrix, Table[I].MatrixFile));
  end;
  Geometry := Default(TMarkGeometry);
  Geometry.Step := 0.5;

  AssertTrue(ErrorText, CreateLayerEzdFiles(FWriter, Table, FDirectory,
    Geometry, Done, ErrorText));
  for I := 0 to 1 do
  begin
    AssertEquals(FilePath('Layer' + IntToStr(I + 1) + '_A2.ezd'), Done[I].EZDFile);
    AssertTrue(FileExists(Done[I].EZDFile));
  end;
end;

initialization
  RegisterTest(TMarkEzdWriterTests);

end.
