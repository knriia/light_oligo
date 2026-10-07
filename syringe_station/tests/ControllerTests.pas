unit ControllerTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fpcunit, testregistry, DispenserController,
  DispenserTypes, SerialPort;

type
  TMockSerialPort = class(TSerialPort)
  private
    FResponses: array of AnsiString;
  protected
    FResponseIndex: Integer;
    function GetPortName: string; override;
    function GetConnected: Boolean; override;
    function GetLastError: string; override;
  public
    OpenResult: Boolean;
    ReadResult: Boolean;
    WriteResult: Boolean;
    FailReadAtCall: Integer;
    FailWriteAtCall: Integer;
    PortErrorText: string;
    ConnectedState: Boolean;
    OpenCalls: Integer;
    CloseCalls: Integer;
    WriteCalls: Integer;
    ReadCalls: Integer;
    ClearCalls: Integer;
    LastOpenedPort: string;
    LastWrittenData: AnsiString;
    WrittenData: TStringList;

    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(const Response: AnsiString);
    function Open(const APortName: string; Baud: Integer = 9600): Boolean; override;
    procedure Close; override;
    function Write(const Data: AnsiString): Boolean; override;
    function ReadResponse(out Data: AnsiString;
      TimeoutMs: Cardinal = 1000): Boolean; override;
    procedure ClearInputBuffer; override;
    procedure ScanAvailablePorts(PortList: TStrings); override;
  end;

  TSerializedMockSerialPort = class(TMockSerialPort)
  private
    FGuard: TCriticalSection;
    FReadEntered: TEvent;
    FReleaseFirstRead: TEvent;
    FActiveReads: Integer;
    FReadCount: Integer;
    FResponseStatus: Byte;
    FInterleavingDetected: Boolean;
    function GetInterleavingDetected: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearInputBuffer; override;
    function Write(const Data: AnsiString): Boolean; override;
    function ReadResponse(out Data: AnsiString;
      TimeoutMs: Cardinal = 1000): Boolean; override;
    property ReadEntered: TEvent read FReadEntered;
    property ReleaseFirstRead: TEvent read FReleaseFirstRead;
    property InterleavingDetected: Boolean read GetInterleavingDetected;
  end;

  TControllerQueryThread = class(TThread)
  private
    FController: TDispenserController;
    FAddress: Integer;
    FStartedEvent: TEvent;
    FFinishedEvent: TEvent;
  protected
    procedure Execute; override;
  public
    Succeeded: Boolean;
    StatusCode: Byte;
    constructor Create(AController: TDispenserController; AAddress: Integer);
    destructor Destroy; override;
    property StartedEvent: TEvent read FStartedEvent;
    property FinishedEvent: TEvent read FFinishedEvent;
  end;

  TDispenserControllerTests = class(TTestCase)
  private
    FPort: TMockSerialPort;
    FController: TDispenserController;
    FLogs: TStringList;
    procedure CaptureLog(const Msg: string);
    procedure QueueStatus(StatusCode: Byte);
    procedure QueueDeviceAck(StatusCode: Byte = 0);
    procedure QueueValvePosition(const Position: AnsiString;
      IncludeStatusByte: Boolean = True);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MovementCommandBuildersCoverValveAndDirectionOptions;
    procedure ConnectDisconnectAndSendCommand;
    procedure QueryStatusCoversStatusDescriptionsAndQuietMode;
    procedure QueryStatusWithoutDetailsUpdatesReadyWithoutLogging;
    procedure QueryStatusHandlesAddressTransportAndProtocolErrors;
    procedure QueryPlungerEncoderPositionReadsActualSteps;
    procedure ProtocolParsersRejectMalformedFrames;
    procedure DetectValveTypeHandlesPositionsAndFailures;
    procedure DeviceCommandMethodsValidateAndSerializeArguments;
    procedure SetValvePositionBuildsDistributiveChannelCommands;
    procedure SetValvePositionUsesRequestedNonDistributiveChannel;
    procedure ChangeMovementSpeedSendsVCommandWhileBusy;
    procedure TerminateMovementSendsTCommand;
    procedure DeviceCommandsRejectTransportProtocolAndDeviceErrors;
    procedure BypassRequiresSupportedValveAndWaitsForIdle;
    procedure WaitForIdleCoversReadyNotInitializedErrorAndTimeout;
    procedure ScanPortsDelegatesToSerialTransport;
    procedure SendsAnotherDispenserCommandWhileFirstIsMoving;
    procedure SerializesConcurrentPortTransactions;
  end;

  TSerialPortFailureTests = class(TTestCase)
  published
    procedure MissingPortLeavesTransportDisconnectedAndReportsFailures;
  end;

implementation

uses
  DispenserLimits;

constructor TMockSerialPort.Create;
begin
  inherited Create;
  OpenResult := True;
  ReadResult := True;
  WriteResult := True;
  PortErrorText := 'mock port error';
  WrittenData := TStringList.Create;
end;

destructor TMockSerialPort.Destroy;
begin
  WrittenData.Free;
  inherited Destroy;
end;

function TMockSerialPort.GetPortName: string;
begin
  Result := LastOpenedPort;
end;

function TMockSerialPort.GetConnected: Boolean;
begin
  Result := ConnectedState;
end;

function TMockSerialPort.GetLastError: string;
begin
  Result := PortErrorText;
end;

procedure TMockSerialPort.QueueResponse(const Response: AnsiString);
begin
  SetLength(FResponses, Length(FResponses) + 1);
  FResponses[High(FResponses)] := Response;
end;

function TMockSerialPort.Open(const APortName: string;
  Baud: Integer): Boolean;
begin
  Inc(OpenCalls);
  LastOpenedPort := APortName;
  ConnectedState := OpenResult;
  Result := OpenResult;
end;

procedure TMockSerialPort.Close;
begin
  Inc(CloseCalls);
  ConnectedState := False;
end;

function TMockSerialPort.Write(const Data: AnsiString): Boolean;
begin
  Inc(WriteCalls);
  LastWrittenData := Data;
  WrittenData.Add(string(Data));
  Result := WriteResult and
    ((FailWriteAtCall = 0) or (WriteCalls <> FailWriteAtCall));
end;

function TMockSerialPort.ReadResponse(out Data: AnsiString;
  TimeoutMs: Cardinal): Boolean;
begin
  Inc(ReadCalls);
  Data := '';
  Result := ReadResult and
    ((FailReadAtCall = 0) or (ReadCalls <> FailReadAtCall));
  if not Result then
    Exit;
  if FResponseIndex < Length(FResponses) then
  begin
    Data := FResponses[FResponseIndex];
    Inc(FResponseIndex);
  end;
end;

procedure TMockSerialPort.ClearInputBuffer;
begin
  Inc(ClearCalls);
end;

procedure TMockSerialPort.ScanAvailablePorts(PortList: TStrings);
begin
  PortList.Clear;
  PortList.Add('COM_FAKE');
end;

constructor TSerializedMockSerialPort.Create;
begin
  inherited Create;
  FGuard := TCriticalSection.Create;
  FReadEntered := TEvent.Create(nil, True, False, '');
  FReleaseFirstRead := TEvent.Create(nil, True, False, '');
  FActiveReads := 0;
  FReadCount := 0;
  FResponseStatus := 0;
  FInterleavingDetected := False;
end;

destructor TSerializedMockSerialPort.Destroy;
begin
  FReleaseFirstRead.SetEvent;
  FReadEntered.Free;
  FReleaseFirstRead.Free;
  FGuard.Free;
  inherited Destroy;
end;

function TSerializedMockSerialPort.GetInterleavingDetected: Boolean;
begin
  FGuard.Acquire;
  try
    Result := FInterleavingDetected;
  finally
    FGuard.Release;
  end;
end;

procedure TSerializedMockSerialPort.ClearInputBuffer;
begin
  FGuard.Acquire;
  try
    if FActiveReads > 0 then
      FInterleavingDetected := True;
  finally
    FGuard.Release;
  end;
end;

function TSerializedMockSerialPort.Write(const Data: AnsiString): Boolean;
begin
  FGuard.Acquire;
  try
    if FActiveReads > 0 then
      FInterleavingDetected := True;
    if Pos('/1Q', string(Data)) > 0 then
      FResponseStatus := STATUS_READY_MASK
    else
      FResponseStatus := 0;
  finally
    FGuard.Release;
  end;
  Result := True;
end;

function TSerializedMockSerialPort.ReadResponse(out Data: AnsiString;
  TimeoutMs: Cardinal): Boolean;
var
  ReadNumber: Integer;
  Status: Byte;
begin
  FGuard.Acquire;
  try
    Inc(FReadCount);
    ReadNumber := FReadCount;
    Inc(FActiveReads);
    if FActiveReads > 1 then
      FInterleavingDetected := True;
    FReadEntered.SetEvent;
  finally
    FGuard.Release;
  end;

  if ReadNumber = 1 then
    FReleaseFirstRead.WaitFor(2000);

  FGuard.Acquire;
  try
    Status := FResponseStatus;
    Dec(FActiveReads);
  finally
    FGuard.Release;
  end;

  Data := '/0' + AnsiChar(Status) + #3#13#10;
  Result := True;
end;

constructor TControllerQueryThread.Create(AController: TDispenserController;
  AAddress: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FController := AController;
  FAddress := AAddress;
  FStartedEvent := TEvent.Create(nil, True, False, '');
  FFinishedEvent := TEvent.Create(nil, True, False, '');
  Succeeded := False;
  StatusCode := 0;
end;

destructor TControllerQueryThread.Destroy;
begin
  FStartedEvent.Free;
  FFinishedEvent.Free;
  inherited Destroy;
end;

procedure TControllerQueryThread.Execute;
begin
  FStartedEvent.SetEvent;
  Succeeded := FController.QueryStatus(FAddress, StatusCode);
  FFinishedEvent.SetEvent;
end;

procedure TDispenserControllerTests.SetUp;
begin
  inherited SetUp;
  FPort := TMockSerialPort.Create;
  FController := TDispenserController.Create(FPort);
  FLogs := TStringList.Create;
  FController.OnLogMessage := @CaptureLog;
end;

procedure TDispenserControllerTests.TearDown;
begin
  FLogs.Free;
  FController.Free;
  inherited TearDown;
end;

procedure TDispenserControllerTests.CaptureLog(const Msg: string);
begin
  FLogs.Add(Msg);
end;

procedure TDispenserControllerTests.QueueStatus(StatusCode: Byte);
begin
  FPort.QueueResponse(AnsiString('/0') + AnsiChar(StatusCode) + #3#13#10);
end;

procedure TDispenserControllerTests.QueueDeviceAck(StatusCode: Byte);
begin
  QueueStatus(StatusCode);
end;

procedure TDispenserControllerTests.QueueValvePosition(
  const Position: AnsiString; IncludeStatusByte: Boolean);
begin
  if IncludeStatusByte then
    FPort.QueueResponse(AnsiString('/0') + AnsiChar(96) + Position + #3#13#10)
  else
    FPort.QueueResponse(AnsiString('/0') + Position + #3#13#10);
end;

procedure TDispenserControllerTests.MovementCommandBuildersCoverValveAndDirectionOptions;
begin
  AssertEquals('/1Iv900V6000P12000R',
    BuildDispenserMovementCommand(1, 1, 12000, 6000, True, True));
  AssertEquals('/1Ov900V6000D12000R',
    BuildDispenserMovementCommand(1, 2, 12000, 6000, False, True));
  AssertEquals('', BuildDispenserMovementCommand(1, 0, 100, 10, True, True));
  AssertEquals('', BuildDispenserMovementCommand(1, 3, 100, 10, False, True));
  AssertEquals('/1I1v1V1P1R',
    BuildDispenserMovementCommand(1, 1, 1, 1, True, False));
  AssertEquals('/15O12v900V6000D12000R',
    BuildDispenserMovementCommand(15, 12, 12000, 6000, False, False));
  AssertEquals('/2BR', BuildDispenserValveCommand(2, 0, True, True));
  AssertEquals('/2IR', BuildDispenserValveCommand(2, 1, False, True));
  AssertEquals('/2OR', BuildDispenserValveCommand(2, 2, False, True));
  AssertEquals('', BuildDispenserValveCommand(2, 3, False, True));
  AssertEquals('', BuildDispenserValveCommand(2, 1, True, False));
end;

procedure TDispenserControllerTests.ConnectDisconnectAndSendCommand;
begin
  AssertTrue(FController.Connect('COM7'));
  AssertTrue(FController.IsConnected);
  AssertEquals('COM7', FController.PortName);
  AssertEquals(1, FPort.OpenCalls);

  AssertTrue(FController.SendCommand('/1Q', True));
  AssertEquals('/1Q' + #13, string(FPort.LastWrittenData));
  AssertTrue(FLogs.Count > 0);

  FController.Disconnect;
  AssertFalse(FController.IsConnected);
  AssertFalse(FController.IsReady);
  AssertEquals(1, FPort.CloseCalls);

  FPort.OpenResult := False;
  AssertFalse(FController.Connect('COM_FAIL'));
  AssertFalse(FController.IsConnected);
  AssertTrue(FController.LastError <> '');
end;

procedure TDispenserControllerTests.QueryStatusCoversStatusDescriptionsAndQuietMode;
const
  ErrorCodes: array[0..12] of Byte = (0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14);
var
  I: Integer;
  StatusCode: Byte;
begin
  for I := Low(ErrorCodes) to High(ErrorCodes) do
  begin
    QueueStatus(ErrorCodes[I]);
    AssertTrue(FController.QueryStatus(1, StatusCode));
    AssertEquals(ErrorCodes[I], StatusCode);
  end;
  QueueStatus(15);
  AssertTrue(FController.QueryStatus(1, StatusCode));
  AssertEquals(15, StatusCode);
  AssertTrue(FLogs.Count >= 14);

  QueueStatus(STATUS_READY_MASK);
  AssertTrue(FController.QueryStatus(1, StatusCode));
  AssertTrue(FController.IsReady);
  QueueStatus(0);
  AssertTrue(FController.QueryStatusQuiet(1, StatusCode));
  AssertTrue(FController.IsReady);
  AssertFalse(FController.QueryStatusQuiet(MAX_DISPENSER_VALUE + 1,
    StatusCode));
end;

procedure TDispenserControllerTests.QueryStatusWithoutDetailsUpdatesReadyWithoutLogging;
var
  StatusCode: Byte;
begin
  QueueStatus(STATUS_READY_MASK);
  AssertTrue(FController.QueryStatusWithoutDetails(1, StatusCode));
  AssertEquals(STATUS_READY_MASK, StatusCode);
  AssertTrue(FController.IsReady);
  AssertEquals(0, FLogs.Count);
end;

procedure TDispenserControllerTests.QueryStatusHandlesAddressTransportAndProtocolErrors;
var
  StatusCode: Byte;
begin
  AssertFalse(FController.QueryStatus(MIN_DISPENSER_VALUE - 1, StatusCode));

  FPort.WriteResult := False;
  AssertFalse(FController.QueryStatus(1, StatusCode));
  AssertTrue(Pos('/1Q', FController.LastError) > 0);

  FPort.WriteResult := True;
  FPort.ReadResult := False;
  AssertFalse(FController.QueryStatus(1, StatusCode));
  AssertTrue(FController.LastError <> '');

  FPort.ReadResult := True;
  FPort.QueueResponse('');
  AssertFalse(FController.QueryStatus(1, StatusCode));
  AssertTrue(Pos('<empty>', FController.LastError) > 0);

  FPort.QueueResponse(AnsiString('/1') + AnsiChar(1) + #3#13#10);
  AssertFalse(FController.QueryStatus(1, StatusCode));
  AssertTrue(Pos('<01>', FController.LastError) > 0);

  FPort.QueueResponse(AnsiString('/0') + AnsiChar(0) + #0#13#10);
  AssertFalse(FController.QueryStatus(1, StatusCode));
  AssertTrue(Pos('<00>', FController.LastError) > 0);
end;

procedure TDispenserControllerTests.QueryPlungerEncoderPositionReadsActualSteps;
var
  PositionSteps: Int64;
begin
  PositionSteps := -1;
  AssertFalse(FController.QueryPlungerEncoderPosition(
    MIN_DISPENSER_VALUE - 1, PositionSteps));
  AssertEquals(0, PositionSteps);
  AssertEquals(0, FPort.WriteCalls);

  QueueValvePosition('12345');
  AssertTrue(FController.QueryPlungerEncoderPosition(1, PositionSteps));
  AssertEquals(12345, PositionSteps);
  AssertEquals('/1?4' + #13, string(FPort.LastWrittenData));

  QueueValvePosition('not-a-number');
  AssertFalse(FController.QueryPlungerEncoderPosition(1, PositionSteps));
  AssertEquals(0, PositionSteps);

  QueueValvePosition('-1');
  AssertFalse(FController.QueryPlungerEncoderPosition(1, PositionSteps));
  AssertEquals(0, PositionSteps);
end;

procedure TDispenserControllerTests.ProtocolParsersRejectMalformedFrames;
var
  StatusCode: Byte;
  ValveType: TDispenserValveType;
begin
  FPort.QueueResponse('/0');
  AssertFalse(FController.QueryStatus(1, StatusCode));

  FPort.QueueResponse('no frame');
  AssertFalse(FController.DetectValveType(1, ValveType));

  FPort.QueueResponse('/');
  AssertFalse(FController.DetectValveType(1, ValveType));

  FPort.QueueResponse('/1i' + #3#13#10);
  AssertFalse(FController.DetectValveType(1, ValveType));

  FPort.QueueResponse('/0i');
  AssertFalse(FController.DetectValveType(1, ValveType));
end;

procedure TDispenserControllerTests.DetectValveTypeHandlesPositionsAndFailures;
var
  ValveType: TDispenserValveType;
  Positions: array[0..4] of AnsiString;
  I: Integer;
begin
  AssertFalse(FController.DetectValveType(0, ValveType));
  AssertFalse(FController.DetectValveType(MAX_DISPENSER_VALUE + 1,
    ValveType));
  AssertEquals(Ord(dvtUnknown), Ord(ValveType));

  Positions[0] := 'i';
  Positions[1] := 'o';
  Positions[2] := 'b';
  Positions[3] := 'e';
  Positions[4] := 'x';
  for I := Low(Positions) to High(Positions) do
  begin
    QueueValvePosition(Positions[I]);
    AssertTrue(FController.DetectValveType(1, ValveType));
    if I < 4 then
      AssertEquals(Ord(dvtNonDistributive), Ord(ValveType))
    else
      AssertEquals(Ord(dvtDistributive), Ord(ValveType));
  end;

  QueueValvePosition('i', False);
  AssertTrue(FController.DetectValveType(1, ValveType));
  AssertEquals(Ord(dvtNonDistributive), Ord(ValveType));

  FPort.QueueResponse('/0' + #3#13#10);
  AssertFalse(FController.DetectValveType(1, ValveType));
  FPort.ReadResult := False;
  AssertFalse(FController.DetectValveType(1, ValveType));
  FPort.ReadResult := True;
  FPort.WriteResult := False;
  AssertFalse(FController.DetectValveType(1, ValveType));
end;

procedure TDispenserControllerTests.DeviceCommandMethodsValidateAndSerializeArguments;
begin
  AssertFalse(FController.InitializeValve(0, 1));
  AssertFalse(FController.InitializeValve(MAX_DISPENSER_VALUE + 1, 1));
  AssertFalse(FController.InitializeValve(1, 0));
  AssertFalse(FController.InitializeValve(1, MAX_CHANNEL_COUNT + 1));
  QueueDeviceAck;
  AssertTrue(FController.InitializeValve(1, 12));
  AssertEquals('/1w12,0R' + #13, string(FPort.LastWrittenData));

  AssertFalse(FController.InitializePlunger(MAX_DISPENSER_VALUE + 1));
  AssertFalse(FController.InitializePlunger(MIN_DISPENSER_VALUE - 1));
  QueueDeviceAck;
  AssertTrue(FController.InitializePlunger(1));
  AssertEquals('/1W0R' + #13, string(FPort.LastWrittenData));

  AssertFalse(FController.SetFinePositioningMode(0));
  AssertFalse(FController.SetFinePositioningMode(
    MAX_DISPENSER_VALUE + 1));
  QueueDeviceAck;
  AssertTrue(FController.SetFinePositioningMode(1));
  AssertEquals('/1N1R' + #13, string(FPort.LastWrittenData));

  AssertFalse(FController.ExecuteMovement(0, 1, 1, 1, True, dvtDistributive));
  AssertFalse(FController.ExecuteMovement(MAX_DISPENSER_VALUE + 1, 1, 1, 1,
    True, dvtDistributive));
  AssertFalse(FController.ExecuteMovement(1, 0, 1, 1, True, dvtDistributive));
  AssertFalse(FController.ExecuteMovement(1, MAX_CHANNEL_COUNT + 1, 1, 1,
    True, dvtDistributive));
  AssertFalse(FController.ExecuteMovement(1, MAX_NON_DISTRIBUTIVE_CHANNEL_COUNT + 1,
    1, 1, True, dvtNonDistributive));
  AssertFalse(FController.ExecuteMovement(1, 1, 0, 1, True, dvtDistributive));
  AssertFalse(FController.ExecuteMovement(1, 1, 1, MIN_SPEED - 1, True,
    dvtDistributive));
  AssertFalse(FController.ExecuteMovement(1, 1, 1, MAX_SPEED + 1, True,
    dvtDistributive));
  QueueDeviceAck;
  AssertTrue(FController.ExecuteMovement(1, MAX_CHANNEL_COUNT, 123, MAX_SPEED,
    True, dvtDistributive));
  AssertEquals('/1I12v900V6000P123R' + #13, string(FPort.LastWrittenData));
  QueueDeviceAck;
  AssertTrue(FController.ExecuteMovement(1, 2, 123, MIN_SPEED, False,
    dvtNonDistributive));
  AssertEquals('/1Ov1V1D123R' + #13, string(FPort.LastWrittenData));
end;

procedure TDispenserControllerTests.SetValvePositionBuildsDistributiveChannelCommands;
begin
  QueueDeviceAck;
  AssertTrue(FController.SetValvePosition(1, 2, True, dvtDistributive));
  AssertEquals('/1I2R' + #13, string(FPort.LastWrittenData));

  QueueDeviceAck;
  AssertTrue(FController.SetValvePosition(1, 2, False, dvtDistributive));
  AssertEquals('/1O2R' + #13, string(FPort.LastWrittenData));
end;

procedure TDispenserControllerTests.SetValvePositionUsesRequestedNonDistributiveChannel;
var
  WritesBefore: Integer;
begin
  QueueDeviceAck;
  AssertTrue(FController.SetValvePosition(1, 2, True, dvtNonDistributive));
  AssertEquals('/1OR' + #13, string(FPort.LastWrittenData));

  QueueDeviceAck;
  AssertTrue(FController.SetValvePosition(1, 1, False, dvtNonDistributive));
  AssertEquals('/1IR' + #13, string(FPort.LastWrittenData));

  WritesBefore := FPort.WriteCalls;
  AssertFalse(FController.SetValvePosition(1, 3, True,
    dvtNonDistributive));
  AssertEquals(WritesBefore, FPort.WriteCalls);
end;

procedure TDispenserControllerTests.ChangeMovementSpeedSendsVCommandWhileBusy;
begin
  AssertFalse(FController.ChangeMovementSpeed(0, 1));
  AssertFalse(FController.ChangeMovementSpeed(MAX_DISPENSER_VALUE + 1, 1));
  AssertFalse(FController.ChangeMovementSpeed(1, MIN_SPEED - 1));
  AssertFalse(FController.ChangeMovementSpeed(1, MAX_SPEED + 1));

  QueueDeviceAck(0);
  AssertTrue(FController.ChangeMovementSpeed(1, 4800));
  AssertEquals('/1V4800' + #13, string(FPort.LastWrittenData));

  QueueDeviceAck(STATUS_READY_MASK or 3);
  AssertFalse(FController.ChangeMovementSpeed(1, 4800));
  AssertTrue(Pos('отклонена', FController.LastError) > 0);
end;

procedure TDispenserControllerTests.TerminateMovementSendsTCommand;
begin
  AssertFalse(FController.TerminateMovement(MIN_DISPENSER_VALUE - 1));
  AssertFalse(FController.TerminateMovement(MAX_DISPENSER_VALUE + 1));
  AssertEquals(0, FPort.WriteCalls);

  QueueDeviceAck;
  AssertTrue(FController.TerminateMovement(1));
  AssertEquals('/1T' + #13, string(FPort.LastWrittenData));
end;

procedure TDispenserControllerTests.BypassRequiresSupportedValveAndWaitsForIdle;
begin
  AssertFalse(FController.SetBypass(0, 1, True, dvtNonDistributive));
  AssertFalse(FController.SetBypass(MAX_DISPENSER_VALUE + 1, 1, True,
    dvtNonDistributive));
  AssertFalse(FController.SetBypass(1, 1, True, dvtDistributive));
  AssertFalse(FController.SetBypass(1, 0, False, dvtNonDistributive));
  AssertFalse(FController.SetBypass(1, 3, False, dvtNonDistributive));

  QueueDeviceAck;
  QueueStatus(STATUS_READY_MASK);
  AssertTrue(FController.SetBypass(1, 2, True, dvtNonDistributive));
  AssertEquals('/1BR' + #13, string(FPort.WrittenData[0]));
  AssertEquals(2, FPort.WriteCalls);
  AssertEquals('/1Q' + #13, string(FPort.LastWrittenData));

  QueueDeviceAck;
  QueueStatus(STATUS_READY_MASK);
  AssertTrue(FController.SetBypass(1, 2, False, dvtNonDistributive));
  AssertEquals('/1OR' + #13, string(FPort.WrittenData[2]));
end;

procedure TDispenserControllerTests.DeviceCommandsRejectTransportProtocolAndDeviceErrors;
begin
  FPort.WriteResult := False;
  AssertFalse(FController.InitializePlunger(1));

  FPort.WriteResult := True;
  FPort.ReadResult := False;
  AssertFalse(FController.InitializePlunger(1));

  FPort.ReadResult := True;
  FPort.QueueResponse('invalid response');
  AssertFalse(FController.InitializePlunger(1));

  QueueDeviceAck(2);
  AssertFalse(FController.InitializePlunger(1));
  AssertTrue(FController.LastError <> '');

  QueueDeviceAck;
  AssertTrue(FController.InitializePlunger(1));
end;

procedure TDispenserControllerTests.WaitForIdleCoversReadyNotInitializedErrorAndTimeout;
begin
  QueueStatus(STATUS_READY_MASK);
  AssertTrue(FController.WaitForIdle(1, False, 'normal'));

  QueueStatus(STATUS_READY_MASK or STATUS_NOT_INITIALIZED);
  AssertTrue(FController.WaitForIdle(1, True, 'initialization', False));

  QueueStatus(STATUS_NOT_INITIALIZED);
  AssertFalse(FController.WaitForIdle(1, True, 'not-ready-not-initialized',
    False, 0));

  QueueStatus(STATUS_READY_MASK or 2);
  AssertFalse(FController.WaitForIdle(1, True, 'other-device-error', False,
    0));

  QueueStatus($22);
  AssertFalse(FController.WaitForIdle(1, False, 'error', False, 0));
  AssertTrue(FController.LastError <> '');

  QueueStatus(0);
  AssertFalse(FController.WaitForIdle(1, False, 'timeout', False, 0));
  AssertTrue(Pos('timeout', LowerCase(FController.LastError)) > 0);

  FPort.ReadResult := False;
  AssertFalse(FController.WaitForIdle(1, False, 'read-error', False, 0));
end;

procedure TDispenserControllerTests.ScanPortsDelegatesToSerialTransport;
var
  Ports: TStringList;
begin
  Ports := TStringList.Create;
  try
    Ports.Add('STALE');
    FController.ScanPorts(Ports);
    AssertEquals(1, Ports.Count);
    AssertEquals('COM_FAKE', Ports[0]);
  finally
    Ports.Free;
  end;
end;

procedure TDispenserControllerTests.SerializesConcurrentPortTransactions;
var
  Port: TSerializedMockSerialPort;
  Controller: TDispenserController;
  FirstQuery: TControllerQueryThread;
  SecondQuery: TControllerQueryThread;
  FirstStarted: Boolean;
  SecondStarted: Boolean;
  SecondReturnedBeforeRelease: Boolean;
  InterleavingDetected: Boolean;
  FirstStatus: Byte;
  SecondStatus: Byte;
  FirstSucceeded: Boolean;
  SecondSucceeded: Boolean;
begin
  Port := TSerializedMockSerialPort.Create;
  Controller := TDispenserController.Create(Port);
  FirstQuery := TControllerQueryThread.Create(Controller, 1);
  SecondQuery := TControllerQueryThread.Create(Controller, 2);
  FirstStarted := False;
  SecondStarted := False;
  SecondReturnedBeforeRelease := False;
  InterleavingDetected := False;
  try
    FirstQuery.Start;
    FirstStarted := True;
    AssertTrue(FirstQuery.StartedEvent.WaitFor(1000) = wrSignaled);
    AssertTrue(Port.ReadEntered.WaitFor(1000) = wrSignaled);

    SecondQuery.Start;
    SecondStarted := True;
    AssertTrue(SecondQuery.StartedEvent.WaitFor(1000) = wrSignaled);
    SecondReturnedBeforeRelease :=
      SecondQuery.FinishedEvent.WaitFor(250) = wrSignaled;
    InterleavingDetected := Port.InterleavingDetected;

    Port.ReleaseFirstRead.SetEvent;
    FirstQuery.WaitFor;
    SecondQuery.WaitFor;
    FirstStatus := FirstQuery.StatusCode;
    SecondStatus := SecondQuery.StatusCode;
    FirstSucceeded := FirstQuery.Succeeded;
    SecondSucceeded := SecondQuery.Succeeded;
  finally
    Port.ReleaseFirstRead.SetEvent;
    if FirstStarted then
      FirstQuery.WaitFor;
    if SecondStarted then
      SecondQuery.WaitFor;
    SecondQuery.Free;
    FirstQuery.Free;
    Controller.Free;
  end;

  AssertFalse('A second transaction must wait for the current COM response.',
    SecondReturnedBeforeRelease);
  AssertFalse('COM writes or reads interleaved between two transactions.',
    InterleavingDetected);
  AssertTrue(FirstSucceeded);
  AssertTrue(SecondSucceeded);
  AssertEquals(STATUS_READY_MASK, FirstStatus);
  AssertEquals(0, SecondStatus);
end;

procedure TDispenserControllerTests.SendsAnotherDispenserCommandWhileFirstIsMoving;
var
  StatusCode: Byte;
begin
  QueueDeviceAck;
  AssertTrue(FController.ExecuteMovement(1, 2, 100, 100, True,
    dvtDistributive));

  QueueStatus(0);
  AssertTrue(FController.QueryStatus(1, StatusCode));
  AssertEquals(0, StatusCode and STATUS_READY_MASK);

  QueueDeviceAck;
  AssertTrue(FController.ExecuteMovement(2, 3, 100, 100, True,
    dvtDistributive));
  AssertEquals(3, FPort.WrittenData.Count);
  AssertTrue(Pos('/2', string(FPort.WrittenData[2])) > 0);
end;

procedure TSerialPortFailureTests.MissingPortLeavesTransportDisconnectedAndReportsFailures;
const
  MissingPortName = '__syringe_pump_test_missing_port__';
var
  Port: TSerialPort;
  Response: AnsiString;
begin
  Port := TSerialPort.Create;
  try
    AssertFalse(Port.Open(MissingPortName));
    AssertFalse(Port.Connected);
    AssertEquals(MissingPortName, Port.PortName);
    AssertTrue(Port.LastError <> '');
    AssertFalse(Port.Write('test'));
    AssertFalse(Port.ReadResponse(Response, 0));
    AssertEquals('', string(Response));
    AssertTrue(Port.LastError <> '');
    Port.ClearInputBuffer;
    Port.Close;
    AssertFalse(Port.Connected);
  finally
    Port.Free;
  end;
end;

initialization
  RegisterTest(TDispenserControllerTests);
  RegisterTest(TSerialPortFailureTests);

end.
