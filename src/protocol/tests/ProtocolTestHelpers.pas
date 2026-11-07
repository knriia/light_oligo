unit ProtocolTestHelpers;

{$mode objfpc}{$H+}

interface

uses
  ProtocolFormat;

function MakeStep(const ANames, AValves, AVolumes, ASpeeds: string): TSyringeStep;
function StepError(const AStep: TSyringeStep): string;

implementation

function MakeStep(const ANames, AValves, AVolumes, ASpeeds: string): TSyringeStep;
begin
  Result.Dispensers := ANames;
  Result.Valves := AValves;
  Result.Volumes := AVolumes;
  Result.VolumeUnit := 'мкл';
  Result.Speeds := ASpeeds;
  Result.SpeedUnit := 'мкл/с';
end;

function StepError(const AStep: TSyringeStep): string;
begin
  if CheckSyringeStep(AStep, Result) then
    Result := '';
end;

end.
