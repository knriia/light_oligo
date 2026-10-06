unit Dilutor;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TValve = (vPosOff, vPosOn, vBypass); // клапан положения 1, 2, bypass

type

  { TPump }

  TPump = class
    fAddress: Integer;
    fLabel: String;
    fValvePosition: TValve;
    fSyringeVolume: Double;
    fVolume: Double;
    fCONSpeed: Double;
    fCOFFSpeed: Double;
    fCurrentSpeed: Double;
  private
    procedure SetCONSpeed(AValue: Double);
    procedure SetValvePosition(AValue: TValve);

  public
    property Valve: TValve read fValvePosition write SetValvePosition;
    property CONSpeed: Double read fCONSpeed write SetCONSpeed;
  end;



implementation

{ TPump }

procedure TPump.SetCONSpeed(AValue: Double);
begin
  if fCONSpeed=AValue then Exit;
  if AValue
  fCONSpeed:=AValue;
end;

procedure TPump.SetValvePosition(AValue: TValve);
begin
  if fValvePosition=AValue then Exit;
  fValvePosition:=AValue;
end;

end.

