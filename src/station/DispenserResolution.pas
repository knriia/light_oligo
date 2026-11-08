unit DispenserResolution;

{$mode objfpc}{$H+}

interface

const
  N1_STEP_MULTIPLIER = 8;

function EffectiveN1StepCount(AStepCount: Integer): Int64;
function N1StepsForMicroliters(AMicroliters: Double; ASyringeVolume,
  AStepCount: Integer; out ASteps: Int64): Boolean;
function MicrolitersForN1Steps(ASteps: Int64; ASyringeVolume,
  AStepCount: Integer): Double;
function MinimumVolumeRate(ASyringeVolume, AStepCount: Integer): Integer;
function MaximumVolumeRate(AMaxMotorSpeed, ASyringeVolume,
  AStepCount: Integer): Integer;
function ClampVolumeRateToMaximum(AVolumeRate,
  AMaximumVolumeRate: Integer): Integer;
function ConvertVolumeRateToMotorSpeed(AVolumeRate, AMaxMotorSpeed,
  ASyringeVolume, AStepCount: Integer; out AMotorSpeed: Integer): Boolean;
function ConvertMotorSpeedToVolumeRate(AMotorSpeed, ASyringeVolume,
  AStepCount: Integer): Integer;

implementation

function N1StepsForMicroliters(AMicroliters: Double; ASyringeVolume,
  AStepCount: Integer; out ASteps: Int64): Boolean;
var
  StepCount: Int64;
  CalculatedSteps: Extended;
begin
  ASteps := 0;
  Result := False;
  if (ASyringeVolume <= 0) or (AStepCount <= 0) or
    (AMicroliters < 0) or (AMicroliters <> AMicroliters) then
    Exit;

  StepCount := EffectiveN1StepCount(AStepCount);
  if StepCount <= 0 then
    Exit;

  CalculatedSteps := Extended(AMicroliters) * StepCount / ASyringeVolume;
  if (CalculatedSteps < 0) or (CalculatedSteps > High(Int64) - 1) then
    Exit;

  ASteps := Round(CalculatedSteps);
  Result := True;
end;

function MicrolitersForN1Steps(ASteps: Int64; ASyringeVolume,
  AStepCount: Integer): Double;
var
  StepCount: Int64;
begin
  Result := 0.0;
  if (ASyringeVolume <= 0) or (AStepCount <= 0) then
    Exit;

  StepCount := EffectiveN1StepCount(AStepCount);
  if StepCount <= 0 then
    Exit;

  Result := Double(ASteps) * ASyringeVolume / StepCount;
end;

function EffectiveN1StepCount(AStepCount: Integer): Int64;
begin
  if AStepCount <= 0 then
    Exit(0);
  Result := Int64(AStepCount) * N1_STEP_MULTIPLIER;
end;

function MinimumVolumeRate(ASyringeVolume, AStepCount: Integer): Integer;
var
  StepCount: Int64;
  Denominator: Int64;
  MinimumRate: Int64;
begin
  Result := 0;
  StepCount := AStepCount;
  if (ASyringeVolume <= 0) or (StepCount <= 0) then
    Exit;

  Denominator := StepCount * 2;
  MinimumRate := (Int64(ASyringeVolume) + Denominator - 1) div Denominator;
  if MinimumRate < 1 then
    MinimumRate := 1;
  if MinimumRate > High(Integer) then
    Exit;
  Result := Integer(MinimumRate);
end;

function MaximumVolumeRate(AMaxMotorSpeed, ASyringeVolume,
  AStepCount: Integer): Integer;
var
  MaximumRate: Int64;
begin
  Result := 0;
  if (AMaxMotorSpeed <= 0) or (ASyringeVolume <= 0) or
    (AStepCount <= 0) then
    Exit;

  MaximumRate := (Int64(AMaxMotorSpeed) * ASyringeVolume) div
    AStepCount;
  if MaximumRate > High(Integer) then
    MaximumRate := High(Integer);
  Result := Integer(MaximumRate);
end;

function ClampVolumeRateToMaximum(AVolumeRate,
  AMaximumVolumeRate: Integer): Integer;
begin
  Result := AVolumeRate;
  if (AMaximumVolumeRate > 0) and (Result > AMaximumVolumeRate) then
    Result := AMaximumVolumeRate;
end;

function ConvertVolumeRateToMotorSpeed(AVolumeRate, AMaxMotorSpeed,
  ASyringeVolume, AStepCount: Integer; out AMotorSpeed: Integer): Boolean;
var
  StepCount: Int64;
  Numerator: Int64;
  MinimumRate: Integer;
  MaximumRate: Integer;
begin
  AMotorSpeed := 0;
  Result := False;
  if (AVolumeRate <= 0) or (AMaxMotorSpeed <= 0) or
    (ASyringeVolume <= 0) or (AStepCount <= 0) then
    Exit;
  StepCount := AStepCount;

  MinimumRate := MinimumVolumeRate(ASyringeVolume, AStepCount);
  MaximumRate := MaximumVolumeRate(AMaxMotorSpeed, ASyringeVolume,
    AStepCount);
  if (MaximumRate < MinimumRate) or (AVolumeRate < MinimumRate) or
    (AVolumeRate > MaximumRate) then
    Exit;

  if Int64(AVolumeRate) > High(Int64) div StepCount then
    Exit;

  Numerator := Int64(AVolumeRate) * StepCount;
  AMotorSpeed := Integer((Numerator + ASyringeVolume div 2) div
    ASyringeVolume);
  if AMotorSpeed < 1 then
    AMotorSpeed := 1;
  Result := AMotorSpeed <= AMaxMotorSpeed;
  if not Result then
    AMotorSpeed := 0;
end;

function ConvertMotorSpeedToVolumeRate(AMotorSpeed, ASyringeVolume,
  AStepCount: Integer): Integer;
var
  VolumeRate: Int64;
begin
  Result := 0;
  if (AMotorSpeed <= 0) or (ASyringeVolume <= 0) or
    (AStepCount <= 0) then
    Exit;

  VolumeRate := (Int64(AMotorSpeed) * ASyringeVolume) div
    AStepCount;
  if VolumeRate > High(Integer) then
    VolumeRate := High(Integer);
  Result := Integer(VolumeRate);
end;

end.
