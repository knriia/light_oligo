unit SynthesisSessionTests;
// Тесты сессии синтеза: слои, протоколы по буквам, готовность к запуску.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, OligoSlices, ProtocolFormat,
  ProtocolModel, SynthesisSession;

type
  TSynthesisSessionTests = class(TTestCase)
  private
    FDirectory: string;
    FSession: TSynthesisSession;
    function FilePath(const AName: string): string;
    procedure WriteProtocol(const AName, ABlock: string);
    procedure WriteLayers(const AName: string; const ALines: array of string);
    function Layer(ANumber: Integer; const ALetter: string): TSliceLayer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure LetterIsFileNameWithoutPathAndExtension;
    procedure ProtocolIsStoredByLetterInLoadOrder;
    procedure SecondProtocolForSameLetterIsRejected;
    procedure BrokenOrMissingProtocolFileKeepsSession;
    procedure SetLayersCopiesTable;
    procedure LoadLayersFileReplacesLayers;
    procedure LoadLayersFileReportsEachProblem;
    procedure MissingLettersAreUniqueInLayerOrder;
    procedure NotReadyWithoutLayers;
    procedure NotReadyNamesLettersWithoutProtocol;
    procedure ReadyWhenEveryLetterHasProtocol;
    procedure ClearRemovesLayersAndProtocols;
    procedure ProtocolIndexOutsideRangeRaises;
  end;

implementation

procedure TSynthesisSessionTests.SetUp;
begin
  inherited SetUp;
  FSession := TSynthesisSession.Create;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_synth_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TSynthesisSessionTests.TearDown;
var
  Search: TSearchRec;
begin
  FSession.Free;
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

function TSynthesisSessionTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TSynthesisSessionTests.WriteProtocol(const AName, ABlock: string);
var
  F: TStringList;
begin
  F := TStringList.Create;
  try
    F.Add('Block=' + ABlock + ';');
    F.Add(#9'Pause=5;');
    F.SaveToFile(FilePath(AName));
  finally
    F.Free;
  end;
end;

procedure TSynthesisSessionTests.WriteLayers(const AName: string;
  const ALines: array of string);
var
  F: TStringList;
  I: Integer;
begin
  F := TStringList.Create;
  try
    F.Add('Layer' + #9 + 'Letter' + #9 + 'File');
    for I := 0 to High(ALines) do
      F.Add(ALines[I]);
    F.SaveToFile(FilePath(AName));
  finally
    F.Free;
  end;
end;

function TSynthesisSessionTests.Layer(ANumber: Integer;
  const ALetter: string): TSliceLayer;
begin
  Result := Default(TSliceLayer);
  Result.LayerNumber := ANumber;
  Result.Letter := ALetter;
  Result.EZDFile := 'Layer' + IntToStr(ANumber) + '.ezd';
end;

procedure TSynthesisSessionTests.LetterIsFileNameWithoutPathAndExtension;
begin
  AssertEquals('A', TSynthesisSession.LetterOfFile('D:\data\protocols\A.pro'));
  AssertEquals('Greed', TSynthesisSession.LetterOfFile('Greed.pro'));
  AssertEquals('T', TSynthesisSession.LetterOfFile('T'));
end;

procedure TSynthesisSessionTests.ProtocolIsStoredByLetterInLoadOrder;
var
  Letter, ErrorText: string;
begin
  WriteProtocol('G.pro', 'GBlock');
  WriteProtocol('A.pro', 'ABlock');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('G.pro'), Letter,
    ErrorText));
  AssertEquals('G', Letter);
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  AssertEquals(2, FSession.ProtocolCount);
  AssertEquals('G', FSession.ProtocolLetters[0]);
  AssertEquals('A', FSession.ProtocolLetters[1]);
  AssertTrue(FSession.HasProtocol('A'));
  AssertFalse(FSession.HasProtocol('T'));
  AssertEquals('ABlock', FSession.ProtocolOf('A').BlockNames[0]);
  AssertEquals('GBlock', FSession.ProtocolOf('G').BlockNames[0]);
  AssertTrue(FSession.ProtocolOf('T') = nil);
end;

procedure TSynthesisSessionTests.SecondProtocolForSameLetterIsRejected;
var
  Letter, ErrorText: string;
begin
  WriteProtocol('A.pro', 'First');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  WriteProtocol('A.pro', 'Second');
  AssertFalse(FSession.AddProtocolFile(FilePath('A.pro'), Letter, ErrorText));
  AssertTrue(ErrorText, Pos('"A"', ErrorText) > 0);
  AssertEquals(1, FSession.ProtocolCount);
  AssertEquals('первый протокол остался', 'First',
    FSession.ProtocolOf('A').BlockNames[0]);
end;

procedure TSynthesisSessionTests.BrokenOrMissingProtocolFileKeepsSession;
var
  Letter, ErrorText: string;
  F: TStringList;
begin
  WriteProtocol('A.pro', 'Ok');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  F := TStringList.Create;
  try
    F.Add('Block=Bad;');
    F.Add(#9'Pause=oops;');
    F.SaveToFile(FilePath('C.pro'));
  finally
    F.Free;
  end;
  AssertFalse(FSession.AddProtocolFile(FilePath('C.pro'), Letter, ErrorText));
  AssertTrue(ErrorText, Pos('C.pro', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('2', ErrorText) > 0); // строка с ошибкой
  AssertFalse(FSession.AddProtocolFile(FilePath('none.pro'), Letter, ErrorText));
  AssertTrue(ErrorText, Pos('none.pro', ErrorText) > 0);
  AssertEquals(1, FSession.ProtocolCount);
  AssertFalse('не загруженная буква не появилась', FSession.HasProtocol('C'));
end;

procedure TSynthesisSessionTests.SetLayersCopiesTable;
var
  Table: TSliceLayers;
begin
  SetLength(Table, 2);
  Table[0] := Layer(1, 'A');
  Table[1] := Layer(2, 'T');
  FSession.SetLayers(Table);
  Table[0].Letter := 'X';
  SetLength(Table, 0);
  AssertEquals(2, FSession.LayerCount);
  AssertEquals('A', FSession.Layers[0].Letter);
  FSession.ClearLayers;
  AssertEquals(0, FSession.LayerCount);
end;

procedure TSynthesisSessionTests.LoadLayersFileReplacesLayers;
var
  ErrorText: string;
begin
  FSession.SetLayers(nil);
  WriteLayers('Slices.lays', ['1' + #9 + 'A' + #9 + 'Layer1.ezd',
    '2' + #9 + 'T' + #9 + 'Layer2.ezd']);
  AssertTrue(ErrorText, FSession.LoadLayersFile(FilePath('Slices.lays'),
    ErrorText));
  AssertEquals(2, FSession.LayerCount);
  AssertEquals(2, FSession.Layers[1].LayerNumber);
  AssertEquals('T', FSession.Layers[1].Letter);
  AssertEquals(FilePath('Layer2.ezd'), FSession.Layers[1].EZDFile);
end;

procedure TSynthesisSessionTests.LoadLayersFileReportsEachProblem;
var
  Old: TSliceLayers;
  ErrorText: string;
begin
  SetLength(Old, 1);
  Old[0] := Layer(7, 'G');
  FSession.SetLayers(Old);

  AssertFalse(FSession.LoadLayersFile(FilePath('none.lays'), ErrorText));
  AssertTrue(ErrorText, Pos('none.lays', ErrorText) > 0);

  WriteLayers('two.lays', ['1' + #9 + 'A' + #9 + 'a.ezd', 'broken line']);
  AssertFalse(FSession.LoadLayersFile(FilePath('two.lays'), ErrorText));
  AssertTrue(ErrorText, Pos('two.lays', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('3', ErrorText) > 0); // строка с ошибкой

  WriteLayers('num.lays', ['abc' + #9 + 'A' + #9 + 'a.ezd']);
  AssertFalse(FSession.LoadLayersFile(FilePath('num.lays'), ErrorText));
  AssertTrue(ErrorText, Pos('abc', ErrorText) > 0);
  AssertTrue(ErrorText, Pos('2', ErrorText) > 0);

  WriteLayers('empty.lays', []);
  AssertFalse(FSession.LoadLayersFile(FilePath('empty.lays'), ErrorText));
  AssertTrue(ErrorText, Pos('empty.lays', ErrorText) > 0);

  AssertEquals('слои не изменились', 1, FSession.LayerCount);
  AssertEquals(7, FSession.Layers[0].LayerNumber);
end;

procedure TSynthesisSessionTests.MissingLettersAreUniqueInLayerOrder;
var
  Table: TSliceLayers;
  Missing: TStringArray;
  Letter, ErrorText: string;
begin
  SetLength(Table, 5);
  Table[0] := Layer(1, 'T');
  Table[1] := Layer(2, 'A');
  Table[2] := Layer(3, 'T');
  Table[3] := Layer(4, 'C');
  Table[4] := Layer(5, 'A');
  FSession.SetLayers(Table);
  WriteProtocol('A.pro', 'A');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  Missing := FSession.MissingLetters;
  AssertEquals(2, Length(Missing));
  AssertEquals('T', Missing[0]);
  AssertEquals('C', Missing[1]);
end;

procedure TSynthesisSessionTests.NotReadyWithoutLayers;
var
  ErrorText: string;
begin
  AssertFalse(FSession.CheckReady(ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TSynthesisSessionTests.NotReadyNamesLettersWithoutProtocol;
var
  Table: TSliceLayers;
  ErrorText: string;
begin
  SetLength(Table, 3);
  Table[0] := Layer(1, 'A');
  Table[1] := Layer(2, 'T');
  Table[2] := Layer(3, 'G');
  FSession.SetLayers(Table);
  AssertFalse(FSession.CheckReady(ErrorText));
  AssertTrue(ErrorText, Pos('A, T, G', ErrorText) > 0);
end;

procedure TSynthesisSessionTests.ReadyWhenEveryLetterHasProtocol;
var
  Table: TSliceLayers;
  Letter, ErrorText: string;
begin
  SetLength(Table, 2);
  Table[0] := Layer(1, 'A');
  Table[1] := Layer(2, 'T');
  FSession.SetLayers(Table);
  WriteProtocol('A.pro', 'A');
  WriteProtocol('T.pro', 'T');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  AssertFalse(FSession.CheckReady(ErrorText));
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('T.pro'), Letter,
    ErrorText));
  AssertTrue(ErrorText, FSession.CheckReady(ErrorText));
  AssertEquals('', ErrorText);
end;

procedure TSynthesisSessionTests.ClearRemovesLayersAndProtocols;
var
  Table: TSliceLayers;
  Letter, ErrorText: string;
begin
  SetLength(Table, 1);
  Table[0] := Layer(1, 'A');
  FSession.SetLayers(Table);
  WriteProtocol('A.pro', 'A');
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
  FSession.Clear;
  AssertEquals(0, FSession.LayerCount);
  AssertEquals(0, FSession.ProtocolCount);
  AssertFalse(FSession.HasProtocol('A'));
  // после очистки та же буква загружается снова
  AssertTrue(ErrorText, FSession.AddProtocolFile(FilePath('A.pro'), Letter,
    ErrorText));
end;

procedure TSynthesisSessionTests.ProtocolIndexOutsideRangeRaises;
var
  Raised: Boolean;
  Letter: string;
begin
  Raised := False;
  try
    Letter := FSession.ProtocolLetters[0];
  except
    on EListError do
      Raised := True;
  end;
  AssertTrue(Raised);
end;

initialization
  RegisterTest(TSynthesisSessionTests);

end.
