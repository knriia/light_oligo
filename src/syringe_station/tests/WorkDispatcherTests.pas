unit WorkDispatcherTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fpcunit, testregistry, FormWorkDispatcher;

type
  TDispatcherTestWorkItem = class
  public
    Value: string;
    constructor Create(const AValue: string);
  end;

  TDispatcherTestSink = class
  private
    FLock: TCriticalSection;
    FChangedEvent: TEvent;
    FValues: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute(AWorkItem: TObject);
    function Count: Integer;
    function ValueAt(Index: Integer): string;
    function WaitForCount(ExpectedCount: Integer;
      TimeoutMs: Cardinal): Boolean;
  end;

  TFormWorkDispatcherTests = class(TTestCase)
  published
    procedure ProcessesQueuedItemsInFifoOrder;
    procedure StopDrainsQueuedItemsAndRejectsNewWork;
  end;

implementation

constructor TDispatcherTestWorkItem.Create(const AValue: string);
begin
  inherited Create;
  Value := AValue;
end;

constructor TDispatcherTestSink.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FChangedEvent := TEvent.Create(nil, False, False, '');
  FValues := TStringList.Create;
end;

destructor TDispatcherTestSink.Destroy;
begin
  FValues.Free;
  FChangedEvent.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TDispatcherTestSink.Execute(AWorkItem: TObject);
var
  WorkItem: TDispatcherTestWorkItem;
begin
  WorkItem := TDispatcherTestWorkItem(AWorkItem);
  FLock.Acquire;
  try
    FValues.Add(WorkItem.Value);
  finally
    FLock.Release;
  end;
  FChangedEvent.SetEvent;
  WorkItem.Free;
end;

function TDispatcherTestSink.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FValues.Count;
  finally
    FLock.Release;
  end;
end;

function TDispatcherTestSink.ValueAt(Index: Integer): string;
begin
  FLock.Acquire;
  try
    Result := FValues[Index];
  finally
    FLock.Release;
  end;
end;

function TDispatcherTestSink.WaitForCount(ExpectedCount: Integer;
  TimeoutMs: Cardinal): Boolean;
var
  StartedAt: QWord;
begin
  StartedAt := GetTickCount64;
  repeat
    if Count >= ExpectedCount then
      Exit(True);
    FChangedEvent.WaitFor(10);
  until GetTickCount64 - StartedAt >= TimeoutMs;
  Result := Count >= ExpectedCount;
end;

procedure TFormWorkDispatcherTests.ProcessesQueuedItemsInFifoOrder;
var
  Sink: TDispatcherTestSink;
  Dispatcher: TFormWorkDispatcher;
begin
  Sink := TDispatcherTestSink.Create;
  Dispatcher := TFormWorkDispatcher.Create(@Sink.Execute);
  try
    AssertTrue(Dispatcher.Enqueue(TDispatcherTestWorkItem.Create('one')));
    AssertTrue(Dispatcher.Enqueue(TDispatcherTestWorkItem.Create('two')));
    AssertTrue(Dispatcher.Enqueue(TDispatcherTestWorkItem.Create('three')));
    AssertTrue(Sink.WaitForCount(3, 2000));
    AssertEquals('one', Sink.ValueAt(0));
    AssertEquals('two', Sink.ValueAt(1));
    AssertEquals('three', Sink.ValueAt(2));
  finally
    Dispatcher.Free;
    Sink.Free;
  end;
end;

procedure TFormWorkDispatcherTests.StopDrainsQueuedItemsAndRejectsNewWork;
var
  Sink: TDispatcherTestSink;
  Dispatcher: TFormWorkDispatcher;
  LateWorkItem: TDispatcherTestWorkItem;
begin
  Sink := TDispatcherTestSink.Create;
  Dispatcher := TFormWorkDispatcher.Create(@Sink.Execute);
  try
    AssertTrue(Dispatcher.Enqueue(TDispatcherTestWorkItem.Create('first')));
    AssertTrue(Dispatcher.Enqueue(TDispatcherTestWorkItem.Create('second')));
    Dispatcher.Stop;
    AssertEquals(2, Sink.Count);
    LateWorkItem := TDispatcherTestWorkItem.Create('late');
    AssertFalse(Dispatcher.Enqueue(LateWorkItem));
    LateWorkItem.Free;
  finally
    Dispatcher.Free;
    Sink.Free;
  end;
end;

initialization
  RegisterTest(TFormWorkDispatcherTests);

end.
