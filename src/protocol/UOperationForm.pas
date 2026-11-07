unit UOperationForm;
// Окно операции: протокол синтеза и сценарий станции вводят операции одним
// окном. Слева типы операций, справа поля выбранного типа. Набор типов
// задаёт вызывающий: протокол - все пять, сценарий станции - шприцевая
// станция и пауза. Окно ничего не знает о списках и глобальных данных:
// получает операцию и возвращает введённую.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, ExtCtrls,
  StdCtrls, Spin, IniFiles, ProtocolFormat;

type
  TProtocolStepKinds = set of TProtocolStepKind;

const
  // Типы, которые можно ввести окном, в порядке списка слева.
  OPERATION_KINDS_IN_ORDER: array[0..4] of TProtocolStepKind =
    (pskSyringe, pskVacuum, pskLaser, pskPause, pskComment);
  ALL_OPERATION_KINDS = [pskSyringe, pskVacuum, pskLaser, pskPause, pskComment];

type

  { TOperationForm }

  TOperationForm = class(TForm)
    BB_Cancel: TBitBtn;
    BB_Ok: TBitBtn;
    CB_SyrSpeedUnit: TComboBox;
    CB_SyrVolumeUnit: TComboBox;
    ChB_Vac: TCheckBox;
    GB_Comment: TGroupBox;
    GB_Laser: TGroupBox;
    GB_Pause: TGroupBox;
    GB_SyrSt: TGroupBox;
    GB_Vac: TGroupBox;
    L_LasRepeats: TLabel;
    L_LasTime: TLabel;
    L_Pause: TLabel;
    LE_Comment: TLabeledEdit;
    LE_SyrNames: TLabeledEdit;
    LE_SyrSpeeds: TLabeledEdit;
    LE_SyrValves: TLabeledEdit;
    LE_SyrVolumes: TLabeledEdit;
    Panel1: TPanel;
    Panel2: TPanel;
    RG_Operator: TRadioGroup;
    SE_LasRepeats: TSpinEdit;
    SE_LasTime: TSpinEdit;
    SE_Pause: TSpinEdit;
    procedure BB_OkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RG_OperatorClick(Sender: TObject);
  private
    FKinds: array of TProtocolStepKind; // тип операции для каждой строки списка
    function SelectedKind: TProtocolStepKind;
    procedure ShowOperationPanel;
    function EnteredStep: TProtocolStep;
    procedure LoadStep(const AStep: TProtocolStep);
  public
    // Задаёт, какие типы можно выбрать, и подписи из файла интерфейса
    // (раздел Operator); без файла остаются русские подписи формы.
    procedure Setup(AAllowed: TProtocolStepKinds; ACaptions: TCustomIniFile);
  end;

// Значения по умолчанию для новой операции выбранного типа.
function DefaultOperation(AKind: TProtocolStepKind = pskSyringe): TProtocolStep;
// True - пользователь нажал OK и значения проверены; AStep заменяется.
// ACaption пустой - заголовок из файла подписей или по умолчанию.
function EditOperation(const ACaption: string; AAllowed: TProtocolStepKinds;
  var AStep: TProtocolStep; ACaptions: TCustomIniFile = nil): Boolean;

implementation

{$R *.lfm}

const
  CAPTIONS_SECTION = 'Operator';

function DefaultOperation(AKind: TProtocolStepKind): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := AKind;
  case AKind of
    pskSyringe:
      begin
        Result.Syringe.Dispensers := 'A';
        Result.Syringe.Valves := '1';
        Result.Syringe.Volumes := '100';
        Result.Syringe.VolumeUnit := VOLUME_UNITS[1];
        Result.Syringe.Speeds := '10';
        Result.Syringe.SpeedUnit := SPEED_UNITS[1];
      end;
    pskVacuum: Result.BoolValue := True;
    pskLaser:
      begin
        Result.IntValue := 1;
        Result.FloatValue := 10;
      end;
    pskPause: Result.IntValue := 10;
  end;
end;

function EditOperation(const ACaption: string; AAllowed: TProtocolStepKinds;
  var AStep: TProtocolStep; ACaptions: TCustomIniFile): Boolean;
var
  Form: TOperationForm;
begin
  Form := TOperationForm.Create(Application);
  try
    Form.Setup(AAllowed, ACaptions);
    if ACaption <> '' then
      Form.Caption := ACaption;
    Form.LoadStep(AStep);
    Result := Form.ShowModal = mrOk;
    if Result then
      AStep := Form.EnteredStep;
  finally
    Form.Free;
  end;
end;

{ TOperationForm }

procedure TOperationForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  for I := Low(VOLUME_UNITS) to High(VOLUME_UNITS) do
    CB_SyrVolumeUnit.Items.Add(VOLUME_UNITS[I]);
  for I := Low(SPEED_UNITS) to High(SPEED_UNITS) do
    CB_SyrSpeedUnit.Items.Add(SPEED_UNITS[I]);
  CB_SyrVolumeUnit.ItemIndex := 1;
  CB_SyrSpeedUnit.ItemIndex := 1;
end;

procedure TOperationForm.Setup(AAllowed: TProtocolStepKinds;
  ACaptions: TCustomIniFile);
var
  I: Integer;
  Kind: TProtocolStepKind;
  PauseName: string;

  function Cap(const AKey: string; const ADefault: string): string;
  begin
    if ACaptions = nil then
      Result := ADefault
    else
      Result := ACaptions.ReadString(CAPTIONS_SECTION, AKey, ADefault);
  end;

begin
  PauseName := 'Пауза';
  if ACaptions <> nil then
  begin
    Caption := Cap('ProtocolOperationForm', Caption);
    RG_Operator.Caption := Cap('RG_Operator', RG_Operator.Caption);
    BB_Cancel.Caption := Cap('BB_Cancel', BB_Cancel.Caption);
    BB_Ok.Caption := Cap('BB_Ok', BB_Ok.Caption);
    GB_SyrSt.Caption := Cap('GB_SyrSt', GB_SyrSt.Caption);
    LE_SyrNames.EditLabel.Caption := Cap('LE_SyrNames', LE_SyrNames.EditLabel.Caption);
    LE_SyrValves.EditLabel.Caption := Cap('LE_SyrValves', LE_SyrValves.EditLabel.Caption);
    LE_SyrVolumes.EditLabel.Caption := Cap('LE_SyrVolumes', LE_SyrVolumes.EditLabel.Caption);
    LE_SyrSpeeds.EditLabel.Caption := Cap('LE_SyrSpeeds', LE_SyrSpeeds.EditLabel.Caption);
    GB_Vac.Caption := Cap('GB_Vac', GB_Vac.Caption);
    ChB_Vac.Caption := Cap('ChB_Vac', ChB_Vac.Caption);
    GB_Laser.Caption := Cap('GB_Laser', GB_Laser.Caption);
    L_LasRepeats.Caption := Cap('L_LasRepeats', L_LasRepeats.Caption);
    L_LasTime.Caption := Cap('L_LasTime', L_LasTime.Caption);
    GB_Pause.Caption := Cap('GB_Pause', GB_Pause.Caption);
    L_Pause.Caption := Cap('L_Pause', L_Pause.Caption);
    GB_Comment.Caption := Cap('GB_Comment', GB_Comment.Caption);
    LE_Comment.EditLabel.Caption := Cap('LE_Comment', LE_Comment.EditLabel.Caption);
    PauseName := Cap('Pause_RG', PauseName);
  end;

  FKinds := nil;
  RG_Operator.Items.Clear;
  for I := Low(OPERATION_KINDS_IN_ORDER) to High(OPERATION_KINDS_IN_ORDER) do
  begin
    Kind := OPERATION_KINDS_IN_ORDER[I];
    if not (Kind in AAllowed) then
      Continue;
    SetLength(FKinds, Length(FKinds) + 1);
    FKinds[High(FKinds)] := Kind;
    case Kind of
      pskSyringe: RG_Operator.Items.Add(Cap('SyringeStation_RG', GB_SyrSt.Caption));
      pskVacuum: RG_Operator.Items.Add(Cap('Vacuum_RG', GB_Vac.Caption));
      pskLaser: RG_Operator.Items.Add(Cap('Laser_RG', GB_Laser.Caption));
      pskPause: RG_Operator.Items.Add(PauseName);
      pskComment: RG_Operator.Items.Add(Cap('Comment_RG', GB_Comment.Caption));
    end;
  end;
  if Length(FKinds) > 0 then
    RG_Operator.ItemIndex := 0;
  ShowOperationPanel;
end;

function TOperationForm.SelectedKind: TProtocolStepKind;
begin
  if (RG_Operator.ItemIndex >= 0) and (RG_Operator.ItemIndex <= High(FKinds)) then
    Result := FKinds[RG_Operator.ItemIndex]
  else
    Result := pskSyringe;
end;

procedure TOperationForm.RG_OperatorClick(Sender: TObject);
begin
  ShowOperationPanel;
end;

procedure TOperationForm.ShowOperationPanel;
// Показываем поля выбранного типа операции
var
  Kind: TProtocolStepKind;
begin
  Kind := SelectedKind;
  GB_SyrSt.Visible := Kind = pskSyringe;
  GB_Vac.Visible := Kind = pskVacuum;
  GB_Laser.Visible := Kind = pskLaser;
  GB_Pause.Visible := Kind = pskPause;
  GB_Comment.Visible := Kind = pskComment;
end;

function TOperationForm.EnteredStep: TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := SelectedKind;
  case Result.Kind of
    pskSyringe:
      begin
        Result.Syringe.Dispensers := Trim(LE_SyrNames.Text);
        Result.Syringe.Valves := Trim(LE_SyrValves.Text);
        Result.Syringe.Volumes := Trim(LE_SyrVolumes.Text);
        Result.Syringe.VolumeUnit := CB_SyrVolumeUnit.Text;
        Result.Syringe.Speeds := Trim(LE_SyrSpeeds.Text);
        Result.Syringe.SpeedUnit := CB_SyrSpeedUnit.Text;
      end;
    pskVacuum: Result.BoolValue := ChB_Vac.Checked;
    pskLaser:
      begin
        Result.IntValue := SE_LasRepeats.Value;
        Result.FloatValue := SE_LasTime.Value;
      end;
    pskPause: Result.IntValue := SE_Pause.Value;
    pskComment: Result.Text := Trim(LE_Comment.Text);
  end;
end;

procedure TOperationForm.LoadStep(const AStep: TProtocolStep);
// Поля выбранного типа берём из операции, остальные - по умолчанию.
var
  I: Integer;
  Syringe: TSyringeStep;

  procedure SelectUnit(ACombo: TComboBox; const AUnit: string);
  var
    Index: Integer;
  begin
    Index := ACombo.Items.IndexOf(AUnit);
    if Index < 0 then
      Index := 1;
    ACombo.ItemIndex := Index;
  end;

begin
  if AStep.Kind = pskSyringe then
    Syringe := AStep.Syringe
  else
    Syringe := DefaultOperation(pskSyringe).Syringe;
  LE_SyrNames.Text := Syringe.Dispensers;
  LE_SyrValves.Text := Syringe.Valves;
  LE_SyrVolumes.Text := Syringe.Volumes;
  LE_SyrSpeeds.Text := Syringe.Speeds;
  SelectUnit(CB_SyrVolumeUnit, Syringe.VolumeUnit);
  SelectUnit(CB_SyrSpeedUnit, Syringe.SpeedUnit);

  ChB_Vac.Checked := (AStep.Kind <> pskVacuum) or AStep.BoolValue;
  if AStep.Kind = pskLaser then
  begin
    SE_LasRepeats.Value := AStep.IntValue;
    SE_LasTime.Value := Round(AStep.FloatValue);
  end
  else
  begin
    SE_LasRepeats.Value := DefaultOperation(pskLaser).IntValue;
    SE_LasTime.Value := Round(DefaultOperation(pskLaser).FloatValue);
  end;
  if AStep.Kind = pskPause then
    SE_Pause.Value := AStep.IntValue
  else
    SE_Pause.Value := DefaultOperation(pskPause).IntValue;
  if AStep.Kind = pskComment then
    LE_Comment.Text := AStep.Text
  else
    LE_Comment.Text := '';

  for I := 0 to High(FKinds) do
    if FKinds[I] = AStep.Kind then
      RG_Operator.ItemIndex := I;
  ShowOperationPanel;
end;

procedure TOperationForm.BB_OkClick(Sender: TObject);
var
  ErrorText: string;
begin
  // Имена дозаторов и лимиты проверяет станция при запуске; здесь проверяем,
  // что запись заполнена и согласована.
  if not CheckProtocolStep(EnteredStep, ErrorText) then
  begin
    ShowMessage(ErrorText);
    ModalResult := mrNone; // окно остаётся открытым для исправления
  end;
end;

end.
