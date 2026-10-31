unit DispenserConnectionCoordinator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, DispenserController, DispenserConfig,
  DispenserRuntimeState, DispenserTypes, DispenserLimits;

type
  TDispenserConnectionResult = (dcrConnected, dcrReady, dcrPortOpenFailed,
    dcrInvalidRequest, dcrInitializationFailed);

  TInitializationPhase = (ipIdle, ipValve, ipPlunger);

  TDispenserConnectionLogEvent = procedure(const Msg: string) of object;

  TDispenserConnectionCoordinator = class
  private
    FController: TDispenserController;
    FRuntimeStates: TDispenserRuntimeStates;
    FOnLogMessage: TDispenserConnectionLogEvent;
    FExecutionLock: TCriticalSection;
    FLock: TCriticalSection;
    FActive: Boolean;
    FAddressActive: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of
      Boolean;
    FTargets: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of
      TDispenserConfig;
    FPhases: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of
      TInitializationPhase;
    FPending: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
    FStartedAt: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of QWord;
    FErrors: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of string;
    FResultFailures: TStringList;
    FLastSuccess: Boolean;
    procedure Log(const Msg: string);
    procedure Enter;
    procedure Leave;
    procedure UpdateActiveInitialization;
    procedure MarkFailure(AAddress: Integer; const AMessage: string);
    procedure StartMotorPhase(AAddress: Integer; APlunger: Boolean);
    procedure FinishInitialization(AAddress: Integer);
  public
    constructor Create(AController: TDispenserController;
      ARuntimeStates: TDispenserRuntimeStates);
    destructor Destroy; override;
    function ConnectPort(const PortName: string; out ErrorText: string):
      TDispenserConnectionResult;
    function InitializeDispensers(Configurations: TDispenserConfigList;
      Failures: TStrings): Boolean;
    procedure PollInitialization;
    function HasActiveInitialization: Boolean;
    function IsAddressInitializing(AAddress: Integer): Boolean;
    procedure GetInitializationResults(Failures: TStrings;
      out Success: Boolean);
    procedure Disconnect;

    property OnLogMessage: TDispenserConnectionLogEvent write FOnLogMessage;
  end;

implementation

uses
  SysUtils;

constructor TDispenserConnectionCoordinator.Create(
  AController: TDispenserController; ARuntimeStates: TDispenserRuntimeStates);
var
  Address: Integer;
begin
  inherited Create;
  FController := AController;
  FRuntimeStates := ARuntimeStates;
  FExecutionLock := TCriticalSection.Create;
  FLock := TCriticalSection.Create;
  FResultFailures := TStringList.Create;
  FLastSuccess := True;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
  begin
    FAddressActive[Address] := False;
    FTargets[Address] := nil;
    FPhases[Address] := ipIdle;
    FPending[Address] := False;
    FStartedAt[Address] := 0;
    FErrors[Address] := '';
  end;
end;

destructor TDispenserConnectionCoordinator.Destroy;
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    FTargets[Address].Free;
  FResultFailures.Free;
  FLock.Free;
  FExecutionLock.Free;
  inherited Destroy;
end;

procedure TDispenserConnectionCoordinator.Log(const Msg: string);
begin
  if Assigned(FOnLogMessage) then
    FOnLogMessage(Msg);
end;

procedure TDispenserConnectionCoordinator.Enter;
begin
  FExecutionLock.Acquire;
end;

procedure TDispenserConnectionCoordinator.Leave;
begin
  FExecutionLock.Release;
end;

procedure TDispenserConnectionCoordinator.UpdateActiveInitialization;
var
  Address: Integer;
begin
  FLock.Acquire;
  try
    FActive := False;
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      FAddressActive[Address] := FPhases[Address] <> ipIdle;
      FActive := FActive or FAddressActive[Address];
    end;
  finally
    FLock.Release;
  end;
end;

procedure TDispenserConnectionCoordinator.MarkFailure(AAddress: Integer;
  const AMessage: string);
begin
  if (AAddress < MIN_DISPENSER_VALUE) or
    (AAddress > MAX_DISPENSER_VALUE) or (FErrors[AAddress] <> '') then
    Exit;
  FErrors[AAddress] := AMessage;
  if FErrors[AAddress] = '' then
    FErrors[AAddress] := 'Не удалось выполнить инициализацию.';
  FPending[AAddress] := False;
  FPhases[AAddress] := ipIdle;
  if (FRuntimeStates <> nil) and (FRuntimeStates.Items[AAddress] <> nil) then
    FRuntimeStates.Items[AAddress].MarkInitializationFailed(FErrors[AAddress]);
  Log(Format('Дозатор №%d: инициализация не выполнена: %s',
    [AAddress, FErrors[AAddress]]));
  if FTargets[AAddress] <> nil then
  begin
    FLock.Acquire;
    try
      FResultFailures.Add(Format('Дозатор №%d: %s',
        [AAddress, FErrors[AAddress]]));
      FLastSuccess := False;
    finally
      FLock.Release;
    end;
  end;
  UpdateActiveInitialization;
end;

procedure TDispenserConnectionCoordinator.StartMotorPhase(AAddress: Integer;
  APlunger: Boolean);
var
  Config: TDispenserConfig;
begin
  Config := FTargets[AAddress];
  if (Config = nil) or (FErrors[AAddress] <> '') then
    Exit;

  if APlunger then
    FPhases[AAddress] := ipPlunger
  else
    FPhases[AAddress] := ipValve;
  if APlunger then
  begin
    if FController.InitializePlunger(AAddress) then
    begin
      FPending[AAddress] := True;
      FStartedAt[AAddress] := GetTickCount64;
    end
    else
      MarkFailure(AAddress, FController.LastError);
  end
  else if FController.InitializeValve(AAddress, Config.IntakeChannel) then
  begin
    FPending[AAddress] := True;
    FStartedAt[AAddress] := GetTickCount64;
    Log(Format('Дозатор №%d: инициализация запущена', [AAddress]));
  end
  else
    MarkFailure(AAddress, FController.LastError);

  UpdateActiveInitialization;
end;

procedure TDispenserConnectionCoordinator.FinishInitialization(
  AAddress: Integer);
var
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
  ValveType: TDispenserValveType;
begin
  Config := FTargets[AAddress];
  if (Config = nil) or (FErrors[AAddress] <> '') or
    (FPhases[AAddress] <> ipPlunger) then
    Exit;

  if not FController.SetFinePositioningMode(AAddress) then
  begin
    MarkFailure(AAddress, FController.LastError);
    Exit;
  end;
  ValveType := dvtUnknown;
  if not FController.DetectValveType(AAddress, ValveType) then
  begin
    MarkFailure(AAddress, FController.LastError);
    Exit;
  end;

  State := FRuntimeStates.Items[AAddress];
  State.ValveType := ValveType;
  State.MarkInitialized(Config);
  Log(Format('Дозатор №%d: инициализирован, готов к работе', [AAddress]));
  FTargets[AAddress].Free;
  FTargets[AAddress] := nil;
  FPending[AAddress] := False;
  FPhases[AAddress] := ipIdle;
  UpdateActiveInitialization;
end;

function TDispenserConnectionCoordinator.ConnectPort(const PortName: string;
  out ErrorText: string): TDispenserConnectionResult;
begin
  ErrorText := '';
  if (FController = nil) or (FRuntimeStates = nil) or
    (Trim(PortName) = '') then
  begin
    ErrorText := 'Не задан COM-порт или состояние дозаторов.';
    Exit(dcrInvalidRequest);
  end;
  Enter;
  try
    if HasActiveInitialization then
    begin
      ErrorText := 'Дождитесь завершения инициализации дозаторов.';
      Exit(dcrInvalidRequest);
    end;
    if FController.IsConnected then
    begin
      ErrorText := 'COM-порт уже подключён.';
      Exit(dcrInvalidRequest);
    end;

    FRuntimeStates.Reset;
    if not FController.Connect(PortName) then
    begin
      ErrorText := FController.LastError;
      Exit(dcrPortOpenFailed);
    end;
    Log('Подключение к COM-порту установлено; дозаторы требуют инициализации');
    Result := dcrConnected;
  finally
    Leave;
  end;
end;

function TDispenserConnectionCoordinator.InitializeDispensers(
  Configurations: TDispenserConfigList; Failures: TStrings): Boolean;
var
  Address, I, AcceptedCount: Integer;
  Config: TDispenserConfig;
  State: TDispenserRuntimeState;
  Seen: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
  Invalid: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of Boolean;
  Candidates: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of
    TDispenserConfig;
  StatusCode, ErrorCode: Byte;
begin
  Result := False;
  if Failures <> nil then
    Failures.Clear;
  if (Configurations = nil) or (Configurations.Count = 0) or
    (Failures = nil) then
  begin
    if Failures <> nil then
      Failures.Add('Не заданы дозаторы для инициализации.');
    Exit;
  end;
  if (FController = nil) or (FRuntimeStates = nil) or
    not FController.IsConnected then
  begin
    Failures.Add('COM-порт не подключён.');
    Exit;
  end;

  Enter;
  try
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      Seen[Address] := False;
      Invalid[Address] := False;
      Candidates[Address] := nil;
    end;

    for I := 0 to Configurations.Count - 1 do
    begin
      Config := Configurations[I];
      if Config = nil then
      begin
        Failures.Add('В списке конфигурации есть пустой дозатор.');
        Continue;
      end;
      Address := Config.Address;
      if not (Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
      begin
        Failures.Add(Format('Некорректный адрес дозатора: %d.', [Address]));
        Continue;
      end;
      if Seen[Address] then
      begin
        Invalid[Address] := True;
        Failures.Add(Format('Дозатор №%d: адрес повторяется в конфигурации.',
          [Address]));
        Continue;
      end;
      Seen[Address] := True;
      Candidates[Address] := Config;
    end;

    AcceptedCount := 0;
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      Config := Candidates[Address];
      if (Config = nil) or Invalid[Address] then
        Continue;
      if FPhases[Address] <> ipIdle then
      begin
        Failures.Add(Format('Дозатор №%d: инициализация уже выполняется.',
          [Address]));
        Continue;
      end;

      FTargets[Address].Free;
      FTargets[Address] := Config.Clone;
      FErrors[Address] := '';
      FPending[Address] := False;
      FStartedAt[Address] := 0;
      FPhases[Address] := ipValve;
      Inc(AcceptedCount);
      State := FRuntimeStates.Items[Address];
      if State = nil then
      begin
        MarkFailure(Address, 'Не удалось получить состояние дозатора.');
        Continue;
      end;
      State.RequireInitialization;
      if not FController.QueryStatusWithoutDetails(Address, StatusCode) then
      begin
        MarkFailure(Address, FController.LastError);
        Continue;
      end;
      ErrorCode := StatusCode and STATUS_ERROR_MASK;
      if (ErrorCode <> 0) and (ErrorCode <> STATUS_NOT_INITIALIZED) then
        MarkFailure(Address, Format('Ошибка статуса 0x%s.',
          [IntToHex(StatusCode, 2)]))
      else if (ErrorCode = 0) and
        ((StatusCode and STATUS_READY_MASK) = 0) then
        MarkFailure(Address, 'Дозатор занят и не готов к инициализации.');

      if FPhases[Address] = ipValve then
        StartMotorPhase(Address, False);
    end;

    if AcceptedCount > 0 then
    begin
      if Failures.Count > 0 then
      begin
        FLock.Acquire;
        try
          for I := 0 to Failures.Count - 1 do
            FResultFailures.Add(Failures[I]);
          FLastSuccess := False;
        finally
          FLock.Release;
        end;
      end;
      UpdateActiveInitialization;
      Result := True;
    end;
  finally
    Leave;
  end;
end;

procedure TDispenserConnectionCoordinator.PollInitialization;
var
  Address: Integer;
  StatusCode, ErrorCode: Byte;
begin
  Enter;
  try
    if not HasActiveInitialization then
      Exit;
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
      if FPending[Address] then
      begin
        if GetTickCount64 - FStartedAt[Address] >= INITIALIZE_TIMEOUT_MS then
        begin
          MarkFailure(Address, Format(
            'Ожидание завершения истекло (%d с).',
            [INITIALIZE_TIMEOUT_MS div 1000]));
          Continue;
        end;
        if not FController.QueryStatusQuiet(Address, StatusCode) then
        begin
          MarkFailure(Address, FController.LastError);
          Continue;
        end;
        ErrorCode := StatusCode and STATUS_ERROR_MASK;
        if ((StatusCode and STATUS_READY_MASK) <> 0) and
          ((ErrorCode = 0) or ((FPhases[Address] = ipValve) and
          (ErrorCode = STATUS_NOT_INITIALIZED))) then
        begin
          FPending[Address] := False;
          if FPhases[Address] = ipValve then
            StartMotorPhase(Address, True)
          else if FPhases[Address] = ipPlunger then
            FinishInitialization(Address);
        end
        else if (ErrorCode <> 0) and not
          ((FPhases[Address] = ipValve) and
          (ErrorCode = STATUS_NOT_INITIALIZED)) then
          MarkFailure(Address, Format('Ошибка статуса 0x%s.',
            [IntToHex(StatusCode, 2)]));
      end;

    UpdateActiveInitialization;
  finally
    Leave;
  end;
end;

function TDispenserConnectionCoordinator.HasActiveInitialization: Boolean;
begin
  FLock.Acquire;
  try
    Result := FActive;
  finally
    FLock.Release;
  end;
end;

procedure TDispenserConnectionCoordinator.GetInitializationResults(
  Failures: TStrings; out Success: Boolean);
begin
  FLock.Acquire;
  try
    if Failures <> nil then
      Failures.Assign(FResultFailures);
    Success := FLastSuccess and not FActive;
    if not FActive then
    begin
      FResultFailures.Clear;
      FLastSuccess := True;
    end;
  finally
    FLock.Release;
  end;
end;

function TDispenserConnectionCoordinator.IsAddressInitializing(
  AAddress: Integer): Boolean;
begin
  if not (AAddress in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE]) then
    Exit(False);
  FLock.Acquire;
  try
    Result := FAddressActive[AAddress];
  finally
    FLock.Release;
  end;
end;

procedure TDispenserConnectionCoordinator.Disconnect;
var
  Address: Integer;
begin
  Enter;
  try
    for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    begin
      FPending[Address] := False;
      FPhases[Address] := ipIdle;
      FStartedAt[Address] := 0;
      FErrors[Address] := '';
      FTargets[Address].Free;
      FTargets[Address] := nil;
    end;
    UpdateActiveInitialization;
    if FController <> nil then
      FController.Disconnect;
    if FRuntimeStates <> nil then
      FRuntimeStates.Reset;
  finally
    Leave;
  end;
end;

end.
