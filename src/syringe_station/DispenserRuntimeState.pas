unit DispenserRuntimeState;

{$mode objfpc}{$H+}

interface

uses
  SyncObjs, DispenserLimits, DispenserTypes, DispenserConfig,
  DispenserResolution;

type
  TDispenserLifecycleState = (dlsUninitialized, dlsReady, dlsOperating,
    dlsPositionUnknown);

  TDispenserRuntimeState = class
  private
    FCurrentPositionSteps: Int64;
    FUncalibratedCurrentVolume: Double;
    FCurrentVolumeKnown: Boolean;
    FInitializationRequired: Boolean;
    FInitializationError: string;
    FInitializedConfiguration: TDispenserConfig;
    FValveType: TDispenserValveType;
    FOperationActive: Boolean;
    FOperationOwner: TDispenserOperationOwner;
    FOperationKind: TDispenserOperationKind;
    FOperationName: string;
    FOperationVolume: Integer;
    FOperationStartingVolume: Double;
    FOperationStepCount: Int64;
    FOperationStartingPositionSteps: Int64;
    FCommandPending: Boolean;
    FProtocolReserved: Boolean;
    FStateLock: TCriticalSection;
    function GetCurrentVolume: Double;
    procedure SetCurrentVolume(AValue: Double);
    procedure AssignCurrentVolume(AValue: Double; AMarkKnown: Boolean);
    function GetCurrentPositionSteps: Int64;
    procedure SetCurrentPositionSteps(AValue: Int64);
    function GetCurrentVolumeKnown: Boolean;
    function GetValveType: TDispenserValveType;
    procedure SetValveType(AValue: TDispenserValveType);
    function GetOperationActive: Boolean;
    function GetOperationOwner: TDispenserOperationOwner;
    function GetOperationKind: TDispenserOperationKind;
    function GetOperationName: string;
    function GetOperationVolume: Integer;
    function GetOperationStartingVolume: Double;
    function GetOperationStepCount: Int64;
    function GetOperationStartingPositionSteps: Int64;
    function GetCommandPending: Boolean;
    procedure SetCommandPending(AValue: Boolean);
    function GetProtocolReserved: Boolean;
    procedure SetProtocolReserved(AValue: Boolean);
    function GetInitializationRequired: Boolean;
    function GetInitializationError: string;
    function GetLifecycleState: TDispenserLifecycleState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure RequireInitialization;
    procedure MarkInitialized(AConfig: TDispenserConfig);
    procedure MarkInitializationFailed(const AErrorText: string);
    procedure MarkPositionUnknown(const AErrorText: string);
    procedure CancelOperation(const AErrorText: string);
    procedure ClearOperation;
    function UpdatePositionFromEncoder(ASteps: Int64;
      out AErrorText: string): Boolean;
    function TryBeginOperation(AOwner: TDispenserOperationOwner;
      AKind: TDispenserOperationKind; const AName: string;
      AVolume: Integer; AStepCount, AExpectedStartingPositionSteps: Int64;
      out AErrorText: string): Boolean;
    function CompleteOperation(out AErrorText: string): Boolean;
    function CompleteOperationFromEncoder(ASteps: Int64;
      out AErrorText: string): Boolean;
    function IsInitializedFor(AConfig: TDispenserConfig): Boolean;

    property CurrentVolume: Double read GetCurrentVolume write SetCurrentVolume;
    property CurrentPositionSteps: Int64 read GetCurrentPositionSteps
      write SetCurrentPositionSteps;
    property CurrentVolumeKnown: Boolean read GetCurrentVolumeKnown;
    property InitializationRequired: Boolean read GetInitializationRequired;
    property InitializationError: string read GetInitializationError;
    property LifecycleState: TDispenserLifecycleState read GetLifecycleState;
    property ValveType: TDispenserValveType read GetValveType write SetValveType;
    property OperationActive: Boolean read GetOperationActive;
    property OperationOwner: TDispenserOperationOwner read GetOperationOwner;
    property OperationKind: TDispenserOperationKind read GetOperationKind;
    property OperationName: string read GetOperationName;
    property OperationVolume: Integer read GetOperationVolume;
    property OperationStartingVolume: Double read GetOperationStartingVolume;
    property OperationStepCount: Int64 read GetOperationStepCount;
    property OperationStartingPositionSteps: Int64
      read GetOperationStartingPositionSteps;
    property CommandPending: Boolean read GetCommandPending
      write SetCommandPending;
    property ProtocolReserved: Boolean read GetProtocolReserved
      write SetProtocolReserved;
  end;

  TDispenserRuntimeStates = class
  private
    FItems: array[MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] of
      TDispenserRuntimeState;
    function GetItem(Address: Integer): TDispenserRuntimeState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    function GetCurrentVolume(Address: Integer): Double;
    function GetCurrentPositionSteps(Address: Integer): Int64;
    function IsCurrentVolumeKnown(Address: Integer): Boolean;
    procedure SetCurrentVolume(Address: Integer; AVolume: Double);
    procedure SetCurrentPositionSteps(Address: Integer; ASteps: Int64);
    procedure MarkCurrentVolumeUnknown(Address: Integer);

    property Items[Address: Integer]: TDispenserRuntimeState read GetItem;
  end;

implementation

constructor TDispenserRuntimeState.Create;
begin
  inherited Create;
  FStateLock := TCriticalSection.Create;
  Reset;
end;

destructor TDispenserRuntimeState.Destroy;
begin
  FStateLock.Free;
  FInitializedConfiguration.Free;
  inherited Destroy;
end;

procedure TDispenserRuntimeState.Reset;
begin
  FStateLock.Acquire;
  try
  FInitializedConfiguration.Free;
  FInitializedConfiguration := nil;
  FCurrentPositionSteps := 0;
  FUncalibratedCurrentVolume := 0.0;
  FCurrentVolumeKnown := False;
  FInitializationRequired := True;
  FInitializationError := '';
  FValveType := dvtUnknown;
  FOperationActive := False;
  FOperationOwner := dooNone;
  FOperationKind := dokFill;
  FOperationName := '';
  FOperationVolume := 0;
  FOperationStartingVolume := 0.0;
  FOperationStepCount := 0;
  FOperationStartingPositionSteps := 0;
  FCommandPending := False;
  FProtocolReserved := False;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.RequireInitialization;
begin
  FStateLock.Acquire;
  try
  FInitializationRequired := True;
  FInitializationError := '';
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.MarkInitialized(AConfig: TDispenserConfig);
begin
  FStateLock.Acquire;
  try
  FInitializedConfiguration.Free;
  if AConfig = nil then
    FInitializedConfiguration := nil
  else
    FInitializedConfiguration := AConfig.Clone;
  FInitializationRequired := False;
  FInitializationError := '';
  FCurrentPositionSteps := 0;
  FUncalibratedCurrentVolume := 0.0;
  FCurrentVolumeKnown := True;
  FOperationActive := False;
  FOperationOwner := dooNone;
  FOperationStepCount := 0;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.IsInitializedFor(
  AConfig: TDispenserConfig): Boolean;
begin
  FStateLock.Acquire;
  try
  Result := not FInitializationRequired and FCurrentVolumeKnown and
    (FInitializedConfiguration <> nil) and (AConfig <> nil) and
    (FInitializedConfiguration.Number = AConfig.Number) and
    (FInitializedConfiguration.Name = AConfig.Name) and
    (FInitializedConfiguration.Address = AConfig.Address) and
    (FInitializedConfiguration.Volume = AConfig.Volume) and
    (FInitializedConfiguration.ChannelCount = AConfig.ChannelCount) and
    (FInitializedConfiguration.StepCount = AConfig.StepCount) and
    (FInitializedConfiguration.IntakeChannel = AConfig.IntakeChannel) and
    (FInitializedConfiguration.MaxFlowRate = AConfig.MaxFlowRate);
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.MarkInitializationFailed(
  const AErrorText: string);
begin
  FStateLock.Acquire;
  try
    FInitializationRequired := True;
    FInitializationError := AErrorText;
    FCurrentVolumeKnown := False;
    FOperationActive := False;
    FOperationOwner := dooNone;
    FOperationStepCount := 0;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.MarkPositionUnknown(
  const AErrorText: string);
begin
  FStateLock.Acquire;
  try
    FInitializationRequired := True;
    FInitializationError := AErrorText;
    FCurrentVolumeKnown := False;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.CancelOperation(
  const AErrorText: string);
begin
  FStateLock.Acquire;
  try
    FInitializationRequired := True;
    FInitializationError := AErrorText;
    FCurrentVolumeKnown := False;
    FOperationActive := False;
    FOperationOwner := dooNone;
    FOperationStepCount := 0;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.ClearOperation;
begin
  FStateLock.Acquire;
  try
    FOperationActive := False;
    FOperationOwner := dooNone;
    FOperationStepCount := 0;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.UpdatePositionFromEncoder(ASteps: Int64;
  out AErrorText: string): Boolean;
var
  MaximumPositionSteps: Int64;
begin
  Result := False;
  AErrorText := '';
  FStateLock.Acquire;
  try
    if (FInitializedConfiguration = nil) or FInitializationRequired or
      not FCurrentVolumeKnown then
      AErrorText := 'Положение плунжера нельзя обновить до инициализации.'
    else
    begin
      MaximumPositionSteps := EffectiveN1StepCount(
        FInitializedConfiguration.StepCount);
      if (MaximumPositionSteps <= 0) or (ASteps < 0) or
        (ASteps > MaximumPositionSteps) then
        AErrorText := 'Положение энкодера выходит за калибровку шприца.'
      else
      begin
        FCurrentPositionSteps := ASteps;
        Result := True;
      end;
    end;

    if not Result then
    begin
      FInitializationRequired := True;
      FCurrentVolumeKnown := False;
      FInitializationError := AErrorText;
    end;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.TryBeginOperation(
  AOwner: TDispenserOperationOwner; AKind: TDispenserOperationKind;
  const AName: string; AVolume: Integer; AStepCount,
  AExpectedStartingPositionSteps: Int64; out AErrorText: string): Boolean;
var
  MaximumPositionSteps: Int64;
begin
  Result := False;
  AErrorText := '';
  FStateLock.Acquire;
  try
    if FOperationActive then
      AErrorText := 'Дозатор уже выполняет операцию.'
    else if (FInitializedConfiguration = nil) or FInitializationRequired or
      not FCurrentVolumeKnown then
      AErrorText := 'Положение плунжера неизвестно; требуется инициализация.'
    else if AOwner = dooNone then
      AErrorText := 'Не задан владелец операции.'
    else if (AVolume < 0) or (AStepCount <= 0) then
      AErrorText := 'Объём и количество шагов операции должны быть допустимыми.'
    else if FCurrentPositionSteps <> AExpectedStartingPositionSteps then
      AErrorText := 'Положение плунжера изменилось до запуска операции.'
    else
    begin
      MaximumPositionSteps := EffectiveN1StepCount(
        FInitializedConfiguration.StepCount);
      if (MaximumPositionSteps <= 0) or
        (FCurrentPositionSteps < 0) or
        (FCurrentPositionSteps > MaximumPositionSteps) then
        AErrorText := 'Текущее положение плунжера вне калибровки.'
      else if (AKind in [dokFill, dokAspirate]) and
        (AStepCount > MaximumPositionSteps - FCurrentPositionSteps) then
        AErrorText := 'Операция выведет плунжер за пределы шприца.'
      else if (AKind in [dokEmpty, dokDispense]) and
        (AStepCount > FCurrentPositionSteps) then
        AErrorText := 'Недостаточно жидкости для выполнения операции.'
      else
      begin
        FOperationActive := True;
        FOperationOwner := AOwner;
        FOperationKind := AKind;
        FOperationName := AName;
        FOperationVolume := AVolume;
        FOperationStepCount := AStepCount;
        FOperationStartingPositionSteps := FCurrentPositionSteps;
        FOperationStartingVolume := MicrolitersForN1Steps(
          FCurrentPositionSteps, FInitializedConfiguration.Volume,
          FInitializedConfiguration.StepCount);
        Result := True;
      end;
    end;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.CompleteOperation(
  out AErrorText: string): Boolean;
var
  MaximumPositionSteps: Int64;
  NewPositionSteps: Int64;
begin
  Result := False;
  AErrorText := '';
  FStateLock.Acquire;
  try
    if not FOperationActive then
      AErrorText := 'Нет активной операции для завершения.'
    else
    begin
      if (FInitializedConfiguration = nil) or FInitializationRequired or
        not FCurrentVolumeKnown then
        AErrorText := 'Положение плунжера неизвестно после операции.'
      else
      begin
        MaximumPositionSteps := EffectiveN1StepCount(
          FInitializedConfiguration.StepCount);
        if FOperationKind in [dokFill, dokAspirate] then
        begin
          if (FOperationStartingPositionSteps < 0) or
            (FOperationStartingPositionSteps > MaximumPositionSteps) or
            (FOperationStepCount > MaximumPositionSteps -
            FOperationStartingPositionSteps) then
            AErrorText := 'Завершение операции выходит за пределы шприца.'
          else
            NewPositionSteps := FOperationStartingPositionSteps +
              FOperationStepCount;
        end
        else if (FOperationStartingPositionSteps < 0) or
          (FOperationStartingPositionSteps > MaximumPositionSteps) or
          (FOperationStepCount > FOperationStartingPositionSteps) then
          AErrorText := 'Завершение операции задаёт отрицательное положение.'
        else
          NewPositionSteps := FOperationStartingPositionSteps -
            FOperationStepCount;

        if AErrorText = '' then
        begin
          FCurrentPositionSteps := NewPositionSteps;
          FCurrentVolumeKnown := True;
          Result := True;
        end
        else
        begin
          FInitializationRequired := True;
          FCurrentVolumeKnown := False;
          FInitializationError := AErrorText;
        end;
      end;

      if not Result then
      begin
        FInitializationRequired := True;
        FCurrentVolumeKnown := False;
        FInitializationError := AErrorText;
      end;
      FOperationActive := False;
      FOperationOwner := dooNone;
      FOperationStepCount := 0;
    end;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.CompleteOperationFromEncoder(ASteps: Int64;
  out AErrorText: string): Boolean;
var
  MaximumPositionSteps: Int64;
begin
  Result := False;
  AErrorText := '';
  FStateLock.Acquire;
  try
    if not FOperationActive then
      AErrorText := 'Нет активной операции для завершения.'
    else if (FInitializedConfiguration = nil) or FInitializationRequired or
      not FCurrentVolumeKnown then
      AErrorText := 'Положение плунжера неизвестно после операции.'
    else
    begin
      MaximumPositionSteps := EffectiveN1StepCount(
        FInitializedConfiguration.StepCount);
      if (MaximumPositionSteps <= 0) or (ASteps < 0) or
        (ASteps > MaximumPositionSteps) then
        AErrorText := 'Положение энкодера выходит за калибровку шприца.'
      else
      begin
        FCurrentPositionSteps := ASteps;
        Result := True;
      end;
    end;

    if not Result then
    begin
      FInitializationRequired := True;
      FCurrentVolumeKnown := False;
      FInitializationError := AErrorText;
    end;
    FOperationActive := False;
    FOperationOwner := dooNone;
    FOperationStepCount := 0;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.GetCurrentVolume: Double;
begin
  FStateLock.Acquire;
  try
    if FInitializedConfiguration <> nil then
      Result := MicrolitersForN1Steps(FCurrentPositionSteps,
        FInitializedConfiguration.Volume, FInitializedConfiguration.StepCount)
    else
      Result := FUncalibratedCurrentVolume;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.SetCurrentVolume(AValue: Double);
begin
  AssignCurrentVolume(AValue, False);
end;

procedure TDispenserRuntimeState.AssignCurrentVolume(AValue: Double;
  AMarkKnown: Boolean);
var
  PositionSteps: Int64;
  IsValid: Boolean;
begin
  if AValue < 0 then
    AValue := 0;
  FStateLock.Acquire;
  try
    IsValid := True;
    if AValue <> AValue then
    begin
      IsValid := False;
      FCurrentVolumeKnown := False;
      FInitializationRequired := True;
      FInitializationError := 'Объём не является числом.';
    end
    else if FInitializedConfiguration = nil then
      FUncalibratedCurrentVolume := AValue
    else if N1StepsForMicroliters(AValue, FInitializedConfiguration.Volume,
      FInitializedConfiguration.StepCount, PositionSteps) and
      (PositionSteps <= EffectiveN1StepCount(
      FInitializedConfiguration.StepCount)) then
      FCurrentPositionSteps := PositionSteps
    else
    begin
      IsValid := False;
      FCurrentVolumeKnown := False;
      FInitializationRequired := True;
      FInitializationError := 'Объём не представим в пределах калибровки шприца.';
    end;
    if AMarkKnown and IsValid then
      FCurrentVolumeKnown := True;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.GetCurrentPositionSteps: Int64;
begin
  FStateLock.Acquire;
  try
    Result := FCurrentPositionSteps;
  finally
    FStateLock.Release;
  end;
end;

procedure TDispenserRuntimeState.SetCurrentPositionSteps(AValue: Int64);
var
  MaximumPositionSteps: Int64;
begin
  FStateLock.Acquire;
  try
    MaximumPositionSteps := 0;
    if FInitializedConfiguration <> nil then
      MaximumPositionSteps := EffectiveN1StepCount(
        FInitializedConfiguration.StepCount);

    if (AValue < 0) or ((FInitializedConfiguration <> nil) and
      ((MaximumPositionSteps <= 0) or (AValue > MaximumPositionSteps))) then
    begin
      FCurrentVolumeKnown := False;
      FInitializationRequired := True;
      FInitializationError := 'Положение плунжера выходит за калибровку шприца.';
      Exit;
    end;

    FCurrentPositionSteps := AValue;
  finally
    FStateLock.Release;
  end;
end;

function TDispenserRuntimeState.GetCurrentVolumeKnown: Boolean;
begin
  FStateLock.Acquire;
  try Result := FCurrentVolumeKnown; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetValveType: TDispenserValveType;
begin
  FStateLock.Acquire;
  try Result := FValveType; finally FStateLock.Release; end;
end;

procedure TDispenserRuntimeState.SetValveType(AValue: TDispenserValveType);
begin
  FStateLock.Acquire;
  try FValveType := AValue; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationActive: Boolean;
begin
  FStateLock.Acquire;
  try Result := FOperationActive; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationOwner: TDispenserOperationOwner;
begin
  FStateLock.Acquire;
  try Result := FOperationOwner; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationKind: TDispenserOperationKind;
begin
  FStateLock.Acquire;
  try Result := FOperationKind; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationName: string;
begin
  FStateLock.Acquire;
  try Result := FOperationName; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationVolume: Integer;
begin
  FStateLock.Acquire;
  try Result := FOperationVolume; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationStartingVolume: Double;
begin
  FStateLock.Acquire;
  try Result := FOperationStartingVolume; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationStepCount: Int64;
begin
  FStateLock.Acquire;
  try Result := FOperationStepCount; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetOperationStartingPositionSteps: Int64;
begin
  FStateLock.Acquire;
  try Result := FOperationStartingPositionSteps; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetCommandPending: Boolean;
begin
  FStateLock.Acquire;
  try Result := FCommandPending; finally FStateLock.Release; end;
end;

procedure TDispenserRuntimeState.SetCommandPending(AValue: Boolean);
begin
  FStateLock.Acquire;
  try FCommandPending := AValue; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetProtocolReserved: Boolean;
begin
  FStateLock.Acquire;
  try Result := FProtocolReserved; finally FStateLock.Release; end;
end;

procedure TDispenserRuntimeState.SetProtocolReserved(AValue: Boolean);
begin
  FStateLock.Acquire;
  try FProtocolReserved := AValue; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetInitializationRequired: Boolean;
begin
  FStateLock.Acquire;
  try Result := FInitializationRequired; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetInitializationError: string;
begin
  FStateLock.Acquire;
  try Result := FInitializationError; finally FStateLock.Release; end;
end;

function TDispenserRuntimeState.GetLifecycleState:
  TDispenserLifecycleState;
begin
  FStateLock.Acquire;
  try
    if FInitializedConfiguration = nil then
      Result := dlsUninitialized
    else if not FCurrentVolumeKnown then
      Result := dlsPositionUnknown
    else if FInitializationRequired then
      Result := dlsUninitialized
    else if FOperationActive then
      Result := dlsOperating
    else
      Result := dlsReady;
  finally
    FStateLock.Release;
  end;
end;

constructor TDispenserRuntimeStates.Create;
var
  Address: Integer;
begin
  inherited Create;
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    FItems[Address] := TDispenserRuntimeState.Create;
end;

destructor TDispenserRuntimeStates.Destroy;
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    FItems[Address].Free;
  inherited Destroy;
end;

procedure TDispenserRuntimeStates.Reset;
var
  Address: Integer;
begin
  for Address := MIN_DISPENSER_VALUE to MAX_DISPENSER_VALUE do
    FItems[Address].Reset;
end;

function TDispenserRuntimeStates.GetItem(
  Address: Integer): TDispenserRuntimeState;
begin
  if Address in [MIN_DISPENSER_VALUE..MAX_DISPENSER_VALUE] then
    Result := FItems[Address]
  else
    Result := nil;
end;

function TDispenserRuntimeStates.GetCurrentVolume(Address: Integer): Double;
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  if State <> nil then
    Result := State.CurrentVolume
  else
    Result := 0.0;
end;

function TDispenserRuntimeStates.GetCurrentPositionSteps(
  Address: Integer): Int64;
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  if State <> nil then
    Result := State.CurrentPositionSteps
  else
    Result := 0;
end;

function TDispenserRuntimeStates.IsCurrentVolumeKnown(
  Address: Integer): Boolean;
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  Result := (State <> nil) and State.CurrentVolumeKnown;
end;

procedure TDispenserRuntimeStates.SetCurrentVolume(Address: Integer;
  AVolume: Double);
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  if State = nil then
    Exit;

  State.AssignCurrentVolume(AVolume, True);
end;

procedure TDispenserRuntimeStates.SetCurrentPositionSteps(Address: Integer;
  ASteps: Int64);
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  if State = nil then
    Exit;

  State.CurrentPositionSteps := ASteps;
end;

procedure TDispenserRuntimeStates.MarkCurrentVolumeUnknown(Address: Integer);
var
  State: TDispenserRuntimeState;
begin
  State := GetItem(Address);
  if State <> nil then
    State.MarkPositionUnknown('Положение плунжера неизвестно.');
end;

end.
