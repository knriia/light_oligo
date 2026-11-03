unit OligoTests;
// Тесты блока последовательностей: массив олигов, CSV, слайсинг, матрицы слоёв.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MatrixTypes, OligoArray,
  OligoArrayCsv, OligoSlicing, OligoMatrix, MarkGeometry, OligoPaste, OligoArrayDocument,
  OligoSlices, AppPaths;

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
  end;

  TOligoMatrixTests = class(TTestCase)
  published
    procedure AutoCenterOfEmptyMatrixIsZero;
    procedure AutoCenterWithoutGroups;
    procedure AutoCenterWithGroups;
    procedure CopyMatrixMakesIndependentCopy;
  end;

  TMarkGeometryTests = class(TTestCase)
  published
    procedure ManualBiasIsTakenAsIs;
    procedure AutoCenterUsesMatrixAndSteps;
    procedure MarkPointsUseStepGroupsAndBias;
    procedure MarkPointsOfEmptyMatrixAreEmpty;
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
  Table: TArrSliceStruc;
  Lines: TStringList;
  ErrorText: string;
begin
  AssertTrue(ForceDirectories(FilePath('layers')));
  SetLength(Table, 1);
  Table[0] := Default(TSliceStruc);
  Table[0].LayerCount := 1;
  Table[0].Letter := 'T';
  Table[0].NumOfChar := 2;
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
  Table, Loaded: TArrSliceStruc;
  Lines: TStringList;
  ErrorText: string;
begin
  SetLength(Table, 2);
  Table[0] := Default(TSliceStruc);
  Table[0].LayerCount := 1;
  Table[0].Letter := 'T';
  Table[0].EZDFile := FilePath('ezd\Layer1_T2.ezd');
  Table[1] := Default(TSliceStruc);
  Table[1].LayerCount := 2;
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
  Table: TArrSliceStruc;
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
  Table: TArrSliceStruc;
begin
  SetLength(Table, 1);
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileRejectsBadLayerNumber;
var
  Table: TArrSliceStruc;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + 'x'#9'A'#9'a.ezd');
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileWithBadLineGivesEmptyTable;
var
  Table: TArrSliceStruc;
begin
  // первая строка хорошая, вторая - нет: наполовину прочитанной таблицы нет
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + '1'#9'A'#9'a.ezd' +
    LineEnding + '2'#9'T');
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileWithoutLayersFails;
var
  Table: TArrSliceStruc;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER);
  AssertEquals(-1, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(0, Length(Table));
end;

procedure TOligoFileTests.SliceFileSkipsEmptyLines;
var
  Table: TArrSliceStruc;
begin
  WriteText(FilePath('Slices.lays'), LAYS_HEADER + '1'#9'A'#9'a.ezd' +
    LineEnding + LineEnding + '2'#9'T'#9'b.ezd' + LineEnding + LineEnding);
  AssertEquals(0, LoadSliceFile(Table, FilePath('Slices.lays')));
  AssertEquals(2, Length(Table));
  AssertEquals(2, Table[1].LayerCount);
  AssertEquals(FilePath('b.ezd'), Table[1].EZDFile);
end;

procedure TOligoFileTests.WriteLayerFilesBuildsTableAndFiles;
var
  Layers: TOligoLayers;
  Table: TArrSliceStruc;
  Loaded: TMatrix;
  ErrorText: string;
  I: Integer;
begin
  Layers := SliceOligoArray(Arr(['AT;GT']));
  AssertTrue(ErrorText, WriteLayerFiles(Layers, FDirectory, Table, ErrorText));
  AssertEquals(Length(Layers), Length(Table));
  for I := 0 to High(Layers) do
  begin
    AssertEquals(Layers[I].Number, Table[I].LayerCount);
    AssertEquals(Layers[I].Letter, Table[I].Letter);
    AssertEquals(Layers[I].Count, Table[I].NumOfChar);
    AssertEquals(FilePath(LayerFileName(Layers[I])), Table[I].MatrixFile);
    Loaded := nil;
    AssertTrue(ReadMatrixFromFile(Table[I].MatrixFile, Loaded));
    AssertEquals(MatrixToText(Layers[I].Matrix), MatrixToText(Loaded));
  end;
end;

procedure TOligoFileTests.WriteLayerFilesFailureGivesEmptyTable;
var
  Table: TArrSliceStruc;
  ErrorText: string;
begin
  AssertFalse(WriteLayerFiles(SliceOligoArray(Arr(['AT;GT'])),
    FilePath('missing'), Table, ErrorText));
  AssertEquals(0, Length(Table));
  AssertTrue(ErrorText <> '');
end;

{ TOligoMatrixTests }

procedure TOligoMatrixTests.AutoCenterOfEmptyMatrixIsZero;
var
  P: TPoint;
begin
  P := AutoCenterBiasMatrix(nil, 0.1, 0.1, 10);
  AssertEquals(0.0, P[0], 1e-9);
  AssertEquals(0.0, P[1], 1e-9);
end;

procedure TOligoMatrixTests.AutoCenterWithoutGroups;
var
  P: TPoint;
begin
  // 3 строки x 5 столбцов, шаг 1: по X сдвиг -2, по Y +1
  P := AutoCenterBiasMatrix(Matrix(['00000', '00000', '00000']), 1.0, 0.0, 0);
  AssertEquals(-2.0, P[0], 1e-9);
  AssertEquals(1.0, P[1], 1e-9);
end;

procedure TOligoMatrixTests.AutoCenterWithGroups;
var
  P: TPoint;
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
  P: TPoint;
begin
  P := MarkBias(Matrix(['00000']), Geometry(False));
  AssertEquals(3.25, P[0], 1e-9);
  AssertEquals(-1.5, P[1], 1e-9);
end;

procedure TMarkGeometryTests.AutoCenterUsesMatrixAndSteps;
var
  P: TPoint;
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

end.
