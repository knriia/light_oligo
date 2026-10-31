unit UProtocolBlockForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons,
  ExtCtrls, AppState;

type

  { TProtocolBlockForm }

  TProtocolBlockForm = class(TForm)
    BB_Ok: TBitBtn;
    BB_Cancel: TBitBtn;
    LE_String: TLabeledEdit;
    procedure BB_OkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  ProtocolBlockForm: TProtocolBlockForm;

implementation
uses UMainForm;
{$R *.lfm}

{ TProtocolBlockForm }

procedure TProtocolBlockForm.FormCreate(Sender: TObject);
begin
  ProtocolBlockForm.Caption:=MyInterface.ReadString('AddBlock','ProtocolBlockForm','AddBlock');
  LE_String.EditLabel.Caption:=MyInterface.ReadString('AddBlock','LE_String','Add BlockName');
  BB_Cancel.Caption:=MyInterface.ReadString('AddBlock','BB_Cancel','Cancel');
  BB_Ok.Caption:=MyInterface.ReadString('AddBlock','BB_Ok','OK');

  LE_String.Text:=MyIni.ReadString('AddBlock','LE_String','BlockName');
end;

procedure TProtocolBlockForm.BB_OkClick(Sender: TObject);
begin
   MyBlockName:=LE_String.Text;
   ModalResult:=mrOk;
end;


end.

