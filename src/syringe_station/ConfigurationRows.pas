unit ConfigurationRows;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Contnrs,
  DispenserConfig, DispenserConfigValidator, DispenserLimits, ConfigRow,
  DispenserRuntimeState;

type
  TConfigurationRows = class
  private
    FScrollBox: TScrollBox;
    FRows: TObjectList;
    FOnChanged: TNotifyEvent;
    FConnected: Boolean;
    FRuntimeStates: TDispenserRuntimeStates;
    procedure ClearRows;
    procedure ReorderRows;
    procedure NotifyChanged(Sender: TObject);
    procedure MoveRow(Sender: TObject; Direction: Integer);
    function GetNextFreeNumber: Integer;
    function GetRow(Index: Integer): TConfigRow;
    function GetCount: Integer;
  public
    constructor Create(AScrollBox: TScrollBox; AOnChanged: TNotifyEvent);
    destructor Destroy; override;
    procedure LoadFrom(AConfigurations: TDispenserConfigList);
    procedure SetReadOnly(AReadOnly: Boolean);
    procedure SetRuntimeContext(AConnected: Boolean;
      ARuntimeStates: TDispenserRuntimeStates);
    function AddDispenser(out ErrorText: string): Boolean;
    procedure DeleteRow(Sender: TObject);
    procedure MoveUp(Sender: TObject);
    procedure MoveDown(Sender: TObject);
    function BuildConfigurations(out AConfigurations: TDispenserConfigList;
      out ErrorText: string): Boolean;
    property Count: Integer read GetCount;
  end;

implementation

constructor TConfigurationRows.Create(AScrollBox: TScrollBox;
  AOnChanged: TNotifyEvent);
begin
  inherited Create;
  FScrollBox := AScrollBox;
  FScrollBox.DoubleBuffered := True;
  FRows := TObjectList.Create(True);
  FOnChanged := AOnChanged;
end;

destructor TConfigurationRows.Destroy;
begin
  FRows.Free;
  inherited Destroy;
end;

procedure TConfigurationRows.NotifyChanged(Sender: TObject);
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TConfigurationRows.ClearRows;
begin
  while FRows.Count > 0 do
  begin
    TConfigRow(FRows.Last).Panel.Free;
    FRows.Delete(FRows.Count - 1);
  end;
end;

procedure TConfigurationRows.ReorderRows;
var
  I: Integer;
  Row: TConfigRow;
begin
  for I := 0 to FRows.Count - 1 do
  begin
    Row := GetRow(I);
    Row.Panel.Top := 8 + I * (CONFIG_ROW_HEIGHT + CONFIG_ROW_SPACING);
    Row.Panel.Left := 8;
    Row.Panel.Width := FScrollBox.ClientWidth - 16;
    Row.MoveUpButton.Tag := I;
    Row.MoveDownButton.Tag := I;
    Row.DeleteButton.Tag := I;
    Row.MoveUpButton.Enabled := I > 0;
    Row.MoveDownButton.Enabled := I < FRows.Count - 1;
  end;
end;

function TConfigurationRows.GetNextFreeNumber: Integer;
var
  Candidate: Integer;
  I: Integer;
  CurrentNumber: Integer;
  IsUsed: Boolean;
begin
  Candidate := 1;
  while Candidate <= MAX_DISPENSERS do
  begin
    IsUsed := False;
    for I := 0 to FRows.Count - 1 do
      if TryStrToInt(Trim(GetRow(I).EditNumber.Text), CurrentNumber) and
        (CurrentNumber = Candidate) then
      begin
        IsUsed := True;
        Break;
      end;

    if not IsUsed then
    begin
      Result := Candidate;
      Exit;
    end;

    Inc(Candidate);
  end;

  Result := FRows.Count + 1;
end;

function TConfigurationRows.GetRow(Index: Integer): TConfigRow;
begin
  Result := TConfigRow(FRows[Index]);
end;

function TConfigurationRows.GetCount: Integer;
begin
  Result := FRows.Count;
end;

procedure TConfigurationRows.LoadFrom(AConfigurations: TDispenserConfigList);
var
  I: Integer;
  Row: TConfigRow;
  WasVisible: Boolean;
begin
  WasVisible := FScrollBox.Visible;
  FScrollBox.Visible := False;
  try
    ClearRows;

    if (AConfigurations = nil) or (AConfigurations.Count = 0) then
      Exit;

    for I := 0 to AConfigurations.Count - 1 do
    begin
      Row := TConfigRow.Create(FScrollBox, I, AConfigurations[I], False,
        @DeleteRow, @MoveUp, @MoveDown, @NotifyChanged, FConnected,
        FRuntimeStates);
      FRows.Add(Row);
    end;
    ReorderRows;
  finally
    FScrollBox.Visible := WasVisible;
  end;
end;

procedure TConfigurationRows.SetRuntimeContext(AConnected: Boolean;
  ARuntimeStates: TDispenserRuntimeStates);
begin
  FConnected := AConnected;
  FRuntimeStates := ARuntimeStates;
end;

procedure TConfigurationRows.SetReadOnly(AReadOnly: Boolean);
var
  I: Integer;
begin
  for I := 0 to FRows.Count - 1 do
    GetRow(I).SetReadOnly(AReadOnly);
end;

function TConfigurationRows.AddDispenser(out ErrorText: string): Boolean;
var
  Config: TDispenserConfig;
  Row: TConfigRow;
  WasVisible: Boolean;
begin
  ErrorText := '';
  if FRows.Count >= MAX_DISPENSERS then
  begin
    ErrorText := 'Поддерживается не более 15 дозаторов.';
    Exit(False);
  end;

  WasVisible := FScrollBox.Visible;
  FScrollBox.Visible := False;
  try
    Config := TDispenserConfig.Create;
  try
    Config.Number := GetNextFreeNumber;
    Config.Name := Chr(Ord('A') + Config.Number - 1);
    Config.Address := Config.Number;
    Row := TConfigRow.Create(FScrollBox, FRows.Count, Config, True, @DeleteRow,
      @MoveUp, @MoveDown, @NotifyChanged, FConnected, FRuntimeStates);
    FRows.Add(Row);
  finally
    Config.Free;
  end;

    ReorderRows;
  finally
    FScrollBox.Visible := WasVisible;
  end;
  NotifyChanged(Self);
  Result := True;
end;

procedure TConfigurationRows.MoveRow(Sender: TObject; Direction: Integer);
var
  Index: Integer;
  NewIndex: Integer;
  WasVisible: Boolean;
begin
  if not (Sender is TButton) then
    Exit;

  Index := TButton(Sender).Tag;
  NewIndex := Index + Direction;
  if (Index < 0) or (Index >= FRows.Count) or
    (NewIndex < 0) or (NewIndex >= FRows.Count) then
    Exit;

  WasVisible := FScrollBox.Visible;
  FScrollBox.Visible := False;
  try
    FRows.Exchange(Index, NewIndex);
    ReorderRows;
  finally
    FScrollBox.Visible := WasVisible;
  end;
  NotifyChanged(Self);
end;

procedure TConfigurationRows.MoveUp(Sender: TObject);
begin
  MoveRow(Sender, -1);
end;

procedure TConfigurationRows.MoveDown(Sender: TObject);
begin
  MoveRow(Sender, 1);
end;

procedure TConfigurationRows.DeleteRow(Sender: TObject);
var
  Index: Integer;
  WasVisible: Boolean;
begin
  if not (Sender is TButton) then
    Exit;

  Index := TButton(Sender).Tag;
  if (Index < 0) or (Index >= FRows.Count) then
    Exit;
  if not GetRow(Index).CanDelete then
    Exit;

  WasVisible := FScrollBox.Visible;
  FScrollBox.Visible := False;
  try
    GetRow(Index).Panel.Free;
    FRows.Delete(Index);
    ReorderRows;
  finally
    FScrollBox.Visible := WasVisible;
  end;
  NotifyChanged(Self);
end;

function TConfigurationRows.BuildConfigurations(
  out AConfigurations: TDispenserConfigList; out ErrorText: string): Boolean;
var
  I: Integer;
  Config: TDispenserConfig;
  RowError: string;
begin
  AConfigurations := TDispenserConfigList.Create;
  ErrorText := '';

  for I := 0 to FRows.Count - 1 do
  begin
    Config := AConfigurations.AddConfig;
    if not GetRow(I).ReadInto(Config, RowError) then
    begin
      ErrorText := Format('Дозатор %d: %s', [I + 1, RowError]);
      AConfigurations.Free;
      AConfigurations := nil;
      Exit(False);
    end;
  end;

  if not TDispenserConfigValidator.ValidateList(AConfigurations, ErrorText) then
  begin
    AConfigurations.Free;
    AConfigurations := nil;
    Exit(False);
  end;

  Result := True;
end;

end.
