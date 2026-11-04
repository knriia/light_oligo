unit UScenarioOperationForm;
// Окно операции сценария станции. Устроено как окно добавления операции
// протокола синтеза (те же размеры и расположение полей), но в нём только
// две операции: шприцевая станция и пауза. Поля шприцевой станции
// проверяются тем же CheckSyringeStep, что и в протоколе. Окно ничего не
// знает о списке: получает операцию и возвращает введённую.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, ExtCtrls,
  StdCtrls, Spin, ProtocolFormat, ScenarioList;

type

  { TScenarioOperationForm }

  TScenarioOperationForm = class(TForm)
    BB_Cancel: TBitBtn;
    BB_Ok: TBitBtn;
    CB_SyrSpeedUnit: TComboBox;
    CB_SyrVolumeUnit: TComboBox;
    GB_Pause: TGroupBox;
    GB_SyrSt: TGroupBox;
    L_Pause: TLabel;
    LE_SyrNames: TLabeledEdit;
    LE_SyrSpeeds: TLabeledEdit;
    LE_SyrValves: TLabeledEdit;
    LE_SyrVolumes: TLabeledEdit;
    Panel1: TPanel;
    Panel2: TPanel;
    RG_Operator: TRadioGroup;
    SE_Pause: TSpinEdit;
    procedure BB_OkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RG_OperatorClick(Sender: TObject);
  private
    procedure ShowOperationPanel;
    function EnteredStep: TSyringeStep;
    procedure LoadStep(const AStep: TSyringeStep);
  public
    procedure LoadItem(const AItem: TScenarioItem);
    function EnteredItem: TScenarioItem;
  end;

// Операция для нового элемента: шприцевая станция с типовыми значениями.
function DefaultScenarioOperation: TScenarioItem;
// True - пользователь нажал OK и значения проверены; AItem заменяется.
function EditScenarioOperation(const ACaption: string;
  var AItem: TScenarioItem): Boolean;

implementation

{$R *.lfm}

const
  OPERATION_SYRINGE = 0;
  OPERATION_PAUSE = 1;

function DefaultScenarioOperation: TScenarioItem;
var
  Step: TSyringeStep;
begin
  Step := Default(TSyringeStep);
  Step.Dispensers := 'W';
  Step.Valves := '2';
  Step.Volumes := '100';
  Step.VolumeUnit := VOLUME_UNITS[1];
  Step.Speeds := '10';
  Step.SpeedUnit := SPEED_UNITS[1];
  Result := MakeSyringe(Step);
end;

function EditScenarioOperation(const ACaption: string;
  var AItem: TScenarioItem): Boolean;
var
  Form: TScenarioOperationForm;
begin
  Form := TScenarioOperationForm.Create(Application);
  try
    Form.Caption := ACaption;
    Form.LoadItem(AItem);
    Result := Form.ShowModal = mrOk;
    if Result then
      AItem := Form.EnteredItem;
  finally
    Form.Free;
  end;
end;

{ TScenarioOperationForm }

procedure TScenarioOperationForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  for I := Low(VOLUME_UNITS) to High(VOLUME_UNITS) do
    CB_SyrVolumeUnit.Items.Add(VOLUME_UNITS[I]);
  for I := Low(SPEED_UNITS) to High(SPEED_UNITS) do
    CB_SyrSpeedUnit.Items.Add(SPEED_UNITS[I]);
  CB_SyrVolumeUnit.ItemIndex := 1;
  CB_SyrSpeedUnit.ItemIndex := 1;
  ShowOperationPanel;
end;

procedure TScenarioOperationForm.RG_OperatorClick(Sender: TObject);
begin
  ShowOperationPanel;
end;

procedure TScenarioOperationForm.ShowOperationPanel;
// Показываем поля выбранной операции
begin
  GB_SyrSt.Visible := RG_Operator.ItemIndex = OPERATION_SYRINGE;
  GB_Pause.Visible := RG_Operator.ItemIndex = OPERATION_PAUSE;
end;

function TScenarioOperationForm.EnteredStep: TSyringeStep;
begin
  Result := Default(TSyringeStep);
  Result.Dispensers := Trim(LE_SyrNames.Text);
  Result.Valves := Trim(LE_SyrValves.Text);
  Result.Volumes := Trim(LE_SyrVolumes.Text);
  Result.VolumeUnit := CB_SyrVolumeUnit.Text;
  Result.Speeds := Trim(LE_SyrSpeeds.Text);
  Result.SpeedUnit := CB_SyrSpeedUnit.Text;
end;

procedure TScenarioOperationForm.LoadStep(const AStep: TSyringeStep);

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
  LE_SyrNames.Text := AStep.Dispensers;
  LE_SyrValves.Text := AStep.Valves;
  LE_SyrVolumes.Text := AStep.Volumes;
  LE_SyrSpeeds.Text := AStep.Speeds;
  SelectUnit(CB_SyrVolumeUnit, AStep.VolumeUnit);
  SelectUnit(CB_SyrSpeedUnit, AStep.SpeedUnit);
end;

procedure TScenarioOperationForm.LoadItem(const AItem: TScenarioItem);
begin
  if AItem.Kind = sikPause then
  begin
    RG_Operator.ItemIndex := OPERATION_PAUSE;
    SE_Pause.Value := AItem.PauseSeconds;
    LoadStep(DefaultScenarioOperation.Syringe);
  end
  else
  begin
    RG_Operator.ItemIndex := OPERATION_SYRINGE;
    LoadStep(AItem.Syringe);
  end;
  ShowOperationPanel;
end;

function TScenarioOperationForm.EnteredItem: TScenarioItem;
begin
  if RG_Operator.ItemIndex = OPERATION_PAUSE then
    Result := MakePause(SE_Pause.Value)
  else
    Result := MakeSyringe(EnteredStep);
end;

procedure TScenarioOperationForm.BB_OkClick(Sender: TObject);
var
  ErrorText: string;
begin
  // Имена дозаторов и лимиты проверяет станция при запуске; здесь проверяем,
  // что запись заполнена и согласована.
  if not CheckScenarioItem(EnteredItem, ErrorText) then
  begin
    ShowMessage(ErrorText);
    ModalResult := mrNone; // окно остаётся открытым для исправления
  end;
end;

end.
