unit ManualTests;
// Тесты ручной вкладки: матрица точек, настройки вкладки.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MatrixTypes, OligoMatrix,
  MatrixDocument, MarkGeometry, LaserPen, ManualSettings;

type
  TMatrixDocumentTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NewDocumentHasSizeAndZeros;
    procedure ResizeKeepsValues;
    procedure ClearKeepsSize;
    procedure FillRandomUsesGivenSource;
    procedure FillCellsFillsRectangle;
    procedure FillCellsAcceptsReversedCorners;
    procedure FillCellsSkipsOutsideCells;
    procedure LoadReplacesMatrix;
    procedure FailedLoadKeepsMatrix;
    procedure SettingsDefaultsAreFormerProgConfigValues;
    procedure SettingsRoundTrip;
    procedure SettingsKeepLaserPenInSameFile;
    procedure SettingsBadMatrixSizeFallsBackToDefault;
    procedure GeometryMissingKeysTakeGivenDefaults;
  end;

implementation

function Text(const AMatrix: TMatrix): string;
var
  I, J: Integer;
begin
  Result := '';
  for I := 0 to High(AMatrix) do
  begin
    if I > 0 then
      Result := Result + '|';
    for J := 0 to High(AMatrix[I]) do
      Result := Result + IntToStr(AMatrix[I][J]);
  end;
end;

var
  RandomCalls: Integer;

function AlternatingRandom(ARange: Integer): Integer;
// 1, 0, 1, 0... и запоминаем, что просили 0 или 1
begin
  if ARange <> 2 then
    raise Exception.Create('ожидался диапазон 2');
  Result := (RandomCalls + 1) mod 2;
  Inc(RandomCalls);
end;

function TMatrixDocumentTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TMatrixDocumentTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_manual_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TMatrixDocumentTests.TearDown;
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

procedure TMatrixDocumentTests.NewDocumentHasSizeAndZeros;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 3);
  try
    AssertEquals(2, D.Rows);
    AssertEquals(3, D.Cols);
    AssertEquals('000|000', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.ResizeKeepsValues;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 2);
  try
    D.FillCells(0, 0, 0, 0, 1);
    D.Resize(3, 1);
    AssertEquals('1|0|0', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.ClearKeepsSize;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 2);
  try
    D.FillCells(0, 0, 1, 1, 5);
    D.Clear;
    AssertEquals('00|00', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.FillRandomUsesGivenSource;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 2);
  try
    RandomCalls := 0;
    D.FillRandom(@AlternatingRandom);
    AssertEquals(4, RandomCalls);
    AssertEquals('10|10', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.FillCellsFillsRectangle;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(3, 4);
  try
    D.FillCells(1, 1, 2, 2, 7);
    AssertEquals('0000|0770|0770', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.FillCellsAcceptsReversedCorners;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 3);
  try
    D.FillCells(1, 2, 0, 1, 1);
    AssertEquals('011|011', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.FillCellsSkipsOutsideCells;
var
  D: TMatrixDocument;
begin
  D := TMatrixDocument.Create(2, 2);
  try
    // выделение с заголовками таблицы (-1) и за краем
    D.FillCells(-1, -1, 5, 0, 1);
    AssertEquals('10|10', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.LoadReplacesMatrix;
var
  D: TMatrixDocument;
  M: TMatrix;
  ErrorText: string;
begin
  M := nil;
  SetLength(M, 2, 5);
  M[0][0] := 1;
  M[1][4] := 1;
  AssertTrue(SaveMatrixAsFile(M, FilePath('m.txt')));
  D := TMatrixDocument.Create(20, 20);
  try
    AssertTrue(ErrorText, D.LoadFromFile(FilePath('m.txt'), ErrorText));
    AssertEquals(2, D.Rows);
    AssertEquals(5, D.Cols);
    AssertEquals('10000|00001', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.FailedLoadKeepsMatrix;
var
  D: TMatrixDocument;
  ErrorText: string;
begin
  D := TMatrixDocument.Create(1, 2);
  try
    D.FillCells(0, 1, 0, 1, 1);
    AssertFalse(D.LoadFromFile(FilePath('missing.txt'), ErrorText));
    AssertTrue(ErrorText <> '');
    AssertEquals('01', Text(D.Matrix));
  finally
    D.Free;
  end;
end;

procedure TMatrixDocumentTests.SettingsDefaultsAreFormerProgConfigValues;
var
  S: TManualSettings;
begin
  S := LoadManualSettings(FilePath('missing.ini'));
  AssertEquals(0.1, S.Geometry.Step, 1e-9);
  AssertEquals(10, S.Geometry.Group);
  AssertEquals(0.1, S.Geometry.GroupStep, 1e-9);
  AssertTrue(S.Geometry.AutoCenter);
  AssertEquals(60.0, S.Geometry.SpotSize, 1e-9);
  AssertEquals(20.0, S.Geometry.SubstrateDiameter, 1e-9);
  AssertEquals(30, S.MatrixRows);
  AssertEquals(30, S.MatrixCols);
end;

procedure TMatrixDocumentTests.SettingsRoundTrip;
var
  S, L: TManualSettings;
  ErrorText: string;
begin
  S := DefaultManualSettings;
  S.Geometry.Step := 0.25;
  S.Geometry.AutoCenter := False;
  S.Geometry.BiasX := -1.5;
  S.Geometry.SubstrateDiameter := 25;
  S.MatrixRows := 2;
  S.MatrixCols := 7;
  AssertTrue(ErrorText, SaveManualSettings(FilePath('manual.ini'), S, ErrorText));
  L := LoadManualSettings(FilePath('manual.ini'));
  AssertEquals(0.25, L.Geometry.Step, 1e-9);
  AssertFalse(L.Geometry.AutoCenter);
  AssertEquals(-1.5, L.Geometry.BiasX, 1e-9);
  AssertEquals(25.0, L.Geometry.SubstrateDiameter, 1e-9);
  AssertEquals(2, L.MatrixRows);
  AssertEquals(7, L.MatrixCols);
end;

procedure TMatrixDocumentTests.SettingsKeepLaserPenInSameFile;
var
  Pen: TLaserPen;
  ErrorText: string;
begin
  Pen := DefaultLaserPen;
  Pen.nPenNo := 4;
  AssertTrue(ErrorText, SaveLaserPen(FilePath('manual.ini'), Pen, ErrorText));
  AssertTrue(ErrorText, SaveManualSettings(FilePath('manual.ini'),
    DefaultManualSettings, ErrorText));
  AssertEquals(4, LoadLaserPen(FilePath('manual.ini')).nPenNo);
end;

procedure TMatrixDocumentTests.SettingsBadMatrixSizeFallsBackToDefault;
var
  Lines: TStringList;
  S: TManualSettings;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Manual]');
    Lines.Add('MatrixRows=0');
    Lines.Add('MatrixCols=abc');
    Lines.SaveToFile(FilePath('manual.ini'));
  finally
    Lines.Free;
  end;
  S := LoadManualSettings(FilePath('manual.ini'));
  AssertEquals(30, S.MatrixRows);
  AssertEquals(30, S.MatrixCols);
end;

procedure TMatrixDocumentTests.GeometryMissingKeysTakeGivenDefaults;
var
  Lines: TStringList;
  D, G: TMarkGeometry;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Geometry]');
    Lines.Add('Step=0.3');
    Lines.Add('SpotSize=-5');
    Lines.SaveToFile(FilePath('g.ini'));
  finally
    Lines.Free;
  end;
  D := DefaultMarkGeometry;
  D.SpotSize := 60;
  D.Group := 4;
  G := LoadMarkGeometry(FilePath('g.ini'), D);
  AssertEquals(0.3, G.Step, 1e-9);
  AssertEquals('нет ключа', 4, G.Group);
  AssertEquals('недопустимое', 60.0, G.SpotSize, 1e-9);
end;

initialization
  RegisterTest(TMatrixDocumentTests);

end.
