unit LaserMarkingTests;
// Тесты маркировки слоя через EzCAD: порядок действий и каждая беда.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, LaserMarking;

type
  // Подставной EzCAD: помнит, запущен ли он, и записывает действия.
  TFakeEzCad = class(TEzCadDriver)
  public
    Journal: TStringList;
    Running: Boolean;
    Closing: Boolean;
    ClosePollsLeft: Integer;      // сколько опросов нужно, чтобы EzCAD закрылся
    ClosePollsNeeded: Integer;    // для нового Close; -1 - не закроется никогда
    LaunchOk: Boolean;
    RunsAfterLaunch: Boolean;
    MarkOk: Boolean;
    StopAfterMarks: Integer;      // 0 - остановку не просим
    Marks: Integer;
    Polls: Integer;
    constructor Create;
    destructor Destroy; override;
    function IsRunning: Boolean; override;
    function Launch(const AEzdFile: string): Boolean; override;
    function SendMark: Boolean; override;
    procedure Close; override;
    procedure Wait(AMilliseconds: Integer); override;
    procedure Poll(AMilliseconds: Integer); override;
    function StopRequested: Boolean; override;
    procedure Log(const AText: string); override;
    procedure Opening; override;
  end;

  TLaserMarkingTests = class(TTestCase)
  private
    FEz: TFakeEzCad;
    function Joined: string;
    function Mark(ARepeats: Integer; ATime: Double; out AError: string): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NormalRunOpensMarksAndCloses;
    procedure MarksAsManyTimesAsAskedWithWaitAfterEach;
    procedure NoRepeatsOnlyOpensAndCloses;
    procedure WaitsForEzCadStillClosingFromPreviousLayer;
    procedure EzCadThatNeverClosesIsAnErrorWithoutMarking;
    procedure LaunchFailureIsReportedWithFile;
    procedure EzCadThatDiesAfterLaunchIsReported;
    procedure RejectedMarkCommandIsReportedAndEzCadClosed;
    procedure StopRequestEndsMarkingButStillClosesEzCad;
    procedure SlowCloseIsWaitedFor;
    procedure CloseThatNeverFinishesOnlyWarns;
  end;

implementation

constructor TFakeEzCad.Create;
begin
  inherited Create;
  Journal := TStringList.Create;
  LaunchOk := True;
  RunsAfterLaunch := True;
  MarkOk := True;
end;

destructor TFakeEzCad.Destroy;
begin
  Journal.Free;
  inherited Destroy;
end;

function TFakeEzCad.IsRunning: Boolean;
begin
  Result := Running;
end;

function TFakeEzCad.Launch(const AEzdFile: string): Boolean;
begin
  Journal.Add('launch ' + AEzdFile);
  Result := LaunchOk;
  if Result then
    Running := RunsAfterLaunch;
end;

function TFakeEzCad.SendMark: Boolean;
begin
  Journal.Add('mark');
  Inc(Marks);
  Result := MarkOk;
end;

procedure TFakeEzCad.Close;
begin
  Journal.Add('close');
  if ClosePollsNeeded = 0 then
    Running := False
  else if ClosePollsNeeded > 0 then
  begin
    Closing := True;
    ClosePollsLeft := ClosePollsNeeded;
  end;
end;

procedure TFakeEzCad.Wait(AMilliseconds: Integer);
begin
  Journal.Add('wait ' + IntToStr(AMilliseconds));
end;

procedure TFakeEzCad.Poll(AMilliseconds: Integer);
begin
  Inc(Polls);
  if Closing then
  begin
    Dec(ClosePollsLeft);
    if ClosePollsLeft <= 0 then
    begin
      Closing := False;
      Running := False;
    end;
  end;
end;

function TFakeEzCad.StopRequested: Boolean;
begin
  Result := (StopAfterMarks > 0) and (Marks >= StopAfterMarks);
end;

procedure TFakeEzCad.Log(const AText: string);
begin
  Journal.Add('log ' + AText);
end;

procedure TFakeEzCad.Opening;
begin
  Journal.Add('opening');
end;

{ TLaserMarkingTests }

procedure TLaserMarkingTests.SetUp;
begin
  inherited SetUp;
  FEz := TFakeEzCad.Create;
end;

procedure TLaserMarkingTests.TearDown;
begin
  FEz.Free;
  inherited TearDown;
end;

function TLaserMarkingTests.Joined: string;
begin
  Result := StringReplace(Trim(FEz.Journal.Text), LineEnding, '|',
    [rfReplaceAll]);
end;

function TLaserMarkingTests.Mark(ARepeats: Integer; ATime: Double;
  out AError: string): Boolean;
begin
  Result := MarkLayerWithEzCad(FEz, 'D:\arr\Layer 1.ezd', ARepeats, ATime, 1500,
    AError);
end;

procedure TLaserMarkingTests.NormalRunOpensMarksAndCloses;
var
  Error: string;
begin
  AssertTrue(Error, Mark(2, 3, Error));
  AssertEquals(
    'opening|log EzCAD opening|launch D:\arr\Layer 1.ezd|wait 1500|' +
    'mark|wait 3000|log Laser----F2--->|' +
    'mark|wait 3000|log Laser----F2--->|' +
    'close|log EzCAD closed', Joined);
  AssertFalse(FEz.Running);
end;

procedure TLaserMarkingTests.MarksAsManyTimesAsAskedWithWaitAfterEach;
var
  Error: string;
begin
  AssertTrue(Error, Mark(4, 2.4, Error));   // время округляется до секунд
  AssertEquals(4, FEz.Marks);
  AssertTrue(Joined, Pos('mark|wait 2000', Joined) > 0);
end;

procedure TLaserMarkingTests.NoRepeatsOnlyOpensAndCloses;
var
  Error: string;
begin
  AssertTrue(Error, Mark(0, 3, Error));
  AssertEquals(0, FEz.Marks);
  AssertTrue(Joined, Pos('launch', Joined) > 0);
  AssertTrue(Joined, Pos('close', Joined) > 0);
end;

procedure TLaserMarkingTests.WaitsForEzCadStillClosingFromPreviousLayer;
var
  Error: string;
begin
  FEz.Running := True;       // предыдущий слой ещё закрывается
  FEz.Closing := True;
  FEz.ClosePollsLeft := 3;
  AssertTrue(Error, Mark(1, 1, Error));
  AssertEquals('три опроса до закрытия', 3, FEz.Polls);
  AssertTrue(Joined, Pos('launch', Joined) > Pos('log ', Joined));
  AssertEquals('маркировка не пропущена', 1, FEz.Marks);
end;

procedure TLaserMarkingTests.EzCadThatNeverClosesIsAnErrorWithoutMarking;
var
  Error: string;
begin
  FEz.Running := True;       // чужой EzCAD, закрывать себя не собирается
  AssertFalse(Mark(1, 1, Error));
  AssertTrue(Error, Pos('EzCAD2', Error) > 0);
  AssertEquals('ждали всё отведённое время',
    EZCAD_CLOSE_WAIT_MS div EZCAD_POLL_MS, FEz.Polls);
  AssertEquals(0, Pos('launch', Joined));
  AssertEquals(0, FEz.Marks);
  AssertEquals('чужой EzCAD не трогаем', 0, Pos('close', Joined));
end;

procedure TLaserMarkingTests.LaunchFailureIsReportedWithFile;
var
  Error: string;
begin
  FEz.LaunchOk := False;
  AssertFalse(Mark(1, 1, Error));
  AssertTrue(Error, Pos('Layer 1.ezd', Error) > 0);
  AssertEquals(0, FEz.Marks);
  AssertEquals('нечего закрывать', 0, Pos('close', Joined));
end;

procedure TLaserMarkingTests.EzCadThatDiesAfterLaunchIsReported;
var
  Error: string;
begin
  FEz.RunsAfterLaunch := False;
  AssertFalse(Mark(1, 1, Error));
  AssertTrue(Error, Pos('Layer 1.ezd', Error) > 0);
  AssertEquals(0, FEz.Marks);
end;

procedure TLaserMarkingTests.RejectedMarkCommandIsReportedAndEzCadClosed;
var
  Error: string;
begin
  FEz.MarkOk := False;
  AssertFalse(Mark(3, 1, Error));
  AssertTrue(Error, Pos('1 из 3', Error) > 0);
  AssertEquals('после отказа не продолжаем', 1, FEz.Marks);
  AssertTrue('EzCAD закрыт', Pos('close', Joined) > 0);
  AssertFalse(FEz.Running);
end;

procedure TLaserMarkingTests.StopRequestEndsMarkingButStillClosesEzCad;
var
  Error: string;
begin
  FEz.StopAfterMarks := 1;
  AssertTrue(Error, Mark(5, 1, Error));
  AssertEquals(1, FEz.Marks);
  AssertTrue(Joined, Pos('close', Joined) > 0);
  AssertFalse(FEz.Running);
end;

procedure TLaserMarkingTests.SlowCloseIsWaitedFor;
var
  Error: string;
begin
  FEz.ClosePollsNeeded := 3;
  AssertTrue(Error, Mark(1, 1, Error));
  AssertEquals(3, FEz.Polls);
  AssertTrue(Joined, Pos('log EzCAD closed', Joined) > Pos('close|', Joined));
end;

procedure TLaserMarkingTests.CloseThatNeverFinishesOnlyWarns;
var
  Error: string;
begin
  FEz.ClosePollsNeeded := -1;
  AssertTrue('сама маркировка выполнена', Mark(1, 1, Error));
  AssertTrue(Joined, Pos('log WARNING', Joined) > 0);
  AssertEquals(0, Pos('log EzCAD closed', Joined));
  AssertEquals(EZCAD_CLOSE_WAIT_MS div EZCAD_POLL_MS, FEz.Polls);
end;

initialization
  RegisterTest(TLaserMarkingTests);

end.
