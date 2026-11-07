unit ScenarioTests;
// Тесты сценариев станции: список, проверка элементов, текст и файл.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ProtocolFormat, ScenarioList,
  ProtocolTestHelpers;

type
  TScenarioListTests = class(TTestCase)
  private
    function Pause(ASeconds: Integer): TScenarioItem;
    function Names(AList: TScenarioList): string;
  published
    procedure NewListIsEmpty;
    procedure AddAppendsAndReturnsIndex;
    procedure InsertPutsItemAtPositionAndAllowsEnd;
    procedure ReplaceChangesOnlyOneItem;
    procedure DeleteShiftsFollowingItems;
    procedure MoveForwardAndBack;
    procedure ClearAndAssignCopyItems;
    procedure ScenarioCountSkipsPauses;
    procedure IndexOutsideListRaises;
  end;

  TScenarioFormatTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
    function Sample: TScenarioList;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure AcceptsValidItems;
    procedure ChecksScenarioLikeSyrStInProtocol;
    procedure RejectsNegativePause;
    procedure SummaryShowsEachKind;
    procedure TextIsSyrStAndPauseLinesWithoutBlockHeader;
    procedure TextRoundTrip;
    procedure EmptyTextGivesEmptyList;
    procedure ProtocolParserAcceptsScenarioText;
    procedure RejectsBlockHeaderLine;
    procedure RejectsOperationsOtherThanSyrStAndPause;
    procedure FailedParseKeepsList;
    procedure SaveAndLoadFile;
    procedure SaveRejectsInvalidItemAndWritesNothing;
    procedure LoadReportsMissingFile;
    procedure LoadReportsBrokenFileAndKeepsList;
    procedure SaveReportsUnwritablePlace;
    procedure LoadsFileWithUtf8Bom;
    procedure ConvertsItemToProtocolStepAndBack;
    procedure OtherProtocolOperationsBecomeSyringe;
  end;

implementation

function Block(const ANames, AValves, AVolumes, ASpeeds: string): TScenarioItem;
begin
  Result := MakeSyringe(MakeStep(ANames, AValves, AVolumes, ASpeeds));
end;

{ TScenarioListTests }

function TScenarioListTests.Pause(ASeconds: Integer): TScenarioItem;
begin
  Result := MakePause(ASeconds);
end;

function TScenarioListTests.Names(AList: TScenarioList): string;
// пауза 5 -> "d5", блок -> его дозаторы
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ',';
    if AList[I].Kind = sikPause then
      Result := Result + 'd' + IntToStr(AList[I].PauseSeconds)
    else
      Result := Result + AList[I].Syringe.Dispensers;
  end;
end;

procedure TScenarioListTests.NewListIsEmpty;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    AssertEquals(0, L.Count);
    AssertEquals(0, L.SyringeCount);
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.AddAppendsAndReturnsIndex;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    AssertEquals(0, L.Add(Block('A', '1', '10', '5')));
    AssertEquals(1, L.Add(Pause(3)));
    AssertEquals('A,d3', Names(L));
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.InsertPutsItemAtPositionAndAllowsEnd;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    L.Add(Block('A', '1', '10', '5'));
    L.Add(Block('B', '1', '10', '5'));
    L.Insert(1, Pause(7));
    AssertEquals('A,d7,B', Names(L));
    L.Insert(0, Pause(1));
    AssertEquals('d1,A,d7,B', Names(L));
    L.Insert(L.Count, Pause(2));
    AssertEquals('d1,A,d7,B,d2', Names(L));
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.ReplaceChangesOnlyOneItem;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    L.Add(Block('A', '1', '10', '5'));
    L.Add(Pause(3));
    L.Add(Block('B', '1', '10', '5'));
    L.Replace(1, Pause(9));
    AssertEquals('A,d9,B', Names(L));
    L.Replace(0, Block('C', '2', '20', '6'));
    AssertEquals('C,d9,B', Names(L));
    AssertEquals('2', L[0].Syringe.Valves);
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.DeleteShiftsFollowingItems;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    L.Add(Block('A', '1', '10', '5'));
    L.Add(Pause(3));
    L.Add(Block('B', '1', '10', '5'));
    L.Delete(1);
    AssertEquals('A,B', Names(L));
    L.Delete(1);
    AssertEquals('A', Names(L));
    L.Delete(0);
    AssertEquals(0, L.Count);
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.MoveForwardAndBack;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    L.Add(Block('A', '1', '10', '5'));
    L.Add(Pause(1));
    L.Add(Block('B', '1', '10', '5'));
    L.Add(Pause(2));
    L.Move(0, 2);
    AssertEquals('d1,B,A,d2', Names(L));
    L.Move(3, 0);
    AssertEquals('d2,d1,B,A', Names(L));
    L.Move(1, 1);
    AssertEquals('d2,d1,B,A', Names(L));
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.ClearAndAssignCopyItems;
var
  A, B: TScenarioList;
begin
  A := TScenarioList.Create;
  B := TScenarioList.Create;
  try
    A.Add(Block('A', '1', '10', '5'));
    A.Add(Pause(4));
    B.Add(Pause(99));
    B.Assign(A);
    AssertEquals('A,d4', Names(B));
    A.Delete(0);
    AssertEquals('копия не зависит от исходного', 'A,d4', Names(B));
    B.Clear;
    AssertEquals(0, B.Count);
    AssertEquals(1, A.Count);
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TScenarioListTests.ScenarioCountSkipsPauses;
var
  L: TScenarioList;
begin
  L := TScenarioList.Create;
  try
    L.Add(Pause(1));
    L.Add(Block('A', '1', '10', '5'));
    L.Add(Pause(2));
    L.Add(Block('B', '1', '10', '5'));
    AssertEquals(4, L.Count);
    AssertEquals(2, L.SyringeCount);
  finally
    L.Free;
  end;
end;

procedure TScenarioListTests.IndexOutsideListRaises;
var
  L: TScenarioList;
  Raised: Boolean;

  procedure Expect(const AWhat: string; AAction: Integer);
  begin
    Raised := False;
    try
      case AAction of
        0: L.Delete(5);
        1: L.Replace(-1, Pause(1));
        2: L.Insert(3, Pause(1));
        3: L.Move(0, 2);
        4: L.Move(2, 0);
        5: if L[2].PauseSeconds = 0 then ;
      end;
    except
      on EListError do
        Raised := True;
    end;
    AssertTrue(AWhat, Raised);
  end;

begin
  L := TScenarioList.Create;
  try
    L.Add(Pause(1));
    L.Add(Pause(2));
    Expect('Delete', 0);
    Expect('Replace', 1);
    Expect('Insert за концом', 2);
    Expect('Move в никуда', 3);
    Expect('Move из ниоткуда', 4);
    Expect('чтение', 5);
  finally
    L.Free;
  end;
end;

{ TScenarioFormatTests }

function TScenarioFormatTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

function TScenarioFormatTests.Sample: TScenarioList;
begin
  Result := TScenarioList.Create;
  Result.Add(Block('A/Act', '2/3', '100/50', '10'));
  Result.Add(MakePause(30));
  Result.Add(Block('B', '1', '5', '2'));
end;

procedure TScenarioFormatTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_scenario_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TScenarioFormatTests.TearDown;
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

procedure TScenarioFormatTests.AcceptsValidItems;
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, CheckScenarioItem(Block('A/B', '1/2', '10', '5'), ErrorText));
  AssertTrue(ErrorText, CheckScenarioItem(MakePause(0), ErrorText));
  AssertTrue(ErrorText, CheckScenarioItem(MakePause(3600), ErrorText));
  AssertEquals('', ErrorText);
end;

procedure TScenarioFormatTests.ChecksScenarioLikeSyrStInProtocol;
var
  Item: TScenarioItem;
  ErrorText, ProtocolError: string;
begin
  // два дозатора, а объёмов три - как и в протоколе
  Item := Block('A/B', '1/2', '10/20/30', '5');
  AssertFalse(CheckScenarioItem(Item, ErrorText));
  AssertFalse(CheckSyringeStep(Item.Syringe, ProtocolError));
  AssertTrue(ErrorText <> '');
  AssertEquals(ProtocolError, ErrorText);
end;

procedure TScenarioFormatTests.RejectsNegativePause;
var
  ErrorText: string;
begin
  AssertFalse(CheckScenarioItem(MakePause(-1), ErrorText));
  AssertTrue(ErrorText <> '');
end;

procedure TScenarioFormatTests.SummaryShowsEachKind;
var
  Text: string;
begin
  Text := ScenarioItemSummary(Block('A/B', '1/2', '10', '5'));
  AssertTrue(Text, Pos('SyrSt', Text) > 0);
  AssertTrue(Text, Pos('A/B', Text) > 0);
  Text := ScenarioItemSummary(MakePause(45));
  AssertTrue(Text, Pos('45', Text) > 0);
end;

procedure TScenarioFormatTests.TextIsSyrStAndPauseLinesWithoutBlockHeader;
var
  L: TScenarioList;
  Expected: string;
begin
  L := Sample;
  try
    Expected :=
      'SyrSt;' + LineEnding +
      #9'Dispensers=A/Act;' + LineEnding +
      #9'Valves=2/3;' + LineEnding +
      #9'Volumes=100/50;' + LineEnding +
      #9'VolumeUnit=мкл;' + LineEnding +
      #9'Speeds=10;' + LineEnding +
      #9'SpeedUnit=мкл/с;' + LineEnding +
      'Pause=30;' + LineEnding +
      'SyrSt;' + LineEnding +
      #9'Dispensers=B;' + LineEnding +
      #9'Valves=1;' + LineEnding +
      #9'Volumes=5;' + LineEnding +
      #9'VolumeUnit=мкл;' + LineEnding +
      #9'Speeds=2;' + LineEnding +
      #9'SpeedUnit=мкл/с;' + LineEnding;
    AssertEquals(Expected, ScenarioListToText(L));
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.TextRoundTrip;
var
  Source, Loaded: TScenarioList;
  ErrorText: string;
  I: Integer;
begin
  Source := Sample;
  Loaded := TScenarioList.Create;
  try
    AssertTrue(ErrorText, ParseScenarioText(ScenarioListToText(Source), Loaded,
      ErrorText));
    AssertEquals(Source.Count, Loaded.Count);
    for I := 0 to Source.Count - 1 do
    begin
      AssertTrue(Source[I].Kind = Loaded[I].Kind);
      AssertEquals(Source[I].PauseSeconds, Loaded[I].PauseSeconds);
      AssertEquals(Source[I].Syringe.Dispensers, Loaded[I].Syringe.Dispensers);
      AssertEquals(Source[I].Syringe.Valves, Loaded[I].Syringe.Valves);
      AssertEquals(Source[I].Syringe.Volumes, Loaded[I].Syringe.Volumes);
      AssertEquals(Source[I].Syringe.VolumeUnit, Loaded[I].Syringe.VolumeUnit);
      AssertEquals(Source[I].Syringe.Speeds, Loaded[I].Syringe.Speeds);
      AssertEquals(Source[I].Syringe.SpeedUnit, Loaded[I].Syringe.SpeedUnit);
    end;
  finally
    Loaded.Free;
    Source.Free;
  end;
end;

procedure TScenarioFormatTests.EmptyTextGivesEmptyList;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := Sample;
  try
    AssertTrue(ErrorText, ParseScenarioText('', L, ErrorText));
    AssertEquals(0, L.Count);
    L.Add(MakePause(1));
    AssertTrue(ErrorText, ParseScenarioText(LineEnding + LineEnding, L,
      ErrorText));
    AssertEquals('только пустые строки', 0, L.Count);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.ProtocolParserAcceptsScenarioText;
var
  L: TScenarioList;
  Document: TProtocolDocument;
  ErrorText: string;
begin
  L := Sample;
  try
    AssertTrue(ErrorText, ParseProtocolText(ScenarioListToText(L), Document,
      ErrorText, True));
    AssertEquals(1, Length(Document));
    AssertEquals(3, Length(Document[0].Steps));
    AssertTrue(Document[0].Steps[0].Kind = pskSyringe);
    AssertTrue(Document[0].Steps[1].Kind = pskPause);
    AssertEquals(30, Document[0].Steps[1].IntValue);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.RejectsBlockHeaderLine;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    AssertFalse(ParseScenarioText('Pause=1;' + LineEnding + 'Block=Two;' +
      LineEnding, L, ErrorText));
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0); // строка с Block
    AssertTrue(ErrorText, Pos('Block', ErrorText) > 0);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.RejectsOperationsOtherThanSyrStAndPause;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    AssertFalse(ParseScenarioText('Pause=1;' + LineEnding + 'Vacuum=1;' +
      LineEnding, L, ErrorText));
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0);
    AssertTrue(ErrorText, Pos('Vacuum', ErrorText) > 0);
    AssertFalse(ParseScenarioText('Laser=2; Time=1;' + LineEnding, L, ErrorText));
    AssertTrue(ErrorText, Pos('Laser', ErrorText) > 0);
    AssertFalse(ParseScenarioText('Comment=text;' + LineEnding, L, ErrorText));
    AssertTrue(ErrorText, Pos('Comment', ErrorText) > 0);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.FailedParseKeepsList;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := Sample;
  try
    AssertFalse(ParseScenarioText('Pause=abc;' + LineEnding, L, ErrorText));
    AssertEquals(3, L.Count);
    AssertFalse(ParseScenarioText('Pause=1;' + LineEnding + 'Vacuum=1;' +
      LineEnding, L, ErrorText));
    AssertEquals('частично разобранное не попадает в список', 3, L.Count);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.SaveAndLoadFile;
var
  Source, Loaded: TScenarioList;
  ErrorText: string;
begin
  Source := Sample;
  Loaded := TScenarioList.Create;
  try
    AssertTrue(ErrorText, SaveScenarioFile(FilePath('a' + SCENARIO_FILE_EXT),
      Source, ErrorText));
    AssertTrue(FileExists(FilePath('a' + SCENARIO_FILE_EXT)));
    AssertTrue(ErrorText, LoadScenarioFile(FilePath('a' + SCENARIO_FILE_EXT),
      Loaded, ErrorText));
    AssertEquals(ScenarioListToText(Source), ScenarioListToText(Loaded));
    AssertEquals(2, Loaded.SyringeCount);
  finally
    Loaded.Free;
    Source.Free;
  end;
end;

procedure TScenarioFormatTests.SaveRejectsInvalidItemAndWritesNothing;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := Sample;
  try
    L.Add(Block('', '1', '5', '2'));  // четвёртый элемент без дозаторов
    AssertFalse(SaveScenarioFile(FilePath('bad.scn'), L, ErrorText));
    AssertTrue(ErrorText, Pos('4', ErrorText) > 0);
    AssertFalse('файл не создан', FileExists(FilePath('bad.scn')));
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.LoadReportsMissingFile;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := Sample;
  try
    AssertFalse(LoadScenarioFile(FilePath('none.scn'), L, ErrorText));
    AssertTrue(ErrorText, Pos('none.scn', ErrorText) > 0);
    AssertEquals(3, L.Count);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.LoadReportsBrokenFileAndKeepsList;
var
  L: TScenarioList;
  F: TStringList;
  ErrorText: string;
begin
  F := TStringList.Create;
  try
    F.Add('Pause=1;');
    F.Add('Pause=oops;');
    F.SaveToFile(FilePath('broken.scn'));
  finally
    F.Free;
  end;
  L := Sample;
  try
    AssertFalse(LoadScenarioFile(FilePath('broken.scn'), L, ErrorText));
    AssertTrue(ErrorText, Pos('broken.scn', ErrorText) > 0);
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0); // строка с ошибкой
    AssertEquals(3, L.Count);
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.SaveReportsUnwritablePlace;
var
  L: TScenarioList;
  ErrorText: string;
begin
  L := Sample;
  try
    // вместо файла - папка
    AssertFalse(SaveScenarioFile(FDirectory, L, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    L.Free;
  end;
end;

procedure TScenarioFormatTests.ConvertsItemToProtocolStepAndBack;
var
  Step: TProtocolStep;
  Item: TScenarioItem;
begin
  Step := ScenarioItemToStep(MakePause(12));
  AssertTrue(Step.Kind = pskPause);
  AssertEquals(12, Step.IntValue);
  Item := ScenarioItemFromStep(Step);
  AssertTrue(Item.Kind = sikPause);
  AssertEquals(12, Item.PauseSeconds);

  Step := ScenarioItemToStep(Block('A/B', '1/2', '10', '5'));
  AssertTrue(Step.Kind = pskSyringe);
  AssertEquals('A/B', Step.Syringe.Dispensers);
  Item := ScenarioItemFromStep(Step);
  AssertTrue(Item.Kind = sikSyringe);
  AssertEquals('1/2', Item.Syringe.Valves);
  AssertEquals('5', Item.Syringe.Speeds);
end;

procedure TScenarioFormatTests.OtherProtocolOperationsBecomeSyringe;
var
  Step: TProtocolStep;
begin
  // в сценарии нет вакуума, лазера и комментариев
  Step := Default(TProtocolStep);
  Step.Kind := pskVacuum;
  Step.BoolValue := True;
  AssertTrue(ScenarioItemFromStep(Step).Kind = sikSyringe);
  Step.Kind := pskLaser;
  AssertTrue(ScenarioItemFromStep(Step).Kind = sikSyringe);
end;

procedure TScenarioFormatTests.LoadsFileWithUtf8Bom;
var
  Source, Loaded: TScenarioList;
  Stream: TFileStream;
  Body: UTF8String;
  Bom: array[0..2] of Byte;
  ErrorText: string;
begin
  Source := Sample;
  Loaded := TScenarioList.Create;
  try
    Body := ScenarioListToText(Source);
    Bom[0] := $EF;
    Bom[1] := $BB;
    Bom[2] := $BF;
    Stream := TFileStream.Create(FilePath('bom.scn'), fmCreate);
    try
      Stream.WriteBuffer(Bom, SizeOf(Bom));
      Stream.WriteBuffer(Body[1], Length(Body));
    finally
      Stream.Free;
    end;
    AssertTrue(ErrorText, LoadScenarioFile(FilePath('bom.scn'), Loaded,
      ErrorText));
    AssertEquals(Body, ScenarioListToText(Loaded));
  finally
    Loaded.Free;
    Source.Free;
  end;
end;

initialization
  RegisterTest(TScenarioListTests);
  RegisterTest(TScenarioFormatTests);

end.
