unit SynthesisRunnerTests;
// Тесты хода синтеза: порядок слоёв и операций, остановка, ошибки.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, OligoSlices, ProtocolFormat,
  ProtocolModel, SynthesisRunner, ProtocolFormatTests;

type
  // Подставной исполнитель: записывает, что его просили сделать.
  TRecordingActions = class(TSynthesisActions)
  public
    Journal: TStringList;       // журнал синтеза и вызовы действий
    StopAfterCalls: Integer;    // после стольких действий просим остановку (0 - не просим)
    FailSyringe: Boolean;
    FailLaser: Boolean;
    Calls: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: string); override;
    function StopRequested: Boolean; override;
    function RunSyringe(const AStep: TSyringeStep;
      out AErrorText: string): Boolean; override;
    procedure Pause(ASeconds: Integer); override;
    procedure Vacuum(AOn: Boolean); override;
    function Laser(ARepeats: Integer; ATimeSeconds: Double;
      const AEzdFile: string; out AErrorText: string): Boolean; override;
  end;

  TSynthesisRunnerTests = class(TTestCase)
  private
    FActions: TRecordingActions;
    FProtocolA: TProtocolModel;
    FProtocolT: TProtocolModel;
    function Lookup(const ALetter: string): TProtocolModel;
    function Layers(const ALetters: string): TSliceLayers;
    function Joined: string;
    procedure AddStep(AModel: TProtocolModel; const AStep: TProtocolStep);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure RunsLayersBlocksAndStepsInOrder;
    procedure EachLayerUsesProtocolOfItsLetter;
    procedure LaserGetsLayerFileRepeatsAndTime;
    procedure StopRequestedBeforeStartDoesNothing;
    procedure StopBetweenStepsSkipsRestOfProtocol;
    procedure StopDoesNotStartNextBlock;
    procedure SyringeFailureStopsSynthesisAndLogsError;
    procedure MissingProtocolStopsWithError;
    procedure LaserFailureStopsSynthesisAndLogsError;
    procedure NoLayersStartsAndCompletes;
    procedure ReturnsTrueOnlyWhenAllLayersRun;
  end;

implementation

{ TRecordingActions }

constructor TRecordingActions.Create;
begin
  inherited Create;
  Journal := TStringList.Create;
end;

destructor TRecordingActions.Destroy;
begin
  Journal.Free;
  inherited Destroy;
end;

procedure TRecordingActions.Log(const AText: string);
begin
  Journal.Add('log ' + AText);
end;

function TRecordingActions.StopRequested: Boolean;
begin
  Result := (StopAfterCalls > 0) and (Calls >= StopAfterCalls);
end;

function TRecordingActions.RunSyringe(const AStep: TSyringeStep;
  out AErrorText: string): Boolean;
begin
  Inc(Calls);
  Journal.Add('syringe ' + AStep.Dispensers);
  Result := not FailSyringe;
  if Result then
    AErrorText := ''
  else
    AErrorText := 'device offline';
end;

procedure TRecordingActions.Pause(ASeconds: Integer);
begin
  Inc(Calls);
  Journal.Add('pause ' + IntToStr(ASeconds));
end;

procedure TRecordingActions.Vacuum(AOn: Boolean);
begin
  Inc(Calls);
  Journal.Add('vacuum ' + IntToStr(Ord(AOn)));
end;

function TRecordingActions.Laser(ARepeats: Integer; ATimeSeconds: Double;
  const AEzdFile: string; out AErrorText: string): Boolean;
begin
  Inc(Calls);
  Journal.Add('laser ' + IntToStr(ARepeats) + ' ' +
    FloatToStr(ATimeSeconds) + ' ' + AEzdFile);
  Result := not FailLaser;
  if Result then
    AErrorText := ''
  else
    AErrorText := 'ezcad busy';
end;

{ TSynthesisRunnerTests }

procedure TSynthesisRunnerTests.SetUp;
begin
  inherited SetUp;
  FActions := TRecordingActions.Create;
  FProtocolA := TProtocolModel.Create;
  FProtocolT := TProtocolModel.Create;
end;

procedure TSynthesisRunnerTests.TearDown;
begin
  FProtocolT.Free;
  FProtocolA.Free;
  FActions.Free;
  inherited TearDown;
end;

function TSynthesisRunnerTests.Lookup(const ALetter: string): TProtocolModel;
begin
  if ALetter = 'A' then
    Result := FProtocolA
  else if ALetter = 'T' then
    Result := FProtocolT
  else
    Result := nil;
end;

function TSynthesisRunnerTests.Layers(const ALetters: string): TSliceLayers;
// "AT" - два слоя: A (номер 1) и T (номер 2)
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ALetters));
  for I := 1 to Length(ALetters) do
  begin
    Result[I - 1] := Default(TSliceLayer);
    Result[I - 1].LayerNumber := I;
    Result[I - 1].Letter := ALetters[I];
    Result[I - 1].EZDFile := 'Layer' + IntToStr(I) + '.ezd';
  end;
end;

function TSynthesisRunnerTests.Joined: string;
begin
  Result := StringReplace(Trim(FActions.Journal.Text), LineEnding, '|',
    [rfReplaceAll]);
end;

procedure TSynthesisRunnerTests.AddStep(AModel: TProtocolModel;
  const AStep: TProtocolStep);
begin
  AModel.AddStep(AModel.BlockCount - 1, AStep);
end;

function PauseOf(ASeconds: Integer): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskPause;
  Result.IntValue := ASeconds;
end;

function VacuumOf(AOn: Boolean): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskVacuum;
  Result.BoolValue := AOn;
end;

function CommentOf(const AText: string): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskComment;
  Result.Text := AText;
end;

function LaserOf(ARepeats: Integer; ATime: Double): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskLaser;
  Result.IntValue := ARepeats;
  Result.FloatValue := ATime;
end;

function SyringeOf(const ADispensers: string): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskSyringe;
  Result.Syringe := MakeStep(ADispensers, '1', '10', '5');
end;

procedure TSynthesisRunnerTests.RunsLayersBlocksAndStepsInOrder;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('Wash');
  AddStep(FProtocolA, CommentOf('start'));
  AddStep(FProtocolA, PauseOf(3));
  AddStep(FProtocolA, VacuumOf(True));
  AddStep(FProtocolA, SyringeOf('PA'));
  FProtocolA.AddBlock('Dry');
  AddStep(FProtocolA, PauseOf(1));
  Runner := TSynthesisRunner.Create(Layers('A'), @Lookup, FActions);
  try
    AssertTrue(Runner.Run);
    AssertFalse(Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertEquals(
    'log Synthesis started|' +
    'log CICLE=0;    PROTOCOL LETTER=A; LAYER NUMBER=1|' +
    'log Name=Wash|' +
    'log Name=start|' +
    'pause 3|log Pause=3|' +
    'vacuum 1|log Vac=' + BoolToStr(True) + '|' +
    'log ' + SyringeStepSummary(MakeStep('PA', '1', '10', '5')) + '|' +
    'syringe PA|log SyrSt done|' +
    'log Name=Dry|' +
    'pause 1|log Pause=1|' +
    'log Synthesis completed!', Joined);
end;

procedure TSynthesisRunnerTests.EachLayerUsesProtocolOfItsLetter;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('FromA');
  AddStep(FProtocolA, PauseOf(1));
  FProtocolT.AddBlock('FromT');
  AddStep(FProtocolT, PauseOf(2));
  Runner := TSynthesisRunner.Create(Layers('ATA'), @Lookup, FActions);
  try
    AssertTrue(Runner.Run);
  finally
    Runner.Free;
  end;
  AssertEquals(
    'log Synthesis started|' +
    'log CICLE=0;    PROTOCOL LETTER=A; LAYER NUMBER=1|log Name=FromA|pause 1|log Pause=1|' +
    'log CICLE=1;    PROTOCOL LETTER=T; LAYER NUMBER=2|log Name=FromT|pause 2|log Pause=2|' +
    'log CICLE=2;    PROTOCOL LETTER=A; LAYER NUMBER=3|log Name=FromA|pause 1|log Pause=1|' +
    'log Synthesis completed!', Joined);
end;

procedure TSynthesisRunnerTests.LaserGetsLayerFileRepeatsAndTime;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('Mark');
  AddStep(FProtocolA, LaserOf(3, 2));
  Runner := TSynthesisRunner.Create(Layers('AA'), @Lookup, FActions);
  try
    Runner.Run;
  finally
    Runner.Free;
  end;
  AssertTrue(Joined, Pos('log Laser=3|log File=Layer1.ezd|laser 3 2 Layer1.ezd', Joined) > 0);
  AssertTrue(Joined, Pos('log File=Layer2.ezd|laser 3 2 Layer2.ezd', Joined) > 0);
end;

procedure TSynthesisRunnerTests.StopRequestedBeforeStartDoesNothing;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, PauseOf(1));
  FActions.StopAfterCalls := 1; // Calls = 0 -> не просим; ставим уже достигнутым
  FActions.Calls := 1;
  Runner := TSynthesisRunner.Create(Layers('A'), @Lookup, FActions);
  try
    AssertFalse(Runner.Run);
    AssertFalse('остановка по просьбе - не ошибка', Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertEquals('log Synthesis started|log Synthesis stopped by user', Joined);
end;

procedure TSynthesisRunnerTests.StopBetweenStepsSkipsRestOfProtocol;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, PauseOf(1));
  AddStep(FProtocolA, PauseOf(2));
  AddStep(FProtocolA, PauseOf(3));
  FActions.StopAfterCalls := 1; // после первого действия
  Runner := TSynthesisRunner.Create(Layers('AA'), @Lookup, FActions);
  try
    AssertFalse(Runner.Run);
  finally
    Runner.Free;
  end;
  AssertTrue(Joined, Pos('pause 1|log Pause=1', Joined) > 0);
  AssertEquals(0, Pos('pause 2', Joined));
  AssertEquals('второй слой не начат', 0, Pos('CICLE=1', Joined));
  AssertTrue(Joined, Pos('log Synthesis stopped by user', Joined) > 0);
  AssertEquals('остановка не называется завершением', 0,
    Pos('Synthesis completed', Joined));
end;

procedure TSynthesisRunnerTests.StopDoesNotStartNextBlock;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('First');
  AddStep(FProtocolA, PauseOf(1));
  FProtocolA.AddBlock('Second');
  AddStep(FProtocolA, PauseOf(2));
  FActions.StopAfterCalls := 1;
  Runner := TSynthesisRunner.Create(Layers('A'), @Lookup, FActions);
  try
    Runner.Run;
  finally
    Runner.Free;
  end;
  AssertEquals('имя следующего блока не выводится', 0, Pos('Name=Second', Joined));
end;

procedure TSynthesisRunnerTests.SyringeFailureStopsSynthesisAndLogsError;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, SyringeOf('PA'));
  AddStep(FProtocolA, PauseOf(5));
  FActions.FailSyringe := True;
  Runner := TSynthesisRunner.Create(Layers('AA'), @Lookup, FActions);
  try
    AssertFalse(Runner.Run);
    AssertTrue('это ошибка', Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertTrue(Joined, Pos('log SyrSt ERROR: device offline', Joined) > 0);
  AssertEquals('после ошибки операции не идут', 0, Pos('pause 5', Joined));
  AssertEquals('второй слой не начат', 0, Pos('CICLE=1', Joined));
  AssertTrue(Joined, Pos('log Synthesis stopped by error', Joined) > 0);
  AssertEquals('ошибка не называется завершением', 0,
    Pos('Synthesis completed', Joined));
  AssertEquals('и не остановкой пользователем', 0,
    Pos('stopped by user', Joined));
end;

procedure TSynthesisRunnerTests.MissingProtocolStopsWithError;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, PauseOf(1));
  Runner := TSynthesisRunner.Create(Layers('AGA'), @Lookup, FActions);
  try
    AssertFalse(Runner.Run);
    AssertTrue(Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertTrue(Joined, Pos('log ERROR: no protocol for letter G', Joined) > 0);
  AssertEquals('слой после ошибки не выполнен', 0, Pos('CICLE=2', Joined));
  AssertTrue(Joined, Pos('log Synthesis stopped by error', Joined) > 0);
end;

procedure TSynthesisRunnerTests.LaserFailureStopsSynthesisAndLogsError;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, LaserOf(1, 1));
  AddStep(FProtocolA, PauseOf(5));
  FActions.FailLaser := True;
  Runner := TSynthesisRunner.Create(Layers('AA'), @Lookup, FActions);
  try
    AssertFalse(Runner.Run);
    AssertTrue(Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertTrue(Joined, Pos('log Laser ERROR: ezcad busy', Joined) > 0);
  AssertEquals('после ошибки лазера операции не идут', 0, Pos('pause 5', Joined));
  AssertEquals('второй слой не начат', 0, Pos('CICLE=1', Joined));
  AssertTrue(Joined, Pos('log Synthesis stopped by error', Joined) > 0);
end;

procedure TSynthesisRunnerTests.NoLayersStartsAndCompletes;
var
  Runner: TSynthesisRunner;
begin
  Runner := TSynthesisRunner.Create(Layers(''), @Lookup, FActions);
  try
    AssertTrue(Runner.Run);
  finally
    Runner.Free;
  end;
  AssertEquals('log Synthesis started|log Synthesis completed!', Joined);
end;

procedure TSynthesisRunnerTests.ReturnsTrueOnlyWhenAllLayersRun;
var
  Runner: TSynthesisRunner;
begin
  FProtocolA.AddBlock('B');
  AddStep(FProtocolA, PauseOf(1));
  Runner := TSynthesisRunner.Create(Layers('AAA'), @Lookup, FActions);
  try
    AssertTrue(Runner.Run);
    AssertFalse(Runner.Failed);
  finally
    Runner.Free;
  end;
  AssertEquals(3, FActions.Calls);
end;

initialization
  RegisterTest(TSynthesisRunnerTests);

end.
