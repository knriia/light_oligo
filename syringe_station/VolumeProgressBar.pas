unit VolumeProgressBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls;

type
  TVolumeProgressBar = class(TGraphicControl)
  private
    FMax: Integer;
    FPosition: Integer;
    FTargetPosition: Integer;
    FKnown: Boolean;
    FUnitCaption: string;
    FAnimationTimer: TTimer;
    procedure SetMax(AValue: Integer);
    procedure SetPosition(AValue: Integer);
    procedure SetKnown(AValue: Boolean);
    procedure SetUnitCaption(const AValue: string);
    procedure AnimationTick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Max: Integer read FMax write SetMax;
    property Position: Integer read FPosition write SetPosition;
    property Known: Boolean read FKnown write SetKnown;
    property UnitCaption: string read FUnitCaption write SetUnitCaption;
  end;

implementation

constructor TVolumeProgressBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMax := 100;
  FPosition := 0;
  FTargetPosition := 0;
  FKnown := False;
  FUnitCaption := '';
  ControlStyle := ControlStyle + [csOpaque];

  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 15;
  FAnimationTimer.Enabled := False;
  FAnimationTimer.OnTimer := @AnimationTick;
end;

procedure TVolumeProgressBar.SetMax(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FMax = AValue then
    Exit;

  FMax := AValue;
  if FPosition > FMax then
    FPosition := FMax;
  if FTargetPosition > FMax then
    FTargetPosition := FMax;
  Invalidate;
end;

procedure TVolumeProgressBar.SetPosition(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > FMax then
    AValue := FMax;
  FTargetPosition := AValue;
  if FPosition = FTargetPosition then
  begin
    FAnimationTimer.Enabled := False;
    Exit;
  end;

  FAnimationTimer.Enabled := True;
end;

procedure TVolumeProgressBar.SetKnown(AValue: Boolean);
begin
  if FKnown = AValue then
    Exit;

  FKnown := AValue;
  if not FKnown then
  begin
    FPosition := 0;
    FTargetPosition := 0;
    FAnimationTimer.Enabled := False;
  end;
  Invalidate;
end;

procedure TVolumeProgressBar.SetUnitCaption(const AValue: string);
begin
  if FUnitCaption = AValue then
    Exit;

  FUnitCaption := AValue;
  Invalidate;
end;

procedure TVolumeProgressBar.AnimationTick(Sender: TObject);
var
  Step: Integer;
begin
  Step := FMax div 30;
  if Step < 1 then
    Step := 1;

  if FPosition < FTargetPosition then
  begin
    Inc(FPosition, Step);
    if FPosition > FTargetPosition then
      FPosition := FTargetPosition;
  end
  else if FPosition > FTargetPosition then
  begin
    Dec(FPosition, Step);
    if FPosition < FTargetPosition then
      FPosition := FTargetPosition;
  end;

  if FPosition = FTargetPosition then
    FAnimationTimer.Enabled := False;
  Invalidate;
end;

procedure TVolumeProgressBar.Paint;
var
  FillWidth: Integer;
  TextLeft: Integer;
  TextTop: Integer;
  DisplayText: string;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBtnFace;
  Canvas.Pen.Color := clBtnShadow;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);

  if FKnown then
  begin
    FillWidth := Round(ClientWidth * FPosition / FMax);
    if FillWidth > 2 then
    begin
      Canvas.Brush.Color := RGBToColor(76, 175, 80);
      Canvas.Pen.Style := psClear;
      Canvas.Rectangle(1, 1, FillWidth - 1, ClientHeight - 1);
      Canvas.Pen.Style := psSolid;
    end;
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Style := [fsBold];
  if FKnown then
    DisplayText := Format('%d / %d %s', [FPosition, FMax, FUnitCaption])
  else
    DisplayText := 'не инициализирован';
  TextLeft := (ClientWidth - Canvas.TextWidth(DisplayText)) div 2;
  TextTop := (ClientHeight - Canvas.TextHeight(DisplayText)) div 2;

  Canvas.Font.Color := clBlack;
  Canvas.TextOut(TextLeft, TextTop, DisplayText);
end;

end.
