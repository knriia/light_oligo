unit UChoiceForm;
// Окно выбора одного пункта из списка (алгоритм слайсинга, слайс проекта).
// Собирается кодом, файла формы нет.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls;

// True - выбрали пункт и нажали OK; тогда AIndex - номер пункта (с 0).
// При отмене AIndex не меняется. Если AIndex допустим, этот пункт выбран
// заранее; иначе заранее выбран первый.
function ChooseFromList(const ACaption, APrompt: string; AItems: TStrings;
  var AIndex: Integer): Boolean;

implementation

type
  TChoiceForm = class(TForm)
  private
    FList: TListBox;
    procedure ListDblClick(Sender: TObject);
    procedure ChoiceCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateChoice(AOwner: TComponent; const ACaption, APrompt: string;
      AItems: TStrings; AIndex: Integer);
    property List: TListBox read FList;
  end;

constructor TChoiceForm.CreateChoice(AOwner: TComponent; const ACaption,
  APrompt: string; AItems: TStrings; AIndex: Integer);
var
  Prompt: TLabel;
  OkButton, CancelButton: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := ACaption;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := 360;
  ClientHeight := 240;
  OnCloseQuery := @ChoiceCloseQuery;

  Prompt := TLabel.Create(Self);
  Prompt.Parent := Self;
  Prompt.Left := 8;
  Prompt.Top := 8;
  Prompt.Caption := APrompt;

  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.SetBounds(8, 32, 344, 160);
  FList.Items.Assign(AItems);
  if (AIndex >= 0) and (AIndex < FList.Items.Count) then
    FList.ItemIndex := AIndex
  else if FList.Items.Count > 0 then
    FList.ItemIndex := 0;
  FList.OnDblClick := @ListDblClick;

  OkButton := TButton.Create(Self);
  OkButton.Parent := Self;
  OkButton.SetBounds(188, 204, 80, 26);
  OkButton.Caption := 'OK';
  OkButton.ModalResult := mrOK;
  OkButton.Default := True;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Self;
  CancelButton.SetBounds(272, 204, 80, 26);
  CancelButton.Caption := 'Отмена';
  CancelButton.ModalResult := mrCancel;
  CancelButton.Cancel := True;
end;

procedure TChoiceForm.ListDblClick(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then
    ModalResult := mrOK;
end;

procedure TChoiceForm.ChoiceCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // OK без выбранного пункта окно не закрывает
  if ModalResult = mrOK then
    CanClose := FList.ItemIndex >= 0;
end;

function ChooseFromList(const ACaption, APrompt: string; AItems: TStrings;
  var AIndex: Integer): Boolean;
var
  Form: TChoiceForm;
begin
  Form := TChoiceForm.CreateChoice(nil, ACaption, APrompt, AItems, AIndex);
  try
    Result := Form.ShowModal = mrOK;
    if Result then
      AIndex := Form.List.ItemIndex;
  finally
    Form.Free;
  end;
end;

end.
