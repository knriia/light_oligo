unit ProtocolModelTests;
// Тесты модели протокола синтеза: блоки и операции, запись в текст и файл,
// проверка перед записью.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ProtocolFormat, ProtocolModel,
  ProtocolTestHelpers;

type
  TProtocolModelTests = class(TTestCase)
  private
    function Names(AModel: TProtocolModel): string;
    function Ops(AModel: TProtocolModel; ABlock: Integer): string;
  published
    procedure NewModelIsEmpty;
    procedure AddInsertRenameDeleteBlocks;
    procedure MoveBlocksKeepsTheirSteps;
    procedure StepsAreAddedInsertedReplacedDeleted;
    procedure MoveStepStaysInsideItsBlock;
    procedure StepsOfBlocksAreIndependent;
    procedure AssignMakesIndependentCopy;
    procedure IndexOutsideRangeRaises;
  end;

  TProtocolTextTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure WritesEveryOperationKind;
    procedure ParsedProtocolIsWrittenBackSame;
    procedure WritesDecimalPointInAnyLocale;
    procedure ReadsLaserTimeWithPointOrComma;
    procedure ReadsFileWrittenByOldTreeEditor;
    procedure LoadFromTextKeepsModelOnError;
    procedure EmptyTextGivesEmptyProtocol;
    procedure CheckAcceptsValidProtocol;
    procedure CheckRejectsBadBlockNames;
    procedure CheckRejectsBadOperationsAndNamesPlace;
    procedure CheckRejectsBadTextInComment;
    procedure SaveAndLoadFileKeepsCyrillic;
    procedure SaveRejectsInvalidProtocolAndWritesNothing;
    procedure LoadReportsMissingFile;
    procedure LoadReportsBrokenFileAndKeepsModel;
    procedure SaveReportsUnwritablePlace;
  end;

implementation

function SyrStep: TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskSyringe;
  Result.Syringe := MakeStep('A/Act', '2/3', '100/50', '10');
end;

function PauseStep(ASeconds: Integer): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskPause;
  Result.IntValue := ASeconds;
end;

function VacuumStep(AOn: Boolean): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskVacuum;
  Result.BoolValue := AOn;
end;

function LaserStep(ARepeats: Integer; ATime: Double): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskLaser;
  Result.IntValue := ARepeats;
  Result.FloatValue := ATime;
end;

function CommentStep(const AText: string): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskComment;
  Result.Text := AText;
end;

function SampleModel: TProtocolModel;
begin
  Result := TProtocolModel.Create;
  Result.AddBlock('Condensation');
  Result.AddStep(0, CommentStep('начало'));
  Result.AddStep(0, SyrStep);
  Result.AddStep(0, PauseStep(30));
  Result.AddBlock('Wash');
  Result.AddStep(1, VacuumStep(True));
  Result.AddStep(1, LaserStep(5, 3));
end;

{ TProtocolModelTests }

function TProtocolModelTests.Names(AModel: TProtocolModel): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AModel.BlockCount - 1 do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + AModel.BlockNames[I];
  end;
end;

function TProtocolModelTests.Ops(AModel: TProtocolModel; ABlock: Integer): string;
// P5 - пауза 5 с, V1 - вакуум, L - лазер, C - комментарий, S - станция
var
  I: Integer;
  Step: TProtocolStep;
begin
  Result := '';
  for I := 0 to AModel.StepCount(ABlock) - 1 do
  begin
    Step := AModel.Steps[ABlock, I];
    if Result <> '' then
      Result := Result + ',';
    case Step.Kind of
      pskPause: Result := Result + 'P' + IntToStr(Step.IntValue);
      pskVacuum: Result := Result + 'V' + IntToStr(Ord(Step.BoolValue));
      pskLaser: Result := Result + 'L';
      pskComment: Result := Result + 'C';
      pskSyringe: Result := Result + 'S';
    end;
  end;
end;

procedure TProtocolModelTests.NewModelIsEmpty;
var
  M: TProtocolModel;
begin
  M := TProtocolModel.Create;
  try
    AssertEquals(0, M.BlockCount);
    AssertEquals('', M.ToText);
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.AddInsertRenameDeleteBlocks;
var
  M: TProtocolModel;
begin
  M := TProtocolModel.Create;
  try
    AssertEquals(0, M.AddBlock('A'));
    AssertEquals(1, M.AddBlock('C'));
    M.InsertBlock(1, 'B');
    AssertEquals('A,B,C', Names(M));
    M.InsertBlock(M.BlockCount, 'D');
    AssertEquals('A,B,C,D', Names(M));
    M.RenameBlock(2, 'X');
    AssertEquals('A,B,X,D', Names(M));
    M.DeleteBlock(0);
    AssertEquals('B,X,D', Names(M));
    M.DeleteBlock(2);
    AssertEquals('B,X', Names(M));
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.MoveBlocksKeepsTheirSteps;
var
  M: TProtocolModel;
begin
  M := SampleModel;
  try
    M.MoveBlock(0, 1);
    AssertEquals('Wash,Condensation', Names(M));
    AssertEquals('V1,L', Ops(M, 0));
    AssertEquals('C,S,P30', Ops(M, 1));
    M.MoveBlock(1, 0);
    AssertEquals('Condensation,Wash', Names(M));
    M.MoveBlock(1, 1);
    AssertEquals('Condensation,Wash', Names(M));
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.StepsAreAddedInsertedReplacedDeleted;
var
  M: TProtocolModel;
begin
  M := TProtocolModel.Create;
  try
    M.AddBlock('B');
    AssertEquals(0, M.AddStep(0, PauseStep(1)));
    AssertEquals(1, M.AddStep(0, PauseStep(3)));
    M.InsertStep(0, 1, PauseStep(2));
    AssertEquals('P1,P2,P3', Ops(M, 0));
    M.InsertStep(0, 0, VacuumStep(False));
    M.InsertStep(0, M.StepCount(0), CommentStep('x'));
    AssertEquals('V0,P1,P2,P3,C', Ops(M, 0));
    M.ReplaceStep(0, 2, PauseStep(9));
    AssertEquals('V0,P1,P9,P3,C', Ops(M, 0));
    M.DeleteStep(0, 0);
    M.DeleteStep(0, 3);
    AssertEquals('P1,P9,P3', Ops(M, 0));
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.MoveStepStaysInsideItsBlock;
var
  M: TProtocolModel;
begin
  M := SampleModel;
  try
    M.MoveStep(0, 0, 2);
    AssertEquals('S,P30,C', Ops(M, 0));
    M.MoveStep(0, 2, 0);
    AssertEquals('C,S,P30', Ops(M, 0));
    AssertEquals('другой блок не тронут', 'V1,L', Ops(M, 1));
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.StepsOfBlocksAreIndependent;
var
  M: TProtocolModel;
begin
  M := SampleModel;
  try
    M.DeleteStep(1, 0);
    AssertEquals('C,S,P30', Ops(M, 0));
    AssertEquals('L', Ops(M, 1));
    M.DeleteBlock(0);
    AssertEquals('L', Ops(M, 0));
  finally
    M.Free;
  end;
end;

procedure TProtocolModelTests.AssignMakesIndependentCopy;
var
  A, B: TProtocolModel;
begin
  A := SampleModel;
  B := TProtocolModel.Create;
  try
    B.AddBlock('old');
    B.Assign(A);
    AssertEquals('Condensation,Wash', Names(B));
    A.DeleteStep(0, 0);
    A.RenameBlock(1, 'Other');
    AssertEquals('C,S,P30', Ops(B, 0));
    AssertEquals('Wash', B.BlockNames[1]);
    B.AddStep(0, PauseStep(1));
    AssertEquals('S,P30', Ops(A, 0));
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TProtocolModelTests.IndexOutsideRangeRaises;
var
  M: TProtocolModel;
  Raised: Boolean;

  procedure Expect(const AWhat: string; AAction: Integer);
  begin
    Raised := False;
    try
      case AAction of
        0: M.DeleteBlock(3);
        1: M.RenameBlock(-1, 'x');
        2: M.InsertBlock(3, 'x');
        3: M.MoveBlock(0, 2);
        4: M.AddStep(5, PauseStep(1));
        5: M.DeleteStep(0, 1);
        6: M.InsertStep(0, 2, PauseStep(1));
        7: M.MoveStep(0, 0, 1);
        8: if M.Steps[0, 4].IntValue = 0 then ;
        9: if M.BlockNames[7] = '' then ;
        10: if M.StepCount(2) = 0 then ;
        11: M.ReplaceStep(1, 0, PauseStep(1));
      end;
    except
      on EListError do
        Raised := True;
    end;
    AssertTrue(AWhat, Raised);
  end;

begin
  M := TProtocolModel.Create;
  try
    M.AddBlock('B');
    M.AddStep(0, PauseStep(1));
    Expect('DeleteBlock', 0);
    Expect('RenameBlock', 1);
    Expect('InsertBlock за концом', 2);
    Expect('MoveBlock', 3);
    Expect('AddStep в несуществующий блок', 4);
    Expect('DeleteStep', 5);
    Expect('InsertStep за концом', 6);
    Expect('MoveStep', 7);
    Expect('чтение операции', 8);
    Expect('чтение имени', 9);
    Expect('StepCount', 10);
    Expect('ReplaceStep в несуществующем блоке', 11);
  finally
    M.Free;
  end;
end;

{ TProtocolTextTests }

function TProtocolTextTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TProtocolTextTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_protocol_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TProtocolTextTests.TearDown;
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

procedure TProtocolTextTests.WritesEveryOperationKind;
var
  M: TProtocolModel;
  Expected: string;
begin
  M := SampleModel;
  try
    Expected :=
      'Block=Condensation;' + LineEnding +
      #9'Comment=начало;' + LineEnding +
      #9'SyrSt;' + LineEnding +
      #9#9'Dispensers=A/Act;' + LineEnding +
      #9#9'Valves=2/3;' + LineEnding +
      #9#9'Volumes=100/50;' + LineEnding +
      #9#9'VolumeUnit=мкл;' + LineEnding +
      #9#9'Speeds=10;' + LineEnding +
      #9#9'SpeedUnit=мкл/с;' + LineEnding +
      #9'Pause=30;' + LineEnding +
      'Block=Wash;' + LineEnding +
      #9'Vacuum=1;' + LineEnding +
      #9'Laser=5; Time=3;' + LineEnding;
    AssertEquals(Expected, M.ToText);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.ParsedProtocolIsWrittenBackSame;
var
  M: TProtocolModel;
  ErrorText, First: string;
begin
  M := SampleModel;
  try
    First := M.ToText;
    M.Clear;
    AssertTrue(ErrorText, M.LoadFromText(First, ErrorText));
    AssertEquals(2, M.BlockCount);
    AssertEquals(First, M.ToText);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.WritesDecimalPointInAnyLocale;
var
  M: TProtocolModel;
  Saved: Char;
begin
  M := TProtocolModel.Create;
  Saved := DefaultFormatSettings.DecimalSeparator;
  try
    M.AddBlock('L');
    M.AddStep(0, LaserStep(2, 3.5));
    DefaultFormatSettings.DecimalSeparator := ',';
    AssertTrue(M.ToText, Pos('Time=3.5;', M.ToText) > 0);
  finally
    DefaultFormatSettings.DecimalSeparator := Saved;
    M.Free;
  end;
end;

procedure TProtocolTextTests.ReadsLaserTimeWithPointOrComma;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := TProtocolModel.Create;
  try
    AssertTrue(ErrorText, M.LoadFromText('Block=L;' + LineEnding +
      #9'Laser=2; Time=3,5;' + LineEnding + #9'Laser=1; Time=0.25;' +
      LineEnding, ErrorText));
    AssertEquals(3.5, M.Steps[0, 0].FloatValue, 1e-9);
    AssertEquals(0.25, M.Steps[0, 1].FloatValue, 1e-9);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.ReadsFileWrittenByOldTreeEditor;
// Старый редактор писал "Vacuum=-1; " с пробелом после ";" и время лазера
// в локали Windows (с запятой).
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := TProtocolModel.Create;
  try
    AssertTrue(ErrorText, M.LoadFromText('Block=Old;' + LineEnding +
      #9'Vacuum=-1; ' + LineEnding + #9'Laser=5; Time=3,5;' + LineEnding +
      #9'Pause=7;' + LineEnding, ErrorText));
    AssertTrue(M.Steps[0, 0].BoolValue);
    AssertEquals(5, M.Steps[0, 1].IntValue);
    AssertEquals(7, M.Steps[0, 2].IntValue);
    AssertTrue(M.Check(ErrorText));
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.LoadFromTextKeepsModelOnError;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    AssertFalse(M.LoadFromText('Block=A;' + LineEnding + #9'Pause=abc;' +
      LineEnding, ErrorText));
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0);
    AssertEquals(2, M.BlockCount);
    AssertFalse(M.LoadFromText(#9'Pause=1;' + LineEnding, ErrorText));
    AssertEquals(2, M.BlockCount);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.EmptyTextGivesEmptyProtocol;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    AssertTrue(ErrorText, M.LoadFromText('', ErrorText));
    AssertEquals(0, M.BlockCount);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.CheckAcceptsValidProtocol;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    AssertTrue(ErrorText, M.Check(ErrorText));
    AssertEquals('', ErrorText);
    M.Clear;
    AssertTrue('пустой протокол допустим', M.Check(ErrorText));
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.CheckRejectsBadBlockNames;
var
  M: TProtocolModel;
  ErrorText: string;

  procedure Bad(const AName, AWhat: string);
  begin
    M.Clear;
    M.AddBlock('Ok');
    M.AddBlock(AName);
    AssertFalse(AWhat, M.Check(ErrorText));
    AssertTrue(AWhat + ': ' + ErrorText, Pos('2', ErrorText) > 0);
  end;

begin
  M := TProtocolModel.Create;
  try
    Bad('', 'пустое имя');
    Bad('   ', 'одни пробелы');
    Bad('a;b', 'точка с запятой');
    Bad(' lead', 'пробел в начале');
    Bad('trail ', 'пробел в конце');
    Bad('two' + LineEnding + 'lines', 'перевод строки');
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.CheckRejectsBadOperationsAndNamesPlace;
var
  M: TProtocolModel;
  ErrorText: string;
  Step: TProtocolStep;
begin
  M := SampleModel;
  try
    // станция: два дозатора, а объёмов три
    Step := SyrStep;
    Step.Syringe := MakeStep('A/B', '1/2', '10/20/30', '5');
    M.ReplaceStep(0, 1, Step);
    AssertFalse(M.Check(ErrorText));
    AssertTrue(ErrorText, Pos('1', ErrorText) > 0);   // блок 1
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0);   // операция 2
    AssertTrue(ErrorText, Pos('Condensation', ErrorText) > 0);
    M.ReplaceStep(0, 1, SyrStep);
    AssertTrue(ErrorText, M.Check(ErrorText));

    M.ReplaceStep(0, 2, PauseStep(-1));
    AssertFalse(M.Check(ErrorText));
    AssertTrue(ErrorText, Pos('3', ErrorText) > 0);
    M.ReplaceStep(0, 2, PauseStep(0));
    AssertTrue(ErrorText, M.Check(ErrorText));

    M.ReplaceStep(1, 1, LaserStep(0, 3));
    AssertFalse('повторов 0', M.Check(ErrorText));
    AssertTrue(ErrorText, Pos('Wash', ErrorText) > 0);
    M.ReplaceStep(1, 1, LaserStep(1, 0));
    AssertFalse('время 0', M.Check(ErrorText));
    M.ReplaceStep(1, 1, LaserStep(1, 0.5));
    AssertTrue(ErrorText, M.Check(ErrorText));
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.CheckRejectsBadTextInComment;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := TProtocolModel.Create;
  try
    M.AddBlock('B');
    M.AddStep(0, CommentStep('ok text'));
    AssertTrue(ErrorText, M.Check(ErrorText));
    M.ReplaceStep(0, 0, CommentStep('a;b'));
    AssertFalse(M.Check(ErrorText));
    M.ReplaceStep(0, 0, CommentStep('a' + LineEnding + 'b'));
    AssertFalse(M.Check(ErrorText));
    M.ReplaceStep(0, 0, CommentStep(' pad'));
    AssertFalse(M.Check(ErrorText));
    M.ReplaceStep(0, 0, CommentStep(''));
    AssertTrue('пустой комментарий допустим', M.Check(ErrorText));
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.SaveAndLoadFileKeepsCyrillic;
var
  A, B: TProtocolModel;
  ErrorText: string;
begin
  A := SampleModel;
  B := TProtocolModel.Create;
  try
    AssertTrue(ErrorText, A.SaveToFile(FilePath('p.pro'), ErrorText));
    AssertTrue(FileExists(FilePath('p.pro')));
    AssertTrue(ErrorText, B.LoadFromFile(FilePath('p.pro'), ErrorText));
    AssertEquals(A.ToText, B.ToText);
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TProtocolTextTests.SaveRejectsInvalidProtocolAndWritesNothing;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    M.AddBlock('bad;name');
    AssertFalse(M.SaveToFile(FilePath('bad.pro'), ErrorText));
    AssertTrue(ErrorText, Pos('3', ErrorText) > 0);
    AssertFalse('файл не создан', FileExists(FilePath('bad.pro')));
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.LoadReportsMissingFile;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    AssertFalse(M.LoadFromFile(FilePath('none.pro'), ErrorText));
    AssertTrue(ErrorText, Pos('none.pro', ErrorText) > 0);
    AssertEquals(2, M.BlockCount);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.LoadReportsBrokenFileAndKeepsModel;
var
  M: TProtocolModel;
  F: TStringList;
  ErrorText: string;
begin
  F := TStringList.Create;
  try
    F.Add('Block=A;');
    F.Add(#9'Pause=oops;');
    F.SaveToFile(FilePath('broken.pro'));
  finally
    F.Free;
  end;
  M := SampleModel;
  try
    AssertFalse(M.LoadFromFile(FilePath('broken.pro'), ErrorText));
    AssertTrue(ErrorText, Pos('broken.pro', ErrorText) > 0);
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0); // строка с ошибкой
    AssertEquals(2, M.BlockCount);
  finally
    M.Free;
  end;
end;

procedure TProtocolTextTests.SaveReportsUnwritablePlace;
var
  M: TProtocolModel;
  ErrorText: string;
begin
  M := SampleModel;
  try
    // вместо файла - папка
    AssertFalse(M.SaveToFile(FDirectory, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    M.Free;
  end;
end;

initialization
  RegisterTest(TProtocolModelTests);
  RegisterTest(TProtocolTextTests);

end.
