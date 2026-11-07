unit OligoTests;
// Тесты блока последовательностей: массив олигов, CSV, слайсинг, матрицы слоёв.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MatrixTypes, OligoArray,
  OligoArrayCsv, OligoSlicing, OligoMatrix, MarkGeometry, OligoPaste, OligoArrayDocument,
  OligoSlices, AppPaths, GridWidthMode;

type
  TOligoArrayTests = class(TTestCase)
  published
    procedure EmptyFillMakesEmptyCells;
    procedure ConstantFillIsUpperCase;
    procedure RandomFillUsesOnlyATGC;
    procedure ZeroSizeGivesEmptyArray;
    procedure CollectSymbolsKeepsFirstSeenOrder;
    procedure LayerTakesMostFrequentLastLetter;
    procedure LayerTieGoesToFirstSymbol;
    procedure LayerIgnoresEmptyOligs;
    procedure OccupiedCellsMarkNonEmptyOligs;
  end;

  TOligoSlicingTests = class(TTestCase)
  published
    procedure SlicesFromTheEndOfOligs;
    procedure SourceArrayIsNotChanged;
    procedure EveryLetterGoesToExactlyOneLayer;
    procedure EmptyArrayHasNoLayers;
    procedure LayerFileNameHasNumberLetterAndCount;
  end;

  TOligoFileTests = class(TTestCase)
  private
    FDirectory: string;
    procedure RemoveTree(const ADirectory: string);
    function FilePath(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure CsvParseSplitsCellsAndUpperCases;
    procedure CsvParseSkipsEmptyLines;
    procedure CsvParseKeepsTrailingEmptyCell;
    procedure CsvFormatJoinsCellsBySemicolon;
    procedure CsvFileRoundTrip;
    procedure CsvFileWithBomLoads;
    procedure CsvMissingFileReportsError;
    procedure MatrixHeaderIsColumnsThenRows;
    procedure NonSquareMatrixRoundTrip;
    procedure MatrixParseRejectsMissingValues;
    procedure MatrixParseRejectsBadValues;
    procedure MatrixFileRoundTrip;
    procedure MatrixReadFailureKeepsOldMatrix;
    procedure EmptyMatrixIsNotSaved;
    procedure LoadMatrixFileKeepsRowsAndColumns;
    procedure LoadMatrixFileReportsErrorAndKeepsMatrix;
    procedure DocumentStartsEmptyAndUnmodified;
    procedure NewArrayIsModifiedWithoutFile;
    procedure NewArrayKeepsOwnCopy;
    procedure LoadRemembersFileAndClearsModified;
    procedure FailedLoadKeepsDocument;
    procedure SetCellMarksModifiedOnlyOnChange;
    procedure SetCellOutsideArrayIsRejected;
    procedure SaveRemembersFileAndClearsModified;
    procedure ClearCellsKeepsSizeAndFile;
    procedure ClearCellsOfEmptyCellsIsNotAChange;
    procedure CloseForgetsArrayAndFile;
    procedure ListLayerFilesFindsOnlyLayers;
    procedure ListLayerFilesOfMissingFolderIsEmpty;
    procedure DeleteLayerFilesKeepsOtherFiles;
    procedure SliceStatisticsInArrayFolderPointsIntoLayers;
    procedure DeleteLayerEzdFilesKeepsMatrices;
    procedure LaysInArrayFolderPointsIntoEzdAndLoads;
    procedure SliceStatisticsReportsUnwritableFolder;
    procedure SliceFileMissingFails;
    procedure SliceFileRejectsBadLayerNumber;
    procedure SliceFileWithBadLineGivesEmptyTable;
    procedure SliceFileWithoutLayersFails;
    procedure SliceFileSkipsEmptyLines;
    procedure WriteLayerFilesBuildsTableAndFiles;
    procedure WriteLayerFilesFailureGivesEmptyTable;
    procedure SliceArrayIntoFolderWritesLayersAndStatistics;
    procedure SliceArrayIntoFolderFailureGivesEmptyTable;
    procedure DocumentSlicingIsKeptAsCopy;
    procedure DocumentSlicingSurvivesSave;
    procedure DocumentForgetsSlicingWhenArrayIsReplaced;
    procedure DocumentForgetsSlicingOnClearAndClose;
    procedure DocumentForgetsSlicingWhenCellChanges;
    procedure GeometryFileMissingGivesDefaults;
    procedure GeometryFileRoundTrip;
    procedure GeometryFileUsesDecimalPoint;
    procedure GeometryFileReadsCommaAndSkipsBadValues;
    procedure GeometrySaveKeepsOtherSections;
    procedure GeometrySaveReportsUnwritableFolder;
    procedure GeometryFileKeepsSpotAndSubstrate;
    procedure NewArrayIsSuggestedIntoDatedFolder;
    procedure OpenedArrayIsSuggestedIntoItsFile;
  end;

  TGridWidthModeTests = class(TTestCase)
  published
    procedure ModesGoInCircle;
  end;

  TOligoMatrixTests = class(TTestCase)
  published
    procedure AutoCenterOfEmptyMatrixIsZero;
    procedure AutoCenterWithoutGroups;
    procedure AutoCenterWithGroups;
    procedure CopyMatrixMakesIndependentCopy;
    procedure ResizeMatrixKeepsValuesAndAddsZeros;
    procedure ResizeMatrixToZero;
  end;

  TMarkGeometryTests = class(TTestCase)
  published
    procedure ManualBiasIsTakenAsIs;
    procedure AutoCenterUsesMatrixAndSteps;
    procedure MarkPointsUseStepGroupsAndBias;
    procedure MarkPointsOfEmptyMatrixAreEmpty;
    procedure SubstrateOverflowCountsSpotRadius;
    procedure SubstrateOutlineIsCircleOfDiameter;
    procedure ZeroDiameterMeansNoSubstrate;
    procedure FitCheckExplainsWhatIsWrong;
  end;

  TOligoPasteTests = class(TTestCase)
  published
    procedure MeasuresRowsAndWidestRow;
    procedure TrailingLineBreakIsNotARow;
    procedure FitsWhenEnoughRoom;
    procedure DoesNotFitByRows;
    procedure DoesNotFitByColumns;
  end;

  TFileNameCheckTests = class(TTestCase)
  published
    procedure AcceptsNormalName;
    procedure RejectsEmptyName;
    procedure RejectsForbiddenCharacters;
    procedure RejectsTrailingDotOrSpace;
    procedure FilePathJoinsFolderNameAndExtension;
    procedure FilePathDoesNotDoubleExtension;
    procedure FilePathAcceptsDriveRootAndTrailingSlash;
    procedure FilePathRejectsRelativeOrEmptyFolder;
    procedure FilePathRejectsBadFolderPartOrName;
    procedure FolderPathChecksDriveAndParts;
  end;

implementation

function Arr(const ARows: array of string): TOligoArr;
// строки вида 'AT;GT' -> строка массива
var
  I, J: Integer;
  Parts: TStringArray;
begin
  Result := nil;
  SetLength(Result, Length(ARows));
  for I := 0 to High(ARows) do
  begin
    Parts := ARows[I].Split(';');
    SetLength(Result[I], Length(Parts));
    for J := 0 to High(Parts) do
      Result[I, J] := Parts[J];
  end;
end;

function Matrix(const ARows: array of string): TMatrix;
// строки вида '101' -> строка матрицы
var
  I, J: Integer;
begin
  SetLength(Result, Length(ARows));
  for I := 0 to High(ARows) do
  begin
    SetLength(Result[I], Length(ARows[I]));
    for J := 1 to Length(ARows[I]) do
      Result[I][J - 1] := Ord(ARows[I][J]) - Ord('0');
  end;
end;

function MatrixToText(const AMatrix: TMatrix): string;
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

function ArrToText(const AArr: TOligoArr): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AArr) do
  begin
    if I > 0 then
      Result := Result + '|';
    Result := Result + string.Join(';', AArr[I]);
  end;
end;

{ TOligoArrayTests }

procedure TOligoArrayTests.EmptyFillMakesEmptyCells;
var
  A: TOligoArr;
begin
  A := CreateOligoArray(2, 3, ofEmpty, 0, '');
  AssertEquals(2, Length(A));
  AssertEquals(3, Length(A[0]));
  AssertEquals(3, Length(A[1]));
  AssertEquals(';;|;;', ArrToText(A));
end;

procedure TOligoArrayTests.ConstantFillIsUpperCase;
var
  A: TOligoArr;
begin
  A := CreateOligoArray(1, 2, ofConstant, 0, 'atGc');
  AssertEquals('ATGC;ATGC', ArrToText(A));
end;

procedure TOligoArrayTests.RandomFillUsesOnlyATGC;
var
  A: TOligoArr;
  I, J, K: Integer;
begin
  RandSeed := 12345;
  A := CreateOligoArray(3, 4, ofRandom, 25, '');
  for I := 0 to High(A) do
    for J := 0 to High(A[I]) do
    begin
      AssertEquals(25, Length(A[I, J]));
      for K := 1 to Length(A[I, J]) do
        AssertTrue('буква ' + A[I, J][K], A[I, J][K] in ['A', 'T', 'G', 'C']);
    end;
end;

procedure TOligoArrayTests.ZeroSizeGivesEmptyArray;
begin
  AssertEquals(0, Length(CreateOligoArray(0, 5, ofEmpty, 0, '')));
  AssertEquals(0, Length(CreateOligoArray(5, 0, ofEmpty, 0, '')));
end;

procedure TOligoArrayTests.CollectSymbolsKeepsFirstSeenOrder;
begin
  AssertEquals('GATC', SymbolsToString(CollectSymbols(Arr(['GA;AT', 'CG']))));
  AssertEquals('', SymbolsToString(CollectSymbols(nil)));
end;

procedure TOligoArrayTests.LayerTakesMostFrequentLastLetter;
var
  A: TOligoArr;
  Symbols: TSymbolSet;
  Layer: TMatrix;
  Letter: TOlig;
  Count: Integer;
begin
  A := Arr(['AT;GT', 'TA;C']);
  Symbols := CollectSymbols(A);
  Count := 0;
  CreateMatrixLayerFromOligoArr(A, Symbols, Layer, Letter, Count);
  AssertEquals('T', Letter);
  AssertEquals(2, Count);
  AssertEquals('11|00', MatrixToText(Layer));
  // буква слоя убрана с конца олигов
  AssertEquals('A;G|TA;C', ArrToText(A));
end;

procedure TOligoArrayTests.LayerTieGoesToFirstSymbol;
var
  A: TOligoArr;
  Symbols: TSymbolSet;
  Layer: TMatrix;
  Letter: TOlig;
  Count: Integer;
begin
  A := Arr(['CA;GC']); // последние A и C поровну
  Symbols := CollectSymbols(A); // C, A, G
  Count := 0;
  CreateMatrixLayerFromOligoArr(A, Symbols, Layer, Letter, Count);
  AssertEquals('C', Letter);
  AssertEquals(1, Count);
  AssertEquals('01', MatrixToText(Layer));
end;

procedure TOligoArrayTests.LayerIgnoresEmptyOligs;
var
  A: TOligoArr;
  Symbols: TSymbolSet;
  Layer: TMatrix;
  Letter: TOlig;
  Count: Integer;
begin
  A := Arr([';;']);
  Symbols := CollectSymbols(A);
  Count := -1;
  CreateMatrixLayerFromOligoArr(A, Symbols, Layer, Letter, Count);
  AssertEquals(0, Count);
end;

procedure TOligoArrayTests.OccupiedCellsMarkNonEmptyOligs;
begin
  AssertEquals('10|01', MatrixToText(OccupiedCellsMatrix(Arr(['AT;', ';G']))));
  AssertEquals(0, Length(OccupiedCellsMatrix(nil)));
end;

{ TOligoSlicingTests }

procedure TOligoSlicingTests.SlicesFromTheEndOfOligs;
var
  Layers: TOligoLayers;
begin
  // последние буквы: T,T,A -> слой T; затем A,G,A -> слой A; затем G
  Layers := SliceOligoArray(Arr(['AT;GT', 'A;']));
  AssertEquals(3, Length(Layers));

  AssertEquals(1, Layers[0].Number);
  AssertEquals('T', Layers[0].Letter);
  AssertEquals(2, Layers[0].Count);
  AssertEquals('11|00', MatrixToText(Layers[0].Matrix));

  AssertEquals(2, Layers[1].Number);
  AssertEquals('A', Layers[1].Letter);
  AssertEquals(2, Layers[1].Count);
  AssertEquals('10|10', MatrixToText(Layers[1].Matrix));

  AssertEquals(3, Layers[2].Number);
  AssertEquals('G', Layers[2].Letter);
  AssertEquals(1, Layers[2].Count);
  AssertEquals('01|00', MatrixToText(Layers[2].Matrix));
end;

procedure TOligoSlicingTests.SourceArrayIsNotChanged;
var
  A: TOligoArr;
begin
  A := Arr(['AT;GT', 'A;']);
  SliceOligoArray(A);
  AssertEquals('AT;GT|A;', ArrToText(A));
end;

procedure TOligoSlicingTests.EveryLetterGoesToExactlyOneLayer;
var
  A: TOligoArr;
  Layers: TOligoLayers;
  I, J, L, Total, Letters: Integer;
  Built: array of array of string;
begin
  RandSeed := 777;
  A := CreateOligoArray(4, 5, ofRandom, 12, '');
  Layers := SliceOligoArray(A);

  // собираем олиги обратно из слоёв: слои идут с конца олига к началу
  SetLength(Built, Length(A));
  for I := 0 to High(A) do
    SetLength(Built[I], Length(A[I]));
  Total := 0;
  for L := 0 to High(Layers) do
  begin
    Letters := 0;
    for I := 0 to High(Layers[L].Matrix) do
      for J := 0 to High(Layers[L].Matrix[I]) do
        if Layers[L].Matrix[I][J] = 1 then
        begin
          Built[I][J] := Layers[L].Letter + Built[I][J];
          Inc(Letters);
        end;
    AssertEquals('количество в слое ' + IntToStr(L + 1), Layers[L].Count, Letters);
    Inc(Total, Letters);
  end;

  AssertEquals(4 * 5 * 12, Total);
  for I := 0 to High(A) do
    for J := 0 to High(A[I]) do
      AssertEquals(A[I, J], Built[I][J]);
end;

procedure TOligoSlicingTests.EmptyArrayHasNoLayers;
begin
  AssertEquals(0, Length(SliceOligoArray(nil)));
  AssertEquals(0, Length(SliceOligoArray(Arr([';']))));
end;

procedure TOligoSlicingTests.LayerFileNameHasNumberLetterAndCount;
var
  Layer: TOligoLayer;
begin
  Layer := Default(TOligoLayer);
  Layer.Number := 12;
  Layer.Letter := 'G';
  Layer.Count := 4088;
  AssertEquals('Layer12_G4088.txt', LayerFileName(Layer));
end;

{ TOligoFileTests }

procedure TOligoFileTests.RemoveTree(const ADirectory: string);
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

function TOligoFileTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TOligoFileTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_oligo_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TOligoFileTests.TearDown;
begin
  RemoveTree(FDirectory);
  inherited TearDown;
end;

procedure TOligoFileTests.CsvParseSplitsCellsAndUpperCases;
begin
  AssertEquals('ATG;CC|T;GA', ArrToText(ParseOligoCsv('atg;CC' + LineEnding +
    'T;ga' + LineEnding)));
end;

procedure TOligoFileTests.CsvParseSkipsEmptyLines;
begin
  AssertEquals('A;T|G', ArrToText(ParseOligoCsv('A;T' + LineEnding + LineEnding +
    'G' + LineEnding + LineEnding)));
end;

procedure TOligoFileTests.CsvParseKeepsTrailingEmptyCell;
var
  A: TOligoArr;
begin
  A := ParseOligoCsv('A;T;' + LineEnding);
  AssertEquals(1, Length(A));
  AssertEquals(3, Length(A[0]));
  AssertEquals('', A[0, 2]);
end;

procedure TOligoFileTests.CsvFormatJoinsCellsBySemicolon;
begin
  AssertEquals('ATG;CC' + LineEnding + 'T;' + LineEnding,
    FormatOligoCsv(Arr(['ATG;CC', 'T;'])));
  AssertEquals('', FormatOligoCsv(nil));
end;

procedure TOligoFileTests.CsvFileRoundTrip;
var
  Loaded: TOligoArr;
  ErrorText: string;
begin
  AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'),
    Arr(['ATG;CC;', 'T;GA;A']), ErrorText));
  AssertTrue(ErrorText, LoadOligoArrayFile(FilePath('a.csv'), Loaded, ErrorText));
  AssertEquals('ATG;CC;|T;GA;A', ArrToText(Loaded));
end;

procedure TOligoFileTests.CsvFileWithBomLoads;
var
  Stream: TFileStream;
  Content: string;
  Loaded: TOligoArr;
  ErrorText: string;
begin
  Content := #$EF#$BB#$BF'ab;c'#13#10;
  Stream := TFileStream.Create(FilePath('bom.csv'), fmCreate);
  try
    Stream.WriteBuffer(Content[1], Length(Content));
  finally
    Stream.Free;
  end;
  AssertTrue(ErrorText, LoadOligoArrayFile(FilePath('bom.csv'), Loaded, ErrorText));
  AssertEquals('AB;C', ArrToText(Loaded));
end;

procedure TOligoFileTests.CsvMissingFileReportsError;
var
  Loaded: TOligoArr;
  ErrorText: string;
begin
  AssertFalse(LoadOligoArrayFile(FilePath('missing.csv'), Loaded, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals(0, Length(Loaded));
end;

procedure TOligoFileTests.MatrixHeaderIsColumnsThenRows;
begin
  // 2 строки по 3 столбца
  AssertEquals('3 2' + LineEnding + ' 1 0 1' + LineEnding + ' 0 1 0' + LineEnding,
    FormatMatrixText(Matrix(['101', '010'])));
end;

procedure TOligoFileTests.NonSquareMatrixRoundTrip;
var
  M: TMatrix;
  ErrorText: string;
begin
  AssertTrue(ErrorText, ParseMatrixText(FormatMatrixText(Matrix(['101', '010'])),
    M, ErrorText));
  AssertEquals('101|010', MatrixToText(M));
  AssertTrue(ErrorText, ParseMatrixText(FormatMatrixText(Matrix(['10', '01', '11'])),
    M, ErrorText));
  AssertEquals('10|01|11', MatrixToText(M));
end;

procedure TOligoFileTests.MatrixParseRejectsMissingValues;
var
  M: TMatrix;
  ErrorText: string;
begin
  AssertFalse(ParseMatrixText('3 2' + LineEnding + '1 0 1' + LineEnding + '0 1',
    M, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertFalse(ParseMatrixText('', M, ErrorText));
  AssertFalse(ParseMatrixText('0 2', M, ErrorText));
end;

procedure TOligoFileTests.MatrixParseRejectsBadValues;
var
  M: TMatrix;
  ErrorText: string;
begin
  AssertFalse(ParseMatrixText('2 1' + LineEnding + '1 x', M, ErrorText));
  AssertFalse(ParseMatrixText('2 1' + LineEnding + '1 256', M, ErrorText));
end;

procedure TOligoFileTests.MatrixFileRoundTrip;
var
  M: TMatrix;
begin
  AssertTrue(SaveMatrixAsFile(Matrix(['1100', '0011']), FilePath('m.txt')));
  M := nil;
  AssertTrue(ReadMatrixFromFile(FilePath('m.txt'), M));
  AssertEquals('1100|0011', MatrixToText(M));
end;

procedure TOligoFileTests.MatrixReadFailureKeepsOldMatrix;
var
  M: TMatrix;
begin
  M := Matrix(['1']);
  AssertFalse(ReadMatrixFromFile(FilePath('missing.txt'), M));
  AssertEquals('1', MatrixToText(M));
end;

procedure TOligoFileTests.EmptyMatrixIsNotSaved;
begin
  AssertFalse(SaveMatrixAsFile(nil, FilePath('empty.txt')));
  AssertFalse(FileExists(FilePath('empty.txt')));
end;

procedure TOligoFileTests.DocumentStartsEmptyAndUnmodified;
var
  Doc: TOligoArrayDocument;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(Doc.IsEmpty);
    AssertFalse(Doc.HasFile);
    AssertFalse(Doc.Modified);
    AssertEquals('', Doc.ArrayDir);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.NewArrayIsModifiedWithoutFile;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'), Arr(['A']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('a.csv'), ErrorText));
    Doc.NewArray(Arr(['AT;G']));
    AssertTrue(Doc.Modified);
    AssertFalse(Doc.HasFile);
    AssertEquals('AT;G', ArrToText(Doc.Arr));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.NewArrayKeepsOwnCopy;
var
  Doc: TOligoArrayDocument;
  Source: TOligoArr;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Source := Arr(['AT;G']);
    Doc.NewArray(Source);
    Source[0, 0] := 'CC';
    AssertEquals('AT', Doc.Cell(0, 0));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.LoadRemembersFileAndClearsModified;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ForceDirectories(FilePath('arr1')));
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('arr1' + PathDelim + 'a.csv'),
      Arr(['AT;G']), ErrorText));
    Doc.NewArray(Arr(['C']));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('arr1' + PathDelim + 'a.csv'), ErrorText));
    AssertFalse(Doc.Modified);
    AssertTrue(Doc.HasFile);
    AssertEquals(FilePath('arr1' + PathDelim + 'a.csv'), Doc.FileName);
    AssertEquals(FilePath('arr1'), Doc.ArrayDir);
    AssertEquals('AT;G', ArrToText(Doc.Arr));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.FailedLoadKeepsDocument;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['C']));
    AssertFalse(Doc.LoadFromFile(FilePath('missing.csv'), ErrorText));
    AssertTrue(ErrorText <> '');
    AssertEquals('C', ArrToText(Doc.Arr));
    AssertTrue(Doc.Modified);
    AssertFalse(Doc.HasFile);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.SetCellMarksModifiedOnlyOnChange;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'), Arr(['AT;G']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('a.csv'), ErrorText));
    AssertTrue(Doc.SetCell(0, 0, 'at')); // то же значение после верхнего регистра
    AssertFalse(Doc.Modified);
    AssertTrue(Doc.SetCell(0, 1, 'gc'));
    AssertTrue(Doc.Modified);
    AssertEquals('GC', Doc.Cell(0, 1));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.SetCellOutsideArrayIsRejected;
var
  Doc: TOligoArrayDocument;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertFalse(Doc.SetCell(0, 0, 'A'));
    Doc.NewArray(Arr(['AT;G', 'C']));
    AssertFalse(Doc.SetCell(1, 1, 'A')); // во второй строке одна ячейка
    AssertFalse(Doc.SetCell(-1, 0, 'A'));
    AssertFalse(Doc.SetCell(2, 0, 'A'));
    AssertEquals('', Doc.Cell(5, 5));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.SaveRemembersFileAndClearsModified;
var
  Doc: TOligoArrayDocument;
  Loaded: TOligoArr;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['AT;G']));
    AssertTrue(ErrorText, Doc.SaveToFile(FilePath('b.csv'), ErrorText));
    AssertFalse(Doc.Modified);
    AssertEquals(FilePath('b.csv'), Doc.FileName);
    AssertTrue(ErrorText, LoadOligoArrayFile(FilePath('b.csv'), Loaded, ErrorText));
    AssertEquals('AT;G', ArrToText(Loaded));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.ClearCellsKeepsSizeAndFile;
var
  Doc: TOligoArrayDocument;
  Loaded: TOligoArr;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'), Arr(['AT;G', 'C;']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('a.csv'), ErrorText));
    Doc.ClearCells;
    AssertEquals(';|;', ArrToText(Doc.Arr));
    AssertTrue(Doc.Modified);
    AssertEquals(FilePath('a.csv'), Doc.FileName);
    // файл на диске не изменился
    AssertTrue(ErrorText, LoadOligoArrayFile(FilePath('a.csv'), Loaded, ErrorText));
    AssertEquals('AT;G|C;', ArrToText(Loaded));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.ClearCellsOfEmptyCellsIsNotAChange;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('e.csv'), Arr([';']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('e.csv'), ErrorText));
    Doc.ClearCells;
    AssertFalse(Doc.Modified);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.CloseForgetsArrayAndFile;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'), Arr(['AT;G']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('a.csv'), ErrorText));
    AssertTrue(Doc.SetCell(0, 0, 'C'));
    Doc.Close;
    AssertTrue(Doc.IsEmpty);
    AssertFalse(Doc.HasFile);
    AssertFalse(Doc.Modified);
    AssertTrue(FileExists(FilePath('a.csv')));
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.ListLayerFilesFindsOnlyLayers;
var
  Files: TStringArray;
  ErrorText: string;
begin
  AssertTrue(ForceDirectories(FilePath('layers')));
  AssertTrue(SaveMatrixAsFile(Matrix(['1']), FilePath('layers\Layer2_A1.txt')));
  AssertTrue(SaveMatrixAsFile(Matrix(['1']), FilePath('layers\Layer1_T1.txt')));
  AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('layers\Layer1_T1.ezd'), nil, ErrorText));
  AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('layers\notes.txt'), nil, ErrorText));
  Files := ListLayerFiles(FilePath('layers'));
  AssertEquals(3, Length(Files));
  AssertEquals(FilePath('layers\Layer1_T1.ezd'), Files[0]);
  AssertEquals(FilePath('layers\Layer1_T1.txt'), Files[1]);
  AssertEquals(FilePath('layers\Layer2_A1.txt'), Files[2]);
end;

procedure TOligoFileTests.ListLayerFilesOfMissingFolderIsEmpty;
begin
  AssertEquals(0, Length(ListLayerFiles(FilePath('missing'))));
end;

procedure TOligoFileTests.DeleteLayerFilesKeepsOtherFiles;
var
  ErrorText: string;
begin
  AssertTrue(SaveMatrixAsFile(Matrix(['1']), FilePath('Layer1_T1.txt')));
  AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('array.csv'), Arr(['A']), ErrorText));
  AssertTrue(ErrorText, DeleteLayerFiles(FDirectory, ErrorText));
  AssertFalse(FileExists(FilePath('Layer1_T1.txt')));
  AssertTrue(FileExists(FilePath('array.csv')));
  AssertEquals(0, Length(ListLayerFiles(FDirectory)));
end;

procedure TOligoFileTests.SliceStatisticsInArrayFolderPointsIntoLayers;
var
  Table: TSliceLayers;
  Lines: TStringList;
  ErrorText: string;
begin
  AssertTrue(ForceDirectories(FilePath('layers')));
  SetLength(Table, 1);
  Table[0] := Default(TSliceLayer);
  Table[0].LayerNumber := 1;
  Table[0].Letter := 'T';
  Table[0].LetterCount := 2;
  Table[0].MatrixFile := FilePath('layers\Layer1_T2.txt');
  AssertTrue(ErrorText, SaveSliceStatistics(FDirectory, Table, SLICES_STAT_FILE,
    ErrorText));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath('Slices.txt'));
    AssertEquals(2, Lines.Count);
    AssertEquals('1'#9'T'#9'2'#9'layers\Layer1_T2.txt', Lines[1]);
  finally
    Lines.Free;
  end;
end;

procedure TOligoFileTests.DeleteLayerEzdFilesKeepsMatrices;
var
  ErrorText: string;
begin
  // EZD и матрицы в одной папке: удаляются только EZD
  AssertTrue(SaveMatrixAsFile(Matrix(['1']), FilePath('Layer1_T1.txt')));
  AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('Layer1_T1.ezd'), nil, ErrorText));
  AssertEquals(1, Length(ListLayerEzdFiles(FDirectory)));
  AssertTrue(ErrorText, DeleteLayerEzdFiles(FDirectory, ErrorText));
  AssertFalse(FileExists(FilePath('Layer1_T1.ezd')));
  AssertTrue(FileExists(FilePath('Layer1_T1.txt')));
end;

procedure TOligoFileTests.LaysInArrayFolderPointsIntoEzdAndLoads;
var
  Table, Loaded: TSliceLayers;
  Lines: TStringList;
  ErrorText: string;
begin
  SetLength(Table, 2);
  Table[0] := Default(TSliceLayer);
  Table[0].LayerNumber := 1;
  Table[0].Letter := 'T';
  Table[0].EZDFile := FilePath('ezd\Layer1_T2.ezd');
  Table[1] := Default(TSliceLayer);
  Table[1].LayerNumber := 2;
  Table[1].Letter := 'A';
  Table[1].EZDFile := FilePath('ezd\Layer2_A1.ezd');
  AssertTrue(ErrorText, SaveSliceStatistics(FDirectory, Table, SLICES_EZD_FILE,
    ErrorText));

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath('Slices.lays'));
    AssertEquals('1'#9'T'#9'ezd\Layer1_T2.ezd', Lines[1]);
  finally
    Lines.Free;
  end;

  AssertEquals(0, LoadSliceFile(Loaded, FilePath('Slices.lays')));
  AssertEquals(2, Length(Loaded));
  AssertEquals(FilePath('ezd\Layer1_T2.ezd'), Loaded[0].EZDFile);
  AssertEquals('A', Loaded[1].Letter);
end;

procedure TOligoFileTests.SliceStatisticsReportsUnwritableFolder;
var
  Table: TSliceLayers;
  ErrorText: string;
begin
  Table := nil;
  // папки нет - файл не записать
  AssertFalse(SaveSliceStatistics(FilePath('missing'), Table, SLICES_EZD_FILE,
    ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure WriteText(const AFileName, AText: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
end;

const
  LAYS_HEADER = 'Layer'#9'Letter'#9'Filepath' + LineEnding;

procedure TOligoFileTests.SliceFileMissingFails;
var
  Table: TSliceLayers;
begin
  SetLength(Table, 1);
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileRejectsBadLayerNumber;
var
  Table: TSliceLayers;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + 'x'#9'A'#9'a.ezd');
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileWithBadLineGivesEmptyTable;
var
  Table: TSliceLayers;
begin
  // первая строка хорошая, вторая - нет: наполовину прочитанной таблицы нет
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + '1'#9'A'#9'a.ezd' +
    LineEnding + '2'#9'T');
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileWithoutLayersFails;
var
  Table: TSliceLayers;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER);
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileSkipsEmptyLines;
var
  Table: TSliceLayers;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + '1'#9'A'#9'a.ezd' +
    LineEnding + LineEnding + '2'#9'T'#9'b.ezd' + LineEnding + LineEnding);
  AssertEquals(0, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(2, Length(Table));
  AssertEquals(2, Table[1].LayerNumber);
  AssertEquals(FilePath('b.ezd'), Table[1].EZDFile);
end;

procedure TOligoFileTests.WriteLayerFilesBuildsTableAndFiles;
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  Loaded: TMatrix;
  ErrorText: string;
  I: Integer;
begin
  Layers := SliceOligoArray(Arr(['AT;GT']));
  AssertTrue(ErrorText, WriteLayerFiles(Layers, FDirectory, Table, ErrorText));
  AssertEquals(Length(Layers), Length(Table));
  for I := 0 to High(Layers) do
  begin
    AssertEquals(Layers[I].Number, Table[I].LayerNumber);
    AssertEquals(Layers[I].Letter, Table[I].Letter);
    AssertEquals(Layers[I].Count, Table[I].LetterCount);
    AssertEquals(FilePath(LayerFileName(Layers[I])), Table[I].MatrixFile);
    Loaded := nil;
    AssertTrue(ReadMatrixFromFile(Table[I].MatrixFile, Loaded));
    AssertEquals(MatrixToText(Layers[I].Matrix), MatrixToText(Loaded));
  end;
end;

procedure TOligoFileTests.WriteLayerFilesFailureGivesEmptyTable;
var
  Table: TSliceLayers;
  ErrorText: string;
begin
  AssertFalse(WriteLayerFiles(SliceOligoArray(Arr(['AT;GT'])),
    FilePath('missing'), Table, ErrorText));
  AssertEquals(0, Length(Table));
  AssertTrue(ErrorText <> '');
end;

procedure TOligoFileTests.SliceArrayIntoFolderWritesLayersAndStatistics;
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  Lines: TStringList;
  ErrorText: string;
begin
  AssertTrue(ForceDirectories(FilePath('layers')));
  AssertTrue(ErrorText, SliceArrayIntoFolder(Arr(['AT;GT']), FilePath('layers'),
    FDirectory, Layers, Table, ErrorText));
  AssertEquals(Length(Layers), Length(Table));
  AssertTrue(FileExists(Table[0].MatrixFile));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath('Slices.txt'));
    AssertEquals(Length(Table) + 1, Lines.Count);
    AssertTrue(Pos('layers' + PathDelim + 'Layer1_', Lines[1]) > 0);
  finally
    Lines.Free;
  end;
end;

procedure TOligoFileTests.SliceArrayIntoFolderFailureGivesEmptyTable;
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  ErrorText: string;
begin
  // папки для слоёв нет - матрицы не записать
  AssertFalse(SliceArrayIntoFolder(Arr(['AT;GT']), FilePath('missing'),
    FDirectory, Layers, Table, ErrorText));
  AssertEquals(0, Length(Table));
  AssertTrue(ErrorText <> '');
  AssertFalse(FileExists(FilePath('Slices.txt')));
end;

function SliceTableOf(ACount: Integer): TSliceLayers;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I] := Default(TSliceLayer);
    Result[I].LayerNumber := I + 1;
    Result[I].Letter := 'A';
  end;
end;

procedure TOligoFileTests.DocumentSlicingIsKeptAsCopy;
var
  Doc: TOligoArrayDocument;
  Table: TSliceLayers;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertFalse(Doc.HasSlicing);
    Table := SliceTableOf(2);
    Doc.SetSlicing(Table, 'D:\arr');
    Table[0].Letter := 'T';
    AssertTrue(Doc.HasSlicing);
    AssertEquals(2, Length(Doc.SliceTable));
    AssertEquals('A', Doc.SliceTable[0].Letter);
    AssertEquals('D:\arr', Doc.SliceDir);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.DocumentSlicingSurvivesSave;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['AT']));
    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    AssertTrue(ErrorText, Doc.SaveToFile(FilePath('a.csv'), ErrorText));
    AssertTrue(Doc.HasSlicing);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.DocumentForgetsSlicingWhenArrayIsReplaced;
var
  Doc: TOligoArrayDocument;
  ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('a.csv'), Arr(['AT']), ErrorText));
    Doc.NewArray(Arr(['G']));
    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    Doc.NewArray(Arr(['C']));
    AssertFalse('новый массив', Doc.HasSlicing);
    AssertEquals('', Doc.SliceDir);

    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('a.csv'), ErrorText));
    AssertFalse('загрузка', Doc.HasSlicing);

    // неудачная загрузка документ не меняет - слои остаются
    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    AssertFalse(Doc.LoadFromFile(FilePath('missing.csv'), ErrorText));
    AssertTrue('неудачная загрузка', Doc.HasSlicing);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.DocumentForgetsSlicingOnClearAndClose;
var
  Doc: TOligoArrayDocument;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['AT']));
    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    Doc.ClearCells;
    AssertFalse('очистка', Doc.HasSlicing);

    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    Doc.Close;
    AssertFalse('удаление из окна', Doc.HasSlicing);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.DocumentForgetsSlicingWhenCellChanges;
var
  Doc: TOligoArrayDocument;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['AT;G']));
    Doc.SetSlicing(SliceTableOf(1), FDirectory);
    // то же значение (с учётом регистра) - не изменение, слои остаются
    AssertTrue(Doc.SetCell(0, 0, 'at'));
    AssertTrue('без изменения', Doc.HasSlicing);
    // ячейки вне массива нет - ничего не меняется
    AssertFalse(Doc.SetCell(5, 5, 'C'));
    AssertTrue('вне массива', Doc.HasSlicing);
    AssertTrue(Doc.SetCell(0, 1, 'C'));
    AssertFalse('ячейка изменена', Doc.HasSlicing);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.LoadMatrixFileKeepsRowsAndColumns;
var
  M: TMatrix;
  ErrorText: string;
begin
  // 2 строки по 5 столбцов - не квадратная, чтобы не перепутать
  AssertTrue(SaveMatrixAsFile(Matrix(['10101', '01010']), FilePath('m.txt')));
  M := nil;
  AssertTrue(ErrorText, LoadMatrixFile(FilePath('m.txt'), M, ErrorText));
  AssertEquals('строки', 2, Length(M));
  AssertEquals('столбцы', 5, Length(M[0]));
  AssertEquals('10101|01010', MatrixToText(M));
end;

procedure TOligoFileTests.LoadMatrixFileReportsErrorAndKeepsMatrix;
var
  M: TMatrix;
  ErrorText: string;
  Lines: TStringList;
begin
  M := Matrix(['11']);
  AssertFalse(LoadMatrixFile(FilePath('missing.txt'), M, ErrorText));
  AssertTrue('нет файла', ErrorText <> '');
  AssertEquals('11', MatrixToText(M));

  Lines := TStringList.Create;
  try
    Lines.Text := '3 2' + LineEnding + ' 1 0 1';  // второй строки нет
    Lines.SaveToFile(FilePath('bad.txt'));
    Lines.Text := '';
    Lines.SaveToFile(FilePath('empty.txt'));
  finally
    Lines.Free;
  end;
  AssertFalse(LoadMatrixFile(FilePath('bad.txt'), M, ErrorText));
  AssertTrue('неполная', ErrorText <> '');
  AssertFalse(LoadMatrixFile(FilePath('empty.txt'), M, ErrorText));
  AssertTrue('пустой файл', ErrorText <> '');
  AssertEquals('11', MatrixToText(M));
end;

procedure TOligoFileTests.GeometryFileMissingGivesDefaults;
var
  G: TMarkGeometry;
begin
  G := LoadMarkGeometry(FilePath('missing.ini'));
  AssertEquals(0.1, G.Step, 1e-9);
  AssertEquals(10, G.Group);
  AssertEquals(0.1, G.GroupStep, 1e-9);
  AssertTrue(G.AutoCenter);
  AssertEquals(0.0, G.BiasX, 1e-9);
  AssertEquals(0.0, G.BiasY, 1e-9);
end;

procedure TOligoFileTests.GeometryFileRoundTrip;
var
  G, Loaded: TMarkGeometry;
  ErrorText: string;
begin
  G := Default(TMarkGeometry);
  G.Step := 0.125;
  G.Group := 4;
  G.GroupStep := 0.05;
  G.AutoCenter := False;
  G.BiasX := -1.5;
  G.BiasY := 2.25;
  AssertTrue(ErrorText, SaveMarkGeometry(FilePath('g.ini'), G, ErrorText));
  Loaded := LoadMarkGeometry(FilePath('g.ini'));
  AssertEquals(0.125, Loaded.Step, 1e-9);
  AssertEquals(4, Loaded.Group);
  AssertEquals(0.05, Loaded.GroupStep, 1e-9);
  AssertFalse(Loaded.AutoCenter);
  AssertEquals(-1.5, Loaded.BiasX, 1e-9);
  AssertEquals(2.25, Loaded.BiasY, 1e-9);
end;

procedure TOligoFileTests.GeometryFileUsesDecimalPoint;
var
  Lines: TStringList;
  ErrorText: string;
begin
  // файл не зависит от региональных настроек Windows
  AssertTrue(ErrorText, SaveMarkGeometry(FilePath('g.ini'), DefaultMarkGeometry,
    ErrorText));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath('g.ini'));
    AssertEquals('0.1', Lines.Values['Step']);
  finally
    Lines.Free;
  end;
end;

procedure TOligoFileTests.GeometryFileReadsCommaAndSkipsBadValues;
var
  Lines: TStringList;
  G: TMarkGeometry;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Geometry]');
    Lines.Add('Step=0,2');
    Lines.Add('Group=-3');
    Lines.Add('GroupStep=abc');
    Lines.Add('BiasX=1.5');
    Lines.SaveToFile(FilePath('g.ini'));
  finally
    Lines.Free;
  end;
  G := LoadMarkGeometry(FilePath('g.ini'));
  AssertEquals('запятая', 0.2, G.Step, 1e-9);
  AssertEquals('отрицательное - по умолчанию', 10, G.Group);
  AssertEquals('не число - по умолчанию', 0.1, G.GroupStep, 1e-9);
  AssertEquals(1.5, G.BiasX, 1e-9);
  AssertTrue('нет ключа - по умолчанию', G.AutoCenter);
end;

procedure TOligoFileTests.GeometrySaveKeepsOtherSections;
var
  Lines: TStringList;
  ErrorText: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Other]');
    Lines.Add('Key=Value');
    Lines.SaveToFile(FilePath('sequences.ini'));
    AssertTrue(ErrorText, SaveMarkGeometry(FilePath('sequences.ini'),
      DefaultMarkGeometry, ErrorText));
    Lines.LoadFromFile(FilePath('sequences.ini'));
    AssertTrue(Lines.IndexOf('[Other]') >= 0);
    AssertTrue(Lines.IndexOf('Key=Value') >= 0);
    AssertTrue(Lines.IndexOf('[Geometry]') >= 0);
  finally
    Lines.Free;
  end;
end;

procedure TOligoFileTests.GeometryFileKeepsSpotAndSubstrate;
var
  G: TMarkGeometry;
  Lines: TStringList;
  ErrorText: string;
begin
  AssertEquals(15.0, DefaultMarkGeometry.SpotSize, 1e-9);
  AssertEquals(20.0, DefaultMarkGeometry.SubstrateDiameter, 1e-9);
  G := DefaultMarkGeometry;
  G.SpotSize := 60;
  G.SubstrateDiameter := 25.5;
  AssertTrue(ErrorText, SaveMarkGeometry(FilePath('g.ini'), G, ErrorText));
  G := LoadMarkGeometry(FilePath('g.ini'));
  AssertEquals(60.0, G.SpotSize, 1e-9);
  AssertEquals(25.5, G.SubstrateDiameter, 1e-9);

  // ноль и меньше - по умолчанию
  Lines := TStringList.Create;
  try
    Lines.Add('[Geometry]');
    Lines.Add('SpotSize=0');
    Lines.Add('SubstrateDiameter=-1');
    Lines.SaveToFile(FilePath('bad.ini'));
  finally
    Lines.Free;
  end;
  G := LoadMarkGeometry(FilePath('bad.ini'));
  AssertEquals(15.0, G.SpotSize, 1e-9);
  AssertEquals(20.0, G.SubstrateDiameter, 1e-9);

  // диаметр 0 - подложки нет, это допустимое значение
  Lines := TStringList.Create;
  try
    Lines.Add('[Geometry]');
    Lines.Add('SubstrateDiameter=0');
    Lines.SaveToFile(FilePath('nosubstrate.ini'));
  finally
    Lines.Free;
  end;
  G := LoadMarkGeometry(FilePath('nosubstrate.ini'));
  AssertEquals(0.0, G.SubstrateDiameter, 1e-9);
end;

procedure TOligoFileTests.GeometrySaveReportsUnwritableFolder;
var
  ErrorText: string;
begin
  // на месте папки - файл, создать папку нельзя
  AssertTrue(SaveMatrixAsFile(Matrix(['1']), FilePath('blocker')));
  AssertFalse(SaveMarkGeometry(FilePath('blocker' + PathDelim + 'g.ini'),
    DefaultMarkGeometry, ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TOligoFileTests.NewArrayIsSuggestedIntoDatedFolder;
var
  Doc: TOligoArrayDocument;
  Folder, FileName: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    Doc.NewArray(Arr(['AT']));
    Doc.SuggestSaveLocation('D:\data\arrays', EncodeDate(2026, 11, 3) +
      EncodeTime(14, 5, 0, 0), Folder, FileName);
    AssertEquals('array_2026-11-03_1405', FileName);
    AssertEquals('D:\data\arrays\array_2026-11-03_1405', Folder);
  finally
    Doc.Free;
  end;
end;

procedure TOligoFileTests.OpenedArrayIsSuggestedIntoItsFile;
var
  Doc: TOligoArrayDocument;
  Folder, FileName, ErrorText: string;
begin
  Doc := TOligoArrayDocument.Create;
  try
    AssertTrue(ErrorText, SaveOligoArrayFile(FilePath('my.csv'), Arr(['AT']), ErrorText));
    AssertTrue(ErrorText, Doc.LoadFromFile(FilePath('my.csv'), ErrorText));
    Doc.SuggestSaveLocation('D:\data\arrays', Now, Folder, FileName);
    AssertEquals('my', FileName);
    AssertEquals(ExcludeTrailingPathDelimiter(ExpandFileName(FDirectory)), Folder);
  finally
    Doc.Free;
  end;
end;

{ TGridWidthModeTests }

procedure TGridWidthModeTests.ModesGoInCircle;
begin
  AssertTrue(NextGridWidthMode(gwmDefault) = gwmLongest);
  AssertTrue(NextGridWidthMode(gwmLongest) = gwmSquare);
  AssertTrue(NextGridWidthMode(gwmSquare) = gwmDefault);
end;

{ TOligoMatrixTests }

procedure TOligoMatrixTests.AutoCenterOfEmptyMatrixIsZero;
var
  P: TMatrixPoint;
begin
  P := AutoCenterBiasMatrix(nil, 0.1, 0.1, 10);
  AssertEquals(0.0, P[0], 1e-9);
  AssertEquals(0.0, P[1], 1e-9);
end;

procedure TOligoMatrixTests.AutoCenterWithoutGroups;
var
  P: TMatrixPoint;
begin
  // 3 строки x 5 столбцов, шаг 1: по X сдвиг -2, по Y +1
  P := AutoCenterBiasMatrix(Matrix(['00000', '00000', '00000']), 1.0, 0.0, 0);
  AssertEquals(-2.0, P[0], 1e-9);
  AssertEquals(1.0, P[1], 1e-9);
end;

procedure TOligoMatrixTests.AutoCenterWithGroups;
var
  P: TMatrixPoint;
begin
  // 5 столбцов, группы по 2: два межгрупповых промежутка по 0.5
  P := AutoCenterBiasMatrix(Matrix(['00000']), 1.0, 0.5, 2);
  AssertEquals(-2.5, P[0], 1e-9);
  AssertEquals(0.0, P[1], 1e-9);
end;

procedure TOligoMatrixTests.CopyMatrixMakesIndependentCopy;
var
  Source, Target: TMatrix;
begin
  Source := Matrix(['10', '01']);
  Target := nil;
  CopyMatrix(Source, Target);
  Source[0][0] := 0;
  AssertEquals('10|01', MatrixToText(Target));
end;

procedure TOligoMatrixTests.ResizeMatrixKeepsValuesAndAddsZeros;
var
  M: TMatrix;
begin
  M := Matrix(['12', '34']);
  ResizeMatrix(M, 3, 3);
  AssertEquals('120|340|000', MatrixToText(M));
  ResizeMatrix(M, 1, 2);
  AssertEquals('12', MatrixToText(M));
end;

procedure TOligoMatrixTests.ResizeMatrixToZero;
var
  M: TMatrix;
begin
  M := Matrix(['12']);
  ResizeMatrix(M, 0, 5);
  AssertEquals(0, Length(M));
  ResizeMatrix(M, 2, -1);
  AssertEquals(2, Length(M));
  AssertEquals(0, Length(M[0]));
end;

{ TMarkGeometryTests }

function Geometry(AAutoCenter: Boolean): TMarkGeometry;
begin
  Result := Default(TMarkGeometry);
  Result.Step := 1.0;
  Result.GroupStep := 0.5;
  Result.Group := 2;
  Result.AutoCenter := AAutoCenter;
  Result.BiasX := 3.25;
  Result.BiasY := -1.5;
end;

procedure TMarkGeometryTests.ManualBiasIsTakenAsIs;
var
  P: TMatrixPoint;
begin
  P := MarkBias(Matrix(['00000']), Geometry(False));
  AssertEquals(3.25, P[0], 1e-9);
  AssertEquals(-1.5, P[1], 1e-9);
end;

procedure TMarkGeometryTests.AutoCenterUsesMatrixAndSteps;
var
  P: TMatrixPoint;
begin
  // то же, что AutoCenterWithGroups: ручное смещение не учитывается
  P := MarkBias(Matrix(['00000']), Geometry(True));
  AssertEquals(-2.5, P[0], 1e-9);
  AssertEquals(0.0, P[1], 1e-9);
end;

procedure TMarkGeometryTests.MarkPointsUseStepGroupsAndBias;
var
  Points: TArrOfTPoint;
begin
  // шаг 1, группы по 2 с доп. шагом 0.5, ручное смещение (3.25; -1.5)
  Points := MatrixToMarkPoints(Matrix(['101', '010']), Geometry(False));
  AssertEquals(3, Length(Points));
  AssertEquals(3.25, Points[0][0], 1e-9);
  AssertEquals(-1.5, Points[0][1], 1e-9);
  AssertEquals(5.75, Points[1][0], 1e-9); // 2*1 + 0.5 за группу + 3.25
  AssertEquals(-1.5, Points[1][1], 1e-9);
  AssertEquals(4.25, Points[2][0], 1e-9);
  AssertEquals(-2.5, Points[2][1], 1e-9);
end;

procedure TMarkGeometryTests.MarkPointsOfEmptyMatrixAreEmpty;
begin
  AssertEquals(0, Length(MatrixToMarkPoints(Matrix(['000']), Geometry(False))));
end;

procedure TMarkGeometryTests.SubstrateOverflowCountsSpotRadius;
var
  G: TMarkGeometry;
  P: TArrOfTPoint;
begin
  G := DefaultMarkGeometry;
  G.SubstrateDiameter := 2;  // радиус 1 мм
  G.SpotSize := 200;         // радиус пятна 0.1 мм
  P := nil;
  SetLength(P, 2);
  P[0][0] := 0;
  P[0][1] := 0;
  P[1][0] := 0;
  P[1][1] := -0.9;           // край пятна ровно на краю подложки
  AssertEquals('помещается', 0.0, SubstrateOverflow(P, G), 1e-9);
  P[1][0] := 0.6;
  P[1][1] := 0.8;            // до центра 1 мм, край пятна - 1.1 мм
  AssertEquals('выходит', 0.1, SubstrateOverflow(P, G), 1e-9);
end;

procedure TMarkGeometryTests.SubstrateOutlineIsCircleOfDiameter;
var
  G: TMarkGeometry;
  P: TArrOfTPoint;
  I: Integer;
begin
  G := DefaultMarkGeometry;
  G.SubstrateDiameter := 10;
  P := SubstrateOutline(G, 8);
  AssertEquals(8, Length(P));
  AssertEquals(5.0, P[0][0], 1e-9);
  AssertEquals(0.0, P[0][1], 1e-9);
  for I := 0 to High(P) do
    AssertEquals(5.0, Sqrt(Sqr(P[I][0]) + Sqr(P[I][1])), 1e-9);
end;

procedure TMarkGeometryTests.ZeroDiameterMeansNoSubstrate;
var
  G: TMarkGeometry;
  P: TArrOfTPoint;
  ErrorText: string;
begin
  G := DefaultMarkGeometry;
  AssertTrue(HasSubstrate(G));
  G.SubstrateDiameter := 0;
  AssertFalse(HasSubstrate(G));
  AssertEquals('нет контура', 0, Length(SubstrateOutline(G, 8)));
  P := nil;
  SetLength(P, 1);
  P[0][0] := 500;            // далеко, но подложки нет
  P[0][1] := 500;
  AssertTrue(SubstrateOverflow(P, G) < 0);
  AssertTrue(CheckArrayFitsSubstrate(P, G, ErrorText));
  AssertEquals('', ErrorText);
end;

procedure TMarkGeometryTests.FitCheckExplainsWhatIsWrong;
var
  G: TMarkGeometry;
  P: TArrOfTPoint;
  ErrorText: string;
begin
  G := DefaultMarkGeometry;
  G.SubstrateDiameter := 2;  // радиус 1 мм
  G.SpotSize := 200;         // пятно 0.2 мм
  P := nil;
  SetLength(P, 2);
  P[0][0] := -0.5;
  P[0][1] := 0;
  P[1][0] := 0.5;
  P[1][1] := 0;
  AssertTrue('помещается', CheckArrayFitsSubstrate(P, G, ErrorText));
  AssertEquals('', ErrorText);

  P[1][0] := 1.5;            // край пятна на 1.6 мм от центра
  AssertFalse(CheckArrayFitsSubstrate(P, G, ErrorText));
  // русский текст между модулями с разной кодировкой исходников не
  // сравнить, поэтому проверяем числа: диаметр, размер 2.2 x 0.2, выход 0.6
  AssertTrue('диаметр', Pos(': 2 ', ErrorText) > 0);
  AssertTrue('ширина', Pos(' 2' + DefaultFormatSettings.DecimalSeparator + '2 ',
    ErrorText) > 0);
  AssertTrue('высота', Pos(' 0' + DefaultFormatSettings.DecimalSeparator + '2 ',
    ErrorText) > 0);
  AssertTrue('выход', Pos(' 0' + DefaultFormatSettings.DecimalSeparator + '6 ',
    ErrorText) > 0);
  AssertEquals('пять строк', 5, Length(ErrorText.Split([LineEnding])));
end;

{ TOligoPasteTests }

procedure TOligoPasteTests.MeasuresRowsAndWidestRow;
var
  Rows, Cols: Integer;
begin
  MeasurePasteText('A'#9'T'#13#10'G'#9'C'#9'A'#13#10'T', Rows, Cols);
  AssertEquals(3, Rows);
  AssertEquals(3, Cols);
end;

procedure TOligoPasteTests.TrailingLineBreakIsNotARow;
var
  Rows, Cols: Integer;
begin
  MeasurePasteText('A'#9'T'#13#10, Rows, Cols);
  AssertEquals(1, Rows);
  AssertEquals(2, Cols);
  MeasurePasteText('', Rows, Cols);
  AssertEquals(0, Rows);
  AssertEquals(0, Cols);
end;

procedure TOligoPasteTests.FitsWhenEnoughRoom;
var
  Msg: string;
begin
  // таблица 3x3 с заголовками: от ячейки (1,1) свободно 2x2
  AssertTrue(CheckPasteFits('A'#9'T'#13#10'G'#9'C'#13#10, 1, 1, 3, 3, Msg));
  AssertEquals('', Msg);
end;

procedure TOligoPasteTests.DoesNotFitByRows;
var
  Msg: string;
begin
  AssertFalse(CheckPasteFits('A'#13#10'T'#13#10'G', 2, 1, 3, 3, Msg));
  AssertTrue(Pos('3 ', Msg) > 0);
  AssertTrue(Pos('1 ', Msg) > 0);
end;

procedure TOligoPasteTests.DoesNotFitByColumns;
var
  Msg: string;
begin
  AssertFalse(CheckPasteFits('A'#9'T'#9'G', 1, 2, 3, 3, Msg));
  AssertTrue(Msg <> '');
end;

{ TFileNameCheckTests }

procedure TFileNameCheckTests.AcceptsNormalName;
var
  ErrorText: string;
begin
  AssertTrue(CheckFileNamePart('array_2026-11-02_2130', 'Папка', ErrorText));
  AssertTrue(CheckFileNamePart('массив 1', 'Папка', ErrorText));
  AssertEquals('', ErrorText);
end;

procedure TFileNameCheckTests.RejectsEmptyName;
var
  ErrorText: string;
begin
  AssertFalse(CheckFileNamePart('', 'Папка', ErrorText));
  AssertFalse(CheckFileNamePart('   ', 'Папка', ErrorText));
  AssertTrue(Pos('Папка', ErrorText) = 1);
end;

procedure TFileNameCheckTests.RejectsForbiddenCharacters;
const
  BAD = '\/:*?"<>|';
var
  ErrorText: string;
  I: Integer;
begin
  for I := 1 to Length(BAD) do
    AssertFalse('символ ' + BAD[I],
      CheckFileNamePart('a' + BAD[I] + 'b', 'Имя файла', ErrorText));
end;

procedure TFileNameCheckTests.RejectsTrailingDotOrSpace;
var
  ErrorText: string;
begin
  AssertFalse(CheckFileNamePart('name.', 'Имя файла', ErrorText));
  AssertFalse(CheckFileNamePart('name ', 'Имя файла', ErrorText));
end;

procedure TFileNameCheckTests.FilePathJoinsFolderNameAndExtension;
var
  FilePath, ErrorText: string;
begin
  AssertTrue(ErrorText, MakeFilePathInFolder(' C:\Users\me\Desktop ', ' arr 1 ',
    '.csv', FilePath, ErrorText));
  AssertEquals('C:\Users\me\Desktop\arr 1.csv', FilePath);
end;

procedure TFileNameCheckTests.FilePathDoesNotDoubleExtension;
var
  FilePath, ErrorText: string;
begin
  AssertTrue(ErrorText, MakeFilePathInFolder('D:\data', 'arr.CSV', '.csv',
    FilePath, ErrorText));
  AssertEquals('D:\data\arr.csv', FilePath);
end;

procedure TFileNameCheckTests.FilePathAcceptsDriveRootAndTrailingSlash;
var
  FilePath, ErrorText: string;
begin
  AssertTrue(ErrorText, MakeFilePathInFolder('D:\', 'a', '.csv', FilePath, ErrorText));
  AssertEquals('D:\a.csv', FilePath);
  AssertTrue(ErrorText, MakeFilePathInFolder('D:\data\', 'a', '.csv', FilePath, ErrorText));
  AssertEquals('D:\data\a.csv', FilePath);
end;

procedure TFileNameCheckTests.FilePathRejectsRelativeOrEmptyFolder;
var
  FilePath, ErrorText: string;
begin
  AssertFalse(MakeFilePathInFolder('', 'a', '.csv', FilePath, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertFalse(MakeFilePathInFolder('data\arrays', 'a', '.csv', FilePath, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertEquals('', FilePath);
end;

procedure TFileNameCheckTests.FilePathRejectsBadFolderPartOrName;
var
  FilePath, ErrorText: string;
begin
  AssertFalse(MakeFilePathInFolder('D:\da?ta\x', 'a', '.csv', FilePath, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertFalse(MakeFilePathInFolder('D:\data.\x', 'a', '.csv', FilePath, ErrorText));
  AssertFalse(MakeFilePathInFolder('D:\data', 'a:b', '.csv', FilePath, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertFalse(MakeFilePathInFolder('D:\data', '', '.csv', FilePath, ErrorText));
end;

procedure TFileNameCheckTests.FolderPathChecksDriveAndParts;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, CheckFolderPath('D:\data\arrays\a1\layers', ErrorText));
  AssertTrue(ErrorText, CheckFolderPath('D:\', ErrorText));
  AssertFalse(CheckFolderPath('layers', ErrorText));
  AssertFalse(CheckFolderPath('', ErrorText));
  AssertFalse(CheckFolderPath('D:\data\la|yers', ErrorText));
  AssertTrue(ErrorText <> '');
end;

initialization
  RegisterTest(TOligoArrayTests);
  RegisterTest(TOligoSlicingTests);
  RegisterTest(TOligoFileTests);
  RegisterTest(TOligoMatrixTests);
  RegisterTest(TMarkGeometryTests);
  RegisterTest(TOligoPasteTests);
  RegisterTest(TFileNameCheckTests);
  RegisterTest(TGridWidthModeTests);

end.
