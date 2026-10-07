unit DispenserConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs;

type
  TDispenserOperationSettings = record
    Volume: Integer;
    // Requested liquid flow rate in whole microliters per second.
    Speed: Integer;
    Channel: Integer;
  end;

  TDispenserConfig = class
  public
    Number: Integer;
    Name: string;
    Address: Integer;
    Volume: Integer;
    ChannelCount: Integer;
    StepCount: Integer;
    IntakeChannel: Integer;
    // Maximum requested liquid flow in whole microliters per second.
    MaxFlowRate: Integer;
    Bypass: Boolean;
    Operation: TDispenserOperationSettings;

    constructor Create;
    function Clone: TDispenserConfig;
  end;

  TDispenserConfigList = class(TObjectList)
  private
    function GetItem(Index: Integer): TDispenserConfig;
  public
    constructor Create;
    function AddConfig: TDispenserConfig;
    function Clone: TDispenserConfigList;
    property Items[Index: Integer]: TDispenserConfig read GetItem; default;
  end;

implementation

uses
  DispenserLimits, DispenserResolution;

constructor TDispenserConfig.Create;
begin
  Number := 1;
  Name := 'Дозатор 1';
  Address := 1;
  Volume := 250;
  ChannelCount := 2;
  StepCount := 12000;
  IntakeChannel := 1;
  MaxFlowRate := MaximumVolumeRate(MAX_SPEED, Volume, StepCount);
  Bypass := False;
  Operation.Volume := Volume;
  Operation.Speed := MaxFlowRate;
  Operation.Channel := 1;
end;

function TDispenserConfig.Clone: TDispenserConfig;
begin
  Result := TDispenserConfig.Create;
  Result.Number := Number;
  Result.Name := Name;
  Result.Address := Address;
  Result.Volume := Volume;
  Result.ChannelCount := ChannelCount;
  Result.StepCount := StepCount;
  Result.IntakeChannel := IntakeChannel;
  Result.MaxFlowRate := MaxFlowRate;
  Result.Bypass := Bypass;
  Result.Operation := Operation;
end;

constructor TDispenserConfigList.Create;
begin
  inherited Create(True);
end;

function TDispenserConfigList.GetItem(Index: Integer): TDispenserConfig;
begin
  Result := TDispenserConfig(TObjectList(Self).Items[Index]);
end;

function TDispenserConfigList.AddConfig: TDispenserConfig;
begin
  Result := TDispenserConfig.Create;
  Add(Result);
end;

function TDispenserConfigList.Clone: TDispenserConfigList;
var
  I: Integer;
begin
  Result := TDispenserConfigList.Create;
  for I := 0 to Count - 1 do
    Result.Add(TDispenserConfig(Items[I]).Clone);
end;

end.
