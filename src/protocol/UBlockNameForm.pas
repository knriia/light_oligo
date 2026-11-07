unit UBlockNameForm;
// Окно имени блока протокола: добавление блока и переименование. Окно
// ничего не знает о протоколе: получает имя и возвращает введённое.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, ExtCtrls,
  IniFiles, ProtocolModel;

type

  { TBlockNameForm }

  TBlockNameForm = class(TForm)
    BB_Cancel: TBitBtn;
    BB_Ok: TBitBtn;
    LE_String: TLabeledEdit;
    procedure BB_OkClick(Sender: TObject);
  private
    procedure ApplyCaptions(ACaptions: TCustomIniFile);
  end;

// True - пользователь нажал OK и имя проверено; AName заменяется.
// ACaption пустой - заголовок из файла подписей или по умолчанию.
// ACaptions - файл подписей интерфейса (раздел AddBlock) или nil.
function EditBlockName(const ACaption: string; var AName: string;
  ACaptions: TCustomIniFile = nil): Boolean;

implementation

{$R *.lfm}

const
  CAPTIONS_SECTION = 'AddBlock';

function EditBlockName(const ACaption: string; var AName: string;
  ACaptions: TCustomIniFile): Boolean;
var
  Form: TBlockNameForm;
begin
  Form := TBlockNameForm.Create(Application);
  try
    Form.ApplyCaptions(ACaptions);
    if ACaption <> '' then
      Form.Caption := ACaption;
    Form.LE_String.Text := AName;
    Result := Form.ShowModal = mrOk;
    if Result then
      AName := Trim(Form.LE_String.Text);
  finally
    Form.Free;
  end;
end;

procedure TBlockNameForm.ApplyCaptions(ACaptions: TCustomIniFile);
begin
  if ACaptions = nil then
    Exit;
  Caption := ACaptions.ReadString(CAPTIONS_SECTION, 'ProtocolBlockForm', Caption);
  LE_String.EditLabel.Caption := ACaptions.ReadString(CAPTIONS_SECTION,
    'LE_String', LE_String.EditLabel.Caption);
  BB_Cancel.Caption := ACaptions.ReadString(CAPTIONS_SECTION, 'BB_Cancel',
    BB_Cancel.Caption);
  BB_Ok.Caption := ACaptions.ReadString(CAPTIONS_SECTION, 'BB_Ok',
    BB_Ok.Caption);
end;

procedure TBlockNameForm.BB_OkClick(Sender: TObject);
var
  ErrorText: string;
begin
  if not CheckProtocolBlockName(Trim(LE_String.Text), ErrorText) then
  begin
    ShowMessage(ErrorText);
    ModalResult := mrNone; // окно остаётся открытым для исправления
  end;
end;

end.
