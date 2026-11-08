unit DispenserProtocol;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DispenserLimits;

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
function FormatResponseForLog(const Response: AnsiString): string;
function ParseStatusResponse(const Response: AnsiString;
  out StatusCode: Byte): Boolean;
function ParseAsciiQueryResponse(const Response: AnsiString;
  out Position: string): Boolean;
function StatusDescription(StatusCode: Byte): string;

implementation

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

function FormatResponseForLog(
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

function ParseStatusResponse(const Response: AnsiString;
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

function ParseAsciiQueryResponse(
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

function StatusDescription(StatusCode: Byte): string;
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

end.
