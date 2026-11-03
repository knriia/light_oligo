unit LayerEzdTests;
// Тесты создания EZD-файлов слоёв: вместо MarkEzd.dll - подменённая запись.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MatrixTypes, MarkGeometry,
  OligoSlices, OligoMatrix, LayerEzd;

type
  // Запоминает вызовы; может отказать при подключении или на заданном файле.
  TFakeEzdWriter = class(TEzdWriter)
  public
    OpenFails: Boolean;
    FailOnFile: string;
    Opened, Closed: Boolean;
    Saved: TStringList;    // "<файл>|<имя объекта>|<число точек>"
    constructor Create;
    destructor Destroy; override;
    function Open(out AErrorText: string): Boolean; override;
    function SavePoints(const AEzdFile, AEntityName: string;
      const APoints: TArrOfTPoint; out AErrorText: string): Boolean; override;
    procedure Close; override;
  end;

  TLayerEzdTests = class(TTestCase)
  private
    FDirectory: string;
    FWriter: TFakeEzdWriter;
    function FilePath(const AName: string): string;
    function Layer(ANumber: Integer; const AMatrixName: string): TSliceStruc;
    procedure WriteMatrix(const AName: string; const ARows: array of string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure EzdNameFollowsMatrixName;
    procedure CreatesEzdForEveryLayer;
    procedure SourceTableIsNotChanged;
    procedure OpenFailureWritesNothing;
    procedure UnreadMatrixLeavesLayerWithoutEzd;
    procedure LayerWithoutPointsFails;
    procedure WriterFailureIsReported;
    procedure SliceEzdFilesWriteLaysNextToArray;
    procedure SliceEzdFailureDoesNotWriteLays;
  end;

implementation

{ TFakeEzdWriter }

constructor TFakeEzdWriter.Create;
begin
  inherited Create;
  Saved := TStringList.Create;
end;

destructor TFakeEzdWriter.Destroy;
begin
  Saved.Free;
  inherited Destroy;
end;

function TFakeEzdWriter.Open(out AErrorText: string): Boolean;
begin
  Opened := True;
  Result := not OpenFails;
  if Result then
    AErrorText := ''
  else
    AErrorText := 'open failed';
end;

function TFakeEzdWriter.SavePoints(const AEzdFile, AEntityName: string;
  const APoints: TArrOfTPoint; out AErrorText: string): Boolean;
begin
  Result := ExtractFileName(AEzdFile) <> FailOnFile;
  if not Result then
  begin
    AErrorText := 'save failed';
    Exit;
  end;
  AErrorText := '';
  Saved.Add(AEzdFile + '|' + AEntityName + '|' + IntToStr(Length(APoints)));
end;

procedure TFakeEzdWriter.Close;
begin
  Closed := True;
end;

{ TLayerEzdTests }

function TLayerEzdTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

function TLayerEzdTests.Layer(ANumber: Integer;
  const AMatrixName: string): TSliceStruc;
begin
  Result := Default(TSliceStruc);
  Result.LayerCount := ANumber;
  Result.Letter := 'A';
  Result.MatrixFile := FilePath(AMatrixName);
end;

procedure TLayerEzdTests.WriteMatrix(const AName: string;
  const ARows: array of string);
var
  Matrix: TMatrix;
  I, J: Integer;
begin
  Matrix := nil;
  SetLength(Matrix, Length(ARows));
  for I := 0 to High(ARows) do
  begin
    SetLength(Matrix[I], Length(ARows[I]));
    for J := 1 to Length(ARows[I]) do
      Matrix[I][J - 1] := Ord(ARows[I][J]) - Ord('0');
  end;
  AssertTrue(SaveMatrixAsFile(Matrix, FilePath(AName)));
end;

procedure TLayerEzdTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_ezd_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
  FWriter := TFakeEzdWriter.Create;
end;

procedure TLayerEzdTests.TearDown;
var
  Search: TSearchRec;
begin
  FWriter.Free;
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

function Geometry: TMarkGeometry;
begin
  Result := Default(TMarkGeometry);
  Result.Step := 1.0;
end;

procedure TLayerEzdTests.EzdNameFollowsMatrixName;
begin
  AssertEquals('Layer3_G7.ezd',
    LayerEzdFileName(Layer(3, 'layers' + PathDelim + 'Layer3_G7.txt')));
end;

procedure TLayerEzdTests.CreatesEzdForEveryLayer;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A2.txt', ['11']);
  WriteMatrix('Layer2_A1.txt', ['01']);
  Table := [Layer(1, 'Layer1_A2.txt'), Layer(2, 'Layer2_A1.txt')];

  AssertTrue(ErrorText, CreateLayerEzdFiles(FWriter, Table, FilePath('ezd'),
    Geometry, Done, ErrorText));
  AssertEquals(FilePath('ezd' + PathDelim + 'Layer1_A2.ezd'), Done[0].EZDFile);
  AssertEquals(FilePath('ezd' + PathDelim + 'Layer2_A1.ezd'), Done[1].EZDFile);
  AssertEquals(2, FWriter.Saved.Count);
  AssertEquals(Done[0].EZDFile + '|Layer1|2', FWriter.Saved[0]);
  AssertEquals(Done[1].EZDFile + '|Layer2|1', FWriter.Saved[1]);
  AssertTrue(FWriter.Closed);
end;

procedure TLayerEzdTests.SourceTableIsNotChanged;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A1.txt', ['1']);
  Table := [Layer(1, 'Layer1_A1.txt')];
  Table[0].EZDFile := 'old.ezd';
  AssertTrue(ErrorText, CreateLayerEzdFiles(FWriter, Table, FDirectory,
    Geometry, Done, ErrorText));
  AssertEquals('old.ezd', Table[0].EZDFile);
end;

procedure TLayerEzdTests.OpenFailureWritesNothing;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A1.txt', ['1']);
  Table := [Layer(1, 'Layer1_A1.txt')];
  Table[0].EZDFile := 'old.ezd';
  FWriter.OpenFails := True;

  AssertFalse(CreateLayerEzdFiles(FWriter, Table, FDirectory, Geometry, Done,
    ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals(0, FWriter.Saved.Count);
  AssertFalse('без подключения закрывать нечего', FWriter.Closed);
  AssertEquals('', Done[0].EZDFile);
end;

procedure TLayerEzdTests.UnreadMatrixLeavesLayerWithoutEzd;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer2_A1.txt', ['1']);
  Table := [Layer(1, 'Layer1_A1.txt'), Layer(2, 'Layer2_A1.txt')];

  AssertFalse(CreateLayerEzdFiles(FWriter, Table, FDirectory, Geometry, Done,
    ErrorText));
  AssertTrue(Pos('Layer1_A1.txt', ErrorText) > 0);
  AssertEquals('', Done[0].EZDFile);
  AssertEquals(FilePath('Layer2_A1.ezd'), Done[1].EZDFile);
  AssertEquals(1, FWriter.Saved.Count);
  AssertTrue(FWriter.Closed);
end;

procedure TLayerEzdTests.LayerWithoutPointsFails;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A0.txt', ['00']);
  Table := [Layer(1, 'Layer1_A0.txt')];

  AssertFalse(CreateLayerEzdFiles(FWriter, Table, FDirectory, Geometry, Done,
    ErrorText));
  AssertTrue(Pos('Layer1_A0.txt', ErrorText) > 0);
  AssertEquals('', Done[0].EZDFile);
  AssertEquals(0, FWriter.Saved.Count);
end;

procedure TLayerEzdTests.WriterFailureIsReported;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A1.txt', ['1']);
  WriteMatrix('Layer2_A1.txt', ['1']);
  Table := [Layer(1, 'Layer1_A1.txt'), Layer(2, 'Layer2_A1.txt')];
  FWriter.FailOnFile := 'Layer1_A1.ezd';

  AssertFalse(CreateLayerEzdFiles(FWriter, Table, FDirectory, Geometry, Done,
    ErrorText));
  AssertTrue(Pos('save failed', ErrorText) > 0);
  AssertEquals('', Done[0].EZDFile);
  AssertEquals(FilePath('Layer2_A1.ezd'), Done[1].EZDFile);
  AssertTrue(FWriter.Closed);
end;

procedure TLayerEzdTests.SliceEzdFilesWriteLaysNextToArray;
var
  Table, Done, Loaded: TArrSliceStruc;
  ErrorText: string;
begin
  WriteMatrix('Layer1_A1.txt', ['1']);
  Table := [Layer(1, 'Layer1_A1.txt')];
  AssertTrue(ErrorText, CreateSliceEzdFiles(FWriter, Table, FilePath('ezd'),
    FDirectory, Geometry, Done, ErrorText));
  AssertEquals(0, LoadSliceFile(Loaded, FilePath('Slices.lays')));
  AssertEquals(1, Length(Loaded));
  AssertEquals(Done[0].EZDFile, Loaded[0].EZDFile);
end;

procedure TLayerEzdTests.SliceEzdFailureDoesNotWriteLays;
var
  Table, Done: TArrSliceStruc;
  ErrorText: string;
begin
  // матрицы слоя нет - EZD для него не создать
  Table := [Layer(1, 'Layer1_A1.txt')];
  AssertFalse(CreateSliceEzdFiles(FWriter, Table, FDirectory, FDirectory,
    Geometry, Done, ErrorText));
  AssertTrue(Pos('Slices.lays', ErrorText) > 0);
  AssertFalse(FileExists(FilePath('Slices.lays')));
end;

initialization
  RegisterTest(TLayerEzdTests);

end.
