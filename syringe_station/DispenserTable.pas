unit DispenserTable;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, Contnrs,
  DispenserConfig, DispenserView, DispenserLayout,
  DispenserCapacityValidator;

type
  TDispenserTable = class
  private
    FHeader: TPanel;
    FHeaderLabels: array[TDispenserColumn] of TLabel;
    FScrollBox: TScrollBox;
    FLayout: TDispenserTableLayout;
    FEmptyLabel: TLabel;
    FViews: TObjectList;
    FOperationsEnabled: Boolean;
    FOnSelect: TDispenserViewEvent;
    FOnOperationSettingsChanged: TDispenserViewEvent;
    FOnOperationSettingsWarning: TDispenserViewWarningEvent;
    FOnFill: TDispenserViewEvent;
    FOnEmpty: TDispenserViewEvent;
    FOnAspirate: TDispenserViewEvent;
    FOnDispense: TDispenserViewEvent;
    FOnStop: TDispenserViewEvent;
    FOnInitialize: TDispenserViewEvent;
    FOnBypassChanged: TDispenserViewBypassEvent;
    procedure ClearFocusOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ScrollBoxResize(Sender: TObject);
    procedure BuildHeader(AParent: TWinControl);
    procedure ResizeLayout;
    procedure ClearViews;
    procedure UpdateEmptyState;
    function GetView(Index: Integer): TDispenserView;
  public
    constructor Create(AHeaderParent: TWinControl; AScrollBox: TScrollBox;
      AEmptyLabel: TLabel; AOnSelect, AOnFill, AOnEmpty,
      AOnAspirate, AOnDispense, AOnStop,
      AOnInitialize: TDispenserViewEvent;
      AOnBypassChanged: TDispenserViewBypassEvent;
      AOnOperationSettingsChanged: TDispenserViewEvent;
      AOnOperationSettingsWarning: TDispenserViewWarningEvent);
    destructor Destroy; override;
    procedure SetConfigurations(AConfigurations: TDispenserConfigList);
    procedure SetOperationsEnabled(AEnabled: Boolean);
    procedure SetProtocolActive(AActive: Boolean);
    procedure SetOperationEnabled(AAddress: Integer; AEnabled: Boolean);
    procedure SetOperationActive(AAddress: Integer; AActive: Boolean);
    procedure SetCommandPending(AAddress: Integer; APending: Boolean);
    procedure SetProtocolReserved(AAddress: Integer; AReserved: Boolean);
    procedure SetBypassSupported(AAddress: Integer; AEnabled: Boolean);
    procedure SetBypassActive(AAddress: Integer; AEnabled: Boolean);
    procedure SetAllBypassSupported(AEnabled: Boolean);
    procedure ForEachSelected(AHandler: TDispenserViewEvent);
    procedure SaveOperationSettings;
    procedure RefreshCurrentVolumes(AProvider: TDispenserVolumeProvider;
      AKnownProvider: TDispenserVolumeKnownProvider);
    procedure ShowCurrentVolume(AAddress: Integer; AVolume: Double;
      AKnown: Boolean);
    function HasSelectedDispensers: Boolean;
    function SelectedCount: Integer;
    function SelectedNotReadyCount: Integer;
    function SelectedOperableCount: Integer;
    function HasSelectedOperableDispensers: Boolean;
    function IsBypassActive(AAddress: Integer): Boolean;
  end;

implementation

constructor TDispenserTable.Create(AHeaderParent: TWinControl;
  AScrollBox: TScrollBox; AEmptyLabel: TLabel; AOnSelect, AOnFill,
  AOnEmpty, AOnAspirate, AOnDispense, AOnStop,
  AOnInitialize: TDispenserViewEvent;
  AOnBypassChanged: TDispenserViewBypassEvent;
  AOnOperationSettingsChanged: TDispenserViewEvent;
  AOnOperationSettingsWarning: TDispenserViewWarningEvent);
begin
  inherited Create;
  FScrollBox := AScrollBox;
  FScrollBox.DoubleBuffered := True;
  FLayout := BuildDispenserTableLayout(FScrollBox.ClientWidth);
  FScrollBox.TabStop := True;
  FScrollBox.OnMouseDown := @ClearFocusOnMouseDown;
  FScrollBox.OnMouseUp := @ClearFocusOnMouseDown;
  FScrollBox.OnResize := @ScrollBoxResize;
  FEmptyLabel := AEmptyLabel;
  FOnSelect := AOnSelect;
  FOnOperationSettingsChanged := AOnOperationSettingsChanged;
  FOnOperationSettingsWarning := AOnOperationSettingsWarning;
  FOnFill := AOnFill;
  FOnEmpty := AOnEmpty;
  FOnAspirate := AOnAspirate;
  FOnDispense := AOnDispense;
  FOnStop := AOnStop;
  FOnInitialize := AOnInitialize;
  FOnBypassChanged := AOnBypassChanged;
  FViews := TObjectList.Create(True);
  FOperationsEnabled := False;
  BuildHeader(AHeaderParent);
  ResizeLayout;
end;

destructor TDispenserTable.Destroy;
begin
  FViews.Free;
  FHeader.Free;
  inherited Destroy;
end;

procedure TDispenserTable.BuildHeader(AParent: TWinControl);
var
  HeaderLabel: TLabel;
  NextColumn: TDispenserColumn;

  procedure AddHeader(const ACaption: string);
  begin
    HeaderLabel := TLabel.Create(FHeader);
    HeaderLabel.Parent := FHeader;
    HeaderLabel.Left := FLayout.RowLeft + FLayout.Columns[NextColumn].Left;
    HeaderLabel.Top := (HEADER_HEIGHT - 16) div 2;
    HeaderLabel.Width := FLayout.Columns[NextColumn].Width;
    HeaderLabel.Height := 16;
    HeaderLabel.AutoSize := False;
    HeaderLabel.Alignment := taCenter;
    HeaderLabel.Caption := ACaption;
    FHeaderLabels[NextColumn] := HeaderLabel;
    if NextColumn <> High(TDispenserColumn) then
      NextColumn := Succ(NextColumn);
  end;

begin
  NextColumn := Low(TDispenserColumn);
  FHeader := TPanel.Create(AParent);
  FHeader.Parent := AParent;
  FHeader.Align := alTop;
  FHeader.DoubleBuffered := True;
  FHeader.Height := HEADER_HEIGHT;
  FHeader.Caption := '';
  FHeader.TabStop := True;
  FHeader.OnMouseDown := @ClearFocusOnMouseDown;
  FHeader.OnMouseUp := @ClearFocusOnMouseDown;

  AddHeader('№');
  AddHeader('Имя');
  AddHeader('Выбор');
  AddHeader('Наполнить');
  AddHeader('Опустошить');
  AddHeader('Каналы');
  AddHeader('Байпас');
  AddHeader('Набрать');
  AddHeader('Дозировать');
  AddHeader('Объём набора (мкл)');
  AddHeader('Скорость, мкл/с');
  AddHeader('Текущий объём (мкл)');
  AddHeader('Остановить');
  AddHeader('Инициализировать');
end;

procedure TDispenserTable.ScrollBoxResize(Sender: TObject);
begin
  ResizeLayout;
end;

procedure TDispenserTable.ResizeLayout;
var
  Column: TDispenserColumn;
  I: Integer;
begin
  FLayout := BuildDispenserTableLayout(FScrollBox.ClientWidth);
  for Column := Low(TDispenserColumn) to High(TDispenserColumn) do
  begin
    FHeaderLabels[Column].Left := FLayout.RowLeft +
      FLayout.Columns[Column].Left;
    FHeaderLabels[Column].Width := FLayout.Columns[Column].Width;
  end;

  for I := 0 to FViews.Count - 1 do
    GetView(I).SetLayout(FLayout);
end;

procedure TDispenserTable.ClearFocusOnMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TWinControl then
  begin
    TWinControl(Sender).TabStop := True;
    TWinControl(Sender).SetFocus;
  end;
end;

procedure TDispenserTable.ClearViews;
begin
  FViews.Clear;
  UpdateEmptyState;
end;

procedure TDispenserTable.UpdateEmptyState;
begin
  if FEmptyLabel <> nil then
    FEmptyLabel.Visible := FViews.Count = 0;
end;

function TDispenserTable.GetView(Index: Integer): TDispenserView;
begin
  Result := TDispenserView(FViews[Index]);
end;

procedure TDispenserTable.SetConfigurations(
  AConfigurations: TDispenserConfigList);
var
  I: Integer;
  WasVisible: Boolean;
begin
  WasVisible := FScrollBox.Visible;
  FScrollBox.Visible := False;
  try
    ClearViews;
    if AConfigurations = nil then
      Exit;

    for I := 0 to AConfigurations.Count - 1 do
      FViews.Add(TDispenserView.Create(FScrollBox,
        TABLE_TOP + I * ROW_HEIGHT, AConfigurations[I], FLayout,
        FOnSelect, FOnFill, FOnEmpty, FOnAspirate, FOnDispense,
        FOnStop, FOnInitialize, FOnBypassChanged,
        FOnOperationSettingsChanged, FOnOperationSettingsWarning));

    SetOperationsEnabled(FOperationsEnabled);
    UpdateEmptyState;
  finally
    FScrollBox.Visible := WasVisible;
  end;
end;

procedure TDispenserTable.SetOperationsEnabled(AEnabled: Boolean);
var
  I: Integer;
begin
  FOperationsEnabled := AEnabled;
  for I := 0 to FViews.Count - 1 do
    GetView(I).SetOperationsEnabled(AEnabled);
end;

procedure TDispenserTable.SetOperationEnabled(AAddress: Integer;
  AEnabled: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetOperationReady(AEnabled);
      Exit;
    end;
end;

procedure TDispenserTable.SetOperationActive(AAddress: Integer;
  AActive: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetOperationActive(AActive);
      Exit;
    end;
end;

procedure TDispenserTable.SetCommandPending(AAddress: Integer;
  APending: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetCommandPending(APending);
      Exit;
    end;
end;

procedure TDispenserTable.SetProtocolReserved(AAddress: Integer;
  AReserved: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetProtocolReserved(AReserved);
      Exit;
    end;
end;

procedure TDispenserTable.SetBypassSupported(AAddress: Integer;
  AEnabled: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetBypassSupported(AEnabled);
      Exit;
    end;
end;

procedure TDispenserTable.SetBypassActive(AAddress: Integer;
  AEnabled: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).SetBypassActive(AEnabled);
      Exit;
    end;
end;

procedure TDispenserTable.SetAllBypassSupported(AEnabled: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    GetView(I).SetBypassSupported(AEnabled);
end;

procedure TDispenserTable.ForEachSelected(AHandler: TDispenserViewEvent);
var
  I: Integer;
begin
  if not Assigned(AHandler) then
    Exit;

  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected and GetView(I).OperationsEnabled and
      not GetView(I).BypassActive then
      AHandler(GetView(I));
end;

procedure TDispenserTable.SaveOperationSettings;
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    GetView(I).SaveOperationSettings;
end;

procedure TDispenserTable.RefreshCurrentVolumes(
  AProvider: TDispenserVolumeProvider;
  AKnownProvider: TDispenserVolumeKnownProvider);
var
  I: Integer;
  View: TDispenserView;
begin
  if not Assigned(AProvider) then
    Exit;

  for I := 0 to FViews.Count - 1 do
  begin
    View := GetView(I);
    View.ShowCurrentVolume(AProvider(View.Config.Address),
      AKnownProvider(View.Config.Address));
  end;
end;

procedure TDispenserTable.ShowCurrentVolume(AAddress: Integer;
  AVolume: Double; AKnown: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
    begin
      GetView(I).ShowCurrentVolume(AVolume, AKnown);
      Exit;
    end;
end;

function TDispenserTable.HasSelectedOperableDispensers: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected and GetView(I).OperationsEnabled and
      not GetView(I).BypassActive then
      Exit(True);
end;

function TDispenserTable.HasSelectedDispensers: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected then
      Exit(True);
end;

function TDispenserTable.SelectedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected then
      Inc(Result);
end;

function TDispenserTable.SelectedNotReadyCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected and not GetView(I).OperationReady then
      Inc(Result);
end;

function TDispenserTable.SelectedOperableCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Selected and GetView(I).OperationsEnabled and
      not GetView(I).BypassActive then
      Inc(Result);
end;

procedure TDispenserTable.SetProtocolActive(AActive: Boolean);
var
  I: Integer;
begin
  for I := 0 to FViews.Count - 1 do
    GetView(I).SetProtocolActive(AActive);
end;

function TDispenserTable.IsBypassActive(AAddress: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FViews.Count - 1 do
    if GetView(I).Config.Address = AAddress then
      Exit(GetView(I).BypassActive);
end;

end.
