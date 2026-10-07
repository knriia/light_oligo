unit ConfigurationForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  ComCtrls, Spin, DispenserConfig, ConfigurationRows,
  WindowSettingsStorage, DispenserRuntimeState;

type
  TConfigurationApplyEvent = function(AConfigurations:
    TDispenserConfigList; out ErrorText: string): Boolean of object;

  { TConfigurationForm }

  TConfigurationForm = class(TForm)
    btnAddDispenser: TButton;
    btnCancel: TButton;
    btnGenerate: TButton;
    ScrollBoxRows: TScrollBox;
    ButtonsPanel: TPanel;

    procedure btnAddDispenserClick(Sender: TObject);
    procedure btnDeleteRowClick(Sender: TObject);
    procedure btnMoveUpClick(Sender: TObject);
    procedure btnMoveDownClick(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

  private
    FRows: TConfigurationRows;
    FInitialConfigurations: TDispenserConfigList;
    FWindowSettings: TWindowSettingsStorage;
    FReadOnly: Boolean;
    FHasAnyEdits: Boolean;
    FOnApply: TConfigurationApplyEvent;

    procedure ClearFocusOnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RowsChanged(Sender: TObject);
    procedure UpdateApplyButton;
    procedure LoadWindowSettings;
    procedure SaveWindowSettings;
    function BuildConfigurations(out AConfigurations: TDispenserConfigList;
      out ErrorText: string): Boolean;
    function SameConfigurations(ALeft, ARight: TDispenserConfigList): Boolean;

  public
    procedure LoadFrom(AConfigurations: TDispenserConfigList);
    procedure SetReadOnly(AReadOnly: Boolean);
    procedure SetRuntimeContext(AConnected: Boolean;
      ARuntimeStates: TDispenserRuntimeStates;
      AOnApply: TConfigurationApplyEvent);
  end;

implementation

{$R *.lfm}

{ TConfigurationForm }

procedure TConfigurationForm.FormCreate(Sender: TObject);
begin
  FRows := TConfigurationRows.Create(ScrollBoxRows, @RowsChanged);
  FWindowSettings := TWindowSettingsStorage.Create;
  FInitialConfigurations := nil;
  ScrollBoxRows.TabStop := True;
  ButtonsPanel.TabStop := True;
  ScrollBoxRows.OnMouseDown := @ClearFocusOnMouseDown;
  ScrollBoxRows.OnMouseUp := @ClearFocusOnMouseDown;
  ButtonsPanel.OnMouseDown := @ClearFocusOnMouseDown;
  ButtonsPanel.OnMouseUp := @ClearFocusOnMouseDown;
  FReadOnly := False;
  FHasAnyEdits := False;
  btnGenerate.Enabled := False;
  Constraints.MinWidth := 620;
  Constraints.MinHeight := 520;
  LoadWindowSettings;
end;

procedure TConfigurationForm.ClearFocusOnMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TWinControl then
  begin
    TWinControl(Sender).TabStop := True;
    TWinControl(Sender).SetFocus;
  end;
end;

procedure TConfigurationForm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  SaveWindowSettings;
end;

procedure TConfigurationForm.FormDestroy(Sender: TObject);
begin
  FInitialConfigurations.Free;
  FWindowSettings.Free;
  FRows.Free;
end;

procedure TConfigurationForm.LoadWindowSettings;
var
  SavedWidth: Integer;
  SavedHeight: Integer;
begin
  FWindowSettings.Load(Width, Height, SavedWidth, SavedHeight);

  if SavedWidth < Constraints.MinWidth then
    SavedWidth := Constraints.MinWidth;
  if SavedHeight < Constraints.MinHeight then
    SavedHeight := Constraints.MinHeight;

  Width := SavedWidth;
  Height := SavedHeight;
end;

procedure TConfigurationForm.SaveWindowSettings;
begin
  FWindowSettings.Save(Width, Height);
end;

procedure TConfigurationForm.LoadFrom(AConfigurations: TDispenserConfigList);
begin
  FRows.LoadFrom(AConfigurations);
  FInitialConfigurations.Free;
  if AConfigurations <> nil then
    FInitialConfigurations := AConfigurations.Clone
  else
    FInitialConfigurations := TDispenserConfigList.Create;
  FHasAnyEdits := False;
  UpdateApplyButton;
end;

procedure TConfigurationForm.SetRuntimeContext(AConnected: Boolean;
  ARuntimeStates: TDispenserRuntimeStates;
  AOnApply: TConfigurationApplyEvent);
begin
  FOnApply := AOnApply;
  FRows.SetRuntimeContext(AConnected, ARuntimeStates);
  UpdateApplyButton;
end;

procedure TConfigurationForm.SetReadOnly(AReadOnly: Boolean);
begin
  FReadOnly := AReadOnly;
  FRows.SetReadOnly(AReadOnly);
  btnAddDispenser.Enabled := not AReadOnly;
  UpdateApplyButton;
  if AReadOnly then
    Caption := Caption + ' (только просмотр)';
end;

procedure TConfigurationForm.RowsChanged(Sender: TObject);
begin
  FHasAnyEdits := True;
  UpdateApplyButton;
end;

function TConfigurationForm.SameConfigurations(ALeft,
  ARight: TDispenserConfigList): Boolean;
var
  I: Integer;
  LeftConfig: TDispenserConfig;
  RightConfig: TDispenserConfig;
begin
  if (ALeft = nil) or (ARight = nil) then
    Exit(ALeft = ARight);
  if ALeft.Count <> ARight.Count then
    Exit(False);

  for I := 0 to ALeft.Count - 1 do
  begin
    LeftConfig := ALeft[I];
    RightConfig := ARight[I];
    if (LeftConfig.Number <> RightConfig.Number) or
      (LeftConfig.Name <> RightConfig.Name) or
      (LeftConfig.Address <> RightConfig.Address) or
      (LeftConfig.Volume <> RightConfig.Volume) or
      (LeftConfig.ChannelCount <> RightConfig.ChannelCount) or
      (LeftConfig.StepCount <> RightConfig.StepCount) or
      (LeftConfig.IntakeChannel <> RightConfig.IntakeChannel) or
      (LeftConfig.MaxFlowRate <> RightConfig.MaxFlowRate) or
      (LeftConfig.Operation.Volume <> RightConfig.Operation.Volume) or
      (LeftConfig.Operation.Speed <> RightConfig.Operation.Speed) or
      (LeftConfig.Operation.Channel <> RightConfig.Operation.Channel) then
      Exit(False);
  end;
  Result := True;
end;

procedure TConfigurationForm.UpdateApplyButton;
var
  Candidate: TDispenserConfigList;
  ErrorText: string;
begin
  btnGenerate.Enabled := False;
  if FReadOnly then
    Exit;

  Candidate := nil;
  if not FRows.BuildConfigurations(Candidate, ErrorText) then
  begin
    btnGenerate.Enabled := FHasAnyEdits;
    Exit;
  end;

  try
    btnGenerate.Enabled := not SameConfigurations(Candidate,
      FInitialConfigurations);
  finally
    Candidate.Free;
  end;
end;

procedure TConfigurationForm.btnAddDispenserClick(Sender: TObject);
var
  ErrorText: string;
begin
  if FReadOnly then
    Exit;
  if not FRows.AddDispenser(ErrorText) then
    ShowMessage(ErrorText);
end;

procedure TConfigurationForm.btnMoveUpClick(Sender: TObject);
begin
  if FReadOnly then
    Exit;
  FRows.MoveUp(Sender);
end;

procedure TConfigurationForm.btnMoveDownClick(Sender: TObject);
begin
  if FReadOnly then
    Exit;
  FRows.MoveDown(Sender);
end;

procedure TConfigurationForm.btnDeleteRowClick(Sender: TObject);
begin
  if FReadOnly then
    Exit;
  FRows.DeleteRow(Sender);
end;

function TConfigurationForm.BuildConfigurations(
  out AConfigurations: TDispenserConfigList; out ErrorText: string): Boolean;
begin
  Result := FRows.BuildConfigurations(AConfigurations, ErrorText);
end;

procedure TConfigurationForm.btnGenerateClick(Sender: TObject);
var
  NewConfigurations: TDispenserConfigList;
  ErrorText: string;
begin
  if FReadOnly or not btnGenerate.Enabled then
    Exit;

  if not BuildConfigurations(NewConfigurations, ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;

  try
    if not Assigned(FOnApply) then
    begin
      ShowMessage('Не задан обработчик применения конфигурации.');
      Exit;
    end;

    if not FOnApply(NewConfigurations, ErrorText) then
    begin
      ShowMessage(ErrorText);
      Exit;
    end;

    ModalResult := mrOk;
  finally
    NewConfigurations.Free;
  end;
end;

end.
