unit DispenserController;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, SerialPort, SerialTransactionQueue,
  DispenserLimits,
  DispenserTypes;

const
  STATUS_READY_MASK = $20;
  STATUS_ERROR_MASK = $0F;
  STATUS_NOT_INITIALIZED = 7;
  INITIALIZE_TIMEOUT_MS = 30000;
  INITIALIZE_POLL_INTERVAL_MS = 500;

function BuildDispenserMovementCommand(AAddress, AChannel, ASteps,
  ASpeed: Integer; AAspirate, ANonDistributive: Boolean): string;
function BuildDispenserValveCommand(AAddress, AChannel: Integer;
  ABypass, ANonDistributive: Boolean): string;
function BuildDispenserPlungerCommand(AAddress, ASteps,
  ASpeed: Integer; AAspirate: Boolean): string;

type
  TGetStrProc = procedure(const Msg: string) of object;

  TDispenserController = class
  private
    FPort: TSerialPort;
    FTransactionQueue: TSerialTransactionQueue;
    FReadyLock: TCriticalSection;
    FOnLogMessage: TGetStrProc;
    FIsReady: Boolean;
    function GetThreadOperationError: string;
    procedure SetThreadOperationError(const AValue: string);
    property FOperationError: string read GetThreadOperationError
      write SetThreadOperationError;
    function FormatResponseForLog(const Response: AnsiString): string;
    function ParseStatusResponse(const Response: AnsiString;
      out StatusCode: Byte): Boolean;
    function ParseAsciiQueryResponse(const Response: AnsiString;
      out Position: string): Boolean;
    function StatusDescription(StatusCode: Byte): string;
    function QueryStatusCode(Address: Integer; out StatusCode: Byte;
      LogDetails: Boolean = True;
      UpdateControllerReady: Boolean = True): Boolean;
    function ExecuteDeviceCommand(Address: Integer;
      const Command, Context: string): Boolean;
    procedure Log(const Msg: string);
  protected
    function GetIsConnected: Boolean; virtual;
    function GetIsReady: Boolean; virtual;
    function GetPortName: string; virtual;
    function GetLastError: string; virtual;
  public
    constructor Create; overload;
    constructor Create(APort: TSerialPort); overload;
    destructor Destroy; override;

    function Connect(const PortName: string): Boolean; virtual;
    procedure Disconnect; virtual;

    function SendCommand(const Command: string;
      LogCommand: Boolean = False): Boolean;
    function QueryStatus(Address: Integer; out StatusCode: Byte): Boolean; overload; virtual;
    function QueryStatusWithoutDetails(Address: Integer;
      out StatusCode: Byte): Boolean; virtual;
    function QueryStatusQuiet(Address: Integer; out StatusCode: Byte): Boolean; virtual;
    function DetectValveType(Address: Integer;
      out AValveType: TDispenserValveType): Boolean; virtual;
    function SetBypass(Address, Channel: Integer;
      AEnabled: Boolean; AValveType: TDispenserValveType): Boolean;
    function InitializeValve(Address, IntakeChannel: Integer): Boolean; virtual;
    function InitializePlunger(Address: Integer): Boolean; virtual;
    function SetFinePositioningMode(Address: Integer): Boolean; virtual;
    function QueryPlungerEncoderPosition(Address: Integer;
      out PositionSteps: Int64): Boolean; virtual;
    function ExecuteMovement(Address, Channel, Steps, Speed: Integer;
      AAspirate: Boolean; AValveType: TDispenserValveType): Boolean; virtual;
    function SetValvePosition(Address, Channel: Integer; AAspirate: Boolean;
      AValveType: TDispenserValveType): Boolean; virtual;
    function ExecutePlungerMovement(Address, Steps, Speed: Integer;
      AAspirate: Boolean): Boolean; virtual;
    function ChangeMovementSpeed(Address, Speed: Integer): Boolean; virtual;
    function TerminateMovement(Address: Integer): Boolean; virtual;
    function WaitForIdle(Address: Integer;
      AllowNotInitialized: Boolean; const PhaseName: string;
      LogReady: Boolean = True;
      TimeoutMs: QWord = INITIALIZE_TIMEOUT_MS): Boolean; virtual;
    procedure ScanPorts(PortList: TStrings);

    property PortName: string read GetPortName;
    property IsConnected: Boolean read GetIsConnected;
    property IsReady: Boolean read GetIsReady;
    property LastError: string read GetLastError;
    property OnLogMessage: TGetStrProc write FOnLogMessage;
  end;

implementation

threadvar
  GLastErrorController: Pointer;
  GLastControllerError: string;

function BuildDispenserMovementCommand(AAddress, AChannel, ASteps,
  ASpeed: Integer; AAspirate, ANonDistributive: Boolean): string;
var
  ValveCommand: string;
  PlungerCommand: string;
  StartSpeed: Integer;
begin
  Result := '';

  if ANonDistributive then
  begin
    case AChannel of
      1: ValveCommand := 'I';
      2: ValveCommand := 'O';
    else
      Exit;
    end;
  end
  else if AAspirate then
    ValveCommand := 'I' + IntToStr(AChannel)
  else
    ValveCommand := 'O' + IntToStr(AChannel);

  if AAspirate then
    PlungerCommand := 'P'
  else
    PlungerCommand := 'D';

  if ASpeed <= MAX_START_SPEED then
    StartSpeed := ASpeed
  else
    StartSpeed := DEFAULT_START_SPEED;

  Result := Format('/%d%sv%dV%d%s%dR',
    [AAddress, ValveCommand, StartSpeed, ASpeed, PlungerCommand, ASteps]);
end;

function BuildDispenserValveCommand(AAddress, AChannel: Integer;
  ABypass, ANonDistributive: Boolean): string;
var
  ValveCommand: string;
begin
  Result := '';
  if not ANonDistributive then
    Exit;

  if ABypass then
    ValveCommand := 'B'
  else
    case AChannel of
      1: ValveCommand := 'I';
      2: ValveCommand := 'O';
    else
      Exit;
    end;

  Result := Format('/%d%sR', [AAddress, ValveCommand]);
end;

function BuildDispenserPlungerCommand(AAddress, ASteps,
  ASpeed: Integer; AAspirate: Boolean): string;
var
  StartSpeed: Integer;
  MovementCommand: Char;
begin
  Result := '';
  if (AAddress < MIN_DISPENSER_VALUE) or
    (AAddress > MAX_DISPENSER_VALUE) or (ASteps <= 0) or
    (ASpeed < MIN_SPEED) or (ASpeed > MAX_SPEED) then
    Exit;

  if ASpeed <= MAX_START_SPEED then
    StartSpeed := ASpeed
  else
    StartSpeed := DEFAULT_START_SPEED;

  if AAspirate then
    MovementCommand := 'P'
  else
    MovementCommand := 'D';

  Result := '/' + IntToStr(AAddress) + 'v' + IntToStr(StartSpeed) + 'V' +
    IntToStr(ASpeed) + MovementCommand + IntToStr(ASteps) + 'R';
end;

constructor TDispenserController.Create;
begin
  inherited Create;
  FPort := TSerialPort.Create;
  FTransactionQueue := TSerialTransactionQueue.Create(FPort);
  FReadyLock := TCriticalSection.Create;
  FIsReady := False;
  FOperationError := '';
end;

constructor TDispenserController.Create(APort: TSerialPort);
begin
  inherited Create;
  if APort = nil then
    FPort := TSerialPort.Create
  else
    FPort := APort;
  FTransactionQueue := TSerialTransactionQueue.Create(FPort);
  FReadyLock := TCriticalSection.Create;
  FIsReady := False;
  FOperationError := '';
end;

destructor TDispenserController.Destroy;
begin
  FTransactionQueue.Free;
  FPort.Free;
  FReadyLock.Free;
  inherited;
end;

function TDispenserController.GetThreadOperationError: string;
begin
  if GLastErrorController = Pointer(Self) then
    Result := GLastControllerError
  else
    Result := '';
end;

procedure TDispenserController.SetThreadOperationError(const AValue: string);
begin
  GLastErrorController := Pointer(Self);
  GLastControllerError := AValue;
end;

procedure TDispenserController.Log(const Msg: string);
begin
  if Assigned(FOnLogMessage) then FOnLogMessage(Msg);
end;

function TDispenserController.Connect(const PortName: string): Boolean;
var
  ErrorText: string;
begin
  FReadyLock.Acquire;
  try
    FIsReady := False;
  finally
    FReadyLock.Release;
  end;
  FOperationError := '';
  Result := FTransactionQueue.OpenPort(PortName, 9600, ErrorText);
  if Result then
    Log('COM-порт открыт: ' + PortName)
  else
  begin
    FOperationError := 'Ошибка открытия ' + PortName + ': ' + ErrorText;
    Log(FOperationError);
  end;
end;

procedure TDispenserController.Disconnect;
begin
  FReadyLock.Acquire;
  try
    FIsReady := False;
  finally
    FReadyLock.Release;
  end;
  FOperationError := '';
  FTransactionQueue.ClosePort;
  Log('Порт закрыт');
end;

function TDispenserController.SendCommand(const Command: string;
  LogCommand: Boolean): Boolean;
var
  ErrorText: string;
begin
  if LogCommand then
    Log('TX: ' + Command);
  Result := FTransactionQueue.Write(AnsiString(Command + #13), ErrorText);
  if not Result then
  begin
    FOperationError := Format('Ошибка отправки команды %s: %s',
      [Command, ErrorText]);
    Log(FOperationError);
  end;
end;
function TDispenserController.FormatResponseForLog(
  const Response: AnsiString): string;
var
  I: Integer;
  Code: Integer;
begin
  Result := '';
  for I := 1 to Length(Response) do
  begin
    Code := Ord(Response[I]);
    if (Code >= $20) and (Code <= $7E) then
      Result := Result + Response[I]
    else
      Result := Result + '<' + IntToHex(Code, 2) + '>';
  end;

  if Result = '' then
    Result := '<empty>';
end;

function TDispenserController.ParseStatusResponse(const Response: AnsiString;
  out StatusCode: Byte): Boolean;
var
  StartPos: Integer;
begin
  StatusCode := 0;
  StartPos := Pos('/', Response);
  Result := (StartPos > 0) and
    (Length(Response) >= StartPos + 5) and
    (Response[StartPos + 1] = '0') and
    (Ord(Response[StartPos + 3]) = $03);

  if Result then
    StatusCode := Byte(Ord(Response[StartPos + 2]));
end;

function TDispenserController.ParseAsciiQueryResponse(
  const Response: AnsiString; out Position: string): Boolean;
var
  StartPos: Integer;
  PayloadStart: Integer;
  EtxPos: Integer;
  I: Integer;
begin
  Result := False;
  Position := '';

  StartPos := Pos('/', Response);
  if (StartPos <= 0) or
    (Length(Response) < StartPos + 2) or
    (Response[StartPos + 1] <> '0') then
    Exit;

  EtxPos := 0;
  for I := StartPos + 2 to Length(Response) do
    if Ord(Response[I]) = $03 then
    begin
      EtxPos := I;
      Break;
    end;

  if EtxPos = 0 then
    Exit;

  // The payload follows /0. Some devices place the status byte (ASCII 96)
  // before it, so remove that byte when it is present.
  PayloadStart := StartPos + 2;
  Position := Copy(Response, PayloadStart, EtxPos - PayloadStart);
  if (Length(Position) > 0) and (Ord(Position[1]) = 96) then
    Delete(Position, 1, 1);

  Result := Position <> '';
end;

function TDispenserController.StatusDescription(StatusCode: Byte): string;
var
  ErrorCode: Byte;
  StateText: string;
begin
  ErrorCode := StatusCode and STATUS_ERROR_MASK;
  if (StatusCode and STATUS_READY_MASK) <> 0 then
    StateText := 'готов'
  else
    StateText := 'занят';

  case ErrorCode of
    0: Result := StateText;
    1: Result := StateText + ', ошибка инициализации';
    2: Result := StateText + ', неверная команда';
    3: Result := StateText + ', неверный параметр';
    6: Result := StateText + ', ошибка EEPROM';
    7: Result := StateText + ', не инициализирован';
    9: Result := StateText + ', перегрузка плунжера';
    10: Result := StateText + ', перегрузка клапана';
    11: Result := StateText + ', перемещение плунжера запрещено';
    12: Result := StateText + ', внутренняя ошибка';
    14: Result := StateText + ', ошибка A/D-преобразователя';
    15: Result := StateText + ', переполнение команды';
  else
    Result := StateText + ', код ошибки ' + IntToStr(ErrorCode);
  end;
end;

function TDispenserController.QueryStatusCode(Address: Integer;
  out StatusCode: Byte; LogDetails: Boolean;
  UpdateControllerReady: Boolean): Boolean;
var
  Response: AnsiString;
  TransportError: string;
begin
  Result := False;
  StatusCode := 0;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format(
      'Дозатор №%d: некорректный адрес для запроса статуса.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  if not FTransactionQueue.Exchange(
    AnsiString(Format('/%dQ', [Address]) + #13), Response,
    TransportError) then
  begin
    FOperationError := Format(
      'Дозатор №%d: ошибка обмена при запросе статуса %s (%s).',
      [Address, Format('/%dQ', [Address]), TransportError]);
    Log(FOperationError);
    Exit;
  end;

  if not ParseStatusResponse(Response, StatusCode) then
  begin
    FOperationError := Format(
      'Дозатор №%d: некорректный ответ статуса: %s.',
      [Address, FormatResponseForLog(Response)]);
    Log(FOperationError);
    Exit;
  end;

  if LogDetails then
    Log(Format('Дозатор №%d: %s', [Address, StatusDescription(StatusCode)]));
  if UpdateControllerReady then
  begin
    FReadyLock.Acquire;
    try
    FIsReady := ((StatusCode and STATUS_READY_MASK) <> 0) and
      ((StatusCode and STATUS_ERROR_MASK) = 0);
    finally
      FReadyLock.Release;
    end;
  end;
  Result := True;
end;
function TDispenserController.QueryStatus(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  Result := QueryStatusCode(Address, StatusCode);
end;

function TDispenserController.QueryStatusWithoutDetails(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  Result := QueryStatusCode(Address, StatusCode, False, True);
end;

function TDispenserController.QueryStatusQuiet(Address: Integer;
  out StatusCode: Byte): Boolean;
begin
  Result := QueryStatusCode(Address, StatusCode, False, False);
end;

function TDispenserController.DetectValveType(Address: Integer;
  out AValveType: TDispenserValveType): Boolean;
var
  Response: AnsiString;
  Position: string;
  TransportError: string;
begin
  Result := False;
  AValveType := dvtUnknown;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format(
      'Дозатор №%d: недопустимый адрес для запроса поддержки bypass.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  if not FTransactionQueue.Exchange(
    AnsiString(Format('/%d?6', [Address]) + #13), Response,
    TransportError) then
  begin
    FOperationError := Format(
      'Дозатор №%d: нет ответа на запрос положения клапана (%s).',
      [Address, TransportError]);
    Log(FOperationError);
    Exit;
  end;

  if not ParseAsciiQueryResponse(Response, Position) then
  begin
    FOperationError := Format(
      'Дозатор №%d: некорректный ответ положения клапана: %s.',
      [Address, FormatResponseForLog(Response)]);
    Log(FOperationError);
    Exit;
  end;

  if (Position = 'i') or (Position = 'o') or (Position = 'b') or (Position = 'e') then
  begin
    AValveType := dvtNonDistributive;
    Log(Format(
      'Дозатор №%d: клапан недистрибутивный, bypass доступен (позиция %s).',
      [Address, Position]));
  end
  else
  begin
    AValveType := dvtDistributive;
    Log(Format(
      'Дозатор №%d: клапан распределительный, bypass недоступен.',
      [Address]));
  end;

  Result := True;
end;

function TDispenserController.QueryPlungerEncoderPosition(Address: Integer;
  out PositionSteps: Int64): Boolean;
var
  Response: AnsiString;
  PositionText: string;
  TransportError: string;
begin
  { SY-01B ?4 reports the encoder's absolute plunger position in increments.
    Initialization configures N1, so these increments match the movement
    units used by this controller. }
  Result := False;
  PositionSteps := 0;
  FOperationError := '';
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format(
      'Дозатор %d: некорректный адрес для запроса положения плунжера.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  if not FTransactionQueue.Exchange(
    AnsiString(Format('/%d?4', [Address]) + #13), Response,
    TransportError) then
  begin
    FOperationError := Format(
      'Дозатор %d: не удалось прочитать положение энкодера (%s).',
      [Address, TransportError]);
    Log(FOperationError);
    Exit;
  end;

  if not ParseAsciiQueryResponse(Response, PositionText) or
    not TryStrToInt64(PositionText, PositionSteps) or
    (PositionSteps < 0) then
  begin
    PositionSteps := 0;
    FOperationError := Format(
      'Дозатор %d: некорректное положение энкодера: %s.',
      [Address, FormatResponseForLog(Response)]);
    Log(FOperationError);
    Exit;
  end;

  Result := True;
end;

function TDispenserController.ExecuteDeviceCommand(Address: Integer;
  const Command, Context: string): Boolean;
var
  Response: AnsiString;
  StatusCode: Byte;
  ErrorCode: Byte;
  TransportError: string;
begin
  Result := False;
  if not FTransactionQueue.Exchange(
    AnsiString(Command + #13), Response, TransportError) then
  begin
    FOperationError := Format('Дозатор №%d: нет ответа на команду %s (%s)',
      [Address, Context, TransportError]);
    Log(FOperationError);
    Exit;
  end;

  if not ParseStatusResponse(Response, StatusCode) then
  begin
    FOperationError := Format(
      'Дозатор №%d: некорректный ответ на команду %s: %s',
      [Address, Context, FormatResponseForLog(Response)]);
    Log(FOperationError);
    Exit;
  end;

  ErrorCode := StatusCode and STATUS_ERROR_MASK;
  if ErrorCode <> 0 then
  begin
    FOperationError := Format(
      'Дозатор №%d: команда %s отклонена: %s (0x%s)',
      [Address, Context, StatusDescription(StatusCode),
      IntToHex(StatusCode, 2)]);
    Log(FOperationError);
    Exit;
  end;

  Result := True;
end;
function TDispenserController.SetBypass(Address, Channel: Integer;
  AEnabled: Boolean; AValveType: TDispenserValveType): Boolean;
var
  Command: string;
  Context: string;
begin
  Result := False;

  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format('Дозатор %d: некорректный адрес для bypass.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  if AValveType <> dvtNonDistributive then
  begin
    FOperationError := Format(
      'Дозатор %d: bypass доступен только для недистрибутивного клапана.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  Command := BuildDispenserValveCommand(Address, Channel, AEnabled, True);
  if Command = '' then
  begin
    FOperationError := Format(
      'Дозатор %d: нельзя выбрать канал %d для bypass.',
      [Address, Channel]);
    Log(FOperationError);
    Exit;
  end;

  if AEnabled then
    Context := 'включения bypass'
  else
    Context := 'возврата клапана в выбранный канал';

  if not ExecuteDeviceCommand(Address, Command, Context) then
    Exit;

  Result := WaitForIdle(Address, False, 'переключения клапана', False);
end;

function TDispenserController.InitializeValve(Address,
  IntakeChannel: Integer): Boolean;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    Log(Format('Инициализация клапана: некорректный адрес дозатора №%d',
      [Address]));
    Exit;
  end;

  if (IntakeChannel < MIN_CHANNEL_NUMBER) or
    (IntakeChannel > MAX_CHANNEL_COUNT) then
  begin
    Log(Format('Дозатор №%d: некорректный входной канал %d',
      [Address, IntakeChannel]));
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address,
    Format('/%dw%d,0R', [Address, IntakeChannel]),
    'инициализации клапана');
end;

function TDispenserController.InitializePlunger(Address: Integer): Boolean;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    Log(Format('Инициализация плунжера: некорректный адрес дозатора №%d',
      [Address]));
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address, Format('/%dW0R', [Address]),
    'инициализации плунжера');
end;

function TDispenserController.SetFinePositioningMode(Address: Integer): Boolean;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    Log(Format('Установка режима N1: некорректный адрес дозатора №%d',
      [Address]));
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address,
    Format('/%dN1R', [Address]),
    'настройку режима N1');
  if Result then
    Log(Format('Дозатор №%d: установлен режим N1', [Address]));
end;

function TDispenserController.ExecuteMovement(Address, Channel, Steps,
  Speed: Integer; AAspirate: Boolean;
  AValveType: TDispenserValveType): Boolean;
var
  Command: string;
  Context: string;
  MaxSupportedChannel: Integer;
begin
  Result := False;

  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format('Недопустимый адрес дозатора: %d.', [Address]);
    Log(FOperationError);
    Exit;
  end;

  if AValveType = dvtNonDistributive then
    MaxSupportedChannel := MAX_NON_DISTRIBUTIVE_CHANNEL_COUNT
  else
    MaxSupportedChannel := MAX_CHANNEL_COUNT;

  if (Channel < MIN_CHANNEL_NUMBER) or
    (Channel > MaxSupportedChannel) then
  begin
    FOperationError := Format('Дозатор %d: недопустимый канал %d.',
      [Address, Channel]);
    Log(FOperationError);
    Exit;
  end;

  if Steps <= 0 then
  begin
    FOperationError := Format(
      'Дозатор %d: количество шагов должно быть больше нуля.', [Address]);
    Log(FOperationError);
    Exit;
  end;

  if (Speed < MIN_SPEED) or (Speed > MAX_SPEED) then
  begin
    FOperationError := Format(
      'Дозатор %d: скорость должна быть в диапазоне %d..%d.',
      [Address, MIN_SPEED, MAX_SPEED]);
    Log(FOperationError);
    Exit;
  end;

  if AAspirate then
  begin
    Command := BuildDispenserMovementCommand(Address, Channel, Steps, Speed,
      True, AValveType = dvtNonDistributive);
    Context := 'набора жидкости';
  end
  else
  begin
    Command := BuildDispenserMovementCommand(Address, Channel, Steps, Speed,
      False, AValveType = dvtNonDistributive);
    Context := 'дозирования жидкости';
  end;

  if not ExecuteDeviceCommand(Address, Command, Context) then
    Exit;

  Result := True;
end;

function TDispenserController.SetValvePosition(Address, Channel: Integer;
  AAspirate: Boolean; AValveType: TDispenserValveType): Boolean;
var
  Command: string;
  Direction: Char;
  MaxSupportedChannel: Integer;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format('Недопустимый адрес дозатора: %d.', [Address]);
    Log(FOperationError);
    Exit;
  end;

  if AValveType = dvtNonDistributive then
  begin
    { For a two-channel valve, the requested channel selects the physical
      port. The piston direction is handled separately by the movement
      command, so aspiration must not force channel 1 or dispensing channel 2. }
    if (Channel < MIN_CHANNEL_NUMBER) or
      (Channel > MAX_NON_DISTRIBUTIVE_CHANNEL_COUNT) then
    begin
      FOperationError := Format('Дозатор %d: недопустимый канал %d.',
        [Address, Channel]);
      Log(FOperationError);
      Exit;
    end;
    Command := BuildDispenserValveCommand(Address, Channel, False, True);
  end
  else
  begin
    if AValveType <> dvtDistributive then
    begin
      FOperationError := Format(
        'Дозатор %d: тип клапана не определён.', [Address]);
      Log(FOperationError);
      Exit;
    end;
    MaxSupportedChannel := MAX_CHANNEL_COUNT;
    if (Channel < MIN_CHANNEL_NUMBER) or
      (Channel > MaxSupportedChannel) then
    begin
      FOperationError := Format('Дозатор %d: недопустимый канал %d.',
        [Address, Channel]);
      Log(FOperationError);
      Exit;
    end;
    if AAspirate then
      Direction := 'I'
    else
      Direction := 'O';
    Command := '/' + IntToStr(Address) + Direction + IntToStr(Channel) + 'R';
  end;

  if Command = '' then
  begin
    FOperationError := Format(
      'Дозатор %d: не удалось подготовить команду переключения клапана.',
      [Address]);
    Log(FOperationError);
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address, Command,
    'переключения клапана');
end;

function TDispenserController.ExecutePlungerMovement(Address, Steps,
  Speed: Integer; AAspirate: Boolean): Boolean;
var
  Command: string;
  Context: string;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format('Недопустимый адрес дозатора: %d.', [Address]);
    Log(FOperationError);
    Exit;
  end;
  if Steps <= 0 then
  begin
    FOperationError := Format(
      'Дозатор %d: количество шагов должно быть больше нуля.', [Address]);
    Log(FOperationError);
    Exit;
  end;
  if (Speed < MIN_SPEED) or (Speed > MAX_SPEED) then
  begin
    FOperationError := Format(
      'Дозатор %d: скорость должна быть в диапазоне %d..%d.',
      [Address, MIN_SPEED, MAX_SPEED]);
    Log(FOperationError);
    Exit;
  end;

  Command := BuildDispenserPlungerCommand(Address, Steps, Speed, AAspirate);
  if AAspirate then
    Context := 'набора жидкости'
  else
    Context := 'дозирования жидкости';
  Result := ExecuteDeviceCommand(Address, Command, Context);
end;

function TDispenserController.ChangeMovementSpeed(Address,
  Speed: Integer): Boolean;
begin
  Result := False;

  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format(
      'Дозатор %d: недопустимый адрес для изменения скорости.', [Address]);
    Log(FOperationError);
    Exit;
  end;

  if (Speed < MIN_SPEED) or (Speed > MAX_SPEED) then
  begin
    FOperationError := Format(
      'Дозатор %d: скорость должна быть в диапазоне %d..%d.',
      [Address, MIN_SPEED, MAX_SPEED]);
    Log(FOperationError);
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address, Format('/%dV%d', [Address, Speed]),
    'изменения скорости во время движения');
end;

function TDispenserController.TerminateMovement(Address: Integer): Boolean;
begin
  Result := False;
  if (Address < MIN_DISPENSER_VALUE) or
    (Address > MAX_DISPENSER_VALUE) then
  begin
    FOperationError := Format(
      'Дозатор %d: недопустимый адрес для остановки.', [Address]);
    Log(FOperationError);
    Exit;
  end;

  Result := ExecuteDeviceCommand(Address, Format('/%dT', [Address]),
    'остановки движения');
end;

function TDispenserController.WaitForIdle(Address: Integer;
  AllowNotInitialized: Boolean; const PhaseName: string;
  LogReady: Boolean; TimeoutMs: QWord): Boolean;
var
  StatusCode: Byte;
  StartedAt: QWord;
  ErrorCode: Byte;
begin
  Result := False;
  StartedAt := GetTickCount64;

  repeat
    Sleep(INITIALIZE_POLL_INTERVAL_MS);
    if not QueryStatusCode(Address, StatusCode, False) then
      Exit;

    ErrorCode := StatusCode and STATUS_ERROR_MASK;
    if ((StatusCode and STATUS_READY_MASK) <> 0) and
      ((ErrorCode = 0) or (AllowNotInitialized and
      (ErrorCode = STATUS_NOT_INITIALIZED))) then
    begin
      if LogReady then
        Log(Format('Дозатор %d: %s готов', [Address, PhaseName]));
      Result := True;
      Exit;
    end;

    if (ErrorCode <> 0) and
      not (AllowNotInitialized and (ErrorCode = STATUS_NOT_INITIALIZED)) then
    begin
      FOperationError := Format(
        'Дозатор %d: %s — ошибка: %s (0x%s)',
        [Address, PhaseName, StatusDescription(StatusCode),
        IntToHex(StatusCode, 2)]);
      Log(FOperationError);
      Exit;
    end;
  until GetTickCount64 - StartedAt >= TimeoutMs;

  FOperationError := 'Дозатор ' + IntToStr(Address) +
    ': ожидание завершения (' + PhaseName + ') истекло (' +
    IntToStr(Int64(TimeoutMs div 1000)) + ' с).';
  Log(FOperationError);
end;

procedure TDispenserController.ScanPorts(PortList: TStrings);
begin
  FTransactionQueue.ScanAvailablePorts(PortList);
end;

function TDispenserController.GetIsConnected: Boolean;
begin
  Result := FTransactionQueue.IsConnected;
end;

function TDispenserController.GetIsReady: Boolean;
begin
  FReadyLock.Acquire;
  try Result := FIsReady; finally FReadyLock.Release; end;
end;

function TDispenserController.GetLastError: string;
begin
  if FOperationError <> '' then
    Result := FOperationError
  else
  begin
    Result := FTransactionQueue.LastError;
  end;
end;

function TDispenserController.GetPortName: string;
begin
  Result := FTransactionQueue.PortName;
end;

end.
