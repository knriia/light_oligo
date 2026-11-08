unit SyringeStepTrackerTests;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, testregistry, ProtocolFormat, SyringeStepTracker;

type
  TSyringeStepTrackerTests = class(TTestCase)
  private
    FTracker: TSyringeStepTracker;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InitialStatusIsIdle;
    procedure StartMakesStatusRunning;
    procedure FinishSucceeded;
    procedure FinishFailedKeepsMessage;
    procedure FinishWithoutStartIsIgnored;
    procedure SecondFinishIsIgnored;
    procedure StopBeforeStartIsRejected;
    procedure StopWhileRunningIsRemembered;
    procedure FinishClearsStopRequest;
    procedure StartResetsPreviousResult;
  end;

implementation

procedure TSyringeStepTrackerTests.SetUp;
begin
  FTracker := TSyringeStepTracker.Create;
end;

procedure TSyringeStepTrackerTests.TearDown;
begin
  FTracker.Free;
end;

procedure TSyringeStepTrackerTests.InitialStatusIsIdle;
var
  Error: string;
begin
  AssertTrue(FTracker.Status(Error) = sssIdle);
  AssertEquals('', Error);
  AssertFalse(FTracker.IsRunning);
  AssertFalse(FTracker.StopRequested);
end;

procedure TSyringeStepTrackerTests.StartMakesStatusRunning;
var
  Error: string;
begin
  FTracker.Start;
  AssertTrue(FTracker.Status(Error) = sssRunning);
  AssertTrue(FTracker.IsRunning);
end;

procedure TSyringeStepTrackerTests.FinishSucceeded;
var
  Error: string;
begin
  FTracker.Start;
  FTracker.Finish(False, 'ok');
  AssertTrue(FTracker.Status(Error) = sssSucceeded);
  AssertEquals('ok', Error);
  AssertFalse(FTracker.IsRunning);
end;

procedure TSyringeStepTrackerTests.FinishFailedKeepsMessage;
var
  Error: string;
begin
  FTracker.Start;
  FTracker.Finish(True, 'сбой');
  AssertTrue(FTracker.Status(Error) = sssFailed);
  AssertEquals('сбой', Error);
end;

procedure TSyringeStepTrackerTests.FinishWithoutStartIsIgnored;
var
  Error: string;
begin
  FTracker.Finish(True, 'сбой');
  AssertTrue(FTracker.Status(Error) = sssIdle);
  AssertEquals('', Error);
end;

procedure TSyringeStepTrackerTests.SecondFinishIsIgnored;
var
  Error: string;
begin
  FTracker.Start;
  FTracker.Finish(False, 'первый');
  FTracker.Finish(True, 'второй');
  AssertTrue(FTracker.Status(Error) = sssSucceeded);
  AssertEquals('первый', Error);
end;

procedure TSyringeStepTrackerTests.StopBeforeStartIsRejected;
begin
  AssertFalse(FTracker.RequestStop);
  AssertFalse(FTracker.StopRequested);
  FTracker.Start;
  AssertFalse('запрос до запуска не должен сохраняться',
    FTracker.StopRequested);
end;

procedure TSyringeStepTrackerTests.StopWhileRunningIsRemembered;
begin
  FTracker.Start;
  AssertTrue(FTracker.RequestStop);
  AssertTrue(FTracker.StopRequested);
  AssertTrue(FTracker.IsRunning);
end;

procedure TSyringeStepTrackerTests.FinishClearsStopRequest;
var
  Error: string;
begin
  FTracker.Start;
  FTracker.RequestStop;
  FTracker.Finish(True, 'остановлен');
  AssertFalse(FTracker.StopRequested);
  AssertTrue(FTracker.Status(Error) = sssFailed);
  AssertFalse(FTracker.RequestStop);
end;

procedure TSyringeStepTrackerTests.StartResetsPreviousResult;
var
  Error: string;
begin
  FTracker.Start;
  FTracker.RequestStop;
  FTracker.Finish(True, 'сбой');
  FTracker.Start;
  AssertTrue(FTracker.Status(Error) = sssRunning);
  AssertEquals('', Error);
  AssertFalse(FTracker.StopRequested);
end;

initialization
  RegisterTest(TSyringeStepTrackerTests);
end.
