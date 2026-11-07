unit ScenarioRunTests;
// Тесты запуска сценариев станции: построение команд из списка и ожидание
// пауз между блоками.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, DispenserConfig,
  DispenserRuntimeState, AutomationProtocol, AutomationProtocolRunner,
  ScenarioList, ProtocolTestHelpers, AutomationProtocolRunnerTests;

type
  TScenarioProtocolTests = class(TTestCase)
  private
    FConfigurations: TDispenserConfigList;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure BuildsCommandForEachItemInOrder;
    procedure SelectedScenarioGivesSingleCommand;
    procedure RejectsSelectedPause;
    procedure RejectsMissingSelection;
    procedure RejectsEmptyListAndListOfPauses;
    procedure ErrorNamesElementNumber;
    procedure RejectsListWithoutConfigurations;
  end;

  TScenarioRunnerTests = class(TTestCase)
  private
    FConfigurations: TDispenserConfigList;
    FRuntimeStates: TDispenserRuntimeStates;
    FController: TProtocolTestController;
    FRunner: TAutomationProtocolRunner;
    FProtocol: TAutomationProtocol;
    FScenarios: TScenarioList;
    procedure StartRun(AItemIndex: Integer = ALL_BLOCKS);
    procedure PollTimes(ACount: Integer);
    procedure RunUntilFinished;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure WaitsForPauseBetweenBlocks;
    procedure PauseCountsFromItsStart;
    procedure LeadingPausePostponesFirstBlock;
    procedure TrailingPausePausesFinish;
    procedure ZeroPauseDoesNotWait;
    procedure StopDuringPauseEndsRunWithoutMovement;
  end;

implementation

var
  FakeNow: QWord;

function FakeClock: QWord;
begin
  Result := FakeNow;
end;

function OneDose(const ANames: string): TScenarioItem;
begin
  Result := MakeSyringe(MakeStep(ANames, '2', '250', '100'));
end;

{ TScenarioProtocolTests }

procedure TScenarioProtocolTests.SetUp;
begin
  inherited SetUp;
  FConfigurations := CreateTestConfigurations;
end;

procedure TScenarioProtocolTests.TearDown;
begin
  FConfigurations.Free;
  inherited TearDown;
end;

procedure TScenarioProtocolTests.BuildsCommandForEachItemInOrder;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  P := nil;
  try
    L.Add(OneDose('PA'));
    L.Add(MakePause(5));
    L.Add(MakeSyringe(MakeStep('PA/PB', '2/3', '250/500', '100')));
    AssertTrue(ErrorText, BuildScenarioProtocol(L, FConfigurations, P, ErrorText));
    AssertEquals(3, P.Count);
    AssertFalse(P[0].IsPause);
    AssertEquals(1, Length(P[0].Targets));
    AssertTrue(P[1].IsPause);
    AssertEquals(5, P[1].PauseSeconds);
    AssertFalse(P[2].IsPause);
    AssertEquals('одновременно два дозатора', 2, Length(P[2].Targets));
    AssertEquals(1, P[0].Number);
    AssertEquals(2, P[1].Number);
    AssertEquals(3, P[2].Number);
    AssertEquals('номер элемента списка', 3, P[2].LineNumber);
  finally
    P.Free;
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.SelectedScenarioGivesSingleCommand;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  P := nil;
  try
    L.Add(OneDose('PA'));
    L.Add(MakePause(5));
    L.Add(OneDose('PB'));
    AssertTrue(ErrorText, BuildScenarioProtocol(L, FConfigurations, P,
      ErrorText, 2));
    AssertEquals(1, P.Count);
    AssertEquals('PB', P[0].Targets[0].Config.Name);
  finally
    P.Free;
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.RejectsSelectedPause;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    L.Add(OneDose('PA'));
    L.Add(MakePause(5));
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText, 1));
    AssertTrue(ErrorText <> '');
    AssertTrue(P = nil);
  finally
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.RejectsMissingSelection;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    L.Add(OneDose('PA'));
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText, 4));
    AssertTrue(ErrorText <> '');
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText, -5));
    AssertTrue(P = nil);
  finally
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.RejectsEmptyListAndListOfPauses;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText));
    AssertTrue(ErrorText <> '');
    L.Add(MakePause(3));
    L.Add(MakePause(4));
    ErrorText := '';
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText));
    AssertTrue(ErrorText <> '');
    AssertTrue(P = nil);
  finally
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.ErrorNamesElementNumber;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    L.Add(OneDose('PA'));
    L.Add(OneDose('XX'));    // такого дозатора нет в конфигурации
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText));
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0);
    AssertTrue(ErrorText, Pos('XX', ErrorText) > 0);
    AssertTrue(P = nil);

    L.Delete(1);
    L.Add(MakePause(-1));
    AssertFalse(BuildScenarioProtocol(L, FConfigurations, P, ErrorText));
    AssertTrue(ErrorText, Pos('2', ErrorText) > 0);
  finally
    L.Free;
  end;
end;

procedure TScenarioProtocolTests.RejectsListWithoutConfigurations;
var
  L: TScenarioList;
  P: TAutomationProtocol;
  ErrorText: string;
begin
  L := TScenarioList.Create;
  try
    L.Add(OneDose('PA'));
    AssertFalse(BuildScenarioProtocol(L, nil, P, ErrorText));
    AssertTrue(ErrorText <> '');
  finally
    L.Free;
  end;
end;

{ TScenarioRunnerTests }

procedure TScenarioRunnerTests.SetUp;
begin
  inherited SetUp;
  FakeNow := 100000;
  FConfigurations := CreateTestConfigurations;
  FRuntimeStates := CreateInitializedTestStates(FConfigurations);
  FController := TProtocolTestController.Create;
  FRunner := TAutomationProtocolRunner.Create(FController, FRuntimeStates,
    @FakeClock);
  FScenarios := TScenarioList.Create;
  FProtocol := nil;
end;

procedure TScenarioRunnerTests.TearDown;
begin
  FProtocol.Free;
  FScenarios.Free;
  FRunner.Free;
  FController.Free;
  FRuntimeStates.Free;
  FConfigurations.Free;
  inherited TearDown;
end;

procedure TScenarioRunnerTests.StartRun(AItemIndex: Integer);
var
  ErrorText: string;
begin
  AssertTrue(ErrorText, BuildScenarioProtocol(FScenarios, FConfigurations,
    FProtocol, ErrorText, AItemIndex));
  AssertTrue(ErrorText, FRunner.Start(FProtocol, ErrorText));
  FProtocol := nil; // теперь им владеет запуск
end;

procedure TScenarioRunnerTests.PollTimes(ACount: Integer);
var
  I: Integer;
begin
  for I := 1 to ACount do
    FRunner.Poll;
end;

procedure TScenarioRunnerTests.RunUntilFinished;
var
  I: Integer;
begin
  for I := 1 to 1000 do
  begin
    if not FRunner.IsRunning then
      Exit;
    FRunner.Poll;
  end;
  Fail('Сценарий не завершился за 1000 циклов опроса.');
end;

procedure TScenarioRunnerTests.WaitsForPauseBetweenBlocks;
var
  ActionsBeforePause: Integer;
begin
  FScenarios.Add(OneDose('PA'));
  FScenarios.Add(MakePause(10));
  FScenarios.Add(OneDose('PB'));
  StartRun;

  PollTimes(100);          // первый блок закончился, идёт пауза
  AssertTrue(FRunner.IsRunning);
  AssertEquals(2, FController.CountActionsWithPrefix('M1'));
  AssertEquals(0, FController.CountActionsWithPrefix('M2'));
  ActionsBeforePause := FController.Actions.Count;

  FakeNow := FakeNow + 9999;
  PollTimes(100);
  AssertTrue('до конца паузы секунды не хватает', FRunner.IsRunning);
  AssertEquals(ActionsBeforePause, FController.Actions.Count);

  FakeNow := FakeNow + 1;
  RunUntilFinished;
  AssertEquals(2, FController.CountActionsWithPrefix('M2'));
  AssertEquals(2, FController.CountActionsWithPrefix('M1'));
end;

procedure TScenarioRunnerTests.PauseCountsFromItsStart;
begin
  FScenarios.Add(OneDose('PA'));
  FScenarios.Add(MakePause(4));
  FScenarios.Add(OneDose('PB'));
  StartRun;
  // время идёт и пока работает первый блок, но пауза отсчитывается
  // только с момента, когда он завершился
  FakeNow := FakeNow + 60000;
  PollTimes(100);
  AssertEquals('пауза ещё не прошла', 0,
    FController.CountActionsWithPrefix('M2'));
  FakeNow := FakeNow + 4000;
  RunUntilFinished;
  AssertEquals(2, FController.CountActionsWithPrefix('M2'));
end;

procedure TScenarioRunnerTests.LeadingPausePostponesFirstBlock;
begin
  FScenarios.Add(MakePause(3));
  FScenarios.Add(OneDose('PA'));
  StartRun;
  PollTimes(50);
  AssertEquals(0, FController.Actions.Count);
  FakeNow := FakeNow + 3000;
  RunUntilFinished;
  AssertEquals(2, FController.CountActionsWithPrefix('M1'));
end;

procedure TScenarioRunnerTests.TrailingPausePausesFinish;
begin
  FScenarios.Add(OneDose('PA'));
  FScenarios.Add(MakePause(2));
  StartRun;
  PollTimes(100);
  AssertTrue('ждёт последнюю паузу', FRunner.IsRunning);
  FakeNow := FakeNow + 2000;
  FRunner.Poll;
  AssertFalse(FRunner.IsRunning);
end;

procedure TScenarioRunnerTests.ZeroPauseDoesNotWait;
begin
  FScenarios.Add(OneDose('PA'));
  FScenarios.Add(MakePause(0));
  FScenarios.Add(OneDose('PB'));
  StartRun;
  RunUntilFinished;                 // время не двигалось
  AssertEquals(2, FController.CountActionsWithPrefix('M2'));
end;

procedure TScenarioRunnerTests.StopDuringPauseEndsRunWithoutMovement;
var
  ActionsBeforeStop: Integer;
begin
  FScenarios.Add(OneDose('PA'));
  FScenarios.Add(MakePause(30));
  FScenarios.Add(OneDose('PB'));
  StartRun;
  PollTimes(100);
  AssertTrue(FRunner.IsRunning);
  ActionsBeforeStop := FController.Actions.Count;
  FRunner.Stop;
  AssertFalse(FRunner.IsRunning);
  FakeNow := FakeNow + 60000;
  PollTimes(10);
  AssertEquals('после остановки ничего не отправляется', ActionsBeforeStop,
    FController.Actions.Count);
  AssertEquals(0, FController.TerminateCount);
  AssertFalse('следующий блок не начался', FRunner.IsRunning);
end;

initialization
  RegisterTest(TScenarioProtocolTests);
  RegisterTest(TScenarioRunnerTests);

end.
